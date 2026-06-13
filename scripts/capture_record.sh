#!/usr/bin/env bash
# capture_record.sh <audio-mode> <out-file> [wf-recorder extra args…]
#
# audio-mode: none | system | mic | both
#   system — first PulseAudio monitor source (what the speakers play)
#   mic    — the default input source
#   both   — wf-recorder takes a single device, so mic + system are mixed
#            into a temporary null sink (module-null-sink + 2× loopback)
#            and its monitor is recorded; modules unload between segments.
#
# Signals:
#   SIGUSR1 — toggle pause. wf-recorder can't pause, so each pause boundary
#             finalizes the current segment and resume starts the next one;
#             the final stop concatenates segments losslessly (ffmpeg -c copy).
#   SIGUSR2 — re-read "<out-file>.audioctl" and restart the segment with the
#             new audio source (live audio switching, same segment trick).
#   SIGINT/SIGTERM — stop: finalize, concat, clean up.
set -u

mode="$1"
out="$2"
shift 2

# Optional "--hw <render-node>": VAAPI encode when a libva driver exists
# (silent CPU fallback otherwise — e.g. before intel-media-driver is
# installed). Cross-GPU encode is broken in wf-recorder, so only pass the
# compositor's node here.
hwdev=""
extra=()
while [ $# -gt 0 ]; do
    if [ "$1" = "--hw" ] && [ $# -ge 2 ]; then
        hwdev="$2"
        shift 2
    else
        extra+=("$1")
        shift
    fi
done

ctl="$out.audioctl"
vizfile="$out.vizsource"   # device the QML visualizer should read (matches --audio)
outdir="$(dirname "$out")"
mkdir -p "$outdir"
segdir="$outdir/.pshell_rec_$$"
mkdir -p "$segdir"

enc_args=(--pixel-format yuv420p)
if [ -n "$hwdev" ] && [ -e "$hwdev" ] && { [ -e /usr/lib/dri/iHD_drv_video.so ] || [ -e /usr/lib/dri/i965_drv_video.so ]; }; then
    enc_args=(-c h264_vaapi -d "$hwdev")
fi

base_args=("${enc_args[@]}" "${extra[@]}")

seg_modules=()
audio_args=()

# Unload pshell_rec leftovers from a crashed session.
pactl list short modules 2>/dev/null | grep pshell_rec | cut -f1 | while read -r m; do
    pactl unload-module "$m" 2>/dev/null
done

# Creating the mix sink: WirePlumber may promote a freshly created null sink
# to the DEFAULT sink, silently stealing every new audio stream (Spotify
# started mid-recording plays into the mixer → speakers go mute). Snapshot
# the default and restore it right after loading.
load_mix_sink() {
    local prev sink_id
    prev="$(pactl get-default-sink 2>/dev/null)"
    # priority.session/driver=0 → WirePlumber ranks the mixer below any real
    # card so it won't pick it as the fallback default in the first place.
    sink_id="$(pactl load-module module-null-sink sink_name=pshell_rec sink_properties='device.description=pShell-recording priority.session=0 priority.driver=0')"
    seg_modules+=("$sink_id")
    if [ -n "$prev" ] && [ "$prev" != pshell_rec ]; then
        pactl set-default-sink "$prev" 2>/dev/null
        # Priority alone isn't always enough: WirePlumber can still async-promote
        # a freshly created node to default a beat later, which would silently
        # route (and, in none/both modes, RECORD) the user's audio through the
        # mixer. Re-assert the real default over the ~1s promotion window.
        (
            for _ in 1 2 3 4 5 6; do
                sleep 0.15
                [ "$(pactl get-default-sink 2>/dev/null)" = pshell_rec ] &&
                    pactl set-default-sink "$prev" 2>/dev/null
            done
        ) &
    fi
}

setup_audio() {
    local m="$1"
    audio_args=()
    case "$m" in
    none)
        # A silent track keeps the stream layout identical across segments,
        # so live audio switching survives the final concat.
        load_mix_sink
        audio_args=("--audio=pshell_rec.monitor")
        ;;
    system)
        # Default sink's monitor — deterministic, follows where audio plays.
        local sink mon=""
        sink="$(pactl get-default-sink 2>/dev/null)"
        [ -n "$sink" ] && mon="$sink.monitor"
        audio_args=("--audio${mon:+=$mon}")
        ;;
    mic)
        local src
        src="$(pactl get-default-source 2>/dev/null)"
        audio_args=("--audio${src:+=$src}")
        ;;
    both)
        local lp_mic mon lp_sys
        load_mix_sink
        lp_mic="$(pactl load-module module-loopback source=@DEFAULT_SOURCE@ sink=pshell_rec latency_msec=20)"
        seg_modules+=("$lp_mic")
        mon=""
        local bsink
        bsink="$(pactl get-default-sink 2>/dev/null)"
        [ -n "$bsink" ] && mon="$bsink.monitor"
        if [ -n "$mon" ]; then
            lp_sys="$(pactl load-module module-loopback source="$mon" sink=pshell_rec latency_msec=20)"
            seg_modules+=("$lp_sys")
        fi
        audio_args=("--audio=pshell_rec.monitor")
        ;;
    esac
}

teardown_audio() {
    local i
    for ((i = ${#seg_modules[@]} - 1; i >= 0; i--)); do
        pactl unload-module "${seg_modules[i]}" 2>/dev/null
    done
    seg_modules=()
}

segs=()
seg_i=0
pid=""

start_seg() {
    local m
    m="$(cat "$ctl" 2>/dev/null || true)"
    [ -n "$m" ] || m="$mode"
    teardown_audio
    setup_audio "$m"
    # Publish the exact device the visualizer should read (the --audio target).
    # Empty for none (silent mixer) and for any "--audio" without a device, so
    # the viz stays hidden instead of guessing.
    local vsrc=""
    if [ "$m" != none ] && [ "${#audio_args[@]}" -gt 0 ]; then
        case "${audio_args[0]}" in
        --audio=*) vsrc="${audio_args[0]#--audio=}" ;;
        esac
    fi
    printf '%s' "$vsrc" > "$vizfile" 2>/dev/null || true
    seg_i=$((seg_i + 1))
    local seg="$segdir/seg_$seg_i.mp4"
    segs+=("$seg")
    wf-recorder "${base_args[@]}" "${audio_args[@]}" -f "$seg" &
    pid=$!
}

end_seg() {
    if [ -n "$pid" ]; then
        kill -INT "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        pid=""
    fi
}

want=run
restart=0
stop=0
trap 'if [ "$want" = run ]; then want=pause; else want=run; fi' USR1
trap 'restart=1' USR2
trap 'stop=1' INT TERM

start_seg

while :; do
    if [ "$stop" = 1 ]; then
        end_seg
        break
    fi
    if [ "$restart" = 1 ]; then
        restart=0
        if [ "$want" = run ]; then
            end_seg
            start_seg
        fi
        # paused: the new mode is picked up by the next resume's start_seg
    fi
    if [ "$want" = pause ] && [ -n "$pid" ]; then
        end_seg
    elif [ "$want" = run ] && [ -z "$pid" ]; then
        start_seg
    fi
    sleep 0.2 &
    wait $! 2>/dev/null
done

# Assemble the final file.
if [ "${#segs[@]}" -eq 1 ] && [ -s "${segs[0]}" ]; then
    mv "${segs[0]}" "$out"
else
    list="$segdir/list.txt"
    : > "$list"
    for s in "${segs[@]}"; do
        [ -s "$s" ] && printf "file '%s'\n" "$s" >> "$list"
    done
    if [ -s "$list" ]; then
        ffmpeg -y -f concat -safe 0 -i "$list" -c copy "$out" < /dev/null > /dev/null 2>&1
    fi
fi
rm -rf "$segdir"
rm -f "$ctl" "$vizfile"

teardown_audio

[ -s "$out" ]

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import QtQuick

Singleton {
    id: root

    readonly property var osIcons: ({
            almalinux: "",
            alpine: "",
            arch: "",
            archcraft: "",
            arcolinux: "",
            artix: "",
            centos: "",
            debian: "",
            devuan: "",
            elementary: "",
            endeavouros: "",
            fedora: "",
            freebsd: "",
            garuda: "",
            gentoo: "",
            hyperbola: "",
            kali: "",
            linuxmint: "󰣭",
            mageia: "",
            openmandriva: "",
            manjaro: "",
            neon: "",
            nixos: "",
            opensuse: "",
            suse: "",
            sles: "",
            sles_sap: "",
            "opensuse-tumbleweed": "",
            parrot: "",
            pop: "",
            raspbian: "",
            rhel: "",
            rocky: "",
            slackware: "",
            solus: "",
            steamos: "",
            tails: "",
            trisquel: "",
            ubuntu: "",
            vanilla: "",
            void: "",
            zorin: ""
        })

    // readonly property var weatherIcons: ({
    //         "113": "\ueb30",//"clear_day",
    //         "116": "partly_cloudy_day",
    //         "119": "cloud",
    //         "122": "cloud",
    //         "143": "foggy",
    //         "176": "rainy",
    //         "179": "rainy",
    //         "182": "rainy",
    //         "185": "rainy",
    //         "200": "thunderstorm",
    //         "227": "cloudy_snowing",
    //         "230": "snowing_heavy",
    //         "248": "foggy",
    //         "260": "foggy",
    //         "263": "rainy",
    //         "266": "rainy",
    //         "281": "rainy",
    //         "284": "rainy",
    //         "293": "rainy",
    //         "296": "rainy",
    //         "299": "rainy",
    //         "302": "weather_hail",
    //         "305": "rainy",
    //         "308": "weather_hail",
    //         "311": "rainy",
    //         "314": "rainy",
    //         "317": "rainy",
    //         "320": "cloudy_snowing",
    //         "323": "cloudy_snowing",
    //         "326": "cloudy_snowing",
    //         "329": "snowing_heavy",
    //         "332": "snowing_heavy",
    //         "335": "snowing",
    //         "338": "snowing_heavy",
    //         "350": "rainy",
    //         "353": "rainy",
    //         "356": "rainy",
    //         "359": "weather_hail",
    //         "362": "rainy",
    //         "365": "rainy",
    //         "368": "cloudy_snowing",
    //         "371": "snowing",
    //         "374": "rainy",
    //         "377": "rainy",
    //         "386": "thunderstorm",
    //         "389": "thunderstorm",
    //         "392": "thunderstorm",
    //         "395": "snowing"
    //     })

    readonly property var weatherIcons: ({
        "113": "󰖙",
        "116": "󰖕",
        "119": "󰖐",
        "122": "󰖕",
        "143": "󰖑",
        "176": "󰼳",
        "179": "󰼵",
        "182": "󰙿",
        "185": "󰙿",
        "200": "󰙾",
        "227": "󰼴",
        "230": "󰼶",
        "248": "󰖑",
        "260": "󰖑",
        "263": "󰼳",
        "266": "󰼳",
        "281": "󰙿",
        "284": "󰙿",
        "293": "󰼳",
        "296": "󰼳",
        "299": "󰖖",
        "302": "󰖖",
        "305": "󰖖",
        "308": "󰖖",
        "311": "󰙿",
        "314": "󰙿",
        "317": "󰙿",
        "320": "󰼴",
        "323": "󰼵",
        "326": "󰼵",
        "329": "󰼶",
        "332": "󰼶",
        "335": "󰼵",
        "338": "󰼶",
        "350": "󰙿",
        "353": "󰼳",
        "356": "󰖖",
        "359": "󰖖",
        "362": "󰼵",
        "365": "󰼵",
        "368": "󰼵",
        "371": "󰼵",
        "374": "󰼵",
        "377": "󰙿",
        "386": "󰙾",
        "389": "󰙾",
        "392": "󰼶",
        "395": "󰼵",
        })


    readonly property var desktopEntrySubs: ({
            "gimp-3.0": "gimp"
        })

    readonly property var categoryIcons: ({
            WebBrowser: "\uefe6",//"web",
            Printing: "\ueb0e",//"print",
            Security: "security",
            Network: "chat",
            Archiving: "archive",
            Compression: "archive",
            Development: "code",
            IDE: "code",
            TextEditor: "edit_note",
            Audio: "music_note",
            Music: "music_note",
            Player: "music_note",
            Recorder: "mic",
            Game: "\ueb63",//"sports_esports",
            FileTools: "\ueaad",//"files",
            FileManager: "\ueaad",//"files",
            Filesystem: "\ueaad",//"files",
            FileTransfer: "\ueaad",//"files",
            Settings: "\ueb20",//"settings",
            DesktopSettings: "\ueb20",//"settings",
            HardwareSettings: "\ueb20",//"settings",
            TerminalEmulator: "\uebef",//"terminal",
            ConsoleOnly: "\uebef",//"terminal",
            Utility: "build",
            Monitor: "\uee77",//"monitor_heart",
            Midi: "graphic_eq",
            Mixer: "graphic_eq",
            AudioVideoEditing: "video_settings",
            AudioVideo: "music_video",
            Video: "videocam",
            Building: "construction",
            Graphics: "photo_library",
            "2DGraphics": "photo_library",
            RasterGraphics: "\uea8d",//"photo_library",
            TV: "\uea8d",//"tv",
            System: "host",
            Office: "\uf398"//"content_paste"
        })

    property string osIcon: ""
    property string osName

    function getDesktopEntry(name: string): DesktopEntry {
        name = name.toLowerCase().replace(/ /g, "-");

        if (desktopEntrySubs.hasOwnProperty(name))
            name = desktopEntrySubs[name];

        return DesktopEntries.applications.values.find(a => a.id.toLowerCase() === name) ?? null;
    }

    function getAppIcon(name: string, fallback: string): string {
        return Quickshell.iconPath(getDesktopEntry(name)?.icon, fallback);
    }

    function getAppCategoryIcon(name: string, fallback: string): string {
        const categories = getDesktopEntry(name)?.categories;

        if (categories)
            for (const [key, value] of Object.entries(categoryIcons))
                if (categories.includes(key))
                    return value;
        return fallback;
    }

    function getNetworkIcon(strength: int): string {
        if (strength >= 75)
            return "\ueb52";//"signal_wifi_4_bar";
        if (strength >= 50)
            return "\ueba5";//"network_wifi_3_bar";
        if (strength >= 25)
            return "\ueba4";//"network_wifi_2_bar";
        //if (strength >= 20)
        return "\ueba3";//"network_wifi_1_bar";
        //return "";//"signal_wifi_0_bar";
    }

    function getBluetoothIcon(icon: string): string {
        // if (icon.includes("headset") || icon.includes("headphones"))
        if (icon.includes("headset"))
            return "\ueabd";
        if (icon.includes("headphones"))
            return "\uf5a9";//"headphones";
        if (icon.includes("audio"))
            return "\uea8b";//"speaker";
        if (icon.includes("phone"))
            return "\uea8a";//"smartphone";
        if (icon.includes("mouse"))
            return "\ueaf9";//"mouse";
        if (icon.includes("keyboard"))
            return "\uebd6";//"keyboard";
        return "\uecea";//"bluetooth";
    }

    // ── OSD glyphs (tabler codepoints verified against the installed cmap) ──
    function getVolumeIcon(value: real, muted: bool): string {
        if (muted)
            return "\uf1c3";//"volume-off";
        if (value <= 0)
            return "\ueb50";//"volume-3" (speaker, no waves)
        if (value < 0.5)
            return "\ueb4f";//"volume-2" (one wave)
        return "\ueb51";//"volume" (full)
    }

    function getMicVolumeIcon(value: real, muted: bool): string {
        if (muted)
            return "\ued16";//"microphone-off";
        return "\ueaf0";//"microphone";
    }

    function getBrightnessIcon(value: real): string {
        if (value < 0.34)
            return "\uf237";//"sun-low";
        if (value < 0.67)
            return "\ueb30";//"sun";
        return "\uf236";//"sun-high";
    }

    function getWeatherIcon(code: string): string {
        if (weatherIcons.hasOwnProperty(code))
            return weatherIcons[code];
        return "air";
    }

    // open-meteo WMO weather codes → tabler glyphs (used by services/Weather).
    readonly property var wmoIcons: ({
            "0": "\ueb30",
            "1": "\ueb30",
            "2": "\uea76",
            "3": "\uea76",
            "45": "\uecd9",
            "48": "\uecd9",
            "51": "\uea72",
            "53": "\uea72",
            "55": "\uea72",
            "56": "\uea72",
            "57": "\uea72",
            "61": "\uea72",
            "63": "\uea72",
            "65": "\uea72",
            "66": "\uea72",
            "67": "\uea72",
            "71": "\uea73",
            "73": "\uea73",
            "75": "\uea73",
            "77": "\uea73",
            "80": "\uea72",
            "81": "\uea72",
            "82": "\uea72",
            "85": "\uea73",
            "86": "\uea73",
            "95": "\uea74",
            "96": "\uea74",
            "99": "\uea74"
        })

    function getWeatherIconWmo(code: var): string {
        const k = String(code);
        return wmoIcons.hasOwnProperty(k) ? wmoIcons[k] : "\uea76";
    }

    // Tabler codepoints (all consumers render through StyledIcon) — verified
    // against the installed tabler-icons.ttf cmap.
    function getNotifIcon(summary: string, urgency: int): string {
        if (summary.includes("reboot"))
            return "\uebb5"; // rotate-clockwise-2
        if (summary.includes("recording"))
            return "\ued22"; // video
        if (summary.includes("battery"))
            return "\uea34"; // battery
        if (summary.includes("screenshot"))
            return "\uea54"; // camera
        if (summary.includes("welcome"))
            return "\uec2e"; // hand-stop
        if (summary.includes("time") || summary.includes("a break"))
            return "\uea70"; // clock
        if (summary.includes("installed"))
            return "\uea96"; // download
        if (summary.includes("update"))
            return "\ued57"; // refresh-alert
        if (summary.includes("unable to"))
            return "\uea05"; // alert-circle
        if (summary.includes("profile"))
            return "\ueb4d"; // user
        if (summary.includes("file"))
            return "\uedef"; // files
        if (urgency === NotificationUrgency.Critical)
            return "\uea06"; // alert-triangle
        return "\ueaef"; // message
    }

    FileView {
        path: "/etc/os-release"
        onLoaded: {
            const lines = text().split("\n");
            let osId = lines.find(l => l.startsWith("ID="))?.split("=")[1].replace(/"/g, "");
            if (root.osIcons.hasOwnProperty(osId))
                root.osIcon = root.osIcons[osId];
            else {
                const osIdLike = lines.find(l => l.startsWith("ID_LIKE="))?.split("=")[1].replace(/"/g, "");
                if (osIdLike)
                    for (const id of osIdLike.split(" "))
                        if (root.osIcons.hasOwnProperty(id))
                            return root.osIcon = root.osIcons[id];
            }

            let nameLine = lines.find(l => l.startsWith("PRETTY_NAME="));
            if (!nameLine)
                nameLine = lines.find(l => l.startsWith("NAME="));
            root.osName = nameLine.split("=")[1].replace(/"/g, "");
        }
    }
    function getSpecialWsIcon(name: string): string {
        name = name.toLowerCase().slice("special:".length);

        for (const iconConfig of Config.bar.workspaces.specialWorkspaceIcons)
            if (iconConfig.name === name)
                return iconConfig.icon;

        if (name === "special")
            return "\uf698";
        if (name === "communication")
            return "\uea56";
        if (name === "music")
            return "\uebc1";
        if (name === "todo")
            return "\uef76";
        if (name === "sysmon")
            return "\uee77";
        return name[0].toUpperCase();
    }

    function getTrayIcon(id: string, icon: string): string {
        for (const sub of Config.bar.tray.iconSubs)
            if (sub.id === id)
                return sub.image ? Qt.resolvedUrl(sub.image) : Quickshell.iconPath(sub.icon);

        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=");
            icon = Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
        }
        return icon;
    }
}

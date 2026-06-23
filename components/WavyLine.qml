import QtQuick

// QtQuick Canvas port of caelestia's WavyLine (a C++ QQuickPaintedItem in their
// Caelestia.Components plugin). Faithful reimplementation of its linear paint:
// a sine wave stroked with a round cap, used as the filled part of a wavy slider.
// `fullLength`/`startX` keep the wavelength constant (and continuous) as the fill
// grows, so the wave doesn't stretch. Only repaints on a property change — when
// `waveProgress` is static (not animating) it costs nothing per frame.
Canvas {
    id: root

    property int lineWidth: 4
    property real amplitudeMultiplier: 0.5
    property int frequency: 6
    property real startX: 0
    property real fullLength: width
    property color color: "white"
    property real waveProgress: 0
    property real value: 1

    antialiasing: true

    onLineWidthChanged: requestPaint()
    onAmplitudeMultiplierChanged: requestPaint()
    onFrequencyChanged: requestPaint()
    onStartXChanged: requestPaint()
    onFullLengthChanged: requestPaint()
    onColorChanged: requestPaint()
    onWaveProgressChanged: requestPaint()
    onValueChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.lineWidth = lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = color;

        const amplitude = lineWidth * amplitudeMultiplier;
        const phase = waveProgress * 2 * Math.PI;
        const centerY = height / 2;
        const len = fullLength > 0 ? fullLength : 1;
        const start = lineWidth / 2;
        const fullEnd = width - lineWidth / 2;
        const drawEnd = start + (fullEnd - start) * value;

        ctx.beginPath();
        let first = true;
        for (let x = lineWidth / 2; x <= drawEnd; x++) {
            const theta = frequency * 2 * Math.PI * (x + startX) / len + phase;
            const waveY = centerY + amplitude * Math.sin(theta);
            if (first) {
                ctx.moveTo(x, waveY);
                first = false;
            } else {
                ctx.lineTo(x, waveY);
            }
        }
        ctx.stroke();
    }
}

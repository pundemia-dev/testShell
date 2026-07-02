pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import qs.components.controls
import QtQuick

// Flameshot-style button ring (ButtonHandler port): individual round buttons
// wrap around the selection — bottom edge (l→r), right edge (b→t), top edge
// (r→l), left edge (t→b) — preserving button order along the ring. When a
// side is blocked by the screen edge it is skipped; when a ring is full the
// virtual rect expands one cell and the next ring continues; when nothing
// fits outside at all (selection ≈ whole screen) buttons fall back to rows
// inside the selection, bottom-up. Small selections therefore get several
// concentric rings instead of overflowing.
Item {
    id: root

    required property var editor

    anchors.fill: parent

    readonly property var buttonModel: [
        { kind: "tool", tool: "pencil", glyph: "" },
        { kind: "tool", tool: "line", glyph: "" },
        { kind: "tool", tool: "arrow", glyph: "" },
        { kind: "tool", tool: "rect", glyph: "" },
        { kind: "tool", tool: "ellipse", glyph: "" },
        { kind: "tool", tool: "marker", glyph: "" },
        { kind: "tool", tool: "text", glyph: "" },
        { kind: "tool", tool: "counter", glyph: "" },
        { kind: "tool", tool: "blur", glyph: "" },
        { kind: "tool", tool: "pixelate", glyph: "" },
        { kind: "swatch", glyph: "" },
        { kind: "undo", glyph: "" },
        { kind: "redo", glyph: "" },
        { kind: "copy", glyph: "" },
        { kind: "save", glyph: "" },
        { kind: "ocr", glyph: "" },
        { kind: "lens", glyph: "\uf364" },
        { kind: "record", glyph: "\ued22" },
        { kind: "close", glyph: "" }
    ]

    readonly property real btnSize: Appearance.font.size.large + Appearance.padding.medium * 2 + Appearance.padding.small
    readonly property real sep: Appearance.spacing.small

    readonly property var positions: layout()

    // Resting rect of the OCR button — OcrPanel flows its SDF blob out of
    // this, so the panel reads as leaking straight from the button.
    readonly property rect ocrButtonRect: {
        const i = buttonModel.findIndex(b => b.kind === "ocr");
        const p = i >= 0 ? positions[i] : null;
        return p ? Qt.rect(p.x, p.y, btnSize, btnSize) : Qt.rect(0, 0, 0, 0);
    }

    function dispatch(entry: var): void {
        switch (entry.kind) {
        case "tool":
            editor.activeTool = editor.activeTool === entry.tool ? "" : entry.tool;
            break;
        case "swatch":
            editor.openPalette();
            break;
        case "undo":
            editor.undo();
            break;
        case "redo":
            editor.redo();
            break;
        case "copy":
            editor.commit(true);
            break;
        case "save":
            editor.commit(false);
            break;
        case "ocr":
            editor.toggleOcr();
            break;
        case "lens":
            editor.commitLens();
            break;
        case "record":
            editor.requestRecord();
            break;
        case "close":
            editor.dismissed();
            break;
        }
    }

    function layout(): var {
        const count = buttonModel.length;
        const B = btnSize, S = sep, cell = B + S;
        const W = width, H = height;
        let rx = editor.selX, ry = editor.selY, rw = editor.selW, rh = editor.selH;
        const pos = [];

        // Centered run of n cells along one side, preserving ring direction.
        const addRun = (horizontal, centerC, fixed, n, forward) => {
            const cs = [];
            let c = centerC - (n * cell - S) / 2;
            for (let k = 0; k < n; k++)
                cs.push(c + k * cell);
            if (!forward)
                cs.reverse();
            for (const v of cs) {
                if (pos.length >= count)
                    return;
                pos.push(horizontal ? { x: v, y: fixed } : { x: fixed, y: v });
            }
        };

        let guard = 0;
        while (pos.length < count && guard++ < 6) {
            const bB = ry + rh + S + B > H;
            const bT = ry - S - B < 0;
            const bR = rx + rw + S + B > W;
            const bL = rx - S - B < 0;
            if (bB && bT && bR && bL)
                break;
            const perRow = Math.max(1, Math.floor((rw + S) / cell));
            const perCol = Math.max(1, Math.floor((rh + S) / cell));
            if (!bB && pos.length < count)
                addRun(true, rx + rw / 2, ry + rh + S, Math.min(perRow, count - pos.length), true);
            if (!bR && pos.length < count)
                addRun(false, ry + rh / 2, rx + rw + S, Math.min(perCol, count - pos.length), false);
            if (!bT && pos.length < count)
                addRun(true, rx + rw / 2, ry - S - B, Math.min(perRow, count - pos.length), false);
            if (!bL && pos.length < count)
                addRun(false, ry + rh / 2, rx - S - B, Math.min(perCol, count - pos.length), true);
            // Expand one ring outward, clamped to the screen.
            const nx = Math.max(0, rx - cell), ny = Math.max(0, ry - cell);
            const nx2 = Math.min(W, rx + rw + cell), ny2 = Math.min(H, ry + rh + cell);
            if (nx === rx && ny === ry && nx2 === rx + rw && ny2 === ry + rh)
                break;
            rx = nx;
            ry = ny;
            rw = nx2 - nx;
            rh = ny2 - ny;
        }

        // Fallback: rows inside the selection, bottom-up.
        if (pos.length < count) {
            const perRow = Math.max(1, Math.floor((editor.selW + S) / cell));
            let y = editor.selY + editor.selH - S - B;
            while (pos.length < count) {
                addRun(true, editor.selX + editor.selW / 2, Math.max(0, y), Math.min(perRow, count - pos.length), true);
                y -= cell;
            }
        }

        for (const p of pos) {
            p.x = Math.max(0, Math.min(W - B, p.x));
            p.y = Math.max(0, Math.min(H - B, p.y));
        }
        return pos;
    }

    Repeater {
        model: root.buttonModel

        IconButton {
            id: btn

            required property var modelData
            required property int index

            x: (root.positions[index] ?? ({ x: 0, y: 0 })).x
            y: (root.positions[index] ?? ({ x: 0, y: 0 })).y
            width: root.btnSize
            height: root.btnSize
            type: IconButton.Tonal
            font.pointSize: Appearance.font.size.large
            icon: modelData.glyph
            checked: (modelData.kind === "tool" && root.editor.activeTool === modelData.tool) || (modelData.kind === "ocr" && root.editor.ocrOpen)
            disabled: modelData.kind === "undo" ? root.editor.undoStack.length === 0 : modelData.kind === "redo" ? root.editor.redoStack.length === 0 : false
            onClicked: root.dispatch(modelData)

            Component.onCompleted: {
                // The swatch button's palette glyph is tinted with the active
                // draw colour (it is never disabled, so the lost binding is fine).
                if (modelData.kind === "swatch")
                    label.color = Qt.binding(() => root.editor.drawColor);
            }
        }
    }
}

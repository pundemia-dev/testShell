pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick
import "tools"

// Flameshot-style region editor. The toolbar with every annotation tool is
// visible as soon as a selection exists, and the selection stays movable and
// resizable the whole time:
//   no tool  → drag inside moves, edges/corners resize, drag outside reselects,
//              click on an object selects it (drag moves, Del removes);
//   tool     → drag draws; wheel adjusts thickness; RMB opens the palette.
// Commit renders selection + annotations through an offscreen composite at
// physical resolution (1:1 source pixels), so nothing is resampled.
Item {
    id: root

    required property real outputScale
    required property int physW
    required property int physH
    required property string srcPath
    required property bool srcReady
    required property Item baseItem
    required property Item keyTarget
    required property string outPath
    required property string ocrPath

    signal dismissed()
    // Output-local LOGICAL selection rect; the scope opens the top-panel
    // audio chooser and recording starts from there.
    signal recordRequested(real x, real y, real w, real h)
    // Physical-px selection rect for the Google Lens upload (pure source).
    signal lensRequested(real x, real y, real w, real h)

    anchors.fill: parent
    visible: srcReady

    // ── Cursor (fed by hover AND drag so it never freezes mid-drag) ─
    property real cursorX: 0
    property real cursorY: 0
    readonly property bool hovered: hover.hovered || ma.containsMouse || ma.pressed
    readonly property bool interacting: dragMode !== ""
    readonly property bool aiming: activeTool !== "" || !hasSelection

    // ── Selection (logical px) ──────────────────────────────────────
    property bool hasSelection: false
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    readonly property bool selVisible: hasSelection || dragMode === "select"

    // ── Interaction state ───────────────────────────────────────────
    property string dragMode: ""   // select | move | resize | draw | moveObj
    property real pressX: 0
    property real pressY: 0
    property real origX: 0
    property real origY: 0
    property real origW: 0
    property real origH: 0
    property int resizeEdges: 0    // bits: 1=left 2=right 4=top 8=bottom
    property var origRow: null
    property var preState: null
    property var penPts: []

    // ── Tools ───────────────────────────────────────────────────────
    property string activeTool: ""
    property color drawColor: Colours.palette.primary
    property int thickness: Config.capture.drawThickness
    property int counterNext: 1
    property int selectedObj: -1
    property int editingObj: -1
    property var selObjRect: null
    property var undoStack: []
    property var redoStack: []
    property bool committing: false

    // ── Smart regions (optional; double-click snaps to a detected box).
    // Detector missing/failing ⇒ empty list ⇒ double-click is a no-op and
    // the selector behaves exactly as without the feature.
    property var smartRects: []   // logical px

    function smartRectAt(x: real, y: real): var {
        let best = null;
        for (const r of smartRects) {
            if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
                if (!best || r.w * r.h < best.w * best.h)
                    best = r;
            }
        }
        return best;
    }

    readonly property var smartHover: Config.capture.smartRegions && !hasSelection && srcReady ? smartRectAt(cursorX, cursorY) : null

    Process {
        id: regionsProc

        running: root.srcReady && Config.capture.smartRegions
        command: [`${Quickshell.configDir}/scripts/capture_regions.py`, root.srcPath]

        stdout: StdioCollector {
            id: regionsOut

            onStreamFinished: {
                try {
                    const phys = JSON.parse(regionsOut.text);
                    const s = root.outputScale;
                    root.smartRects = phys.map(r => ({
                        x: r.x / s,
                        y: r.y / s,
                        w: r.width / s,
                        h: r.height / s
                    }));
                } catch (e) {
                    root.smartRects = [];
                }
            }
        }
    }

    // ── Radial palette (RMB / toolbar swatch) ───────────────────────
    property bool paletteOpen: false
    property var palettePos: ({ x: 0, y: 0 })

    function openPalette(): void {
        palettePos = { x: cursorX, y: cursorY };
        paletteOpen = true;
    }

    onActiveToolChanged: {
        selectedObj = -1;
        selObjRect = null;
    }

    ListModel {
        id: objects
    }

    // ── Model helpers ───────────────────────────────────────────────
    function newRow(type: string): var {
        return {
            type: type,
            colorStr: "" + drawColor,
            thickness: thickness,
            rx: 0,
            ry: 0,
            rw: 0,
            rh: 0,
            px2: 0,
            py2: 0,
            ptsJson: "[]",
            textStr: "",
            n: 0,
            editing: false,
            fontPt: Appearance.font.size.normal + thickness * 3
        };
    }

    function serialize(): var {
        const arr = [];
        for (let i = 0; i < objects.count; i++) {
            const r = objects.get(i);
            arr.push({
                type: r.type,
                colorStr: r.colorStr,
                thickness: r.thickness,
                rx: r.rx,
                ry: r.ry,
                rw: r.rw,
                rh: r.rh,
                px2: r.px2,
                py2: r.py2,
                ptsJson: r.ptsJson,
                textStr: r.textStr,
                n: r.n,
                editing: false,
                fontPt: r.fontPt
            });
        }
        return arr;
    }

    function restore(arr: var): void {
        objects.clear();
        for (const r of arr)
            objects.append(r);
        selectedObj = -1;
        selObjRect = null;
        editingObj = -1;
    }

    function pushUndo(state: var): void {
        undoStack = [...undoStack, state];
        redoStack = [];
    }

    function undo(): void {
        if (undoStack.length === 0)
            return;
        redoStack = [...redoStack, serialize()];
        const stack = [...undoStack];
        restore(stack.pop());
        undoStack = stack;
    }

    function redo(): void {
        if (redoStack.length === 0)
            return;
        undoStack = [...undoStack, serialize()];
        const stack = [...redoStack];
        restore(stack.pop());
        redoStack = stack;
    }

    function deleteSelected(): void {
        if (selectedObj < 0)
            return;
        pushUndo(serialize());
        objects.remove(selectedObj);
        selectedObj = -1;
        selObjRect = null;
    }

    // ── Geometry helpers ────────────────────────────────────────────
    function clampv(v: real, lo: real, hi: real): real {
        return Math.max(lo, Math.min(hi, v));
    }

    function edgeAt(x: real, y: real): int {
        if (!hasSelection)
            return 0;
        const t = Appearance.padding.large;
        const inX = x >= selX - t && x <= selX + selW + t;
        const inY = y >= selY - t && y <= selY + selH + t;
        let e = 0;
        if (Math.abs(x - selX) <= t && inY)
            e |= 1;
        if (Math.abs(x - (selX + selW)) <= t && inY)
            e |= 2;
        if (Math.abs(y - selY) <= t && inX)
            e |= 4;
        if (Math.abs(y - (selY + selH)) <= t && inX)
            e |= 8;
        return e;
    }

    function insideSel(x: real, y: real): bool {
        return hasSelection && x >= selX && x <= selX + selW && y >= selY && y <= selY + selH;
    }

    function handlePos(i: int): var {
        const xs = [selX, selX + selW / 2, selX + selW];
        const ys = [selY, selY + selH / 2, selY + selH];
        const map = [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [0, 2], [1, 2], [2, 2]];
        return { x: xs[map[i][0]], y: ys[map[i][1]] };
    }

    function objBounds(i: int): var {
        const r = objects.get(i);
        switch (r.type) {
        case "rect":
        case "ellipse":
        case "blur":
        case "pixelate":
            return Qt.rect(r.rx, r.ry, r.rw, r.rh);
        case "line":
        case "arrow":
        case "marker":
            return Qt.rect(Math.min(r.rx, r.px2), Math.min(r.ry, r.py2), Math.abs(r.px2 - r.rx), Math.abs(r.py2 - r.ry));
        case "pencil": {
            const pts = JSON.parse(r.ptsJson);
            let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
            for (const p of pts) {
                minX = Math.min(minX, p.x);
                minY = Math.min(minY, p.y);
                maxX = Math.max(maxX, p.x);
                maxY = Math.max(maxY, p.y);
            }
            return Qt.rect(minX, minY, Math.max(0, maxX - minX), Math.max(0, maxY - minY));
        }
        case "text":
            return Qt.rect(r.rx, r.ry, Math.max(20, r.textStr.length * r.fontPt * 0.7), r.fontPt * 1.8);
        case "counter": {
            const d = Appearance.font.size.large + r.thickness * 3;
            return Qt.rect(r.rx - d / 2, r.ry - d / 2, d, d);
        }
        }
        return Qt.rect(0, 0, 0, 0);
    }

    function hitObject(x: real, y: real): int {
        const pad = Appearance.padding.smaller;
        for (let i = objects.count - 1; i >= 0; i--) {
            const b = objBounds(i);
            if (x >= b.x - pad && x <= b.x + b.width + pad && y >= b.y - pad && y <= b.y + b.height + pad)
                return i;
        }
        return -1;
    }

    // ── Interaction steps ───────────────────────────────────────────
    function updateSelect(mx: real, my: real): void {
        const x = clampv(mx, 0, width);
        const y = clampv(my, 0, height);
        selX = Math.min(pressX, x);
        selY = Math.min(pressY, y);
        selW = Math.abs(x - pressX);
        selH = Math.abs(y - pressY);
    }

    function applyResize(mx: real, my: real): void {
        let x1 = origX, y1 = origY, x2 = origX + origW, y2 = origY + origH;
        const dx = mx - pressX, dy = my - pressY;
        if (resizeEdges & 1)
            x1 = clampv(origX + dx, 0, x2 - 1);
        if (resizeEdges & 2)
            x2 = clampv(origX + origW + dx, x1 + 1, width);
        if (resizeEdges & 4)
            y1 = clampv(origY + dy, 0, y2 - 1);
        if (resizeEdges & 8)
            y2 = clampv(origY + origH + dy, y1 + 1, height);
        selX = x1;
        selY = y1;
        selW = x2 - x1;
        selH = y2 - y1;
    }

    function startDraw(mx: real, my: real): void {
        preState = serialize();
        if (activeTool === "counter") {
            const row = newRow("counter");
            row.rx = mx;
            row.ry = my;
            row.n = counterNext++;
            objects.append(row);
            pushUndo(preState);
            preState = null;
            return;
        }
        if (activeTool === "text") {
            const row = newRow("text");
            row.rx = mx;
            row.ry = my - row.fontPt;
            row.editing = true;
            objects.append(row);
            editingObj = objects.count - 1;
            return;
        }
        const row = newRow(activeTool);
        row.rx = mx;
        row.ry = my;
        row.px2 = mx;
        row.py2 = my;
        if (activeTool === "pencil") {
            penPts = [{ x: mx, y: my }];
            row.ptsJson = JSON.stringify(penPts);
        }
        objects.append(row);
        dragMode = "draw";
    }

    function applyDraw(mx: real, my: real): void {
        const i = objects.count - 1;
        if (activeTool === "pencil") {
            penPts.push({ x: mx, y: my });
            objects.setProperty(i, "ptsJson", JSON.stringify(penPts));
        } else if (activeTool === "line" || activeTool === "arrow" || activeTool === "marker") {
            objects.setProperty(i, "px2", mx);
            objects.setProperty(i, "py2", my);
        } else {
            objects.setProperty(i, "rx", Math.min(pressX, mx));
            objects.setProperty(i, "ry", Math.min(pressY, my));
            objects.setProperty(i, "rw", Math.abs(mx - pressX));
            objects.setProperty(i, "rh", Math.abs(my - pressY));
        }
    }

    function finishDraw(): void {
        const i = objects.count - 1;
        const r = objects.get(i);
        let valid = true;
        if (r.type === "rect" || r.type === "ellipse" || r.type === "blur" || r.type === "pixelate")
            valid = r.rw > 2 && r.rh > 2;
        else if (r.type === "line" || r.type === "arrow" || r.type === "marker")
            valid = Math.hypot(r.px2 - r.rx, r.py2 - r.ry) > 2;
        else if (r.type === "pencil")
            valid = JSON.parse(r.ptsJson).length > 1;
        if (valid)
            pushUndo(preState);
        else
            objects.remove(i);
        preState = null;
    }

    function startMoveObj(i: int): void {
        dragMode = "moveObj";
        preState = serialize();
        const r = objects.get(i);
        origRow = {
            rx: r.rx,
            ry: r.ry,
            px2: r.px2,
            py2: r.py2,
            pts: JSON.parse(r.ptsJson)
        };
    }

    function applyMoveObj(mx: real, my: real): void {
        const dx = mx - pressX, dy = my - pressY;
        const i = selectedObj;
        objects.setProperty(i, "rx", origRow.rx + dx);
        objects.setProperty(i, "ry", origRow.ry + dy);
        objects.setProperty(i, "px2", origRow.px2 + dx);
        objects.setProperty(i, "py2", origRow.py2 + dy);
        if (objects.get(i).type === "pencil")
            objects.setProperty(i, "ptsJson", JSON.stringify(origRow.pts.map(p => ({ x: p.x + dx, y: p.y + dy }))));
        selObjRect = objBounds(i);
    }

    // ── Text commit ─────────────────────────────────────────────────
    function commitEditingText(): void {
        if (editingObj < 0)
            return;
        const item = rep.itemAt(editingObj);
        if (item)
            item.commitNow();
        else
            editingObj = -1;
    }

    function commitText(index: int, text: string): void {
        if (index < 0 || index >= objects.count)
            return;
        editingObj = -1;
        if (text.trim() === "") {
            objects.remove(index);
            preState = null;
        } else {
            objects.setProperty(index, "textStr", text);
            objects.setProperty(index, "editing", false);
            if (preState !== null) {
                pushUndo(preState);
                preState = null;
            }
        }
        keyTarget.forceActiveFocus();
    }

    // ── Escape chain: text → palette → tool → (overlay dismisses) ──
    function handleEscape(): bool {
        if (editingObj >= 0) {
            commitEditingText();
            return true;
        }
        if (paletteOpen) {
            paletteOpen = false;
            return true;
        }
        if (ocrOpen) {
            ocrOpen = false;
            return true;
        }
        if (activeTool !== "") {
            activeTool = "";
            return true;
        }
        if (selectedObj >= 0) {
            selectedObj = -1;
            selObjRect = null;
            return true;
        }
        return false;
    }

    // ── Commit: offscreen composite → PNG → copy / save ────────────
    function commit(copyIt: bool): void {
        if (!hasSelection || committing)
            return;
        if (editingObj >= 0)
            commitEditingText();
        committing = true;
        const copy = copyIt;
        const ok = composite.grabToImage(res => {
            res.saveToFile(root.outPath);
            Capture.run(copy ? Capture.copyFileCommand(root.outPath) : Capture.saveFileCommand(root.outPath));
            root.dismissed();
        });
        if (!ok)
            committing = false;
    }

    // ── OCR: inline panel, the selection stays adjustable ──────────
    // Recognition reruns automatically when the frame is moved/resized
    // (on release) and when the language toggle changes. The crop is the
    // pure source grab — annotations never pollute recognition.
    property bool ocrOpen: false
    property bool ocrRunning: false
    property string ocrText: ""
    property string ocrLangsSel: ""

    function ocrInitialLangs(): string {
        const def = Config.capture.ocrDefaultLang;
        if (def === "auto")
            return Config.capture.ocrLastLangs;
        if (def === "all" || def === "")
            return "";
        return def;
    }

    function requestRecord(): void {
        if (!hasSelection || committing)
            return;
        recordRequested(selX, selY, selW, selH);
        dismissed();
    }

    function commitLens(): void {
        if (!hasSelection || committing)
            return;
        const s = outputScale;
        lensRequested(Math.round(selX * s), Math.round(selY * s), Math.max(1, Math.round(selW * s)), Math.max(1, Math.round(selH * s)));
        dismissed();
    }

    function toggleOcr(): void {
        if (ocrOpen) {
            ocrOpen = false;
            return;
        }
        if (!hasSelection || committing)
            return;
        ocrLangsSel = ocrInitialLangs();
        ocrOpen = true;
        runOcrCrop();
    }

    function selectOcrLangs(langs: string): void {
        if (ocrLangsSel === langs)
            return;
        ocrLangsSel = langs;
        // Persisted through the config adapter → "auto" default remembers it.
        Config.capture.ocrLastLangs = langs;
        runOcrRecognize();
    }

    function runOcrCrop(): void {
        if (!hasSelection) {
            ocrOpen = false;
            return;
        }
        ocrRunning = true;
        ocrCropProc.running = false;
        ocrProc.running = false;
        const s = outputScale;
        ocrCropProc.command = Capture.ocrCropCommand(srcPath, Math.round(selX * s), Math.round(selY * s), Math.max(1, Math.round(selW * s)), Math.max(1, Math.round(selH * s)), ocrPath);
        ocrCropProc.running = true;
    }

    function runOcrRecognize(): void {
        ocrRunning = true;
        ocrProc.running = false;
        const langs = ocrLangsSel !== "" ? ocrLangsSel : (Capture.ocrLangsAvailable.join("+") || "eng");
        ocrProc.command = ["bash", "-c", `tesseract '${Capture.shq(ocrPath)}' stdout -l '${Capture.shq(langs)}' 2>/dev/null`];
        ocrProc.running = true;
    }

    Process {
        id: ocrCropProc

        onExited: code => {
            if (code === 0)
                root.runOcrRecognize();
            else
                root.ocrRunning = false;
        }
    }

    Process {
        id: ocrProc

        stdout: StdioCollector {
            id: ocrOut

            onStreamFinished: {
                root.ocrText = ocrOut.text.trim();
                root.ocrRunning = false;
                if (root.ocrText)
                    Capture.copyText(root.ocrText);
            }
        }
    }

    HoverHandler {
        id: hover

        onPointChanged: {
            root.cursorX = point.position.x;
            root.cursorY = point.position.y;
        }
    }

    // ── Annotation layer (above the frozen grab, below the dim) ────
    Item {
        anchors.fill: parent

        Repeater {
            id: rep

            model: objects

            AnnotationItem {
                effectSource: root.baseItem
                pixelateFactor: Config.capture.pixelateFactor
                interactive: true
                onEditCommit: (i, t) => root.commitText(i, t)
            }
        }
    }

    // ── Dim: full-screen before a selection, hole-trick after ──────
    readonly property int dimBorder: Math.max(width, height)

    StyledRect {
        anchors.fill: parent
        visible: !root.selVisible
        color: Colours.palette.scrim
        opacity: Config.capture.dimStrength
    }

    StyledRect {
        visible: root.selVisible
        x: root.selX - root.dimBorder
        y: root.selY - root.dimBorder
        width: root.selW + root.dimBorder * 2
        height: root.selH + root.dimBorder * 2
        color: "transparent"
        border.color: Qt.alpha(Colours.palette.scrim, Config.capture.dimStrength)
        border.width: root.dimBorder
    }

    // ── Aim lines (only while choosing a selection) ─────────────────
    Rectangle {
        visible: !root.hasSelection && root.hovered && Config.capture.showAimLines
        x: Math.round(root.cursorX)
        y: 0
        width: 1
        height: parent.height
        color: Colours.palette.primary
        opacity: 0.4
    }

    Rectangle {
        visible: !root.hasSelection && root.hovered && Config.capture.showAimLines
        x: 0
        y: Math.round(root.cursorY)
        width: parent.width
        height: 1
        color: Colours.palette.primary
        opacity: 0.4
    }

    // ── Smart-region candidate under the cursor ─────────────────────
    Rectangle {
        visible: root.smartHover !== null
        x: root.smartHover?.x ?? 0
        y: root.smartHover?.y ?? 0
        width: root.smartHover?.w ?? 0
        height: root.smartHover?.h ?? 0
        color: Qt.alpha(Colours.palette.primary, 0.1)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.primary, 0.6)
        radius: Appearance.rounding.small / 2
    }

    // ── Selection border + size readout + handles ───────────────────
    DashedRect {
        visible: root.selVisible
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH
        strokeColor: Colours.palette.primary
        strokeWidth: Config.capture.dashWidth
        dashLength: Config.capture.dashLength
        gapLength: Config.capture.dashGap
        cornerRadius: Appearance.rounding.small
    }

    StyledRect {
        visible: root.selVisible
        x: Math.min(root.selX + root.selW - width, root.width - width)
        y: root.selY + root.selH + Appearance.spacing.small
        implicitWidth: dimsText.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: dimsText.implicitHeight + Appearance.padding.smaller * 2
        radius: Appearance.rounding.small
        color: Colours.palette.surface_container

        StyledText {
            id: dimsText

            anchors.centerIn: parent
            color: Colours.palette.on_surface
            text: `${Math.round(root.selW * root.outputScale)} × ${Math.round(root.selH * root.outputScale)}`
        }
    }

    Repeater {
        model: 8

        Rectangle {
            required property int index

            readonly property var hp: root.handlePos(index)

            visible: root.hasSelection && root.activeTool === "" && (root.dragMode === "" || root.dragMode === "resize")
            x: hp.x - width / 2
            y: hp.y - height / 2
            width: Appearance.padding.larger
            height: width
            radius: width / 2
            color: Colours.palette.primary
            border.width: 1
            border.color: Colours.palette.surface
        }
    }

    // ── Selected-object indicator ───────────────────────────────────
    DashedRect {
        visible: root.selectedObj >= 0 && root.selObjRect !== null
        x: (root.selObjRect?.x ?? 0) - Appearance.padding.small
        y: (root.selObjRect?.y ?? 0) - Appearance.padding.small
        width: (root.selObjRect?.width ?? 0) + Appearance.padding.small * 2
        height: (root.selObjRect?.height ?? 0) + Appearance.padding.small * 2
        strokeColor: Colours.palette.on_surface
        strokeWidth: 1
        dashLength: 4
        gapLength: 4
        cornerRadius: Appearance.rounding.small / 2
    }

    // ── Input ───────────────────────────────────────────────────────
    MouseArea {
        id: ma

        anchors.fill: parent
        enabled: root.srcReady && !root.committing
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // Hover is on so the wl_pointer.enter that arrives when the overlay
        // maps under the cursor seeds the crosshair immediately — no mouse
        // movement needed before the aim visuals appear.
        hoverEnabled: true
        onEntered: {
            root.cursorX = mouseX;
            root.cursorY = mouseY;
        }

        cursorShape: {
            if (!root.hasSelection || root.activeTool !== "")
                return Qt.BlankCursor;
            const e = root.edgeAt(root.cursorX, root.cursorY);
            if (e === 5 || e === 10)
                return Qt.SizeFDiagCursor;
            if (e === 6 || e === 9)
                return Qt.SizeBDiagCursor;
            if (e === 1 || e === 2)
                return Qt.SizeHorCursor;
            if (e === 4 || e === 8)
                return Qt.SizeVerCursor;
            if (root.insideSel(root.cursorX, root.cursorY))
                return Qt.SizeAllCursor;
            return Qt.CrossCursor;
        }

        onWheel: wheel => {
            const d = wheel.angleDelta.y > 0 ? 1 : -1;
            root.thickness = Math.max(1, Math.min(24, root.thickness + d));
            if (root.selectedObj >= 0) {
                objects.setProperty(root.selectedObj, "thickness", root.thickness);
                root.selObjRect = root.objBounds(root.selectedObj);
            }
            notifyTimer.restart();
        }

        onPressed: mouse => {
            root.cursorX = mouse.x;
            root.cursorY = mouse.y;
            if (mouse.button === Qt.RightButton) {
                if (root.paletteOpen)
                    root.paletteOpen = false;
                else
                    root.openPalette();
                return;
            }
            if (root.paletteOpen) {
                // A click outside the wheel only closes it.
                root.paletteOpen = false;
                return;
            }
            if (root.editingObj >= 0) {
                root.commitEditingText();
                return;
            }
            root.pressX = mouse.x;
            root.pressY = mouse.y;
            if (!root.hasSelection) {
                root.dragMode = "select";
                root.updateSelect(mouse.x, mouse.y);
                return;
            }
            if (root.activeTool !== "") {
                root.startDraw(mouse.x, mouse.y);
                return;
            }
            const e = root.edgeAt(mouse.x, mouse.y);
            if (e !== 0) {
                root.dragMode = "resize";
                root.resizeEdges = e;
                root.origX = root.selX;
                root.origY = root.selY;
                root.origW = root.selW;
                root.origH = root.selH;
                return;
            }
            if (root.insideSel(mouse.x, mouse.y)) {
                const hit = root.hitObject(mouse.x, mouse.y);
                if (hit >= 0) {
                    root.selectedObj = hit;
                    root.selObjRect = root.objBounds(hit);
                    root.startMoveObj(hit);
                    return;
                }
                root.selectedObj = -1;
                root.selObjRect = null;
                root.dragMode = "move";
                root.origX = root.selX;
                root.origY = root.selY;
                return;
            }
            root.selectedObj = -1;
            root.selObjRect = null;
            root.dragMode = "select";
            root.updateSelect(mouse.x, mouse.y);
        }

        onDoubleClicked: mouse => {
            if (mouse.button !== Qt.LeftButton || !Config.capture.smartRegions)
                return;
            if (root.activeTool !== "" || root.editingObj >= 0)
                return;
            const r = root.smartRectAt(mouse.x, mouse.y);
            if (!r)
                return;
            // Snap the selection to the detected box; it stays adjustable.
            root.selX = r.x;
            root.selY = r.y;
            root.selW = r.w;
            root.selH = r.h;
            root.hasSelection = true;
            root.dragMode = "";
            if (root.ocrOpen)
                root.runOcrCrop();
        }

        onPositionChanged: mouse => {
            root.cursorX = mouse.x;
            root.cursorY = mouse.y;
            switch (root.dragMode) {
            case "select":
                root.updateSelect(mouse.x, mouse.y);
                break;
            case "draw":
                root.applyDraw(mouse.x, mouse.y);
                break;
            case "move":
                root.selX = root.clampv(root.origX + mouse.x - root.pressX, 0, root.width - root.selW);
                root.selY = root.clampv(root.origY + mouse.y - root.pressY, 0, root.height - root.selH);
                break;
            case "resize":
                root.applyResize(mouse.x, mouse.y);
                break;
            case "moveObj":
                root.applyMoveObj(mouse.x, mouse.y);
                break;
            }
        }

        onReleased: mouse => {
            const frameAdjusted = root.dragMode === "select" || root.dragMode === "move" || root.dragMode === "resize";
            switch (root.dragMode) {
            case "select":
                // Plain click = select the whole screen (flameshot).
                if (Math.abs(mouse.x - root.pressX) < 4 && Math.abs(mouse.y - root.pressY) < 4) {
                    root.selX = 0;
                    root.selY = 0;
                    root.selW = root.width;
                    root.selH = root.height;
                }
                root.hasSelection = root.selW >= 2 && root.selH >= 2;
                break;
            case "draw":
                root.finishDraw();
                break;
            case "moveObj":
                if (mouse.x !== root.pressX || mouse.y !== root.pressY)
                    root.pushUndo(root.preState);
                root.preState = null;
                break;
            }
            root.dragMode = "";
            if (frameAdjusted && root.ocrOpen)
                root.runOcrCrop();
        }
    }

    // ── Toolbar ring + radial palette (above the MouseArea) ────────
    EditorToolbar {
        id: toolbar

        editor: root
        visible: root.hasSelection && root.dragMode === "" && !root.committing
    }

    OcrPanel {
        editor: root
        buttonRect: toolbar.ocrButtonRect
        clearance: toolbar.btnSize + toolbar.sep * 2
    }

    ColorWheel {
        editor: root
    }

    // ── Thickness notifier (wheel feedback) ─────────────────────────
    Timer {
        id: notifyTimer

        interval: Appearance.anim.durations.large
    }

    StyledRect {
        visible: notifyTimer.running
        x: root.cursorX + Appearance.spacing.large
        y: root.cursorY - height - Appearance.spacing.large
        implicitWidth: notifyText.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: notifyText.implicitHeight + Appearance.padding.smaller * 2
        radius: Appearance.rounding.full
        color: Colours.palette.surface_container

        StyledText {
            id: notifyText

            anchors.centerIn: parent
            color: Colours.palette.on_surface
            text: `${root.thickness} px`
        }
    }

    // ── Offscreen physical-resolution composite for export ─────────
    Item {
        id: composite

        visible: root.hasSelection
        x: -width - 4000
        y: 0
        width: Math.max(1, Math.round(root.selW * root.outputScale))
        height: Math.max(1, Math.round(root.selH * root.outputScale))

        Image {
            x: -Math.round(root.selX * root.outputScale)
            y: -Math.round(root.selY * root.outputScale)
            width: root.physW
            height: root.physH
            source: root.srcReady ? "file://" + root.srcPath : ""
            smooth: false
        }

        Item {
            x: -Math.round(root.selX * root.outputScale)
            y: -Math.round(root.selY * root.outputScale)

            transform: Scale {
                xScale: root.outputScale
                yScale: root.outputScale
            }

            Repeater {
                model: objects

                AnnotationItem {
                    effectSource: root.baseItem
                    pixelateFactor: Config.capture.pixelateFactor
                }
            }
        }
    }
}

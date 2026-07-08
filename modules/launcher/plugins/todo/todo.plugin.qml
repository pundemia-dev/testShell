import QtQuick
import qs.components.misc
import qs.modules.launcher.content

// Manifest for the todo launcher module. Metadata + settings schema (the single
// value lives in Config.custom.todo.autoSort); the implementation (TodoModule)
// is built lazily on activation. Tasks persist to ${Paths.state}/todos.json.
LauncherManifest {
    title: "Todo"
    description: "Create, check off and reorder tasks"
    icon: "" // tabler checklist
    trigger: "todo"
    order: 20

    settingsSchema: SettingsSchema {
        title: "Todo"
        icon: "" // tabler checklist
        key: "todo"
        fields: [({
                    key: "autoSort",
                    type: "bool",
                    label: "Move completed to bottom",
                    description: "Keep unfinished tasks on top and finished ones at the bottom. Reordering is then limited to within each group (undone among undone, done among done).",
                    "default": true
                }), ({
                    key: "clickDelay2",
                    type: "int",
                    label: "Second-click window (ms)",
                    description: "After the first click, how long to wait for a second click (double-click = edit).",
                    advanced: true,
                    min: 120,
                    max: 600,
                    "default": 350
                }), ({
                    key: "clickDelay3",
                    type: "int",
                    label: "Third-click window (ms)",
                    description: "After the second click, how long to wait for a third click (triple-click = delete).",
                    advanced: true,
                    min: 120,
                    max: 600,
                    "default": 350
                })]
    }

    content: Component {
        TodoModule {}
    }
}

import Quickshell

Variants {
    model: Quickshell.screens

    Scope {
        id: Scope

        required property ShellScreen.modelData

        Exclusions {
            screen: scope.modelData
            bar backgrounds.bar
        }

        StyledWindow {
            id: win

            screen: scope.modelData
            name: drawers

            // Hyprland settings
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        }
    }
}
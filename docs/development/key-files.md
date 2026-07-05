# Key files by task

| Task | File(s) |
|------|---------|
| Color scheme / design tokens | `config/Appearance.qml`, `services/Colours.qml` |
| Bar layout sections | `modules/bar/content/Begin.qml`, `Center.qml`, `End.qml` |
| Bar thickness/position | `modules/bar/config/BarConfig.qml`, `modules/bar/BarWrapper.qml` |
| Backgrounds rendering | `drawers/backgrounds/Backgrounds.qml`, `drawers/backgrounds/components/*.qml`, `services/BackgroundsManager.qml` |
| Border (chrome + 8 zonal interaction strips) | `drawers/border/Border.qml`, `drawers/border/Borders.qml`, `drawers/border/BorderZone.qml`, `config/borderconfig/BorderConfig.qml` |
| Per-rail interaction stack (hover/slide/drop) | `services/InteractionManager.qml` |
| Wrapper contract examples | `modules/{bar,launcher,notifications,stash}/*Wrapper.qml` |
| Slot input mask (bridges + holdover + envelope) | `drawers/backgrounds/components/WindowSlot.qml`, `services/InputManager.qml`, `drawers/Drawers.qml` |
| Edge reservation (exclusion zones) | `drawers/Drawers.qml` (`reservedEdge` aggregation), `drawers/exclusions/Exclusions.qml` |
| Niri integration | `services/Niri.qml`, `services/NiriFocusGrab.qml` |
| LocalSend send | `modules/stash/content/StashContent.qml`, `modules/stash/content/{DevicePicker,DeviceUnit}.qml`, `scripts/localsend_{discover,send}.py` |
| LocalSend receive | `services/LocalSend.qml`, `modules/stash/content/IncomingRequest.qml`, `scripts/localsend_receive.py`, `scripts/localsend_pickdir.sh` |
| Dashed-border component | `components/effects/DashedRect.qml` |
| Per-zone shader logic | `plugin/pshell/Blobs/shaders/blob.frag`, `plugin/pshell/Blobs/blobmaterial.{hpp,cpp}` |
| `sticks` toggle + `stickSmooth` capsule | `plugin/pshell/Blobs/blobrect.{hpp,cpp}`, `blobgroup.{hpp,cpp}`, `shaders/blob.frag`, `drawers/backgrounds/components/WindowSlot.qml`, `config/backgroundsconfig/BackgroundsConfig.qml` |
| SDF frame inset | `drawers/backgrounds/Backgrounds.qml` (`_frameInset*`) |
| Settings UI | `modules/settings/{SettingsContent,SettingsDiscovery,PresetButton}.qml`, `modules/settings/pages/*.qml`, `components/{SettingsSchema,SettingRow,SettingSection}.qml`, `components/controls/{SchemaForm,Hint,HintIcon}.qml`, `services/PresetsManager.qml` |
| Launcher host (state machine, FZF, input row) | `modules/launcher/{LauncherWrapper,ModuleManager,LocalSearcher}.qml`, `modules/launcher/content/{RowInput,LeftPanel,UniversalDelegate}.qml` |
| Launcher plugin slot (contract + units) | `modules/launcher/content/{LauncherManifest,LauncherModule,LauncherRegistry}.qml`, `modules/launcher/plugins/<id>/` |
| Dashboard | `modules/dashboard/{DashboardWrapper,content/*}.qml`, `modules/dashboard/pages/<id>/`, `components/misc/PluginManifest.qml`, `modules/dashboard/config/DashboardConfig.qml`, `modules/dashboard/settings/DashboardSettingsPage.qml` |
| Dashboard rich progress | `components/controls/{DashProgress,StyledProgressBar}.qml` |
| Dashboard backing services | `services/{Players,SystemUsage,Weather,NetworkUsage,Audio,SysInfo}.qml`, `services/Icons.qml` |

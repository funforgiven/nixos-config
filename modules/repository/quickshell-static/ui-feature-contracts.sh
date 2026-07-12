test -f "$shell_config/shell.qml"

theme="$shell_config/generated/Theme.qml"
rg --quiet --fixed-strings 'readonly property color hoverSurface:' "$theme"
rg --quiet --fixed-strings 'readonly property color pressedSurface:' "$theme"
rg --quiet --fixed-strings 'readonly property color outlineStrong:' "$theme"
rg --quiet --fixed-strings 'readonly property color warningSurface:' "$theme"
rg --quiet --fixed-strings 'readonly property color successSurface:' "$theme"
rg --quiet --fixed-strings 'readonly property color accentText:' "$theme"
rg --quiet --fixed-strings 'readonly property real captionFontSize:' "$theme"
rg --quiet --fixed-strings 'readonly property int controlLargeSize: 44' "$theme"
rg --quiet --fixed-strings 'readonly property int animationSlow: 240' "$theme"

amoled="$shell_config/idle/AmoledOverlay.qml"
rg --quiet --fixed-strings 'model: Quickshell.screens' "$amoled"
rg --quiet --fixed-strings 'visible: root.active' "$amoled"
rg --quiet --fixed-strings 'color: "#000000"' "$amoled"
rg --quiet --fixed-strings 'exclusionMode: ExclusionMode.Ignore' "$amoled"
! rg --quiet --fixed-strings 'exclusiveZone:' "$amoled"
rg --quiet --fixed-strings 'WlrLayershell.layer: WlrLayer.Overlay' "$amoled"
rg --quiet --fixed-strings 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' "$amoled"
rg --quiet --fixed-strings 'mask: Region {}' "$amoled"
rg --multiline --multiline-dotall --quiet \
  'anchors[[:space:]]*\{[^}]*top:[[:space:]]*true[^}]*right:[[:space:]]*true[^}]*bottom:[[:space:]]*true[^}]*left:[[:space:]]*true' \
  "$amoled"

rg --quiet --fixed-strings 'property bool interactive: false' \
  "$shell_config/components/Surface.qml"
rg --quiet --fixed-strings 'readonly property color resolvedSurfaceColor:' \
  "$shell_config/components/Surface.qml"
rg --quiet --fixed-strings 'property int outlineWidth: Shell.Theme.outlineWidth' \
  "$shell_config/components/Surface.qml"
rg --quiet --fixed-strings 'readonly property bool pressed: pointer.pressed || keyboardPressed' \
  "$shell_config/components/IconButton.qml"
rg --quiet --fixed-strings 'implicitWidth: Shell.Theme.controlCompactSize' \
  "$shell_config/components/IconButton.qml"
rg --quiet --fixed-strings 'return Shell.Theme.pressedSurface;' \
  "$shell_config/components/IconButton.qml"
tooltip="$shell_config/components/Tooltip.qml"
rg --quiet --fixed-strings 'PopupWindow {' "$tooltip"
rg --quiet --fixed-strings 'property int maximumWidth: 320' "$tooltip"
rg --quiet --fixed-strings 'PopupAdjustment.FlipY | PopupAdjustment.Slide | PopupAdjustment.Resize' "$tooltip"
rg --quiet --fixed-strings 'mask: Region {}' "$tooltip"
rg --quiet --fixed-strings 'a48885b9fec485c903c955749a7da6e30147cd38' "$tooltip"
! rg --quiet --fixed-strings 'Controls.ToolTip' "$tooltip"

bar="$shell_config/bar/Bar.qml"
rg --quiet --fixed-strings 'id: leftIsland' "$bar"
rg --quiet --fixed-strings 'id: rightIsland' "$bar"
! rg --quiet --fixed-strings 'id: centerIsland' "$bar"
! rg --quiet --fixed-strings 'WindowStrip {' "$bar"
rg --quiet --fixed-strings 'implicitHeight: 56' "$bar"
rg --quiet --fixed-strings 'workspaceTasks.implicitWidth' "$bar"
rg --quiet --fixed-strings 'NiriStatus {' "$bar"
rg --quiet --fixed-strings 'readonly property bool failed: Services.NiriService.stale' \
  "$shell_config/bar/NiriStatus.qml"
rg --quiet --fixed-strings 'Accessible.role: Accessible.AlertMessage' \
  "$shell_config/bar/NiriStatus.qml"
rg --quiet --fixed-strings 'Accessible.description: failureMessage' \
  "$shell_config/bar/NiriStatus.qml"
workspace_strip="$shell_config/bar/WorkspaceStrip.qml"
rg --quiet --fixed-strings 'model: root.workspaceKeys' "$workspace_strip"
rg --quiet --fixed-strings 'model: workspaceDelegate.windowKeys' "$workspace_strip"
rg --quiet --fixed-strings 'StableKeys.reconcile(root.workspaceKeys, root.workspaceModel' "$workspace_strip"
rg --quiet --fixed-strings 'StableKeys.reconcile(workspaceDelegate.windowKeys, workspaceDelegate.liveWindows' "$workspace_strip"
rg --quiet --fixed-strings 'width: occupied ? occupiedWidth : emptyWidth' "$workspace_strip"
rg --quiet --fixed-strings 'Services.AppService.iconPathForWindow(windowModel)' "$workspace_strip"
rg --quiet --fixed-strings 'Components.AppIcon {' "$workspace_strip"
rg --quiet --fixed-strings 'Services.NiriService.focusWindow(windowDelegate.windowModel.id)' "$workspace_strip"
! rg --quiet --fixed-strings 'workspaceLabel' "$workspace_strip"
test ! -e "$shell_config/bar/WindowStrip.qml"
rg --quiet --fixed-strings 'Services.AudioService.channel("system")' \
  "$shell_config/bar/MixerButton.qml"
tray="$shell_config/bar/Tray.qml"
tray_menu="$shell_config/bar/TrayMenu.qml"
rg --quiet --fixed-strings 'TrayMenu {' "$tray"
rg --quiet --fixed-strings 'onMenuDismissed: root.handleMenuDismissed()' "$tray"
rg --quiet --fixed-strings 'screen: root.parentWindow.screen' "$tray"
rg --quiet --fixed-strings 'barHeight: root.parentWindow.height' "$tray"
rg --quiet --fixed-strings 'root.menuOpening();' "$tray"
rg --quiet --fixed-strings 'function dismissMenu()' "$tray"
! rg --quiet 'hoverHandoff|lastClosedMenuItem' "$tray"
rg --quiet --fixed-strings 'signal mixerRequested(var anchorItem, var screen, real topInset)' "$bar"
rg --quiet --fixed-strings 'tray.dismissMenu();' "$bar"
rg --quiet --fixed-strings 'root.mixerRequested(mixerButton, barWindow.screen, barWindow.height);' "$bar"
rg --quiet --fixed-strings 'onTrayMenuOpening: mixer.dismissActiveChildPopup(false)' \
  "$shell_config/shell.qml"
rg --quiet --fixed-strings 'function clearMenuForAnchor(anchorItem)' "$tray"
rg --quiet --fixed-strings 'Component.onDestruction: root.clearMenuForAnchor(trayDelegate)' "$tray"
test -f "$tray_menu"
rg --quiet --fixed-strings 'PanelWindow {' "$tray_menu"
rg --quiet --fixed-strings 'QsMenuOpener {' "$tray_menu"
test "$(rg --count --fixed-strings 'QsMenuOpener {' "$tray_menu")" -eq 2
rg --quiet --fixed-strings 'id: menuLifetime' "$tray_menu"
rg --quiet --fixed-strings 'menu: root.topLevelMenu' "$tray_menu"
rg --quiet --fixed-strings 'exclusionMode: ExclusionMode.Ignore' "$tray_menu"
rg --quiet --fixed-strings 'WlrLayershell.layer: WlrLayer.Overlay' "$tray_menu"
rg --quiet --fixed-strings 'WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None' "$tray_menu"
rg --quiet --fixed-strings 'y: root.barHeight' "$tray_menu"
rg --quiet --fixed-strings 'function updatePlacement()' "$tray_menu"
! rg --quiet --fixed-strings 'PopupWindow {' "$tray_menu"
! rg --quiet --fixed-strings 'grabFocus: true' "$tray_menu"
rg --quiet --fixed-strings 'function enterSubmenu(entry)' "$tray_menu"
rg --quiet --fixed-strings 'function leaveSubmenu()' "$tray_menu"
rg --quiet --fixed-strings 'entry.triggered();' "$tray_menu"
rg --quiet --fixed-strings 'model: menuOpener.children' "$tray_menu"
rg --quiet --fixed-strings 'modelData.buttonType === QsMenuButtonType.CheckBox' "$tray_menu"
rg --quiet --fixed-strings 'modelData.buttonType === QsMenuButtonType.RadioButton' "$tray_menu"
rg --quiet --fixed-strings 'onTriggered: root.releaseIfClosed(root.lifecycleSerial)' "$tray_menu"
rg --quiet --fixed-strings 'readonly property int minimumPopupWidth: 160' "$tray_menu"
rg --quiet --fixed-strings 'readonly property int maximumPopupWidth:' "$tray_menu"
rg --quiet --fixed-strings 'readonly property real desiredPopupWidth:' "$tray_menu"
rg --quiet --fixed-strings 'menuFontMetrics.advanceWidth' "$tray_menu"
rg --quiet --fixed-strings 'readonly property int visualInset: Shell.Theme.spacingXSmall' "$tray_menu"
rg --quiet --fixed-strings 'readonly property int interactiveRowHeight: Shell.Theme.controlCompactSize + visualInset * 2' "$tray_menu"
rg --quiet --fixed-strings 'anchors.margins: root.visualInset' "$tray_menu"
test "$(rg --count --fixed-strings 'anchors.margins: root.visualInset' "$tray_menu")" -eq 2
rg --quiet --fixed-strings 'height: modelData.isSeparator ? Shell.Theme.spacingSmall : root.interactiveRowHeight' "$tray_menu"
rg --quiet --fixed-strings 'anchors.leftMargin: root.rowPadding' "$tray_menu"
rg --quiet --fixed-strings 'readonly property bool hasLeadingContent:' "$tray_menu"
rg --quiet --fixed-strings 'visible: root.hasLeadingContent' "$tray_menu"
test "$(rg --count --fixed-strings 'horizontalAlignment: Text.AlignLeft' "$tray_menu")" -eq 2
! rg --quiet --fixed-strings 'PopupAdjustment.' "$tray_menu"
! rg --quiet --fixed-strings 'Math.min(320' "$tray_menu"
! rg --quiet --fixed-strings 'root.anchorItem = null;' "$tray_menu"
! rg --quiet --fixed-strings 'QsMenuAnchor {' "$tray" "$tray_menu"
! rg --quiet --fixed-strings 'Controls.ScrollBar' "$tray_menu"
rg --quiet --fixed-strings 'trayDelegate.trayItem.secondaryActivate();' "$tray"
rg --quiet --fixed-strings 'trayDelegate.trayItem.scroll(' "$tray"
! rg --quiet --fixed-strings 'trayItem.display(' "$tray"

dock="$shell_config/dock/Dock.qml"
rg --quiet --multiline --multiline-dotall \
  'readonly property var pinnedDesktopIds: \[[[:space:]]*"firefox",[[:space:]]*"org\.kde\.dolphin",[[:space:]]*"org\.telegram\.desktop",[[:space:]]*"discord"[[:space:]]*\]' \
  "$shell_config/generated/ShellConfig.qml"
rg --quiet --fixed-strings 'Shell.ShellConfig.dockOutput' "$dock"
rg --quiet --fixed-strings 'DockLauncher {' "$dock"
rg --quiet --fixed-strings 'model: root.dockKeys' "$dock"
rg --quiet --fixed-strings 'StableKeys.reconcile(root.dockKeys, root.dockItems' "$dock"
rg --quiet --fixed-strings 'DockModel.orderUnpinned(unpinned)' "$dock"
test -f "$shell_config/dock/DockModel.js"
rg --quiet --fixed-strings 'return leftKey < rightKey ? -1' \
  "$shell_config/dock/DockModel.js"
rg --quiet --fixed-strings 'separatorBefore: !appGroup.pinned' "$dock"
rg --quiet --fixed-strings 'pending: Services.AppService.isLaunchPending(' "$dock"
rg --quiet --fixed-strings 'Services.AppService.lastLaunchFailureDesktopId === dockDelegate.appGroup.desktopId' "$dock"
! rg --quiet --fixed-strings 'import "../launcher" as Launcher' "$dock"
dock_launcher="$shell_config/dock/DockLauncher.qml"
dock_app="$shell_config/dock/DockApp.qml"
rg --quiet --fixed-strings 'Launcher.Launcher.toggle()' "$dock_launcher"
! rg --quiet \
  'pendingDesktop(Id|Ids)|failureDesktopId|failureMessage|isLaunchPending|lastLaunch' \
  "$dock_launcher"
rg --quiet --fixed-strings \
  'border.width: Launcher.Launcher.opened ? Shell.Theme.outlineWidth : 0' \
  "$dock_launcher"
rg --quiet --fixed-strings \
  'Accessible.description: Launcher.Launcher.opened ? "Launcher open" : "Launcher closed"' \
  "$dock_launcher"
rg --quiet --fixed-strings 'readonly property int instanceCount: appGroup.windows.length' \
  "$dock_app"
! rg --quiet \
  'stateColor:.*pending|tileColor:.*pending|border\.(color|width):.*pending|visible:.*pending|opacity:.*pending' \
  "$dock_app"
rg --quiet --fixed-strings 'readonly property bool pressed: !pending && dockPointer.pressed' \
  "$dock_app"
rg --quiet --fixed-strings 'if (!root.pending)' "$dock_app"
rg --quiet --fixed-strings \
  'Accessible.description: errorText.length > 0 ? errorText : (pending ? "Launch pending"' \
  "$dock_app"
! rg --quiet --fixed-strings 'property real lift:' \
  "$dock_app" "$dock_launcher"
! rg --quiet --fixed-strings 'root.hovered ? 1.06' \
  "$dock_app" "$dock_launcher"
! rg --quiet --fixed-strings 'anchors.verticalCenter: parent.verticalCenter' \
  "$dock_app"
rg --quiet --fixed-strings 'verticalAlignment: Text.AlignVCenter' \
  "$dock_app"
rg --quiet --fixed-strings 'Services.NiriService.focusWindow(group.windows[0].id);' "$dock"
rg --quiet --fixed-strings 'Services.AppService.isLaunchPending(desktopId)' "$dock"
rg --quiet --fixed-strings 'function activateIfReady()' \
  "$shell_config/dock/DockApp.qml"
! rg --quiet --fixed-strings 'activeFocusOnTab: true' \
  "$shell_config/bar" "$shell_config/dock"

! rg --quiet --fixed-strings 'loops: Animation.Infinite' \
  "$shell_config/bar" "$shell_config/dock"

launcher="$shell_config/launcher/Launcher.qml"
test -f "$launcher"
test -f "$shell_config/launcher/LauncherResult.qml"
test -f "$shell_config/launcher/LauncherSearchField.qml"
test -f "$shell_config/launcher/LauncherModel.js"
rg --quiet --fixed-strings 'singleton Launcher 1.0 Launcher.qml' \
  "$shell_config/launcher/qmldir"
rg --quiet --fixed-strings 'readonly property var launcherController: Launcher.Launcher' \
  "$shell_config/shell.qml"
rg --quiet --fixed-strings 'target: "launcher"' "$launcher"
rg --quiet --fixed-strings 'function open(): void' "$launcher"
rg --quiet --fixed-strings 'function close(): void' "$launcher"
rg --quiet --fixed-strings 'function toggle(): void' "$launcher"
rg --quiet --fixed-strings 'root.query = "";' "$launcher"
rg --quiet --fixed-strings 'root.pointerAnchor = null;' "$launcher"
rg --quiet --fixed-strings 'root.opened = false;' "$launcher"
rg --quiet --fixed-strings 'Qt.Key_Home' "$launcher"
rg --quiet --fixed-strings 'Qt.Key_End' "$launcher"
! rg --quiet --fixed-strings 'Controls.ScrollBar' "$launcher"
rg --quiet --fixed-strings 'interactive: true' "$launcher"
rg --quiet --fixed-strings 'Shell.ShellConfig.dockOutput' "$launcher"
rg --quiet --fixed-strings 'readonly property var selectedScreen: configuredScreen()' "$launcher"
rg --quiet --fixed-strings 'if (screen.name === Shell.ShellConfig.dockOutput)' "$launcher"
! rg --quiet 'focusedOutputName|NiriService\.workspaces|property string outputName' "$launcher"
rg --quiet --fixed-strings 'Services.NiriService.focusMonitor(Shell.ShellConfig.dockOutput)' "$launcher"
rg --quiet --fixed-strings 'property bool openRequested: false' "$launcher"
rg --quiet --fixed-strings 'function showAfterOutputFocus(): void' "$launcher"
rg --quiet --fixed-strings 'onBackingWindowVisibleChanged: root.focusSearchWhenMapped()' "$launcher"
rg --quiet --fixed-strings 'WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None' "$launcher"
rg --quiet --fixed-strings 'LauncherModel.pointerMovedEnough(root.pointerAnchor, current, 5)' "$launcher"
rg --quiet --fixed-strings 'Services.AppService.launchDesktopId(application.id)' "$launcher"
rg --quiet --fixed-strings 'width: Math.min(680, launcherWindow.width' "$launcher"
rg --quiet --fixed-strings 'anchors.margins: Shell.Theme.spacingXLarge' "$launcher"
! rg --quiet --fixed-strings 'text: "Applications"' "$launcher"
! rg --quiet --fixed-strings 'view-app-grid-symbolic' "$launcher"
! rg --quiet --fixed-strings 'Find and open an installed application' "$launcher"
! rg --quiet --fixed-strings 'text: "MOD + SPACE"' "$launcher"
rg --quiet --fixed-strings 'color: Shell.Theme.errorSurface' "$launcher"
rg --quiet --fixed-strings 'Accessible.name: pendingText.text' "$launcher"
! rg --quiet --fixed-strings 'text: "RESULTS"' "$launcher"
! rg --quiet --fixed-strings '↑↓ navigate' "$launcher"
rg --quiet --fixed-strings 'text: root.query.length === 0 ? "No apps available" : "No matches"' "$launcher"
rg --quiet --fixed-strings 'text: root.query.length === 0 ? "No launchable apps found." : "Try another search."' "$launcher"
rg --quiet --fixed-strings 'anchors.verticalCenter: parent.verticalCenter' "$launcher"
rg --quiet --fixed-strings 'Accessible.role: Accessible.AlertMessage' "$launcher"
rg --quiet --fixed-strings 'Accessible.name: failureText.text' "$launcher"
! rg --quiet --multiline --multiline-dotall \
  'id: failureText.{0,180}anchors\.fill: parent' "$launcher"
rg --quiet --fixed-strings 'Components.IconButton {' \
  "$shell_config/launcher/LauncherSearchField.qml"
rg --quiet --fixed-strings 'implicitHeight: 56' \
  "$shell_config/launcher/LauncherSearchField.qml"
rg --quiet --fixed-strings 'inputFocused ? Shell.Theme.selectedSurface' \
  "$shell_config/launcher/LauncherSearchField.qml"
rg --quiet --fixed-strings 'Accessible.description: "Filter installed apps"' \
  "$shell_config/launcher/LauncherSearchField.qml"
rg --quiet --fixed-strings 'tooltipText: "Clear"' \
  "$shell_config/launcher/LauncherSearchField.qml"
rg --quiet --fixed-strings 'pressed: rowTap.pressed' \
  "$shell_config/launcher/LauncherResult.qml"
rg --quiet --fixed-strings 'height: 72' \
  "$shell_config/launcher/LauncherResult.qml"
rg --quiet --fixed-strings 'surfaceColor: "transparent"' \
  "$shell_config/launcher/LauncherResult.qml"
rg --quiet --fixed-strings 'outlineWidth: selected || failed ? Shell.Theme.outlineWidth : 0' \
  "$shell_config/launcher/LauncherResult.qml"
rg --quiet --fixed-strings 'Components.StatusChip {' \
  "$shell_config/launcher/LauncherResult.qml"
rg --quiet --fixed-strings 'Accessible.description: pending ? "Starting" : (failed ? "Launch failed" : "Open app")' \
  "$shell_config/launcher/LauncherResult.qml"
! rg --quiet --fixed-strings 'application.comment' \
  "$shell_config/launcher/LauncherResult.qml"
rg --quiet --fixed-strings 'cursorShape: Qt.PointingHandCursor' \
  "$shell_config/launcher/LauncherResult.qml"
rg --quiet --fixed-strings 'd82d86df5cb932fc275dcf30c35cd72705a21065' "$launcher"
rg --quiet --fixed-strings 'a48885b9fec485c903c955749a7da6e30147cd38' \
  "$launcher" "$shell_config/launcher/LauncherModel.js"
rg --quiet --fixed-strings 'THIRD_PARTY_NOTICES.md' \
  "$launcher" "$shell_config/launcher/LauncherModel.js"
! rg --quiet '\b(Process|PersistentProperties|FileView|JsonAdapter)\b|Quickshell\.execDetached' \
  "$shell_config/launcher"
! rg --quiet --fixed-strings 'loops: Animation.Infinite' \
  "$shell_config/launcher"

test -f "$shell_config/THIRD_PARTY_NOTICES.md"
rg --quiet --fixed-strings 'Copyright (c) 2025 noctalia-dev' \
  "$shell_config/THIRD_PARTY_NOTICES.md"
rg --quiet --fixed-strings 'Copyright (c) 2025 Avenge Media LLC' \
  "$shell_config/THIRD_PARTY_NOTICES.md"

rg --quiet --fixed-strings 'Accessible.role: Accessible.Slider' \
  "$shell_config/components/MaterialSlider.qml"
rg --quiet --fixed-strings 'preventStealing: true' \
  "$shell_config/components/MaterialSlider.qml"
rg --quiet --fixed-strings 'readonly property real presentedValue: pointer.pressed ? dragValue : clampedValue' \
  "$shell_config/components/MaterialSlider.qml"
rg --quiet --fixed-strings 'drag.target: pointerGrabTarget' \
  "$shell_config/components/MaterialSlider.qml"
rg --quiet --fixed-strings 'drag.threshold: 0' \
  "$shell_config/components/MaterialSlider.qml"
rg --quiet --fixed-strings 'property color trackColor: Shell.Theme.outline' \
  "$shell_config/components/MaterialSlider.qml"
rg --quiet --fixed-strings 'color: root.trackColor' \
  "$shell_config/components/MaterialSlider.qml"
test -f "$shell_config/components/StableKeys.js"
rg --quiet --fixed-strings 'return same(previous, next) ? previous : next;' \
  "$shell_config/components/StableKeys.js"

rg --quiet --fixed-strings 'id: dragProxy' \
  "$shell_config/mixer/DragSession.qml"
rg --quiet --fixed-strings 'property int currentToken: 0' \
  "$shell_config/mixer/DragSession.qml"
rg --quiet --fixed-strings 'function updatePointer(token, pointerItem, pointerX, pointerY)' \
  "$shell_config/mixer/DragSession.qml"
rg --quiet --fixed-strings 'Drag.source: root' \
  "$shell_config/mixer/DragSession.qml"
rg --quiet --fixed-strings 'DragModel.groupPayload(root.group, root.sourceChannelId)' \
  "$shell_config/mixer/StreamCard.qml"
rg --quiet --fixed-strings 'root.dragSession.begin(' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'target: null' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'Component.onDestruction:' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'grabPermissions: PointerHandler.CanTakeOverFromAnything' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'model: root.groupKeys' \
  "$shell_config/mixer/ChannelCard.qml"
rg --quiet --fixed-strings 'model: root.streamKeys' \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'model: root.unroutedGroupKeys' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'return !root.groupIsMoving(group);' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'model: Shell.ShellConfig.audioChannels' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'DragModel.canDrop(payload, root.channel.id, root.channel.sink !== null)' \
  "$shell_config/mixer/ChannelCard.qml"
! rg --quiet --fixed-strings 'Components.DropOverlay {' \
  "$shell_config/mixer/ChannelCard.qml"
rg --quiet --fixed-strings 'visible: root.dropHovering && root.dragInProgress' \
  "$shell_config/mixer/ChannelCard.qml"
! rg --quiet 'routingExpanded|text: "Move"|groupRouteRepeater|childRouteRepeater' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'readonly property string statusText:' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'DragModel.adjacentChannelId(' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'Accessible.role: Accessible.Slider' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'interactive: !mixerDragSession.active' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'id: mixerDragSession' \
  "$shell_config/mixer/MixerPopup.qml"
! rg --quiet --fixed-strings 'id: dragTargetRail' \
  "$shell_config/mixer/MixerPopup.qml"
! rg --quiet --fixed-strings 'text: "Channel mixer"' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'readonly property string channelSymbol:' \
  "$shell_config/mixer/ChannelCard.qml"
rg --quiet --fixed-strings 'font.family: "Material Symbols Rounded"' \
  "$shell_config/mixer/ChannelCard.qml"
rg --quiet --fixed-strings 'color: Shell.Theme.systemAccent' \
  "$shell_config/mixer/ChannelCard.qml"
rg --quiet --fixed-strings 'color: Shell.Theme.accentText' \
  "$shell_config/mixer/ChannelCard.qml"
rg --quiet --fixed-strings 'Layout.alignment: Qt.AlignBottom' \
  "$shell_config/mixer/ChannelCard.qml"
! rg --quiet --fixed-strings 'Components.Tooltip {' \
  "$shell_config/mixer/StreamCard.qml" \
  "$shell_config/mixer/StreamChildren.qml"
! rg --quiet --fixed-strings 'open four-channel mixer' \
  "$shell_config/bar/MixerButton.qml"
rg --quiet --fixed-strings 'onOpenedChanged:' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'if (mixerDragSession.active)' \
  "$shell_config/mixer/MixerPopup.qml"
! rg --quiet --fixed-strings 'id: groupGhost' \
  "$shell_config/mixer/StreamCard.qml"
! rg --quiet --fixed-strings 'id: childGhost' \
  "$shell_config/mixer/StreamChildren.qml"
rg --quiet --fixed-strings 'payload.sourceChannelId !== text(targetChannelId)' \
  "$shell_config/mixer/DragModel.js"
rg --quiet --fixed-strings 'snapshotSignature: snapshotSignature' \
  "$shell_config/mixer/AudioModel.js"
rg --quiet --fixed-strings 'Services.AudioActions.movePayload(payload, root.channel.id)' \
  "$shell_config/mixer/ChannelCard.qml"
rg --quiet --fixed-strings 'playbackStreams: playbackStreams' \
  "$shell_config/shell.qml"

! rg --quiet --fixed-strings 'PopupWindow {' \
  "$shell_config/mixer/OutputPicker.qml"
! rg --quiet --fixed-strings 'grabFocus: true' \
  "$shell_config/mixer/OutputPicker.qml"
! rg --quiet --fixed-strings 'PopupAdjustment.' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'required property var dropdownHost' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'readonly property bool expanded: dropdownHost !== null && dropdownHost.activeOutputPicker === root' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'readonly property Component dropdownComponent: outputDropdownComponent' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'dropdownHost.openOutputPicker(root);' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'readonly property int desiredPopupWidth: root.contentDrivenPopupWidth()' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'readonly property int maximumPopupWidth: 680' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'Math.min(root.maximumPopupWidth, Math.max(root.minimumPopupWidth' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'outputLabelMetrics.advanceWidth(output.label || "")' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'rowWidth + root.popupContentPadding * 2' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'readonly property int rowHeight: rowContentHeight + rowInset * 2' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'return root.rowInset * 2 + root.entryHorizontalPadding * 2' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'anchors.margins: root.rowInset' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'anchors.leftMargin: root.entryHorizontalPadding' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'anchors.margins: root.popupContentPadding' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'Layout.alignment: Qt.AlignRight' \
  "$shell_config/mixer/OutputPicker.qml"
! rg --quiet --fixed-strings 'Math.max(root.desiredPopupWidth, selector.width)' \
  "$shell_config/mixer/OutputPicker.qml"
! rg --quiet --fixed-strings 'id: scrollTrack' \
  "$shell_config/mixer/OutputPicker.qml"
test -f "$shell_config/mixer/OutputSelection.js"
rg --quiet --fixed-strings 'property string highlightedOutputKey: ""' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'root.dropdownHost.reconcileActiveOutputPicker(root);' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'OutputSelection.reconcileSelection(root.outputs, highlightedOutputKey, root.channel.output)' \
  "$shell_config/mixer/OutputPicker.qml"
rg --quiet --fixed-strings 'Accessible.role: Accessible.StaticText' \
  "$shell_config/mixer/OutputPicker.qml"

mixer_popup="$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'PanelWindow {' "$mixer_popup"
rg --quiet --fixed-strings 'exclusionMode: ExclusionMode.Ignore' "$mixer_popup"
rg --quiet --fixed-strings 'WlrLayershell.layer: WlrLayer.Overlay' "$mixer_popup"
rg --quiet --fixed-strings 'WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None' "$mixer_popup"
rg --quiet --fixed-strings 'mask: Region {' "$mixer_popup"
rg --quiet --fixed-strings 'property var activeOutputPicker: null' "$mixer_popup"
rg --quiet --fixed-strings 'function dismissActiveChildPopup(restoreFocus)' "$mixer_popup"
rg --quiet --fixed-strings 'id: outputDropdownLoader' "$mixer_popup"
rg --quiet --fixed-strings 'active: root.activeOutputPicker !== null' "$mixer_popup"
rg --quiet --fixed-strings 'sourceComponent: root.activeOutputPicker ? root.activeOutputPicker.dropdownComponent : null' "$mixer_popup"
rg --quiet --fixed-strings 'dropdownHost: root' "$mixer_popup"
! rg --quiet --fixed-strings 'PopupWindow {' "$mixer_popup"
! rg --quiet --fixed-strings 'grabFocus: true' "$mixer_popup"

rg --quiet --fixed-strings 'const identity = Services.AppService.resolveDesktopId(desktopId);' \
  "$shell_config/dock/Dock.qml"
! rg --quiet --fixed-strings 'Quickshell.iconPath(icon' "$shell_config/dock/Dock.qml"
rg --quiet --fixed-strings 'property bool opened: false' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'readonly property bool visible: mixerWindow.visible' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'opened = true;' "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'visible: root.opened && root.selectedScreen !== null' \
  "$shell_config/mixer/MixerPopup.qml"
rg --quiet --fixed-strings 'const stableWindows = group.windows.slice().sort' \
  "$shell_config/dock/Dock.qml"

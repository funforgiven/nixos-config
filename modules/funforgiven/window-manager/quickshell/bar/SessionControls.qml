import QtQuick
import Quickshell
import ".." as Shell
import "../components" as Components
import "../services" as Services

Item {
    id: root

    implicitWidth: controls.implicitWidth
    implicitHeight: Shell.Theme.controlCompactSize

    function accessibleName(action, label) {
        if (Services.SessionActions.failedAction === action)
            return `${label}: ${Services.SessionActions.error}. Activate to retry`;
        if (Services.SessionActions.activeAction === action)
            return `${label} requested`;
        if (Services.SessionActions.armedAction === action)
            return `Confirm ${label.toLowerCase()}`;
        return label;
    }

    function tooltip(action, label) {
        if (Services.SessionActions.failedAction === action)
            return `${label} failed · ${Services.SessionActions.error} · Click to retry`;
        if (Services.SessionActions.activeAction === action)
            return `${label} requested`;
        if (Services.SessionActions.armedAction === action)
            return `Click again to confirm ${label.toLowerCase()}`;
        return label;
    }

    Row {
        id: controls

        height: parent.height
        spacing: Shell.Theme.spacingXSmall

        Components.IconButton {
            activeFocusOnTab: false
            iconSource: Quickshell.iconPath("system-log-out-symbolic", "system-log-out")
            tintIcon: true
            accessibleName: root.accessibleName("logout", "Log out")
            tooltipText: root.tooltip("logout", "Log out")
            accent: Shell.Theme.error
            checked: Services.SessionActions.armedAction === "logout" || Services.SessionActions.activeAction === "logout"
            attention: Services.SessionActions.failedAction === "logout"
            enabled: !Services.SessionActions.busy
            onClicked: button => {
                if (button === Qt.LeftButton)
                    Services.SessionActions.requestLogout();
            }
        }

        Components.IconButton {
            activeFocusOnTab: false
            iconSource: Quickshell.iconPath("system-reboot-symbolic", "system-reboot")
            tintIcon: true
            accessibleName: root.accessibleName("reboot", "Restart")
            tooltipText: root.tooltip("reboot", "Restart")
            accent: Shell.Theme.error
            checked: Services.SessionActions.armedAction === "reboot" || Services.SessionActions.activeAction === "reboot"
            attention: Services.SessionActions.failedAction === "reboot"
            enabled: !Services.SessionActions.busy
            onClicked: button => {
                if (button === Qt.LeftButton)
                    Services.SessionActions.requestReboot();
            }
        }

        Components.IconButton {
            activeFocusOnTab: false
            iconSource: Quickshell.iconPath("system-shutdown-symbolic", "system-shutdown")
            tintIcon: true
            accessibleName: root.accessibleName("poweroff", "Shut down")
            tooltipText: root.tooltip("poweroff", "Shut down")
            accent: Shell.Theme.error
            checked: Services.SessionActions.armedAction === "poweroff" || Services.SessionActions.activeAction === "poweroff"
            attention: Services.SessionActions.failedAction === "poweroff"
            enabled: !Services.SessionActions.busy
            onClicked: button => {
                if (button === Qt.LeftButton)
                    Services.SessionActions.requestPoweroff();
            }
        }
    }
}

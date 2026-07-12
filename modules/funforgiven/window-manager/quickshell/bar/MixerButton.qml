import QtQuick
import Quickshell
import ".." as Shell
import "../components" as Components
import "../services" as Services

Components.IconButton {
    id: root

    activeFocusOnTab: false

    signal requested

    readonly property var systemChannel: Services.AudioService.channel("system")
    readonly property var systemAudio: systemChannel !== null && systemChannel.bridge ? systemChannel.bridge.audio : null
    readonly property bool muted: systemAudio !== null && systemAudio.muted === true
    readonly property real volume: systemAudio !== null ? Number(systemAudio.volume) : 0
    readonly property bool warning: !Services.AudioService.ready || Services.AudioService.defaultWarning || Services.AudioActions.recentErrors.length > 0
    readonly property string volumeIcon: {
        if (muted || volume <= 0)
            return "audio-volume-muted-symbolic";
        if (volume < 0.34)
            return "audio-volume-low-symbolic";
        if (volume < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    iconSource: Quickshell.iconPath(volumeIcon, "audio-volume-high")
    accessibleName: warning ? "Audio mixer, needs attention" : "Audio mixer"
    tooltipText: {
        if (!Services.AudioService.ready)
            return "Audio connecting";
        if (Services.AudioService.defaultWarning)
            return "Output mismatch";
        if (Services.AudioActions.recentErrors.length > 0)
            return "Audio error";
        return `System · ${muted ? "muted" : Math.round(volume * 100) + "%"}`;
    }
    accent: Shell.Theme.systemAccent
    attention: warning
    onClicked: button => {
        if (button === Qt.LeftButton)
            root.requested();
    }
}

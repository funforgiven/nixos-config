pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".." as Shell
import "../components" as Components

Item {
    id: root

    property var flow: null
    property bool registrationFailed: false
    property int inputEpoch: 0

    readonly property bool authenticationActive: root.flow !== null && !root.flow.isCompleted
    readonly property bool responseRequired: root.authenticationActive && root.flow.isResponseRequired
    readonly property bool retryAvailable: root.authenticationActive && root.flow.canRetry === true
    readonly property int identityCount: root.authenticationActive && root.flow.identities ? root.flow.identities.length : 0

    implicitWidth: 560
    implicitHeight: content.implicitHeight + Shell.Theme.spacingLarge * 2

    function identityLabel(identity) {
        if (identity === null || identity === undefined) {
            return "Unknown identity";
        }

        const displayName = typeof identity.displayName === "string" ? identity.displayName : "";
        const accountName = typeof identity.string === "string" ? identity.string : "";
        let label = "";
        if (displayName.length > 0 && accountName.length > 0 && displayName !== accountName) {
            label = displayName + " (" + accountName + ")";
        } else if (displayName.length > 0) {
            label = displayName;
        } else if (accountName.length > 0) {
            label = accountName;
        } else {
            label = identity.isGroup ? "Unknown group" : "Unknown user";
        }
        return label + " — " + (identity.isGroup ? "group " : "user ") + identity.id;
    }

    function identityIndex(identity) {
        if (!root.authenticationActive || identity === null || identity === undefined) {
            return -1;
        }
        for (var index = 0; index < root.flow.identities.length; index += 1) {
            if (root.flow.identities[index] === identity) {
                return index;
            }
        }
        return -1;
    }

    function isForbiddenEditingShortcut(event) {
        if (event.key === Qt.Key_Copy || event.key === Qt.Key_Cut || event.key === Qt.Key_Undo || event.key === Qt.Key_Redo) {
            return true;
        }

        const commandModifier = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
        if (commandModifier && (event.key === Qt.Key_C || event.key === Qt.Key_X || event.key === Qt.Key_Insert || event.key === Qt.Key_Y || event.key === Qt.Key_Z)) {
            return true;
        }

        return (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Delete;
    }

    function clearSensitiveInput() {
        root.inputEpoch += 1;
        if (responseLoader.item !== null) {
            responseLoader.item.text = "";
            responseLoader.item.deselect(); // qmllint disable missing-property
        }
        responseLoader.active = false;
    }

    function prepareSensitiveInput() {
        root.clearSensitiveInput();
        if (!root.responseRequired) {
            return;
        }

        const expectedEpoch = root.inputEpoch;
        Qt.callLater(function () {
            if (expectedEpoch !== root.inputEpoch || !root.responseRequired) {
                return;
            }
            responseLoader.active = true;
            Qt.callLater(root.focusConversation);
        });
    }

    function focusConversation() {
        if (!root.authenticationActive) {
            return;
        }
        if (responseLoader.item !== null) {
            responseLoader.item.forceActiveFocus(Qt.ActiveWindowFocusReason); // qmllint disable missing-property
            root.revealItem(responseLoader.item);
        } else if (root.retryAvailable) {
            submitButton.forceActiveFocus(Qt.ActiveWindowFocusReason);
            root.revealItem(submitButton);
        } else {
            cancelButton.forceActiveFocus(Qt.ActiveWindowFocusReason);
            root.revealItem(cancelButton);
        }
    }

    function revealItem(item) {
        if (item === null || item === undefined || scroller.contentHeight <= scroller.height) {
            return;
        }

        const position = item.mapToItem(content, 0, 0);
        const top = position.y - Shell.Theme.spacingSmall;
        const bottom = position.y + item.height + Shell.Theme.spacingSmall;
        if (top < scroller.contentY) {
            scroller.contentY = Math.max(0, top);
        } else if (bottom > scroller.contentY + scroller.height) {
            scroller.contentY = Math.min(scroller.contentHeight - scroller.height, bottom - scroller.height);
        }
    }

    function submitResponse() {
        if (root.retryAvailable) {
            root.clearSensitiveInput();
            root.flow.retryAuthentication();
            root.prepareSensitiveInput();
            return;
        }

        if (!root.responseRequired || responseLoader.item === null) {
            root.clearSensitiveInput();
            return;
        }

        root.flow.submit(responseLoader.item.text); // qmllint disable missing-property
        root.clearSensitiveInput();
        root.prepareSensitiveInput();
    }

    function cancelAuthentication() {
        root.clearSensitiveInput();
        if (root.authenticationActive && !root.flow.isCancelled) {
            root.flow.cancelAuthenticationRequest();
        }
    }

    function selectIdentity(index) {
        if (!root.authenticationActive || index < 0 || index >= root.flow.identities.length) {
            return;
        }

        const identity = root.flow.identities[index];
        if (identity === root.flow.selectedIdentity) {
            return;
        }
        root.clearSensitiveInput();
        root.flow.selectedIdentity = identity;
    }

    onFlowChanged: root.prepareSensitiveInput()
    Component.onDestruction: root.clearSensitiveInput()

    Shortcut {
        enabled: root.authenticationActive && !root.flow.isCancelled
        sequence: StandardKey.Cancel
        context: Qt.WindowShortcut
        onActivated: root.cancelAuthentication()
    }

    Connections {
        target: root.flow
        enabled: root.flow !== null
        ignoreUnknownSignals: true

        function onAuthenticationFailed() {
            root.clearSensitiveInput();
        }

        function onAuthenticationRequestCancelled() {
            root.clearSensitiveInput();
        }

        function onAuthenticationSucceeded() {
            root.clearSensitiveInput();
        }

        function onCanRetryChanged() {
            root.clearSensitiveInput();
            Qt.callLater(root.focusConversation);
        }

        function onInputPromptChanged() {
            root.prepareSensitiveInput();
        }

        function onIsCompletedChanged() {
            if (root.flow && root.flow.isCompleted) {
                root.clearSensitiveInput();
            }
        }

        function onIsResponseRequiredChanged() {
            root.prepareSensitiveInput();
        }

        function onResponseVisibleChanged() {
            root.prepareSensitiveInput();
        }

        function onSelectedIdentityChanged() {
            root.clearSensitiveInput();
        }
    }

    Components.Surface {
        anchors.fill: parent
        elevated: true
        radius: Shell.Theme.radiusLarge
        outlineColor: root.registrationFailed && !root.authenticationActive ? Shell.Theme.error : Shell.Theme.border
    }

    Flickable {
        id: scroller

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            margins: Shell.Theme.spacingLarge
        }
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Controls.ScrollBar.vertical: Controls.ScrollBar {}

        ColumnLayout {
            id: content

            width: scroller.width - (scroller.contentHeight > scroller.height ? Shell.Theme.spacingMedium : 0)
            spacing: Shell.Theme.spacingMedium

            RowLayout {
                Layout.fillWidth: true
                spacing: Shell.Theme.spacingMedium

                IconImage {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    source: root.authenticationActive && root.flow.iconName.length > 0 ? Quickshell.iconPath(root.flow.iconName, "dialog-password") : Quickshell.iconPath(root.registrationFailed ? "dialog-error" : "dialog-password")
                    mipmap: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        color: Shell.Theme.primaryText
                        text: root.registrationFailed && !root.authenticationActive ? "Authentication agent unavailable" : "Authentication required"
                        font.family: Shell.Theme.sansFont
                        font.pixelSize: Shell.Theme.applicationFontSize + 2
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.authenticationActive && root.flow.actionId.length > 0
                        color: Shell.Theme.secondaryText
                        text: root.authenticationActive ? root.flow.actionId : ""
                        font.family: Shell.Theme.monoFont
                        font.pixelSize: Shell.Theme.desktopFontSize - 1
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.authenticationActive
                color: Shell.Theme.primaryText
                text: root.authenticationActive ? root.flow.message : ""
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.applicationFontSize
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.registrationFailed && !root.authenticationActive
                color: Shell.Theme.errorText
                text: "Quickshell could not confirm registration with polkit. Privileged prompts may not appear. Restart quickshell.service and inspect its journal."
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.applicationFontSize
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.authenticationActive && root.identityCount === 1
                color: Shell.Theme.secondaryText
                text: root.identityCount === 1 ? root.identityLabel(root.flow.identities[0]) : ""
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.desktopFontSize
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }

            Controls.ComboBox {
                id: identitySelector

                Layout.fillWidth: true
                visible: root.authenticationActive && root.identityCount > 1
                enabled: visible
                model: root.authenticationActive ? root.flow.identities : []
                currentIndex: root.authenticationActive ? root.identityIndex(root.flow.selectedIdentity) : -1
                displayText: root.authenticationActive ? root.identityLabel(root.flow.selectedIdentity) : ""
                leftPadding: Shell.Theme.spacingMedium
                rightPadding: Shell.Theme.spacingLarge * 2
                topPadding: Shell.Theme.spacingSmall
                bottomPadding: Shell.Theme.spacingSmall

                palette.button: Shell.Theme.raisedSurface
                palette.buttonText: Shell.Theme.primaryText
                palette.highlight: Shell.Theme.systemAccent
                palette.highlightedText: Shell.Theme.baseSurface
                palette.text: Shell.Theme.primaryText
                palette.window: Shell.Theme.elevatedSurface
                palette.windowText: Shell.Theme.primaryText

                contentItem: Text {
                    color: Shell.Theme.primaryText
                    text: identitySelector.displayText
                    font.family: Shell.Theme.sansFont
                    font.pixelSize: Shell.Theme.desktopFontSize
                    textFormat: Text.PlainText
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                delegate: Controls.ItemDelegate {
                    id: identityDelegate

                    required property int index
                    required property var modelData

                    width: identitySelector.width
                    highlighted: identitySelector.highlightedIndex === index

                    contentItem: Text {
                        color: identityDelegate.highlighted ? Shell.Theme.baseSurface : Shell.Theme.primaryText
                        text: root.identityLabel(identityDelegate.modelData)
                        font.family: Shell.Theme.sansFont
                        font.pixelSize: Shell.Theme.desktopFontSize
                        textFormat: Text.PlainText
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: identityDelegate.highlighted ? Shell.Theme.systemAccent : Shell.Theme.elevatedSurface
                    }

                    onClicked: {
                        identitySelector.popup.close();
                        root.selectIdentity(index);
                    }
                }

                indicator: Text {
                    x: identitySelector.width - width - Shell.Theme.spacingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    color: Shell.Theme.secondaryText
                    text: "▾"
                    font.family: Shell.Theme.sansFont
                    font.pixelSize: Shell.Theme.applicationFontSize
                }

                background: Rectangle {
                    color: identitySelector.pressed ? Shell.Theme.baseSurface : Shell.Theme.raisedSurface
                    radius: Shell.Theme.radiusSmall
                    border.color: identitySelector.activeFocus ? Shell.Theme.systemAccent : Shell.Theme.border
                    border.width: identitySelector.activeFocus ? 2 : 1
                }

                onActivated: index => root.selectIdentity(index)
            }

            Text {
                Layout.fillWidth: true
                visible: root.authenticationActive && root.flow.supplementaryMessage.length > 0
                color: root.authenticationActive && root.flow.supplementaryIsError ? Shell.Theme.errorText : Shell.Theme.secondaryText
                text: root.authenticationActive ? root.flow.supplementaryMessage : ""
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.desktopFontSize
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.authenticationActive && root.flow.failed
                color: Shell.Theme.errorText
                text: "Authentication failed. Check the response and try again."
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.desktopFontSize
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                visible: root.responseRequired
                color: Shell.Theme.primaryText
                text: root.responseRequired ? root.flow.inputPrompt : ""
                font.family: Shell.Theme.sansFont
                font.pixelSize: Shell.Theme.desktopFontSize
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }

            Loader {
                id: responseLoader

                Layout.fillWidth: true
                Layout.preferredHeight: item !== null ? item.implicitHeight : 0 // qmllint disable missing-property
                active: false

                sourceComponent: Controls.TextField {
                    width: responseLoader.width
                    echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    selectByMouse: false
                    persistentSelection: false
                    maximumLength: 4096
                    leftPadding: Shell.Theme.spacingMedium
                    rightPadding: Shell.Theme.spacingMedium
                    topPadding: Shell.Theme.spacingSmall
                    bottomPadding: Shell.Theme.spacingSmall
                    color: Shell.Theme.primaryText
                    selectionColor: Shell.Theme.systemAccent
                    selectedTextColor: Shell.Theme.baseSurface
                    font.family: Shell.Theme.sansFont
                    font.pixelSize: Shell.Theme.applicationFontSize
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                    Accessible.name: root.flow && root.flow.inputPrompt.length > 0 ? root.flow.inputPrompt : "Authentication response"
                    Accessible.passwordEdit: !(root.flow && root.flow.responseVisible)

                    Keys.priority: Keys.BeforeItem
                    Keys.onShortcutOverride: event => {
                        if (root.isForbiddenEditingShortcut(event)) {
                            event.accepted = true;
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.cancelAuthentication();
                            event.accepted = true;
                            return;
                        }
                        if (root.isForbiddenEditingShortcut(event)) {
                            event.accepted = true;
                        }
                    }

                    background: Rectangle {
                        color: Shell.Theme.baseSurface
                        radius: Shell.Theme.radiusSmall
                        border.color: parent.activeFocus ? Shell.Theme.systemAccent : Shell.Theme.border
                        border.width: parent.activeFocus ? 2 : 1
                    }

                    onAccepted: root.submitResponse()
                    Component.onDestruction: text = ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Shell.Theme.spacingSmall
                visible: root.authenticationActive
                spacing: Shell.Theme.spacingSmall

                Item {
                    Layout.fillWidth: true
                }

                Controls.Button {
                    id: cancelButton

                    text: "Cancel"
                    enabled: root.authenticationActive && !root.flow.isCancelled
                    leftPadding: Shell.Theme.spacingLarge
                    rightPadding: Shell.Theme.spacingLarge
                    palette.buttonText: Shell.Theme.primaryText

                    contentItem: Text {
                        color: Shell.Theme.primaryText
                        text: cancelButton.text
                        font.family: Shell.Theme.sansFont
                        font.pixelSize: Shell.Theme.desktopFontSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: cancelButton.pressed ? Shell.Theme.baseSurface : Shell.Theme.raisedSurface
                        radius: Shell.Theme.radiusSmall
                        border.color: cancelButton.activeFocus ? Shell.Theme.systemAccent : Shell.Theme.border
                        border.width: cancelButton.activeFocus ? 2 : 1
                    }

                    Keys.onEscapePressed: event => {
                        root.cancelAuthentication();
                        event.accepted = true;
                    }
                    onClicked: root.cancelAuthentication()
                }

                Controls.Button {
                    id: submitButton

                    text: root.retryAvailable ? "Retry" : "Continue"
                    enabled: root.retryAvailable || (root.responseRequired && responseLoader.item !== null)
                    leftPadding: Shell.Theme.spacingLarge
                    rightPadding: Shell.Theme.spacingLarge
                    palette.buttonText: Shell.Theme.baseSurface

                    contentItem: Text {
                        color: submitButton.enabled ? Shell.Theme.baseSurface : Shell.Theme.secondaryText
                        text: submitButton.text
                        font.family: Shell.Theme.sansFont
                        font.pixelSize: Shell.Theme.desktopFontSize
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: submitButton.enabled ? (submitButton.pressed ? Shell.Theme.gameAccent : Shell.Theme.systemAccent) : Shell.Theme.raisedSurface
                        radius: Shell.Theme.radiusSmall
                        border.color: submitButton.activeFocus ? Shell.Theme.primaryText : "transparent"
                        border.width: submitButton.activeFocus ? 2 : 0
                    }

                    Keys.onEscapePressed: event => {
                        root.cancelAuthentication();
                        event.accepted = true;
                    }
                    onClicked: root.submitResponse()
                }
            }
        }
    }
}

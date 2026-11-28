import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.bg_dark

    readonly property real u: height / 2160
    readonly property real d: u * 1.5
    readonly property int motion: parseInt(config.motion_ms)
    readonly property real line: parseInt(config.border_width)
    property int sessionIndex: sessionModel.lastIndex
    property var sessionNames: []
    property bool failed: false

    readonly property real railTop: 1440 * u
    readonly property real bandTop: railTop + 29 * d
    readonly property real bandHeight: 116 * d
    readonly property real underTop: bandTop + bandHeight + 3 * d

    function login() {
        root.failed = false
        sddm.login(userInput.text, passwordInput.text, root.sessionIndex)
    }

    function stepSession(step) {
        var n = root.sessionNames.length
        if (n > 0)
            root.sessionIndex = (root.sessionIndex + step + n) % n
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordInput.text = ""
            root.failed = true
            passwordInput.forceActiveFocus()
        }
        function onLoginSucceeded() {
            root.failed = false
        }
    }

    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: {
                var names = root.sessionNames.slice()
                names[index] = model.name
                root.sessionNames = names
            }
        }
    }

    Image {
        anchors.fill: parent
        source: "backdrop.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    component Label: Text {
        font.family: config.font_display
        font.pixelSize: 16 * root.d
        font.letterSpacing: font.pixelSize * 0.12
        font.capitalization: Font.AllUppercase
        color: config.text_faint
    }

    component Mono: Text {
        font.family: config.font_data
        font.pixelSize: 18 * root.d
        color: config.text_muted
    }

    component Rail: Item {
        id: rail
        property bool under: false
        x: 0
        width: root.width
        height: 29 * root.d
        Rectangle {
            width: parent.width
            height: 3 * root.d
            y: rail.under ? 26 * root.d : 0
            color: config.bronze_dark
        }
        Row {
            y: rail.under ? 0 : 8 * root.d
            spacing: 16 * root.d
            Repeater {
                model: Math.ceil(rail.width / (44 * root.d))
                Rectangle {
                    width: 28 * root.d
                    height: 18 * root.d
                    color: config.surface
                }
            }
        }
    }

    Row {
        x: 96 * root.d
        y: 64 * root.d
        spacing: 18 * root.d
        Image {
            width: 76 * root.d
            height: 76 * root.d
            source: "mark.png"
            sourceSize.width: 256
            sourceSize.height: 256
            smooth: true
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Label {
                text: "AVSPEX"
                color: config.bronze
                font.pixelSize: 24 * root.d
            }
            Label {
                text: "LEG · XIV · AVGVR"
            }
        }
    }

    Mono {
        anchors.right: parent.right
        anchors.rightMargin: 96 * root.d
        y: 86 * root.d
        font.pixelSize: 17 * root.d
        text: "[ host " + sddm.hostName + " ]"
    }

    Rail {
        y: root.railTop
    }

    Rectangle {
        id: band
        x: 0
        y: root.bandTop
        width: root.width
        height: root.bandHeight
        color: config.bg_darker

        Rectangle { width: parent.width; height: 3 * root.d; color: config.bronze }
        Rectangle { y: 3 * root.d; width: parent.width; height: 6 * root.d; color: config.bg_dark }
        Rectangle { y: parent.height - 9 * root.d; width: parent.width; height: 6 * root.d; color: config.bg_dark }
        Rectangle { y: parent.height - 3 * root.d; width: parent.width; height: 3 * root.d; color: config.bronze }

        Row {
            x: 160 * root.d
            height: parent.height
            spacing: 80 * root.d

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 480 * root.d
                spacing: 6 * root.d
                Label {
                    text: "OPERATOR"
                }
                TextInput {
                    id: userInput
                    width: parent.width
                    text: userModel.lastUser
                    font.family: config.font_body
                    font.pixelSize: 30 * root.d
                    font.weight: Font.Medium
                    color: config.text
                    selectionColor: config.surface
                    selectedTextColor: config.text_bright
                    clip: true
                    KeyNavigation.tab: passwordInput
                    KeyNavigation.backtab: poweroffButton
                    Keys.onReturnPressed: passwordInput.forceActiveFocus()
                    Keys.onEnterPressed: passwordInput.forceActiveFocus()
                }
                Rectangle {
                    width: parent.width
                    height: 3 * root.d
                    color: userInput.activeFocus ? config.gold : config.border
                    Behavior on color { ColorAnimation { duration: root.motion } }
                }
            }

            Rectangle {
                y: 18 * root.d
                width: 640 * root.d
                height: band.height - 36 * root.d
                color: config.bg_dark

                TextInput {
                    id: passwordInput
                    anchors.left: parent.left
                    anchors.right: passwordLabel.left
                    anchors.leftMargin: 24 * root.d
                    anchors.rightMargin: 18 * root.d
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    font.family: config.font_body
                    font.pixelSize: 30 * root.d
                    color: config.text
                    selectionColor: config.surface
                    selectedTextColor: config.text_bright
                    clip: true
                    KeyNavigation.tab: sessionZone
                    KeyNavigation.backtab: userInput
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()
                    onTextChanged: if (text.length > 0) root.failed = false
                }
                Label {
                    id: passwordLabel
                    anchors.right: parent.right
                    anchors.rightMargin: 24 * root.d
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PASSWORD"
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 3 * root.d
                    color: passwordInput.activeFocus ? config.gold : config.border
                    Behavior on color { ColorAnimation { duration: root.motion } }
                }
            }

            FocusScope {
                id: sessionZone
                anchors.verticalCenter: parent.verticalCenter
                width: sessionColumn.width
                height: sessionColumn.height
                activeFocusOnTab: true
                KeyNavigation.tab: rebootButton
                KeyNavigation.backtab: passwordInput
                Keys.onLeftPressed: root.stepSession(-1)
                Keys.onUpPressed: root.stepSession(-1)
                Keys.onRightPressed: root.stepSession(1)
                Keys.onDownPressed: root.stepSession(1)
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()

                Column {
                    id: sessionColumn
                    spacing: 6 * root.d
                    Label {
                        text: "SESSION"
                    }
                    Row {
                        id: sessionRow
                        Repeater {
                            model: root.sessionNames
                            Rectangle {
                                readonly property bool on: index === root.sessionIndex
                                width: sessionText.implicitWidth + 44 * root.d
                                height: sessionText.implicitHeight + 20 * root.d
                                color: on ? config.porphyry : "transparent"
                                border.width: root.line
                                border.color: on ? config.porphyry : config.surface
                                Text {
                                    id: sessionText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: config.font_body
                                    font.pixelSize: 22 * root.d
                                    font.weight: Font.Medium
                                    font.letterSpacing: font.pixelSize * 0.12
                                    font.capitalization: Font.AllUppercase
                                    color: parent.on ? config.text_bright : config.text_muted
                                }
                                Rectangle {
                                    visible: parent.on
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 3 * root.d
                                    color: config.bronze
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.sessionIndex = index
                                        sessionZone.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: sessionRow.width
                        height: 3 * root.d
                        color: sessionZone.activeFocus ? config.gold : "transparent"
                        Behavior on color { ColorAnimation { duration: root.motion } }
                    }
                }
            }
        }

        Text {
            id: clock
            anchors.right: parent.right
            anchors.rightMargin: 160 * root.d
            anchors.verticalCenter: parent.verticalCenter
            font.family: config.font_display
            font.pixelSize: 56 * root.d
            font.letterSpacing: font.pixelSize * 0.06
            color: config.gold
            text: Qt.formatTime(new Date(), "HH:mm")
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }
    }

    Rail {
        y: root.underTop
        under: true
    }

    Row {
        x: 160 * root.d
        y: root.underTop + 29 * root.d + 30 * root.d
        spacing: 40 * root.d
        Label {
            visible: root.failed
            text: "LOGIN FAILED"
            color: config.accent
            font.pixelSize: 18 * root.d
        }
        Mono {
            visible: keyboard.capsLock
            text: "[ CAPS ]"
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 96 * root.d
        y: root.underTop + 29 * root.d + 30 * root.d
        spacing: 30 * root.d

        Mono {
            id: rebootButton
            visible: sddm.canReboot
            text: "[ REBOOT ]"
            color: activeFocus ? config.gold : config.text_muted
            activeFocusOnTab: true
            KeyNavigation.tab: poweroffButton
            KeyNavigation.backtab: sessionZone
            Keys.onReturnPressed: sddm.reboot()
            Keys.onEnterPressed: sddm.reboot()
            Keys.onSpacePressed: sddm.reboot()
            Behavior on color { ColorAnimation { duration: root.motion } }
            MouseArea {
                anchors.fill: parent
                onClicked: sddm.reboot()
            }
        }
        Mono {
            id: poweroffButton
            visible: sddm.canPowerOff
            text: "[ POWEROFF ]"
            color: activeFocus ? config.gold : config.text_muted
            activeFocusOnTab: true
            KeyNavigation.tab: userInput
            KeyNavigation.backtab: rebootButton
            Keys.onReturnPressed: sddm.powerOff()
            Keys.onEnterPressed: sddm.powerOff()
            Keys.onSpacePressed: sddm.powerOff()
            Behavior on color { ColorAnimation { duration: root.motion } }
            MouseArea {
                anchors.fill: parent
                onClicked: sddm.powerOff()
            }
        }
    }

    Component.onCompleted: {
        if (userInput.text.length > 0)
            passwordInput.forceActiveFocus()
        else
            userInput.forceActiveFocus()
    }
}

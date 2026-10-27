import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

Item {
    id: root
    objectName: "torRoot"

    readonly property var backend: (typeof logos !== "undefined" && logos) ? logos.module("tor_ui") : null
    readonly property bool ready: backend !== null

    function j(raw, fallback) { try { return raw ? JSON.parse(raw) : fallback } catch (e) { return fallback } }
    readonly property var st: ready ? j(backend.statusJson, ({})) : ({})
    readonly property var usage: ready ? j(backend.usageJson, null) : null
    readonly property var entries: ready ? j(backend.logJson, []) : []
    readonly property string torState: ready ? backend.state : "unavailable"
    readonly property bool busy: ready && backend.busy
    readonly property int progress: Number(st.progress) || 0
    // What Arti judges is in the way: offline, filtering, clock, cantReachTor or directory.
    readonly property string blockage: root.st.blockage || ""
    readonly property bool slow: root.torState === "connecting" && root.blockage === "directory"
    property bool advancedOpen: false

    // The SOCKS port, for programs outside Logos: off unless the user turns it on.
    readonly property var socks: ready ? j(backend.settingsJson, ({})).socks || null : null
    readonly property string socksListening: root.socks && root.socks.listening ? root.socks.listening : ""
    readonly property bool socksOpen: root.socksListening !== ""
    // What the switch and the button do; the doc-test calls them, since a click misses a
    // control scrolled out of view.
    function toggleSocks() {
        if (root.socksOpen) backend.setSocks(false, socksField.text.trim())
        else socksDialog.open()
    }
    function askToForget() { forgetDialog.open() }
    function loopbackAddress(a) { return /^(127\.\d{1,3}\.\d{1,3}\.\d{1,3}|\[::1\]):\d+$/.test(String(a || "").trim()) }

    // Read by the doc-test, and true statements about this run besides.
    readonly property bool usageRead: root.usage !== null
    readonly property int appCount: root.apps.length
    readonly property bool hasLog: root.entries.length > 0
    // Times Tor became ready while the view was open; each ready state has its own `since`.
    property int readyCount: 0
    property double lastReadySince: 0
    // Times the SOCKS port moved while the view was open: a reconnect keeps it.
    property int socksChanges: 0
    property string lastSocks: ""
    onStChanged: {
        if (root.st.state === "ready" && Number(root.st.since) !== root.lastReadySince) {
            root.lastReadySince = Number(root.st.since)
            root.readyCount++
        }
        const socks = root.st.socks || ""
        if (socks !== "" && root.lastSocks !== "" && socks !== root.lastSocks) root.socksChanges++
        if (socks !== "") root.lastSocks = socks
    }

    // Moves "asked 12 s ago" between polls.
    property double now: Date.now()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = Date.now() }

    function stateLabel(s) {
        if (s === "idle") return "Idle"
        if (s === "ready") return "Ready"
        if (s === "connecting") return root.progress > 0 ? "Connecting " + root.progress + "%" : "Connecting"
        if (s === "blocked") return "Blocked"
        if (s === "failed") return "Failed"
        if (s === "unavailable") return "Not loaded"
        return "Checking"
    }
    function stateColour(s) {
        if (s === "ready") return Theme.palette.success
        if (s === "connecting") return Theme.palette.info
        if (s === "blocked") return Theme.palette.warning
        if (s === "failed" || s === "unavailable") return Theme.palette.error
        return Theme.palette.textTertiary
    }
    function headline(s) {
        if (s === "idle") return "Tor is off: no app set to use it has asked for it. Nothing connects to the Tor network until one does."
        if (s === "ready") return "Apps set to use Tor reach their servers through it."
        if (s === "connecting") return "Joining the Tor network" + (root.slow ? ", slowly" : "") + ". Connections wait until it is done."
        if (s === "blocked") return "Tor is not getting through."
        if (s === "failed") return "Tor is not running. Apps set to use it have no connection."
        if (s === "unavailable") return "The Tor module is not loaded, so apps set to use it have no connection."
        return "Checking Tor…"
    }
    function blockedTitle(kind) {
        if (kind === "offline") return "This computer seems to be offline"
        if (kind === "filtering") return "This network seems to block Tor"
        if (kind === "clock") return "This computer's clock is off"
        if (kind === "directory") return "Tor's directory is not coming through"
        return "Tor cannot reach its network"
    }
    function blockedMessage(kind) {
        const below = "see \"If Tor is blocked where you are\" below."
        if (kind === "offline") return "Tor cannot open a connection to any relay. Check the network connection: Tor keeps trying, and Reconnect tries now."
        if (kind === "filtering") return "Connections open, but no Tor handshake completes: something on the way filters Tor. To get around it, " + below
        if (kind === "clock") return "Tor checks relays' certificates and its directory against the clock. Set the clock right, then Reconnect."
        if (kind === "directory") return "Its downloads keep failing. A very slow or unsteady connection can do this, and so can a network that "
                                         + "interferes with Tor. Tor keeps trying, and Reconnect tries now. If it stays like this, " + below
        return "Check that this computer is online. If it is, this network may block Tor: " + below
    }
    function fmtBytes(n) {
        if (n === undefined || n === null || n < 0) return "—"
        if (n < 1000) return n + " B"
        const units = ["kB", "MB", "GB", "TB"]
        let v = n / 1000
        let i = 0
        while (v >= 1000 && i < units.length - 1) { v /= 1000; i++ }
        return (v < 10 ? v.toFixed(1) : Math.round(v)) + " " + units[i]
    }
    function fmtClock(ms) { return ms > 0 ? Qt.formatTime(new Date(ms), "hh:mm") : "—" }
    function fmtSecs(ms) { return ms < 10000 ? (ms / 1000).toFixed(1) + " s" : Math.round(ms / 1000) + " s" }
    function ago(ms) {
        const s = Math.max(0, Math.round((root.now - ms) / 1000))
        return s < 60 ? s + " s ago" : Math.floor(s / 60) + " min ago"
    }
    // The modules that follow Tor, by what the user knows them as.
    readonly property var appNames: ({ zcash_node_module: "Zcash wallet" })
    function appName(m) { return root.appNames[m] || m }
    // The modules seen in the last 90 s; usage() also lists those seen earlier, for their traffic.
    readonly property var apps: root.usage && root.usage.apps ? root.usage.apps.filter(function (a) { return a.active }) : []
    function sinceLine() {
        if (root.torState !== "ready") return ""
        const t = "Ready since " + root.fmtClock(Number(root.st.since))
        return root.st.joinMs > 0 ? t + " · joined in " + root.fmtSecs(Number(root.st.joinMs)) : t
    }
    function logLine(e) {
        return Qt.formatTime(new Date(e.at), "hh:mm:ss") + "  " + (e.level + "    ").slice(0, 5)
               + "  " + e.target + ": " + e.message
    }
    readonly property string logText: root.entries.map(root.logLine).join("\n")

    Connections {
        target: (typeof logos !== "undefined") ? logos : null
        ignoreUnknownSignals: true
        function onIntentRequested(requestId, intent, params, requesterName) {
            if (intent === "tor.manage") logos.respond(requestId, true, ({}), "")
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.palette.background }

    LogosScrollView {
        anchors.fill: parent
        anchors.margins: 20

        ColumnLayout {
            width: root.width - 40
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                LogosText { text: "Tor"; font.pixelSize: 22; font.weight: Theme.typography.weightBold }
                LogosBadge { objectName: "stateBadge"; text: root.stateLabel(root.torState); color: root.stateColour(root.torState) }
                Item { Layout.fillWidth: true }
            }
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.palette.textSecondary
                text: "The Tor that comes with Logos. Apps reach it on this computer; each app's privacy settings say whether it uses it."
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.surfaceRaised
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large

                contentItem: ColumnLayout {
                    spacing: 10

                    LogosText {
                        objectName: "headline"
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.weight: Theme.typography.weightBold
                        text: root.headline(root.torState)
                    }
                    LogosProgressBar {
                        objectName: "joinBar"
                        Layout.fillWidth: true
                        visible: root.torState === "connecting" || root.torState === "blocked"
                        value: root.progress / 100
                        indeterminate: root.torState === "connecting" && root.progress === 0
                        trackColor: Theme.palette.borderSecondary
                        fillColor: root.torState === "blocked" ? Theme.palette.warning : Theme.palette.info
                    }
                    LogosText {
                        objectName: "detailText"
                        Layout.fillWidth: true
                        visible: root.torState !== "ready" && text !== ""
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        color: Theme.palette.textTertiary
                        text: root.st.detail || ""
                    }
                    LogosText {
                        objectName: "sinceText"
                        Layout.fillWidth: true
                        visible: text !== ""
                        textFormat: Text.PlainText
                        color: Theme.palette.textSecondary
                        text: root.sinceLine()
                    }
                    LogosNotice {
                        objectName: "blockedNotice"
                        Layout.fillWidth: true
                        severity: LogosNotice.Warning
                        shown: root.torState === "blocked"
                        title: root.blockedTitle(root.blockage)
                        message: root.blockedMessage(root.blockage)
                    }
                    LogosNotice {
                        objectName: "slowNotice"
                        Layout.fillWidth: true
                        severity: LogosNotice.Info
                        shown: root.slow
                        title: "Slow going"
                        message: "Tor's view of the network is downloading slowly, and its downloads keep running out of time. On "
                                 + "a slow connection the first join can take a few minutes; Tor keeps trying by itself."
                    }
                    LogosNotice {
                        objectName: "failedNotice"
                        Layout.fillWidth: true
                        severity: LogosNotice.Error
                        shown: root.torState === "failed"
                        title: "Tor did not start or could not join"
                        message: "A failed join is tried again every minute; Reconnect tries now. If it keeps failing, "
                                 + "the log under Advanced says why."
                    }
                    LogosText {
                        objectName: "errorText"
                        Layout.fillWidth: true
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        color: Theme.palette.error
                        text: root.ready ? backend.lastError : "The Tor app's backend is not available."
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        LogosButton {
                            objectName: "reconnectButton"
                            text: root.torState === "idle" ? "Start" : "Reconnect"
                            enabled: root.ready && !root.busy && root.torState !== "unavailable" && root.torState !== ""
                            onClicked: backend.reconnect()
                        }
                        LogosSpinner { visible: root.busy; running: visible }
                        LogosText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.textTertiary
                            text: root.torState === "idle"
                                  ? "Joins the Tor network now, without waiting for an app."
                                  : "Ends Tor's open connections and joins again on the same port. Apps reconnect by themselves."
                        }
                    }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.surfaceRaised
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large

                contentItem: ColumnLayout {
                    spacing: 8
                    LogosText { text: "Apps using Tor"; font.weight: Theme.typography.weightBold }
                    Repeater {
                        model: root.apps
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            LogosText { objectName: "app_" + modelData.module; textFormat: Text.PlainText; text: root.appName(modelData.module) }
                            Item { Layout.fillWidth: true }
                            LogosText {
                                textFormat: Text.PlainText
                                color: Theme.palette.textTertiary
                                text: (modelData.requests > 0 ? root.fmtBytes(modelData.received) + " received · " : "") + "asked " + root.ago(modelData.seenAt)
                            }
                        }
                    }
                    LogosText {
                        objectName: "noAppsText"
                        Layout.fillWidth: true
                        visible: root.apps.length === 0
                        wrapMode: Text.Wrap
                        color: Theme.palette.textSecondary
                        text: root.usage ? "No app has asked for Tor in the last 90 seconds." : "—"
                    }
                    LogosText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.palette.textTertiary
                        text: "Logos apps reach this Tor over IPC, so it knows which app asks. An app set to skip Tor, or to use your own, does not ask."
                    }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.surfaceRaised
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large

                contentItem: ColumnLayout {
                    spacing: 10
                    LogosText {
                        Layout.fillWidth: true
                        font.weight: Theme.typography.weightBold
                        textFormat: Text.PlainText
                        text: "Since Tor started" + (root.usage ? " at " + root.fmtClock(Number(root.usage.startedAt)) : "")
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.min(5, Math.floor(width / 150)))
                        columnSpacing: 10
                        rowSpacing: 10
                        LogosStatCard {
                            objectName: "sentCard"
                            Layout.fillWidth: true
                            label: "Sent"
                            value: root.usage ? root.fmtBytes(root.usage.sent) : "—"
                        }
                        LogosStatCard {
                            objectName: "receivedCard"
                            Layout.fillWidth: true
                            label: "Received"
                            value: root.usage ? root.fmtBytes(root.usage.received) : "—"
                        }
                        LogosStatCard {
                            objectName: "streamsCard"
                            Layout.fillWidth: true
                            label: "Connections open"
                            value: root.usage ? String(root.usage.streams.open) : "—"
                            caption: root.usage ? root.usage.streams.total + " in all" : ""
                        }
                        LogosStatCard {
                            objectName: "filesCard"
                            Layout.fillWidth: true
                            label: "Tor's files"
                            value: root.usage ? root.fmtBytes(root.usage.files) : "—"
                        }
                        LogosStatCard {
                            objectName: "memoryCard"
                            Layout.fillWidth: true
                            label: "Memory"
                            value: root.usage && root.usage.memory !== null ? root.fmtBytes(root.usage.memory) : "—"
                        }
                    }
                    LogosText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.palette.textTertiary
                        text: "What apps, and programs on the SOCKS port, sent and received through Tor. Tor's own traffic, keeping its view of the network current, is not counted."
                    }
                }
            }

            LogosFrame {
                Layout.fillWidth: true
                backgroundColor: Theme.palette.surfaceRaised
                borderColor: Theme.palette.borderSecondary
                radius: Theme.spacing.radiusLarge
                padding: Theme.spacing.large

                contentItem: ColumnLayout {
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        LogosText { text: "What Tor hides, and what it doesn't"; font.weight: Theme.typography.weightBold }
                        LogosInfoButton {
                            objectName: "privacyInfo"
                            title: "What Tor hides, and what it doesn't"
                            text: "What it hides\n"
                                  + "• From the servers your apps reach: this computer's IP address. They see a Tor relay's address instead.\n"
                                  + "• From your internet provider and anyone on your network: which servers you reach. They see that you use Tor, not what for.\n"
                                  + "• From each relay: the whole picture. Your traffic crosses three relays. The first, your entry guard, sees your "
                                  + "address but not where the traffic goes; the last, the exit, sees where it goes but not who sent it. An onion "
                                  + "service has no exit: the traffic stays inside Tor.\n\n"
                                  + "What it does not hide\n"
                                  + "• What an app sends. A server still reads each request, so an app must put nothing identifying in it. The "
                                  + "wallets send each request over its own circuit, so a server cannot link them together either.\n"
                                  + "• That you use Tor. Some networks block it; most just see it.\n"
                                  + "• Timing, from someone who watches your connection and a server's at the same time. Tor makes matching them "
                                  + "up hard, not impossible.\n\n"
                                  + "What it costs\n"
                                  + "• Speed: every request crosses three relays.\n"
                                  + "• The first start downloads about 7 MB, Tor's view of the network, and takes about 15 s. Later starts take "
                                  + "about a second. Tor keeps about 40 MB of files and uses 40 to 50 MB of memory.\n\n"
                                  + "Without Tor\n"
                                  + "Each app's privacy settings can skip Tor, or use a Tor of your own. Without Tor, a server sees this "
                                  + "computer's address and can tie it to what the app asks for and to when you are online, and your internet "
                                  + "provider sees which servers you reach."
                        }
                    }
                    LogosText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.palette.textSecondary
                        text: "Servers see a Tor relay's address instead of this computer's. Your internet provider sees that you use Tor, not which servers you reach."
                    }
                    RowLayout {
                        Layout.topMargin: 6
                        spacing: 8
                        LogosText { text: "If Tor is blocked where you are"; font.weight: Theme.typography.weightBold }
                        LogosInfoButton {
                            objectName: "blockedInfo"
                            title: "If Tor is blocked where you are"
                            text: "Some networks block Tor: a school's, a company's, or a whole country's. Tor then stays Connecting or "
                                  + "Blocked. First check that this computer is online, then try Reconnect.\n\n"
                                  + "Bridges get around a block: relays that are not listed publicly, reached in a way that does not look "
                                  + "like Tor. They are coming to this app. Until then:\n"
                                  + "1. Install Tor Browser from torproject.org and choose a bridge in its connection settings.\n"
                                  + "2. Keep Tor Browser running. Its Tor listens at socks5h://127.0.0.1:9150.\n"
                                  + "3. In each wallet's privacy settings, choose your own Tor and enter that address.\n\n"
                                  + "A bridge hides from your network that you use Tor. It is slower than connecting directly."
                        }
                    }
                    LogosText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.palette.textSecondary
                        text: "Bridges are coming to this app. Until then, Tor Browser can connect through a bridge and carry your wallets."
                    }
                }
            }

            LogosLink {
                objectName: "advancedLink"
                text: root.advancedOpen ? "Hide advanced" : "Show advanced"
                underline: false
                onActivated: root.advancedOpen = !root.advancedOpen
            }

            ColumnLayout {
                objectName: "advanced"
                Layout.fillWidth: true
                visible: root.advancedOpen
                spacing: 16

                LogosFrame {
                    Layout.fillWidth: true
                    backgroundColor: Theme.palette.surfaceRaised
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large

                    contentItem: ColumnLayout {
                        spacing: 8
                        LogosText { text: "SOCKS port for other programs"; font.weight: Theme.typography.weightBold }
                        LogosText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.textSecondary
                            text: (root.socksOpen ? "On, for programs outside Logos. " : "Off. ")
                                  + "Logos apps reach Tor over IPC and do not need it. It is for a program outside Logos that takes a "
                                  + "SOCKS proxy, such as a browser."
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            LogosSwitch {
                                objectName: "socksSwitch"
                                text: "Open the port"
                                checkable: false
                                checked: root.socksOpen
                                enabled: root.ready && root.socks !== null
                                onClicked: root.toggleSocks()
                            }
                            LogosTextField {
                                id: socksField
                                objectName: "socksField"
                                Layout.fillWidth: true
                                placeholderText: "127.0.0.1:9250"
                                text: root.socks ? root.socks.address : ""
                            }
                            LogosButton {
                                objectName: "socksApplyButton"
                                text: "Move it"
                                visible: root.socksOpen
                                enabled: socksField.text.trim() !== "" && socksField.text.trim() !== (root.socks ? root.socks.address : "")
                                onClicked: backend.setSocks(true, socksField.text.trim())
                            }
                        }
                        LogosCopyableText {
                            objectName: "socksText"
                            Layout.fillWidth: true
                            visible: root.socksOpen
                            text: root.socksListening
                        }
                        LogosText {
                            objectName: "socksError"
                            Layout.fillWidth: true
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: Theme.palette.error
                            text: root.socks && root.socks.error ? root.socks.error : ""
                        }
                        LogosText {
                            Layout.fillWidth: true
                            visible: root.socksOpen
                            wrapMode: Text.Wrap
                            color: root.loopbackAddress(root.socks ? root.socks.address : "") ? Theme.palette.textTertiary : Theme.palette.warning
                            text: root.loopbackAddress(root.socks ? root.socks.address : "")
                                  ? "Any program on this computer can use it, without a password, as with a system Tor."
                                  : "Any program on this computer, and any computer that reaches this address, can use your Tor without a password."
                        }
                    }
                }

                LogosFrame {
                    Layout.fillWidth: true
                    backgroundColor: Theme.palette.surfaceRaised
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large

                    contentItem: ColumnLayout {
                        spacing: 8
                        LogosText { text: "Forget Tor's data"; font.weight: Theme.typography.weightBold }
                        LogosText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.textSecondary
                            text: "For a Tor that stays stuck connecting. Tor deletes the entry guards it picked and its copy of the "
                                  + "network directory, then joins again from scratch."
                        }
                        LogosButton {
                            objectName: "forgetButton"
                            text: "Forget Tor's data…"
                            enabled: root.ready && !root.busy && root.torState !== "unavailable" && root.torState !== ""
                            onClicked: root.askToForget()
                        }
                    }
                }

                LogosFrame {
                    Layout.fillWidth: true
                    backgroundColor: Theme.palette.surfaceRaised
                    borderColor: Theme.palette.borderSecondary
                    radius: Theme.spacing.radiusLarge
                    padding: Theme.spacing.large

                    contentItem: ColumnLayout {
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            LogosText { text: "Tor log"; font.weight: Theme.typography.weightBold }
                            Item { Layout.fillWidth: true }
                            LogosCopyButton { objectName: "copyLogButton"; visible: root.logText !== ""; value: root.logText }
                        }
                        LogosText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.palette.textTertiary
                            text: "Kept in memory only. Tor leaves addresses out of it."
                        }
                        LogosText {
                            objectName: "logText"
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            font.family: Theme.typography.mono
                            font.pixelSize: 11
                            color: Theme.palette.textTertiary
                            text: root.logText !== "" ? root.logText : "No log yet."
                        }
                    }
                }
            }
        }
    }

    LogosWarningDialog {
        id: socksDialog
        objectName: "socksDialog"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        title: "Open a SOCKS port?"
        message: "Programs outside Logos can then send their traffic through your Tor at "
                 + (socksField.text.trim() || "127.0.0.1:9250") + ". It needs no password: any program on this computer can use "
                 + "it" + (root.loopbackAddress(socksField.text) ? "" : ", and so can any computer that reaches this address")
                 + ".\n\nLogos apps do not need it: they reach Tor over IPC, and Tor tells each of them apart. A program "
                 + "on the port is known to Tor only by its SOCKS password, if it sends one."
        leftActions: [ LogosButton { text: "Cancel"; onClicked: socksDialog.close() } ]
        rightActions: [
            LogosButton {
                objectName: "socksConfirmButton"
                text: "Open the port"
                onClicked: { socksDialog.close(); backend.setSocks(true, socksField.text.trim() || "127.0.0.1:9250") }
            }
        ]
    }

    LogosWarningDialog {
        id: forgetDialog
        objectName: "forgetDialog"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        title: "Forget Tor's data?"
        message: "Tor deletes the entry guards it picked and its copy of the network directory, then joins again from "
                 + "scratch: about 7 MB, and 15 s or more.\n\n"
                 + "Use it when Tor stays stuck connecting: guards that stopped answering are a common cause. It is not a "
                 + "routine step. Tor keeps the same guards for months on purpose, since each new guard is another chance "
                 + "for an observer to be your entry.\n\n"
                 + "Open connections end; apps reconnect by themselves."
        leftActions: [ LogosButton { text: "Cancel"; onClicked: forgetDialog.close() } ]
        rightActions: [
            LogosButton {
                objectName: "forgetConfirmButton"
                text: "Forget and reconnect"
                onClicked: { forgetDialog.close(); backend.forgetData() }
            }
        ]
    }
}

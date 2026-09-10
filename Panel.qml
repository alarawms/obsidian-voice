import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget for Obsidian Voice Capture. The bash CLI (bin/obsidian-voice-capture)
// owns all state — recording, transcription (voxtype/whisper.cpp), and filing the
// note into the Obsidian vault — so it works from the SUPER+SHIFT+V Hyprland
// keybinding with no shell running. This widget is a thin, disposable view: it
// polls the CLI's status.json for the mic icon's color/tooltip and offers the
// same start/stop action plus a peek at the last capture from a click.
Panel {
  id: root
  moduleName: "alarawms.obsidian-voice"
  ipcTarget: "alarawms.obsidian-voice"

  readonly property string scriptPath: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/alarawms.obsidian-voice/bin/obsidian-voice-capture"
  readonly property string statusPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/obsidian-voice/status.json"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool alwaysShow: setting("alwaysShow", true)

  property var statusData: ({})
  readonly property string state: statusData.state || "idle"
  readonly property bool recording: state === "recording"
  readonly property bool transcribing: state === "transcribing"
  readonly property bool errored: state === "error"
  readonly property string errorText: statusData.error || ""
  readonly property bool busy: recording || transcribing
  readonly property var last: statusData.last || null

  function parseStatus() {
    var raw = String(statusFile.text() || "")
    if (raw === "") return
    try { statusData = JSON.parse(raw) } catch (e) { /* keep previous state on a half-written file */ }
  }

  FileView {
    id: statusFile
    path: root.statusPath
    watchChanges: true
    onLoaded: root.parseStatus()
    onFileChanged: reload()
    onTextChanged: root.parseStatus()
  }

  // Ensures status.json exists (XDG_RUNTIME_DIR is cleared on every login) so
  // the FileView above has something to load right after a fresh shell start.
  Process { id: ensureStatus; command: [root.scriptPath, "status"]; running: false }
  Component.onCompleted: ensureStatus.running = true

  Process {
    id: captureProc
    running: false
  }
  function runCapture(sub) {
    if (captureProc.running) return
    captureProc.command = [root.scriptPath, sub]
    captureProc.running = true
  }

  function subtitle() {
    if (recording) return "Recording…"
    if (transcribing) return "Transcribing…"
    if (errored) return errorText || "Error"
    return "Idle"
  }

  function when(iso) {
    if (!iso) return ""
    var d = new Date(iso)
    if (isNaN(d.getTime())) return ""
    var now = new Date()
    var hm = Qt.formatTime(d, "HH:mm")
    return d.toDateString() === now.toDateString() ? hm : Qt.formatDate(d, "d MMM") + " " + hm
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  visible: alwaysShow || busy || errored

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍬"
    active: root.busy || root.errored
    useActiveColor: true
    activeColor: root.errored ? root.urgent : root.recording ? root.urgent : Color.accent
    tooltipText: (root.recording ? "Recording… click to stop"
                : root.transcribing ? "Transcribing…"
                : root.errored ? "Voice capture error: " + root.errorText
                : "Voice capture — click to record") + " · SUPER+SHIFT+V · right-click for details"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggle()
      else if (b === Qt.MiddleButton) root.runCapture("cancel")
      else root.runCapture("toggle")
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Obsidian Voice Capture"
          meta: root.subtitle()
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰍬"
              color: root.recording ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            Button {
              text: root.recording ? "Stop" : root.transcribing ? "Working…" : "Record"
              enabled: !root.transcribing
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.runCapture("toggle")
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.last !== null
          Text {
            width: parent.width
            text: "Last capture" + (root.last ? " · " + root.when(root.last.ts) : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            width: parent.width
            text: root.last ? root.last.text : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            visible: root.last && (root.last.dailyPath || root.last.notePath)
            text: root.last ? [root.last.dailyPath, root.last.notePath].filter(function(p) { return !!p }).join("  ·  ") : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }

        Text {
          width: parent.width
          visible: root.last === null
          text: "No captures yet — press SUPER+SHIFT+V and talk, or click Record above."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          Button {
            text: "Open vault"
            visible: root.last !== null && !!root.last.vault
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: Quickshell.execDetached(["xdg-open", root.last.vault])
          }
          Button {
            text: "Open config"
            foreground: root.foreground
            fontFamily: root.fontFamily
            bordered: true
            onClicked: Quickshell.execDetached(["xdg-open", (Quickshell.env("HOME") || "") + "/.config/obsidian-voice/config.json"])
          }
        }

        Text {
          width: parent.width
          text: "Filed to today's daily note and Inbox/ · model + vault path in ~/.config/obsidian-voice/config.json"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }
      }
    }
  }
}

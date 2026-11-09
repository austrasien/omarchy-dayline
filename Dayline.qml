import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "Model.js" as Model

// A rule along the bottom edge of the screen, the third side of the frame
// the day tape and the day bar draw. Nothing shows at rest. A change of
// volume or brightness opens it from the middle, with a card above the
// level; dictation runs its pixel meter along it for as long as it lasts.
Item {
  id: root

  property QtObject shell: null
  property var manifest: null

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")

  readonly property color hud: Color.accent
  readonly property color alarm: "#FF3030"
  readonly property color bright: Qt.tint(hud, Qt.alpha("#ffffff", 0.45))
  readonly property color dim: Qt.tint(Color.background, Qt.alpha(hud, 0.45))
  readonly property color hudBlack: Qt.darker(Color.background, 1.6)
  function dur(ms) { return Style.reduceMotion ? 0 : ms }

  readonly property var targetScreen: {
    var screens = Quickshell.screens
    var want = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    for (var i = 0; i < screens.length; i++) if (screens[i].name === want) return screens[i]
    return screens.length ? screens[0] : null
  }

  // Fixed: Hyprland animates a layer's resize. The surface only exists while
  // something shows. In use, the band rises from the gap below the windows
  // over their bottom edge, as the side rails do over theirs.
  readonly property int surfaceHeight: 170
  readonly property int restHeight: Math.max(8, Style.gapsOut * 2)
  readonly property int bandHeight: 28
  function bandAt(open) { return restHeight + (bandHeight - restHeight) * open }
  readonly property int cardBottom: surfaceHeight - bandHeight
  // From the windows' left border to their right one: the band's top edge and
  // those borders then meet in two corners, without crossing.
  readonly property int edgeInset: Style.gapsOut * 2

  // ---------------------------------------------------------------- the OSD

  property var cur: Model.readOsd({})
  property bool wanted: false      // the message is on: the card stays open
  property bool osdUp: false       // something of it is still on screen
  property real opened: 0          // how far the rule has opened, 0 to 1

  function showOsd(json) {
    var o
    try { o = JSON.parse(json || "{}") } catch (e) { return "bad" }
    var next = Model.readOsd(o)
    if (next.hasProgress && !next.muted) {
      var direction = Model.surgeDirection(lastPercent[next.label], next.percent, next.scale)
      if (direction !== 0) startSurge(direction)
      lastPercent[next.label] = next.percent
    }
    cur = next
    wanted = true
    osdUp = true
    closingRule.stop()
    openingRule.restart()
    if (cur.duration > 0) { hideTimer.interval = cur.duration; hideTimer.restart() }
    else hideTimer.stop()
    return "ok"
  }
  // A change sends a wave along the fill: it gathers speed, slams into its
  // end, right going up and left going down, and the impact flashes.
  property var lastPercent: ({})
  property real surge: 0
  property int surgeDir: 1
  property real impact: 0
  function startSurge(direction) {
    // Keys held down repeat faster than the wave travels: let it arrive.
    if (surgeRun.running && surgeDir === direction) return
    surgeDir = direction
    surgeRun.restart()
  }
  SequentialAnimation {
    id: surgeRun
    PropertyAction { target: root; property: "surge"; value: 0 }
    NumberAnimation { target: root; property: "surge"; to: 1.5; duration: root.dur(340); easing.type: Easing.InCubic }
    PropertyAction { target: root; property: "impact"; value: 1 }
    NumberAnimation { target: root; property: "impact"; to: 0; duration: root.dur(260); easing.type: Easing.OutCubic }
  }

  function closeOsd() {
    hideTimer.stop()
    wanted = false
  }
  Timer { id: hideTimer; onTriggered: root.wanted = false }

  NumberAnimation { id: openingRule; target: root; property: "opened"; to: 1; duration: root.dur(240); easing.type: Easing.OutCubic }
  NumberAnimation {
    id: closingRule
    target: root
    property: "opened"
    to: 0
    duration: root.dur(220)
    easing.type: Easing.OutCubic
    onFinished: root.osdUp = false
  }

  // ----------------------------------------------------------- the dictation

  property string dictState: "idle"
  property string demoState: ""
  readonly property string dictMode: demoState !== "" ? demoState
    : dictState === "recording" || dictState === "transcribing" ? dictState : "idle"
  readonly property bool dictating: dictMode !== "idle"
  property real dictOpened: 0
  readonly property bool dictUp: dictating || dictOpened > 0
  property real peak: 0
  property bool dictFromLeft: true
  property string dictText: ""
  property string demoText: ""
  onDictatingChanged: {
    if (dictating) { dictFromLeft = Math.random() < 0.5; dictText = ""; dictClosing.stop(); dictOpening.restart() }
    else { dictOpening.stop(); dictClosing.restart() }
  }
  NumberAnimation { id: dictOpening; target: root; property: "dictOpened"; to: 1; duration: root.dur(260); easing.type: Easing.OutCubic }
  NumberAnimation { id: dictClosing; target: root; property: "dictOpened"; to: 0; duration: root.dur(200); easing.type: Easing.InCubic }

  // Written on every change, once it exists: it may not, until the first
  // dictation since boot.
  FileView {
    id: stateFile
    path: root.runtimeDir + "/voxtype/state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.dictState = text().trim()
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: stateFile.reload() }

  // What has been said so far, written by the dictation client. Polled, and
  // only during a dictation: the file comes and goes with each one.
  FileView {
    id: textFile
    path: root.runtimeDir + "/nemotron/text"
    printErrors: false
    onLoaded: root.dictText = text()
  }
  Timer {
    interval: 120
    running: root.dictating && root.demoState === ""
    repeat: true
    onTriggered: textFile.reload()
  }

  Process {
    running: root.demoState === "" && root.dictMode === "recording"
    command: ["tail", "-n0", "-F", root.runtimeDir + "/nemotron/levels.ndjson"]
    stdout: SplitParser {
      onRead: function(line) {
        try { root.peak = Number(JSON.parse(line).peak) || 0 } catch (e) {}
      }
    }
  }
  Timer {
    interval: 80
    running: root.demoState === "recording"
    repeat: true
    onTriggered: root.peak = Math.random() * Math.random()
  }

  // ------------------------------------------------------------- the window

  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.targetScreen !== null && (root.osdUp || root.dictUp)
    color: "transparent"
    implicitHeight: root.surfaceHeight
    anchors { bottom: true; left: true; right: true }
    WlrLayershell.namespace: "austraz-dayline"
    // Over everything, a fullscreen video included: that is where the volume
    // changes most, and it only lasts a moment.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    mask: Region {}

    Item {
      id: stage
      anchors.fill: parent

      // The pixel meter, or the bar it turns into while transcribing.
      Loader {
        active: root.dictUp
        visible: !root.osdUp
        x: root.edgeInset
        width: root.bandWidth
        height: parent.height
        sourceComponent: DictationMeter {
          bar: root
          stageWidth: root.bandWidth
          text: root.demoState !== "" ? root.demoText : root.dictText
          stageHeight: stage.height
          mode: root.dictMode
          peak: root.peak
          opened: root.dictOpened
          fromLeft: root.dictFromLeft
        }
      }

      // The rule, opening from the middle as the band rises.
      Item {
        id: ruleClip
        readonly property real band: root.bandAt(root.opened)
        visible: root.osdUp && root.cur.hasProgress
        x: root.edgeInset + (root.bandWidth - width) / 2
        y: stage.height - band
        width: root.bandWidth * root.opened
        height: band
        clip: true

        Item {
          x: root.edgeInset - ruleClip.x
          width: root.bandWidth
          height: parent.height

          Rectangle { anchors.fill: parent; color: Color.background }
          Rectangle { y: 2; width: parent.width; height: parent.height - 2; color: Qt.alpha(root.hud, 0.22) }
          // Up to 100 % in the theme's accent, red past it.
          Rectangle {
            y: 2
            height: parent.height - 2
            width: parent.width * root.greenFill
            color: root.hud
          }
          Rectangle {
            y: 2
            x: parent.width * root.overFrom
            height: parent.height - 2
            width: parent.width * Math.max(0, root.shownFill - root.overFrom)
            color: root.alarm
          }
          // The wave, inside the fill, three pulses deep.
          Item {
            id: surgeZone
            readonly property real length: root.bandWidth * root.shownFill
            y: 2
            width: length
            height: parent.height - 2
            clip: true

            Repeater {
              model: 3
              delegate: Rectangle {
                required property int index
                readonly property real at: Math.min(1, root.surge - index * 0.17)
                readonly property real head: root.surgeDir > 0 ? surgeZone.length * at : surgeZone.length * (1 - at)
                visible: surgeRun.running && root.impact === 0 && at > 0
                x: root.surgeDir > 0 ? head - width : head
                width: 340
                height: surgeZone.height
                opacity: 1 - index * 0.3
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0; color: root.surgeDir > 0 ? "transparent" : "#ffffff" }
                  GradientStop { position: root.surgeDir > 0 ? 0.8 : 0.2; color: Qt.alpha(root.bright, 0.85) }
                  GradientStop { position: 1; color: root.surgeDir > 0 ? "#ffffff" : "transparent" }
                }
              }
            }

            // The impact, against the end it hit.
            Rectangle {
              visible: root.impact > 0
              x: root.surgeDir > 0 ? surgeZone.length - width : 0
              width: 120 + 180 * (1 - root.impact)
              height: surgeZone.height
              opacity: root.impact
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.surgeDir > 0 ? "transparent" : "#ffffff" }
                GradientStop { position: 1; color: root.surgeDir > 0 ? "#ffffff" : "transparent" }
              }
            }
          }
          // Stands in for the window's border it covers.
          Rectangle { width: parent.width; height: 2; color: root.hud }
          Repeater {
            model: Model.ticks(root.cur.scale)
            delegate: Rectangle {
              required property var modelData
              x: Math.round(root.bandWidth * modelData.fraction)
              y: 2
              width: modelData.notch ? 2 : 1
              height: modelData.notch ? ruleClip.band - 2 : modelData.major ? 12 : 6
              color: modelData.notch ? root.bright
                : modelData.fraction <= root.shownFill ? root.hudBlack : root.dim
            }
          }
          // The level itself.
          Rectangle {
            x: Math.round(root.bandWidth * root.shownLevel) - 1 - (root.surgeDir > 0 ? 8 * root.impact : 0)
            width: 3 + (root.surgeDir > 0 ? 8 * root.impact : 0)
            height: parent.height
            color: root.bright
          }
          // Worn tape: dark lines across the whole rule, as over the cards' text.
          Image {
            y: 2
            width: parent.width
            height: parent.height - 2
            fillMode: Image.Tile
            verticalAlignment: Image.AlignTop
            horizontalAlignment: Image.AlignLeft
            source: "data:image/svg+xml," + encodeURIComponent(
              "<svg xmlns='http://www.w3.org/2000/svg' width='3' height='3'><rect width='3' height='1' fill='"
              + root.hudBlack + "' fill-opacity='0.6'/></svg>")
          }
        }
      }

      Loader {
        active: root.osdUp
        sourceComponent: HudCard {
          bar: root
          width: root.cur.hasProgress ? 220 : Math.min(420, Math.max(220, 60 + root.cur.title.length * 10))
          shown: root.wanted
          onClosed: {
            if (root.wanted) return
            openingRule.stop()
            closingRule.restart()
          }
          ink: root.cur.muted || root.cur.overdrive ? root.alarm : root.hud
          statusInk: root.alarm
          head: root.cur.label
          status: root.cur.status
          title: root.cur.title
          x: root.edgeInset + Model.cardX(root.cur.hasProgress ? root.shownLevel : 0.5, width, root.bandWidth, 2)
          y: root.cardBottom - height - 10
          Behavior on x { NumberAnimation { duration: root.dur(120); easing.type: Easing.OutCubic } }
        }
      }
    }
  }

  readonly property real bandWidth: stage.width - 2 * edgeInset

  // The level and the fill move smoothly between two presses of a key, but
  // start in place.
  property real shownLevel: cur.fraction
  property real shownFill: cur.fill
  // The level is pushed a little past its mark, and comes back.
  Behavior on shownLevel { enabled: root.opened > 0; NumberAnimation { duration: root.dur(220); easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
  Behavior on shownFill { enabled: root.opened > 0; NumberAnimation { duration: root.dur(220); easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
  readonly property real overFrom: cur.volume ? 0.5 : 1
  readonly property real greenFill: Math.min(shownFill, overFrom)

  IpcHandler {
    target: "austraz.dayline"
    function osd(payload: string): string { return root.showOsd(payload) }
    function closeOsd(): string { root.closeOsd(); return "ok" }
    function dictation(): string { return "ok" }
    function demo(mode: string): void { root.demoState = mode === "off" ? "" : mode }
    function demoSay(text: string): void { root.demoText = text }
    function snapshot(path: string): void { stage.grabToImage(function(r) { r.saveToFile(path) }) }
  }
}

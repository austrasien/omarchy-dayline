import QtQuick
import qs.Commons
import "Model.js" as Model

// Omakoe's 8-bit meter, as wide as the screen: hard-stepped mirrored columns
// of cells that run across from one edge or the other. Transcribing, they
// become a two-row bar with a light swung along it. What has been said grows
// from the opposite edge, over the meter, and once it fills the band it
// scrolls to the left, its end staying in view.
Item {
  id: meter
  required property var bar
  property real stageWidth: 0
  property real stageHeight: 0
  property string mode: "idle"
  property real peak: 0
  property real opened: 0
  property bool fromLeft: true
  property string text: ""

  readonly property int pitch: 4
  readonly property int columns: Math.ceil(stageWidth / pitch)
  readonly property bool recording: mode === "recording"
  readonly property int meterHeight: Model.WAVE_STEPS * pitch
  readonly property real band: bar.bandAt(opened)

  property var wave: []
  property bool cursorOn: true
  Timer {
    interval: 450
    running: meter.text !== ""
    repeat: true
    onTriggered: meter.cursorOn = !meter.cursorOn
  }
  Timer {
    interval: 50
    running: meter.recording
    repeat: true
    onTriggered: meter.wave = Model.pushWave(meter.wave, meter.peak, meter.columns, 3)
  }

  // One cell, tiled: columns of cells are one image each, not eight items.
  function tile(ink) {
    return "data:image/svg+xml," + encodeURIComponent(
      "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'><rect width='3' height='3' fill='" + ink + "'/></svg>")
  }

  Item {
    id: clipper
    x: meter.fromLeft ? 0 : meter.stageWidth - width
    width: meter.stageWidth * meter.opened
    height: meter.stageHeight
    clip: true

    // The band, rising over the bottom of the windows; the meter rides in it.
    Rectangle {
      x: -clipper.x
      y: meter.stageHeight - meter.band
      width: meter.stageWidth
      height: meter.band
      color: Color.background
      clip: true

      Rectangle { width: parent.width; height: 2; color: meter.bar.hud }

      Item {
      y: parent.height - meter.meterHeight - 1
      width: meter.stageWidth
      height: meter.meterHeight

      Item {
        anchors.fill: parent
        visible: meter.recording
        Repeater {
          model: meter.columns
          delegate: Image {
            required property int index
            readonly property int steps: meter.wave[meter.fromLeft ? index : meter.columns - 1 - index] || 0
            visible: steps > 0
            x: index * meter.pitch
            y: Model.waveTop(steps) * meter.pitch
            width: meter.pitch
            height: steps * meter.pitch
            fillMode: Image.Tile
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignTop
            smooth: false
            source: meter.tile(meter.bar.hud)
          }
        }
      }

      // Transcribing: the bar, dim, and a light going to and fro, in hard steps.
      Item {
        id: scanner
        anchors.fill: parent
        visible: !meter.recording
        property real head: 0
        readonly property int headColumn: meter.fromLeft ? Math.round(head) : meter.columns - 1 - Math.round(head)
        readonly property int tail: 40
        SequentialAnimation on head {
          running: !meter.recording
          loops: Animation.Infinite
          NumberAnimation { to: meter.columns - 1; duration: 1400; easing.type: Easing.InOutSine }
          NumberAnimation { to: 0; duration: 1400; easing.type: Easing.InOutSine }
        }
        Image {
          y: 2 * meter.pitch
          width: parent.width
          height: 2 * meter.pitch
          fillMode: Image.Tile
          horizontalAlignment: Image.AlignLeft
          verticalAlignment: Image.AlignTop
          smooth: false
          opacity: 0.16
          source: meter.tile(meter.bar.hud)
        }
        Repeater {
          model: 4
          delegate: Image {
            required property int index
            readonly property int reach: Math.round(scanner.tail * (4 - index) / 4)
            readonly property int column: scanner.headColumn - reach
            x: column * meter.pitch
            y: 2 * meter.pitch
            width: reach * 2 * meter.pitch
            height: 2 * meter.pitch
            fillMode: Image.Tile
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignTop
            smooth: false
            opacity: 0.3
            source: meter.tile(meter.bar.hud)
          }
        }
      }
      }

      Item {
        id: said
        readonly property int pad: 10
        readonly property real textWidth: saidText.implicitWidth
        visible: meter.text !== ""
        x: meter.fromLeft ? meter.stageWidth - width : 0
        y: 2
        width: Math.min(meter.stageWidth, textWidth + 2 * pad)
        height: parent.height - 2
        clip: true

        Rectangle { anchors.fill: parent; color: meter.bar.hudBlack }
        Image {
          anchors.fill: parent
          fillMode: Image.Tile
          verticalAlignment: Image.AlignTop
          horizontalAlignment: Image.AlignLeft
          source: "data:image/svg+xml," + encodeURIComponent(
            "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'><rect width='4' height='1' fill='"
            + meter.bar.hud + "' fill-opacity='0.07'/></svg>")
        }
        Text {
          id: saidText
          x: Math.min(said.pad, said.width - said.textWidth - said.pad)
          anchors.verticalCenter: parent.verticalCenter
          // Enough to fill the screen, however long the dictation.
          text: meter.text.slice(-400) + (meter.cursorOn ? " █" : "  ")
          textFormat: Text.PlainText
          color: meter.bar.hud
          font.family: Style.fontFamily
          font.pixelSize: 15
          font.bold: true
          font.capitalization: Font.AllUppercase
        }
        // Worn tape: dark lines across everything, text included.
        Image {
          anchors.fill: parent
          fillMode: Image.Tile
          verticalAlignment: Image.AlignTop
          horizontalAlignment: Image.AlignLeft
          source: "data:image/svg+xml," + encodeURIComponent(
            "<svg xmlns='http://www.w3.org/2000/svg' width='3' height='3'><rect width='3' height='1' fill='"
            + meter.bar.hudBlack + "' fill-opacity='0.6'/></svg>")
        }
        // Its front, where it meets the meter.
        Rectangle {
          visible: said.width < meter.stageWidth
          x: meter.fromLeft ? 0 : parent.width - width
          width: 2
          height: parent.height
          color: meter.bar.hud
        }
      }
    }
  }
}

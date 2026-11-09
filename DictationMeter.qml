import QtQuick
import "Model.js" as Model

// Omakoe's 8-bit meter, as wide as the screen: hard-stepped mirrored columns
// of cells that run across from one edge or the other. Transcribing, they
// become a two-row bar with a light swung along it.
Item {
  id: meter
  required property var bar
  property real stageWidth: 0
  property real stageHeight: 0
  property string mode: "idle"
  property real peak: 0
  property real opened: 0
  property bool fromLeft: true

  readonly property int pitch: 4
  readonly property int columns: Math.ceil(stageWidth / pitch)
  readonly property bool recording: mode === "recording"
  readonly property int meterHeight: Model.WAVE_STEPS * pitch
  readonly property int meterY: stageHeight - meterHeight - 2

  property var wave: []
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

    Item {
      x: -clipper.x
      y: meter.meterY
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
  }
}

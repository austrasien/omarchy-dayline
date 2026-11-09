import QtQuick
import qs.Commons
import "Model.js" as Model

// Notifications as a news ticker, in the band along the bottom edge. It keeps
// its own queue, so that what has gone by leaves in the same frame as the row
// is moved back, with no jump, whenever the service gets round to it.
Item {
  id: ticker
  required property var bar
  property real band: height
  property var rows: []
  property bool running: false

  signal passed(string id)
  signal acknowledged(string id)
  signal invoked(string id)

  readonly property int gap: 70
  readonly property int stepPx: 4
  property var queue: []
  property bool looping: false
  property var gone: ({})
  property real offset: width
  readonly property bool hasItems: queue.length > 0

  function idsOf(list) {
    var out = {}
    list.forEach(function(r) { out[r.id] = true })
    return out
  }
  function sync() {
    // Forget what the service has let go of too.
    var present = idsOf(rows)
    var still = {}
    for (var id in gone) if (present[id]) still[id] = true
    gone = still

    var plan = Model.tickerPlan(rows, gone)
    if (plan.looping !== looping) {
      looping = plan.looping
      queue = plan.items
      offset = width
      return
    }
    if (queue.length === 0) offset = width
    var fresh = idsOf(plan.items)
    var byId = {}
    plan.items.forEach(function(r) { byId[r.id] = r })
    var kept = queue.filter(function(r) { return fresh[r.id] }).map(function(r) { return byId[r.id] })
    var known = idsOf(kept)
    queue = kept.concat(plan.items.filter(function(r) { return !known[r.id] }))
  }
  onRowsChanged: sync()

  function drop(id) {
    var next = Object.assign({}, gone)
    next[id] = true
    gone = next
    queue = queue.filter(function(r) { return r.id !== id })
  }
  function acknowledge(id) {
    drop(id)
    acknowledged(id)
    sync()
  }
  function ackFirst() { if (queue.length) acknowledge(queue[0].id) }

  // How many times the list is laid end to end, going round: enough to fill
  // the band. An estimate, so that it does not depend on what it lays out.
  readonly property int copies: {
    if (!looping || !queue.length) return 1
    var chars = queue.reduce(function(n, r) { return n + Model.newsText(r).length }, 0)
    var estimate = chars * 9 + queue.length * (gap + 26)
    return Math.max(2, Math.ceil(width / Math.max(1, estimate)) + 2)
  }
  readonly property var laidOut: {
    var out = []
    for (var i = 0; i < copies; i++) out = out.concat(queue)
    return out
  }

  // In whole pixels, so that the text stays sharp.
  Timer {
    interval: 33
    running: ticker.running && ticker.hasItems
    repeat: true
    onTriggered: {
      ticker.offset -= ticker.stepPx
      if (ticker.looping) {
        var period = (lane.implicitWidth + ticker.gap) / ticker.copies
        if (period > 0 && ticker.offset <= -period) ticker.offset += period
        return
      }
      var first = items.itemAt(0)
      if (first && ticker.offset + first.x + first.width <= 0) {
        var id = first.itemId
        ticker.offset += first.width + ticker.gap
        ticker.drop(id)
        ticker.passed(id)
      }
    }
  }

  Rectangle {
    id: bandFace
    y: ticker.height - ticker.band
    width: ticker.width
    height: ticker.band
    color: ticker.bar.hudBlack
    clip: true

    Image {
      anchors.fill: parent
      fillMode: Image.Tile
      verticalAlignment: Image.AlignTop
      horizontalAlignment: Image.AlignLeft
      source: "data:image/svg+xml," + encodeURIComponent(
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'><rect width='4' height='1' fill='"
        + ticker.bar.hud + "' fill-opacity='0.07'/></svg>")
    }

    Row {
      id: lane
      x: Math.round(ticker.offset)
      y: 2 + (ticker.bar.bandHeight - 2 - height) / 2
      spacing: ticker.gap

      Repeater {
        id: items
        model: ticker.laidOut
        delegate: Row {
          required property var modelData
          readonly property string itemId: modelData.id
          spacing: 8

          Item {
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            Image {
              id: newsIcon
              anchors.fill: parent
              sourceSize: Qt.size(36, 36)
              smooth: true
              source: parent.parent.modelData.icon || ""
            }
            Text {
              visible: newsIcon.status !== Image.Ready
              anchors.centerIn: parent
              text: "◆"
              color: parent.parent.modelData.urgent ? ticker.bar.alarm : ticker.bar.hud
              font.family: Style.fontFamily
              font.pixelSize: 15
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Model.newsText(parent.modelData)
            textFormat: Text.PlainText
            color: parent.modelData.urgent ? ticker.bar.alarm : ticker.bar.hud
            font.family: Style.fontFamily
            font.pixelSize: 15
            font.bold: true
            font.capitalization: Font.AllUppercase
          }
        }
      }
    }

    // Worn tape: dark lines across everything, text included.
    Image {
      anchors.fill: parent
      fillMode: Image.Tile
      verticalAlignment: Image.AlignTop
      horizontalAlignment: Image.AlignLeft
      source: "data:image/svg+xml," + encodeURIComponent(
        "<svg xmlns='http://www.w3.org/2000/svg' width='3' height='3'><rect width='3' height='1' fill='"
        + ticker.bar.hudBlack + "' fill-opacity='0.6'/></svg>")
    }
    // Stands in for the window's border it covers.
    Rectangle { width: parent.width; height: 2; color: ticker.looping ? ticker.bar.alarm : ticker.bar.hud }
  }

  // A right click acknowledges the one under the pointer, a left click runs
  // its action; between two, the next to come.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      var hit = lane.childAt(mouse.x - lane.x, lane.height / 2)
      var id = hit && hit.itemId ? hit.itemId : ticker.queue.length ? ticker.queue[0].id : ""
      if (id === "") return
      if (mouse.button === Qt.RightButton) ticker.acknowledge(id)
      else { ticker.drop(id); ticker.invoked(id) }
    }
  }
}

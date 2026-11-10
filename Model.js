// Pure logic for the day line: what an on-screen message says and where it
// goes. No QML here, so that it can be tested with node.

var WAVE_STEPS = 6

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function labelFor(key) {
  if (key.indexOf("volume") === 0) return "VOLUME"
  if (key === "brightness" || key === "display") return "SCREEN"
  if (key === "keyboard") return "KEYBOARD"
  if (key === "microphone" || key === "mic" || key.indexOf("microphone-") === 0 || key.indexOf("mic-") === 0) return "MICROPHONE"
  if (key === "touchpad") return "TOUCHPAD"
  if (key === "touch" || key === "touchscreen") return "TOUCHSCREEN"
  if (key.indexOf("media") === 0 || key.indexOf("player") === 0) return "MEDIA"
  return /^[a-z][a-z-]*$/.test(key) ? key.toUpperCase() : "SYSTEM"
}

// A message as the shell's OSD forwards it, turned into what the line shows.
// The volume always runs on a 0-200 % rule, 100 % in the middle, whatever
// scale the sender used: its value is a percentage on both.
function readOsd(o) {
  var msg = o || {}
  var key = String(msg.iconKey || "").toLowerCase()
  var volume = key.indexOf("volume") === 0
  var hasProgress = !!msg.hasProgress
  var maxValue = Math.max(1, Number(msg.maxValue) || 100)
  var value = Number(msg.value) || 0
  var scale = volume ? 200 : 100
  var percent = !hasProgress ? 0
    : clamp(Math.round(volume ? value : value * 100 / maxValue), 0, scale)
  var muted = key === "volume-muted"
  var duration = Number(msg.duration)
  return {
    key: key,
    label: labelFor(key),
    hasProgress: hasProgress,
    volume: volume,
    muted: muted,
    scale: scale,
    percent: percent,
    fraction: percent / scale,
    fill: muted ? 0 : percent / scale,
    overdrive: volume && !muted && percent > 100,
    title: hasProgress ? percent + " %" : String(msg.message || ""),
    status: muted ? "MUTED" : volume && percent > 100 ? "OVERDRIVE" : "",
    duration: isFinite(duration) ? Math.max(0, duration) : 1200
  }
}

// The marks along the rule, every 10 %, `major` every 50 %, and `notch` at
// the volume's 100 %.
function ticks(scale) {
  var out = []
  for (var p = 10; p < scale; p += 10) {
    out.push({ fraction: p / scale, major: p % 50 === 0, notch: scale > 100 && p === 100 })
  }
  return out
}

// The card's left edge: centred above the level, kept on the screen.
function cardX(fraction, cardWidth, screenWidth, margin) {
  return clamp(fraction * screenWidth - cardWidth / 2, margin, Math.max(margin, screenWidth - cardWidth - margin))
}

// Which way a change moves the level: 1 up, -1 down, 0 not at all. Held
// against an end, towards that end. With nothing to compare to, none: the
// arrows must not guess, on the first change after the shell starts.
function trendDirection(previous, percent, scale) {
  if (previous === undefined || previous === null) return 0
  if (percent > previous) return 1
  if (percent < previous) return -1
  if (percent >= scale) return 1
  if (percent <= 0) return -1
  return 0
}

// The card's status: what is wrong first, otherwise where the level is going.
function trendStatus(status, trend) {
  if (status) return status
  return trend > 0 ? "\u25B2 UP" : trend < 0 ? "\u25BC DOWN" : ""
}

// One chevron tile, pointing right for 1 and left for -1, dark-edged so that
// it reads over the fill as well as over the bare track.
function chevronSvg(direction, ink, edge, width, height) {
  var cx = width / 2, cy = height / 2, tip = direction > 0 ? 4 : -4
  var points = (cx - tip) + "," + (cy - 8) + " " + (cx + tip) + "," + cy + " " + (cx - tip) + "," + (cy + 8)
  var line = function(color, thick) {
    return "<polyline points='" + points + "' fill='none' stroke='" + color + "' stroke-width='" + thick + "'/>"
  }
  return "data:image/svg+xml," + encodeURIComponent(
    "<svg xmlns='http://www.w3.org/2000/svg' width='" + width + "' height='" + height + "'>"
    + line(edge, 8) + line(ink, 4) + "</svg>")
}

// What the ticker runs: the persistent ones, red, going round until they are
// acknowledged; only without any, the others, each going by once. Oldest first.
function tickerPlan(rows, gone) {
  var left = (Array.isArray(rows) ? rows : []).filter(function(r) { return !(gone && gone[r.id]) })
  left.sort(function(a, b) { return a.timestamp - b.timestamp })
  var urgent = (Array.isArray(rows) ? rows : []).some(function(r) { return r.urgent && !(gone && gone[r.id]) })
  return { looping: urgent, items: left.filter(function(r) { return !!r.urgent === urgent }) }
}

// A notification's line: no markup, no line breaks.
function newsText(item) {
  function plain(s) {
    return String(s || "").replace(/<[^>]*>/g, " ")
      .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
      .replace(/\s+/g, " ").trim()
  }
  var summary = plain(item && item.summary)
  var body = plain(item && item.body)
  return summary && body ? summary + " — " + body : summary || body
}

// One step of the pixel meter's height, from a 0..1 peak. Hard steps on a
// square-root scale, from Omakoe; silence is one step, never none.
function waveStep(peak) {
  var v = typeof peak === "number" && isFinite(peak) ? clamp(peak, 0, 1) : 0
  return clamp(Math.round(Math.sqrt(v) * WAVE_STEPS), 1, WAVE_STEPS)
}

// The history from the edge it started at, newest first. Each level takes
// `repeat` columns, so that the meter crosses the screen in seconds.
function pushWave(wave, peak, length, repeat) {
  var step = waveStep(peak)
  var next = wave.slice()
  for (var i = 0; i < (repeat || 1); i++) next.unshift(step)
  next.length = Math.min(next.length, length)
  return next
}

// The top row of a column of `steps` cells, mirrored around the middle.
function waveTop(steps) {
  return Math.ceil(WAVE_STEPS / 2 - steps / 2)
}

if (typeof module !== "undefined") {
  module.exports = {
    WAVE_STEPS: WAVE_STEPS,
    labelFor: labelFor,
    readOsd: readOsd,
    ticks: ticks,
    cardX: cardX,
    tickerPlan: tickerPlan,
    newsText: newsText,
    trendDirection: trendDirection,
    trendStatus: trendStatus,
    chevronSvg: chevronSvg,
    waveStep: waveStep,
    pushWave: pushWave,
    waveTop: waveTop
  }
}

"use strict"
const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

test("the volume runs on 0-200 %, whatever the sender's scale", () => {
  for (const maxValue of [100, 200]) {
    const r = Model.readOsd({ iconKey: "volume-high", hasProgress: true, value: 62, maxValue })
    assert.equal(r.scale, 200)
    assert.equal(r.percent, 62)
    assert.equal(r.fraction, 0.31)
  }
})

test("past 100 % the volume is in overdrive", () => {
  const r = Model.readOsd({ iconKey: "volume-high", hasProgress: true, value: 150, maxValue: 200 })
  assert.equal(r.overdrive, true)
  assert.equal(r.status, "OVERDRIVE")
  assert.equal(r.fill, 0.75)
})

test("muted, the rule is empty but the level stays", () => {
  const r = Model.readOsd({ iconKey: "volume-muted", hasProgress: true, value: 60, maxValue: 100 })
  assert.equal(r.status, "MUTED")
  assert.equal(r.fill, 0)
  assert.equal(r.fraction, 0.3)
  assert.equal(r.overdrive, false)
})

test("other levels run on 0-100 %", () => {
  const r = Model.readOsd({ iconKey: "brightness", hasProgress: true, value: 40, maxValue: 100 })
  assert.equal(r.label, "SCREEN")
  assert.equal(r.scale, 100)
  assert.equal(r.fraction, 0.4)
  assert.equal(r.title, "40 %")
})

test("a message without a level keeps its text", () => {
  const r = Model.readOsd({ iconKey: "media-play", hasProgress: false, message: "Track" })
  assert.equal(r.label, "MEDIA")
  assert.equal(r.title, "Track")
  assert.equal(r.hasProgress, false)
})

test("a zero duration stays zero, a missing one is the default", () => {
  assert.equal(Model.readOsd({ duration: 0 }).duration, 0)
  assert.equal(Model.readOsd({}).duration, 1200)
})

test("labels", () => {
  assert.equal(Model.labelFor("keyboard"), "KEYBOARD")
  assert.equal(Model.labelFor("mic-off"), "MICROPHONE")
  assert.equal(Model.labelFor("󱓞"), "SYSTEM")
})

test("ticks: every 10 %, a notch at the volume's 100 %", () => {
  const volume = Model.ticks(200)
  assert.equal(volume.length, 19)
  assert.deepEqual(volume.filter(t => t.notch).map(t => t.fraction), [0.5])
  const other = Model.ticks(100)
  assert.equal(other.length, 9)
  assert.equal(other.some(t => t.notch), false)
})

test("the card follows the level and stays on the screen", () => {
  assert.equal(Model.cardX(0.5, 200, 2000, 12), 900)
  assert.equal(Model.cardX(0, 200, 2000, 12), 12)
  assert.equal(Model.cardX(1, 200, 2000, 12), 1788)
})

test("the surge follows the change, and pushes against the ends", () => {
  assert.equal(Model.surgeDirection(40, 45, 100), 1)
  assert.equal(Model.surgeDirection(45, 40, 100), -1)
  assert.equal(Model.surgeDirection(40, 40, 100), 0)
  assert.equal(Model.surgeDirection(100, 100, 100), 1)
  assert.equal(Model.surgeDirection(0, 0, 200), -1)
  assert.equal(Model.surgeDirection(undefined, 30, 100), 1)
})

test("waveStep has hard steps and never reaches zero", () => {
  assert.equal(Model.waveStep(0), 1)
  assert.equal(Model.waveStep(1), 6)
  assert.equal(Model.waveStep(NaN), 1)
  assert.equal(Model.waveStep(2), 6)
})

test("pushWave puts the newest first and keeps its length", () => {
  assert.deepEqual(Model.pushWave([3, 4], 1, 2), [6, 3])
  assert.deepEqual(Model.pushWave([], 0, 3), [1])
})

test("pushWave gives each level several columns", () => {
  assert.deepEqual(Model.pushWave([3], 1, 4, 3), [6, 6, 6, 3])
  assert.deepEqual(Model.pushWave([3], 1, 2, 3), [6, 6])
})

test("waveTop keeps columns on the grid, around the middle", () => {
  assert.equal(Model.waveTop(6), 0)
  assert.equal(Model.waveTop(2), 2)
  assert.equal(Model.waveTop(3), 2)
  assert.equal(Model.waveTop(1), 3)
})

const note = (id, urgent, timestamp) => ({ id, urgent, timestamp })

test("the ticker runs the others once, oldest first", () => {
  const plan = Model.tickerPlan([note("b", false, 2), note("a", false, 1)])
  assert.equal(plan.looping, false)
  assert.deepEqual(plan.items.map(i => i.id), ["a", "b"])
})

test("persistent ones hold the others back until acknowledged", () => {
  const rows = [note("n", false, 1), note("r2", true, 3), note("r1", true, 2)]
  const plan = Model.tickerPlan(rows)
  assert.equal(plan.looping, true)
  assert.deepEqual(plan.items.map(i => i.id), ["r1", "r2"])
  const after = Model.tickerPlan(rows, { r1: true, r2: true })
  assert.equal(after.looping, false)
  assert.deepEqual(after.items.map(i => i.id), ["n"])
})

test("the ticker is empty without rows", () => {
  assert.deepEqual(Model.tickerPlan(null), { looping: false, items: [] })
})

test("newsText strips markup and joins summary and body", () => {
  assert.equal(Model.newsText({ summary: "Mail", body: "<b>Hello</b>\n  &amp; bye" }), "Mail — Hello & bye")
  assert.equal(Model.newsText({ summary: "Only" }), "Only")
  assert.equal(Model.newsText({ body: "Body" }), "Body")
})

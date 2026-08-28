const assert = require("assert")
const M = require("./Model.js")
const at = s => new Date(s).getTime()

let s = M.emptyState()
M.add(s, "terminal", at("2026-08-28T10:00:00"), at("2026-08-28T10:01:00"))
M.add(s, "browser", at("2026-08-28T10:01:00"), at("2026-08-28T10:03:00"))
assert.deepStrictEqual(M.ranking(M.totals(s, at("2026-08-28T12:00:00"), 1)).map(x => x.appId), ["browser", "terminal"])
assert.equal(M.total(M.totals(s, at("2026-08-28T12:00:00"), 1)), 180000)

s = M.emptyState()
M.add(s, "editor", at("2026-08-28T23:59:30"), at("2026-08-29T00:00:30"))
assert.equal(s.days["2026-08-28"].editor, 30000)
assert.equal(s.days["2026-08-29"].editor, 30000)
M.add(s, "", 1, 2); M.add(s, "editor", 4, 3)
assert.equal(M.total(M.totals(s, at("2026-08-29T12:00:00"), 2)), 60000)

let raw = {version: 99, days: {"2026-08-29": {ok: 5.9, bad: -2, nope: "x"}, junk: {x: 2}}}
assert.deepStrictEqual(M.sanitize(raw, at("2026-08-29T12:00:00")).days, {"2026-08-29": {ok: 5}})

s = M.emptyState()
for (let i = 0; i < 370; i++) M.add(s, "a", at("2026-08-29T12:00:00") - i * M.DAY_MS, at("2026-08-29T12:00:01") - i * M.DAY_MS)
M.prune(s, at("2026-08-29T12:00:00"), 365)
assert.equal(Object.keys(s.days).length, 365)
M.resetToday(s, at("2026-08-29T12:00:00")); assert(!s.days["2026-08-29"])
assert.deepStrictEqual(M.resetAll(), {version: 1, days: {}})
assert.equal(M.periodDays("week"), 7); assert.equal(M.periodDays("month"), 30); assert.equal(M.periodDays("year"), 365)
console.log("screen-time model tests passed")

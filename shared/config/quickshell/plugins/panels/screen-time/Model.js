// Pure screen-time accounting and presentation helpers. Times are epoch ms.

var DAY_MS = 86400000

function finiteMs(value) {
  var n = Number(value)
  return isFinite(n) && n > 0 ? Math.floor(n) : 0
}

function dateKey(value) {
  var d = value instanceof Date ? value : new Date(value)
  if (!isFinite(d.getTime())) return ""
  return String(d.getFullYear()).padStart(4, "0") + "-"
    + String(d.getMonth() + 1).padStart(2, "0") + "-"
    + String(d.getDate()).padStart(2, "0")
}

function localMidnightAfter(ms) {
  var d = new Date(ms)
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime()
}

function emptyState() { return { version: 1, days: {} } }

function sanitize(raw, todayMs) {
  var clean = emptyState()
  if (!raw || typeof raw !== "object" || !raw.days || typeof raw.days !== "object") return clean
  Object.keys(raw.days).forEach(function(key) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) return
    var source = raw.days[key]
    if (!source || typeof source !== "object") return
    var bucket = {}
    Object.keys(source).forEach(function(appId) {
      var id = String(appId || "").trim()
      var ms = finiteMs(source[appId])
      if (id && ms) bucket[id] = ms
    })
    if (Object.keys(bucket).length) clean.days[key] = bucket
  })
  return prune(clean, todayMs, 365)
}

function add(state, appId, fromMs, toMs) {
  var id = String(appId || "").trim()
  var start = Number(fromMs), end = Number(toMs)
  if (!id || !isFinite(start) || !isFinite(end) || end <= start) return state
  while (start < end) {
    var boundary = localMidnightAfter(start)
    var stop = Math.min(end, boundary)
    var key = dateKey(start)
    if (!state.days[key]) state.days[key] = {}
    state.days[key][id] = finiteMs(state.days[key][id]) + Math.floor(stop - start)
    start = stop
  }
  return state
}

function keyDays(todayMs, count) {
  var d = new Date(todayMs)
  d = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  var keys = []
  for (var i = 0; i < count; i++) {
    keys.push(dateKey(d))
    d.setDate(d.getDate() - 1)
  }
  return keys
}

function totals(state, todayMs, count) {
  var result = {}, days = state && state.days ? state.days : {}
  keyDays(todayMs, count).forEach(function(key) {
    var bucket = days[key] || {}
    Object.keys(bucket).forEach(function(id) {
      result[id] = finiteMs(result[id]) + finiteMs(bucket[id])
    })
  })
  return result
}

function total(map) {
  return Object.keys(map || {}).reduce(function(sum, id) { return sum + finiteMs(map[id]) }, 0)
}

function ranking(map) {
  return Object.keys(map || {}).map(function(id) { return { appId: id, milliseconds: finiteMs(map[id]) } })
    .filter(function(row) { return row.milliseconds > 0 })
    .sort(function(a, b) { return b.milliseconds - a.milliseconds || a.appId.localeCompare(b.appId) })
}

function prune(state, todayMs, keepDays) {
  var allowed = {}, days = keyDays(todayMs, keepDays || 365)
  days.forEach(function(key) { allowed[key] = true })
  Object.keys(state.days || {}).forEach(function(key) { if (!allowed[key]) delete state.days[key] })
  return state
}

function resetToday(state, todayMs) { delete state.days[dateKey(todayMs)]; return state }
function resetAll() { return emptyState() }

function periodDays(period) {
  return period === "week" ? 7 : period === "month" ? 30 : period === "year" ? 365 : 1
}

function formatDuration(ms, compact) {
  var minutes = Math.floor(finiteMs(ms) / 60000)
  var hours = Math.floor(minutes / 60)
  minutes %= 60
  if (compact) return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m"
  if (hours > 0) return hours + " hr " + minutes + " min"
  return minutes + " min"
}

if (typeof module !== "undefined") module.exports = {
  DAY_MS: DAY_MS, finiteMs: finiteMs, dateKey: dateKey, emptyState: emptyState,
  sanitize: sanitize, add: add, keyDays: keyDays, totals: totals, total: total,
  ranking: ranking, prune: prune, resetToday: resetToday, resetAll: resetAll,
  periodDays: periodDays, formatDuration: formatDuration
}

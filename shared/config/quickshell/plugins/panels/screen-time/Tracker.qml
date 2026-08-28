import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Model.js" as Model

// Owns all mutable tracking state. Consumers only ask for totals/rankings or
// invoke the two reset operations.
Item {
  id: root
  property bool enabled: true
  property bool started: false

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/tsp"
  readonly property string statePath: stateDir + "/screen-time.json"
  readonly property int idleSeconds: 150
  property var state: Model.emptyState()
  property var windows: ({})
  property string currentApp: ""
  property double intervalStartedAt: 0
  property bool accounting: false
  property bool connected: false
  property bool loaded: false
  property int revision: 0
  property bool reconcilingResume: false

  readonly property int todayTotal: {
    var unused = revision
    return Model.total(Model.totals(state, Date.now(), 1))
  }

  function touch() { revision++ }
  function start() {
    if (!enabled || started) return
    started = true
    mkdir.running = true
  }

  function checkpoint(now) {
    var at = Number(now || Date.now())
    if (accounting && currentApp && intervalStartedAt > 0 && at > intervalStartedAt)
      Model.add(state, currentApp, intervalStartedAt, at)
    intervalStartedAt = accounting && currentApp ? at : 0
    Model.prune(state, at, 365)
    touch()
  }

  function setFocus(appId, now) {
    var next = String(appId || "").trim()
    var at = Number(now || Date.now())
    if (next === currentApp) return
    checkpoint(at)
    currentApp = next
    accounting = !idleMonitor.isIdle && next !== ""
    intervalStartedAt = accounting ? at : 0
    scheduleSave()
  }

  function totalsFor(period) {
    var unused = revision
    return Model.totals(state, Date.now(), Model.periodDays(period))
  }

  function periodTotal(period) { return Model.total(totalsFor(period)) }

  function rankedApps(period) {
    return Model.ranking(totalsFor(period)).map(function(row) {
      var entry = DesktopEntries.heuristicLookup(row.appId)
      var name = entry && entry.name ? String(entry.name) : row.appId
      var icon = entry && entry.icon ? String(entry.icon) : "application-x-executable"
      return {
        appId: row.appId,
        name: name,
        icon: icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon),
        milliseconds: row.milliseconds
      }
    })
  }

  function resetToday() {
    checkpoint(Date.now())
    Model.resetToday(state, Date.now())
    intervalStartedAt = accounting && currentApp ? Date.now() : 0
    touch(); flushSave()
  }

  function resetAll() {
    state = Model.resetAll()
    intervalStartedAt = accounting && currentApp ? Date.now() : 0
    touch(); flushSave()
  }

  function scheduleSave() { if (loaded) saveDebounce.restart() }
  function flushSave() {
    if (!loaded) return
    stateFile.setText(JSON.stringify(state, null, 2) + "\n")
  }

  function loadState(raw) {
    if (loaded) return
    var parsed = null
    if (String(raw || "").trim()) {
      try { parsed = JSON.parse(raw) }
      catch (e) { console.warn("screen-time: malformed state; starting empty:", e) }
    }
    state = Model.sanitize(parsed, Date.now())
    loaded = true
    touch()
    reconcile.running = true
  }

  function focusedFromWindows(list) {
    windows = ({})
    var focused = ""
    for (var i = 0; i < list.length; i++) {
      var w = list[i]
      if (!w || w.id === undefined) continue
      windows[String(w.id)] = w
      if (w.is_focused) focused = String(w.app_id || "")
    }
    return focused
  }

  function handleReconcile(raw) {
    var list
    try { list = JSON.parse(String(raw || "[]")) } catch (e) {
      console.warn("screen-time: cannot parse niri windows:", e); list = []
    }
    var focused = focusedFromWindows(Array.isArray(list) ? list : [])
    var at = Date.now()
    currentApp = focused
    accounting = !idleMonitor.isIdle && focused !== ""
    intervalStartedAt = accounting ? at : 0
    reconcilingResume = false
    connected = true
    if (!eventStream.running) eventStream.running = true
    touch()
  }

  function handleEvent(line) {
    var event
    try { event = JSON.parse(String(line || "").trim()) } catch (e) { return }
    connected = true
    if (event.WindowOpenedOrChanged && event.WindowOpenedOrChanged.window) {
      var w = event.WindowOpenedOrChanged.window
      windows[String(w.id)] = w
      if (w.is_focused) setFocus(w.app_id, Date.now())
    } else if (event.WindowClosed) {
      var closed = String(event.WindowClosed.id)
      delete windows[closed]
    } else if (event.WindowFocusChanged) {
      var id = event.WindowFocusChanged.id
      var win = id === null || id === undefined ? null : windows[String(id)]
      setFocus(win ? win.app_id : "", Date.now())
    }
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.enabled
    timeout: root.idleSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      var at = Date.now()
      if (isIdle) {
        root.checkpoint(at)
        root.accounting = false
        root.intervalStartedAt = 0
        root.scheduleSave()
      } else {
        // Focus may have changed while idle; do not account until Niri has
        // supplied a fresh authoritative snapshot.
        root.currentApp = ""
        root.accounting = false
        root.intervalStartedAt = 0
        root.reconcilingResume = true
        if (!reconcile.running) reconcile.running = true
      }
    }
  }

  Process {
    id: mkdir
    command: ["mkdir", "-p", root.stateDir]
    onExited: stateFile.reload()
  }

  Process {
    id: reconcile
    command: ["niri", "msg", "--json", "windows"]
    stdout: StdioCollector { id: reconcileOut; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) root.handleReconcile(reconcileOut.text)
      else { root.connected = false; reconnect.restart() }
    }
  }

  Process {
    id: eventStream
    command: ["niri", "msg", "--json", "event-stream"]
    stdout: SplitParser { onRead: function(line) { root.handleEvent(line) } }
    onExited: {
      root.checkpoint(Date.now())
      root.accounting = false
      root.intervalStartedAt = 0
      root.connected = false
      root.scheduleSave()
      reconnect.restart()
    }
  }

  Timer { id: reconnect; interval: 2000; onTriggered: if (!reconcile.running) reconcile.running = true }
  Timer { id: saveDebounce; interval: 250; onTriggered: root.flushSave() }
  Timer {
    interval: 30000
    repeat: true
    running: root.loaded
    onTriggered: { root.checkpoint(Date.now()); root.flushSave() }
  }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    watchChanges: false
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("")
  }

  onEnabledChanged: start()
  Component.onCompleted: start()
  Component.onDestruction: { checkpoint(Date.now()); flushSave() }
}

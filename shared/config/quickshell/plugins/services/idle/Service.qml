import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  property var shell: null
  property bool stayAwake: false
  property bool monitorsOff: false

  readonly property int lockTimeoutSeconds: 500
  readonly property int monitorOffTimeoutSeconds: 550
  readonly property bool idleEnabled: !stayAwake

  function lockSession() {
    var lockService = shell ? shell.firstPartyServiceFor("tsp.lock") : null
    if (lockService && typeof lockService.beginLock === "function") {
      lockService.beginLock()
    } else {
      console.warn("tsp idle: lock service is unavailable")
    }
  }

  function turnMonitorsOff() {
    if (monitorsOff || monitorOffProcess.running) return
    monitorsOff = true
    monitorOffProcess.running = true
  }

  function wakeMonitors() {
    if (!monitorsOff || monitorOnProcess.running) return
    monitorsOff = false
    monitorOnProcess.running = true
  }

  function setIdleEnabled(value) {
    stayAwake = !value
    if (stayAwake) wakeMonitors()
    return value ? "enabled" : "disabled"
  }

  IdleMonitor {
    id: lockMonitor
    enabled: root.idleEnabled
    timeout: root.lockTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: if (isIdle) root.lockSession()
  }

  IdleMonitor {
    id: displayMonitor
    enabled: root.idleEnabled
    timeout: root.monitorOffTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) root.turnMonitorsOff()
      else root.wakeMonitors()
    }
  }

  Process {
    id: monitorOffProcess
    command: ["niri", "msg", "action", "power-off-monitors"]
  }

  Process {
    id: monitorOnProcess
    command: ["bash", "-c", "niri msg action power-on-monitors && brightnessctl -r"]
  }

  IpcHandler {
    target: "idle"

    function status(): string {
      return JSON.stringify({
        enabled: root.idleEnabled,
        stayAwake: root.stayAwake,
        lockAfter: root.lockTimeoutSeconds,
        monitorOffAfter: root.monitorOffTimeoutSeconds,
        lockIdle: lockMonitor.isIdle,
        displayIdle: displayMonitor.isIdle,
        monitorsOff: root.monitorsOff
      })
    }

    function enable(): string { return root.setIdleEnabled(true) }
    function disable(): string { return root.setIdleEnabled(false) }
    function toggle(): string { return root.setIdleEnabled(!root.idleEnabled) }
  }
}

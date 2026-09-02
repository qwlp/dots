import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

Item {
  id: root

  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME")

  property bool lockRequested: false
  property bool authenticating: false
  property string enteredPassword: ""
  property string pendingPassword: ""
  property string failureMessage: ""
  property int failedAttempts: 0

  readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure

  function beginLock() {
    if (locked) return true

    enteredPassword = ""
    pendingPassword = ""
    failureMessage = ""
    failedAttempts = 0
    authenticating = false
    lockRequested = true
    sessionLock.locked = true
    return true
  }

  function finishUnlock() {
    if (!locked) return

    lockRequested = false
    authenticating = false
    enteredPassword = ""
    pendingPassword = ""
    failureMessage = ""
    sessionLock.locked = false
  }

  function submitPassword(value) {
    var password = String(value || "")
    if (!lockRequested || authenticating || password.length === 0) return

    pendingPassword = password
    enteredPassword = ""
    failureMessage = ""
    authenticating = true

    if (!passwordPam.start()) authenticationFailed()
  }

  function answerPamPrompt() {
    if (!authenticating || !passwordPam.active || !passwordPam.responseRequired) return
    passwordPam.respond(pendingPassword)
    pendingPassword = ""
  }

  function authenticationFailed() {
    if (!lockRequested) return

    authenticating = false
    enteredPassword = ""
    pendingPassword = ""
    failedAttempts += 1
    failureMessage = "Authentication failed (" + failedAttempts + ")"
  }

  WlSessionLock {
    id: sessionLock

    WlSessionLockSurface {
      color: "black"

      LockView {
        anchors.fill: parent
        authenticatingPassword: root.authenticating
        failureMessage: root.failureMessage
        inputEnabled: root.lockRequested
        passwordText: root.enteredPassword
        onPasswordTextEdited: function(password) { root.enteredPassword = password }
        onSubmitPassword: function(password) { root.submitPassword(password) }
        onClearFailureRequested: root.failureMessage = ""
      }
    }

    onLockStateChanged: {
      // If the compositor rejects or releases the lock, reset the UI state.
      if (!locked && root.lockRequested) {
        root.lockRequested = false
        root.authenticating = false
        root.enteredPassword = ""
        root.pendingPassword = ""
      }
    }
  }

  PamContext {
    id: passwordPam
    config: "login"
    user: root.userName

    onResponseRequiredChanged: root.answerPamPrompt()
    onPamMessage: root.answerPamPrompt()
    onCompleted: function(result) {
      root.authenticating = false
      root.pendingPassword = ""
      if (!root.lockRequested) return
      if (result === PamResult.Success) root.finishUnlock()
      else root.authenticationFailed()
    }
  }

  IpcHandler {
    target: "lock"

    function lock(): string {
      return root.beginLock() ? "ok" : "failed"
    }

    function isLocked(): string {
      return root.locked ? "true" : "false"
    }
  }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"
  property var workspaces: []
  property var windows: []

  function refresh() {
    if (!workspaceProcess.running) workspaceProcess.running = true
    if (!windowProcess.running) windowProcess.running = true
  }

  function focusWorkspace(index) {
    Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(index)])
  }

  function appsForWorkspace(workspaceId) {
    var seen = ({})
    var apps = []
    for (var i = 0; i < windows.length; i++) {
      var window = windows[i]
      if (!window || window.workspace_id !== workspaceId) continue
      var appId = String(window.app_id || "").trim()
      if (!appId || seen[appId]) continue
      seen[appId] = true
      apps.push(appId)
    }
    return apps
  }

  function iconForApp(appId) {
    var entry = DesktopEntries.heuristicLookup(appId)
    if (!entry) {
      var needle = String(appId || "").toLowerCase()
      var entries = DesktopEntries.applications.values
      for (var i = 0; i < entries.length; i++) {
        var candidate = entries[i]
        var id = String(candidate.id || "").toLowerCase()
        var startupClass = String(candidate.startupClass || "").toLowerCase()
        if (id === needle || id.indexOf(needle + "-") === 0
            || startupClass === needle || startupClass.indexOf(needle + "-") === 0) {
          entry = candidate
          break
        }
      }
    }
    if (!entry || !entry.icon) return Quickshell.iconPath("application-x-executable")
    var icon = String(entry.icon)
    return icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon)
  }

  readonly property var outputWorkspaces: workspaces.filter(function(workspace) {
    if (!root.bar || !root.bar.screen) return true
    return workspace.output === root.bar.screen.name
  }).sort(function(left, right) { return left.idx - right.idx })

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    columns: root.vertical ? 1 : root.outputWorkspaces.length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.outputWorkspaces

      WidgetButton {
        id: workspaceButton
        required property var modelData
        readonly property var apps: root.appsForWorkspace(modelData.id)
        bar: root.bar
        text: ""
        labelVisible: false
        keepSpace: true
        hasVisualContent: true
        opacity: modelData.active_window_id !== null || modelData.is_focused ? 1 : 0.5
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : workspaceContent.implicitWidth + Style.space(12)
        fixedHeight: root.vertical ? workspaceContent.implicitHeight + Style.space(12) : root.barSize
        onPressed: root.focusWorkspace(modelData.idx)

        Grid {
          id: workspaceContent
          anchors.centerIn: parent
          columns: root.vertical ? 1 : workspaceButton.apps.length + 1
          rows: root.vertical ? workspaceButton.apps.length + 1 : 1
          spacing: Style.space(4)

          Rectangle {
            width: Style.space(18)
            height: Style.space(18)
            radius: Style.space(5)
            color: workspaceButton.modelData.is_focused
              ? Qt.rgba(workspaceButton.foreground.r, workspaceButton.foreground.g, workspaceButton.foreground.b, 0.18)
              : "transparent"

            Text {
              anchors.fill: parent
              text: String(workspaceButton.modelData.name || workspaceButton.modelData.idx)
              color: workspaceButton.foreground
              font.family: workspaceButton.fontFamily
              font.pixelSize: Style.font.body
              font.bold: workspaceButton.modelData.is_focused
              renderType: Text.NativeRendering
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }

          Repeater {
            model: workspaceButton.apps

            Item {
              required property string modelData
              width: Style.space(18)
              height: Style.space(18)

              Image {
                anchors.centerIn: parent
                width: Style.space(14)
                height: width
                source: root.iconForApp(parent.modelData)
                sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }
            }
          }
        }
      }
    }
  }

  Process {
    id: workspaceProcess
    command: ["niri", "msg", "--json", "workspaces"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.workspaces = Array.isArray(parsed) ? parsed : []
        } catch (error) {
          console.warn("Could not parse Niri workspaces:", error)
        }
      }
    }
  }

  Process {
    id: windowProcess
    command: ["niri", "msg", "--json", "windows"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.windows = Array.isArray(parsed) ? parsed : []
        } catch (error) {
          console.warn("Could not parse Niri windows:", error)
        }
      }
    }
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}

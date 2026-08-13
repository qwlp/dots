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

  function focusWindow(windowId) {
    Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(windowId)])
  }

  function appsForWorkspace(workspaceId) {
    var byId = ({})
    var apps = []
    for (var i = 0; i < windows.length; i++) {
      var window = windows[i]
      if (!window || window.workspace_id !== workspaceId) continue
      var appId = String(window.app_id || "").trim()
      if (!appId) continue
      if (!byId[appId]) {
        byId[appId] = { appId: appId, windows: [] }
        apps.push(byId[appId])
      }
      byId[appId].windows.push(window)
    }
    for (var j = 0; j < apps.length; j++) {
      apps[j].windows.sort(function(left, right) {
        var leftTime = left.focus_timestamp || ({ secs: 0, nanos: 0 })
        var rightTime = right.focus_timestamp || ({ secs: 0, nanos: 0 })
        return rightTime.secs !== leftTime.secs
          ? rightTime.secs - leftTime.secs
          : rightTime.nanos - leftTime.nanos
      })
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
              required property var modelData
              id: appIcon
              width: Style.space(18)
              height: Style.space(18)

              readonly property bool hovering: iconMouse.containsMouse

              function requestPreview() {
                previewCloseTimer.stop()
                previewOpenTimer.restart()
              }

              function scheduleClose() {
                previewOpenTimer.stop()
                previewCloseTimer.restart()
              }

              // PopupCard registers its owner with the bar-wide popout
              // coordinator. Give the coordinator a real close operation so
              // moving to another icon or panel cannot leave this native
              // popup mapped underneath the next one.
              function close() {
                previewOpenTimer.stop()
                previewCloseTimer.stop()
                previewPopup.open = false
              }

              Image {
                anchors.centerIn: parent
                width: Style.space(14)
                height: width
                source: root.iconForApp(parent.modelData.appId)
                sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              MouseArea {
                id: iconMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: appIcon.requestPreview()
                onExited: appIcon.scheduleClose()
                onClicked: {
                  previewPopup.open = false
                  root.focusWindow(appIcon.modelData.windows[0].id)
                }
              }

              Timer {
                id: previewOpenTimer
                interval: 350
                onTriggered: previewPopup.open = true
              }

              Timer {
                id: previewCloseTimer
                interval: 180
                onTriggered: {
                  if (!appIcon.hovering && !previewPopup.containsMouse)
                    previewPopup.open = false
                }
              }

              PopupCard {
                id: previewPopup
                anchorItem: appIcon
                bar: root.bar
                owner: appIcon
                triggerMode: "hover"
                padding: Style.space(8)

                readonly property int itemWidth: Style.space(260)
                readonly property int itemHeight: Style.space(40)
                readonly property int itemSpacing: Style.space(8)
                readonly property int windowCount: appIcon.modelData.windows.length
                readonly property int primaryCapacity: Math.max(1, Math.floor(
                  ((root.vertical ? availableCardHeight : availableCardWidth) + itemSpacing)
                    / ((root.vertical ? itemHeight : itemWidth) + itemSpacing)))
                readonly property int primaryCount: Math.min(windowCount, primaryCapacity)
                readonly property int secondaryCount: Math.ceil(windowCount / primaryCapacity)

                contentWidth: root.vertical
                  ? secondaryCount * itemWidth + Math.max(0, secondaryCount - 1) * itemSpacing + padding * 2
                  : primaryCount * itemWidth + Math.max(0, primaryCount - 1) * itemSpacing + padding * 2
                contentHeight: root.vertical
                  ? primaryCount * itemHeight + Math.max(0, primaryCount - 1) * itemSpacing + padding * 2
                  : secondaryCount * itemHeight + Math.max(0, secondaryCount - 1) * itemSpacing + padding * 2

                onContainsMouseChanged: {
                  if (containsMouse) previewCloseTimer.stop()
                  else appIcon.scheduleClose()
                }

                Grid {
                  anchors.fill: parent
                  columns: Math.max(1, root.vertical ? previewPopup.secondaryCount : previewPopup.primaryCount)
                  rows: Math.max(1, root.vertical ? previewPopup.primaryCount : previewPopup.secondaryCount)
                  spacing: previewPopup.itemSpacing

                  Repeater {
                    model: appIcon.modelData.windows

                    Rectangle {
                      id: windowPreview
                      required property var modelData
                      width: previewPopup.itemWidth
                      height: previewPopup.itemHeight
                      radius: Style.cornerRadius
                      color: previewMouse.containsMouse
                        ? Style.hoverFillFor(workspaceButton.foreground, workspaceButton.activeColor)
                        : Qt.rgba(workspaceButton.foreground.r, workspaceButton.foreground.g, workspaceButton.foreground.b, 0.04)
                      border.width: modelData.is_focused ? Math.max(1, Style.space(2)) : 0
                      border.color: workspaceButton.activeColor
                      clip: true

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(6)

                        Image {
                          anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(20)
                          height: width
                          source: root.iconForApp(appIcon.modelData.appId)
                          sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                          sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                          fillMode: Image.PreserveAspectFit
                        }

                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          width: parent.width - Style.space(26)
                          text: windowPreview.modelData.title || appIcon.modelData.appId
                          color: workspaceButton.foreground
                          font.family: workspaceButton.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          elide: Text.ElideRight
                        }
                      }

                      MouseArea {
                        id: previewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          previewPopup.open = false
                          root.focusWindow(windowPreview.modelData.id)
                        }
                      }
                    }
                  }
                }
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

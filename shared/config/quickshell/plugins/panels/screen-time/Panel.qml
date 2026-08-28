import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "tsp.screen-time"
  ipcTarget: "tsp.screen-time"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var tracker: null
  property string period: "today"
  property string confirmAction: ""
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(contentForeground, 1.45)
  readonly property color accent: bar && bar.accent !== undefined ? bar.accent : Color.accent
  readonly property color urgent: bar && bar.urgent !== undefined ? bar.urgent : Color.urgent
  readonly property string contentFont: bar ? bar.fontFamily : Style.font.family
  readonly property var rows: tracker ? tracker.rankedApps(period) : []
  readonly property int totalMs: tracker ? tracker.periodTotal(period) : 0

  function open() { root.controller.show(); Qt.callLater(function() { keyCatcher.forceActiveFocus() }) }
  function close() { confirmAction = ""; root.controller.hide() }
  function toggle() { if (opened) close(); else open() }
  function switchPanel(direction) {
    return bar && typeof bar.switchPanelFrom === "function" ? bar.switchPanelFrom(barIdentity, direction) : false
  }
  function requestReset(action) { confirmAction = confirmAction === action ? "" : action }
  function confirmReset() {
    if (!tracker) return
    if (confirmAction === "today") tracker.resetToday()
    else if (confirmAction === "all") tracker.resetAll()
    confirmAction = ""
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(460))
    contentHeight: popup.fittedContentHeight(Style.space(540))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "1") root.period = "today"
        else if (text === "2") root.period = "week"
        else if (text === "3") root.period = "month"
        else if (text === "4") root.period = "year"
      }

      Column {
        anchors.fill: parent
        spacing: Style.spacing.md

        Row {
          width: parent.width
          spacing: Style.spacing.xs
          Repeater {
            model: [{key:"today", label:"Today"}, {key:"week", label:"Week"}, {key:"month", label:"Month"}, {key:"year", label:"Year"}]
            Rectangle {
              required property var modelData
              width: (parent.width - parent.spacing * 3) / 4
              height: Style.space(34)
              radius: Style.cornerRadius
              color: root.period === modelData.key ? Style.selectedFillFor(root.contentForeground, root.accent) : "transparent"
              Text { anchors.centerIn: parent; text: modelData.label; color: root.contentForeground; font.family: root.contentFont; font.pixelSize: Style.font.body; font.bold: root.period === modelData.key }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.period = modelData.key }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(2)
          Text { text: Model.formatDuration(root.totalMs, false); color: root.contentForeground; font.family: root.contentFont; font.pixelSize: Style.font.display; font.bold: true }
          Text { text: "FOCUSED TIME · " + root.period.toUpperCase(); color: root.dim; font.family: root.contentFont; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
        }

        PanelSeparator { width: parent.width; foreground: root.contentForeground }

        Text {
          visible: !root.tracker || !root.tracker.connected
          width: parent.width
          text: "Screen-time tracker is disconnected from Niri. Reconnecting…"
          wrapMode: Text.WordWrap
          color: root.dim
          font.family: root.contentFont
          font.pixelSize: Style.font.body
        }
        Text {
          visible: root.tracker && root.tracker.connected && root.rows.length === 0
          width: parent.width
          text: "No focused application time in this period yet."
          color: root.dim
          font.family: root.contentFont
          font.pixelSize: Style.font.body
        }

        Flickable {
          width: parent.width
          height: Math.max(0, parent.height - y - actions.height - parent.spacing)
          contentHeight: appColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          Column {
            id: appColumn
            width: parent.width
            spacing: Style.spacing.sm
            Repeater {
              model: root.rows
              Item {
                required property var modelData
                width: appColumn.width
                height: Style.space(54)
                Image { id: appIcon; width: Style.space(28); height: width; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; source: modelData.icon; sourceSize.width: width; sourceSize.height: height }
                Text { anchors.left: appIcon.right; anchors.leftMargin: Style.spacing.sm; anchors.right: duration.left; anchors.rightMargin: Style.spacing.sm; anchors.top: parent.top; text: modelData.name; elide: Text.ElideRight; color: root.contentForeground; font.family: root.contentFont; font.pixelSize: Style.font.body; font.bold: true }
                Text { id: duration; anchors.right: parent.right; anchors.top: parent.top; text: Model.formatDuration(modelData.milliseconds, true); color: root.dim; font.family: root.contentFont; font.pixelSize: Style.font.caption }
                Rectangle { anchors.left: appIcon.right; anchors.leftMargin: Style.spacing.sm; anchors.right: parent.right; anchors.bottom: parent.bottom; height: Style.space(5); radius: height / 2; color: Style.selectedFillFor(root.contentForeground, root.accent)
                  Rectangle { width: parent.width * (root.rows.length && root.rows[0].milliseconds > 0 ? modelData.milliseconds / root.rows[0].milliseconds : 0); height: parent.height; radius: height / 2; color: root.accent }
                }
              }
            }
          }
        }

        Row {
          id: actions
          width: parent.width
          spacing: Style.spacing.sm
          Item { width: Math.max(0, parent.width - todayButton.width - allButton.width - confirmButton.width - parent.spacing * 3); height: 1 }
          PanelActionButton { id: todayButton; iconText: "󰃭"; tooltipText: "Reset today"; foreground: root.contentForeground; fontFamily: root.contentFont; onClicked: root.requestReset("today") }
          PanelActionButton { id: allButton; iconText: "󰆴"; tooltipText: "Reset all history"; foreground: root.contentForeground; hoverColor: root.urgent; fontFamily: root.contentFont; onClicked: root.requestReset("all") }
          PanelActionButton { id: confirmButton; visible: root.confirmAction !== ""; iconText: "󰄬"; tooltipText: root.confirmAction === "all" ? "Confirm reset all history" : "Confirm reset today"; foreground: root.urgent; hoverColor: root.urgent; fontFamily: root.contentFont; onClicked: root.confirmReset() }
        }
      }
    }
  }
}

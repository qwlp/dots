import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "NotificationLogic.js" as NotificationLogic

BarWidget {
  id: root
  moduleName: "tsp.notification-center"

  property bool popupOpen: false
  property string activeTab: "pending"
  readonly property bool opened: popupOpen

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("tsp.notifications")
  readonly property int pendingCount: notificationService ? notificationService.pendingModel.count : 0
  readonly property int pastCount: notificationService ? notificationService.pastModel.count : 0
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color borderColor: Style.normalBorderFor(foreground, Color.accent)
  readonly property color surfaceColor: Style.normalFillFor(foreground, Color.accent)
  readonly property int cardRadius: notificationService ? notificationService.cornerRadius : 0

  function open() { popupOpen = true }
  function close() { popupOpen = false }

  onPopupOpenChanged: {
    if (!popupOpen) return
    activeTab = pendingCount > 0 ? "pending" : "past"
    if (notificationService) notificationService.refreshNotificationCenter()
  }

  function notificationIconSource(icon) {
    var value = String(icon || "")
    if (!value) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.dnd ? "󰂛" : (root.pendingCount > 0 ? "󱅫" : "󰂚")
    active: root.pendingCount > 0 && !root.dnd
    tooltipText: root.dnd ? "Do Not Disturb"
      : (root.pendingCount > 0 ? root.pendingCount + " pending" : "No notifications")
    onPressed: function(b) {
      if (!root.notificationService) return
      if (b === Qt.RightButton)
        root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
      else root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(440))
    contentHeight: popup.cappedContentHeight(Style.space(540))

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.space(10)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: "Notifications"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          color: root.foreground
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Item { Layout.fillWidth: true }

        BorderSurface {
          Layout.preferredHeight: Style.space(26)
          Layout.preferredWidth: dndRow.implicitWidth + Style.space(16)
          radius: Style.space(12)
          color: root.dnd ? Color.accent : root.surfaceColor
          borderSpec: Border.flat(root.dnd ? Color.accent : root.borderColor, Style.normalBorderWidth)

          Row {
            id: dndRow
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text {
              text: root.dnd ? "󰂛" : "󰂚"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              color: root.dnd ? Color.background : root.dim
              font.pixelSize: Style.font.body
            }
            Text {
              text: root.dnd ? "DND on" : "DND off"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              color: root.dnd ? Color.background : root.dim
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notificationService.setDoNotDisturb(!root.dnd)
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
          model: [
            { key: "pending", label: "Pending", count: root.pendingCount },
            { key: "past", label: "Recently", count: root.pastCount }
          ]
          delegate: Item {
            required property var modelData
            readonly property bool selected: root.activeTab === modelData.key
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(32)

            Text {
              anchors.centerIn: parent
              text: parent.modelData.label + (parent.modelData.count ? "  " + parent.modelData.count : "")
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              color: parent.selected ? root.foreground : root.dim
              font.pixelSize: Style.font.body
              font.bold: parent.selected
            }
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Style.space(2)
              color: parent.selected ? Color.accent : root.borderColor
              opacity: parent.selected ? 1 : 0.4
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = parent.modelData.key
            }
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: actionButton.visible ? Style.space(26) : 0

        BorderSurface {
          id: actionButton
          anchors.right: parent.right
          height: Style.space(24)
          width: actionLabel.implicitWidth + Style.space(16)
          visible: root.activeTab === "pending" ? root.pendingCount > 0 : root.pastCount > 0
          radius: root.cardRadius
          color: actionMouse.containsMouse ? root.borderColor : "transparent"
          borderSpec: Border.flat(root.borderColor, Style.normalBorderWidth)
          Text {
            id: actionLabel
            anchors.centerIn: parent
            text: root.activeTab === "pending" ? "Mark all as seen" : "Clear recent"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            color: root.foreground
            font.pixelSize: Style.font.caption
          }
          MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.activeTab === "pending") root.notificationService.markAllSeen()
              else root.notificationService.clearPast()
            }
          }
        }
      }

      ListView {
        id: listView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.space(8)
        readonly property bool pending: root.activeTab === "pending"
        model: !root.notificationService ? null
          : (pending ? root.notificationService.pendingModel : root.notificationService.pastModel)

        delegate: BorderSurface {
          id: card
          required property int index
          required property string app
          required property string appIcon
          required property string summary
          required property string body
          required property string image

          readonly property string cleanBody: NotificationLogic.sanitizeBody(body, app, appIcon)
          readonly property bool usableImage: image.indexOf("file://") === 0
            || image.indexOf("image://icon//") === 0
          readonly property string iconSource: usableImage ? image : root.notificationIconSource(appIcon)
          width: listView.width
          implicitHeight: content.implicitHeight + Style.space(18)
          radius: root.cardRadius
          color: "transparent"
          borderSpec: Border.flat(root.borderColor, Style.normalBorderWidth)

          RowLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(10)
            spacing: Style.space(10)

            Image {
              Layout.preferredWidth: Style.space(32)
              Layout.preferredHeight: Style.space(32)
              Layout.alignment: Qt.AlignVCenter
              source: card.iconSource
              visible: source !== "" && status !== Image.Error
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)
              Text {
                Layout.fillWidth: true
                text: card.summary
                visible: text !== ""
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                color: root.foreground
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
              }
              Text {
                Layout.fillWidth: true
                text: card.cleanBody
                visible: text !== ""
                // Freedesktop notification bodies commonly use the small
                // markup subset (<b>, <i>, <u>, <a>). StyledText renders
                // those without treating the body as a full HTML document.
                textFormat: Text.StyledText
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                color: root.dim
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
              }
            }

            Text {
              Layout.alignment: Qt.AlignVCenter
              text: "✕"
              color: closeMouse.containsMouse ? root.foreground : root.dim
              font.pixelSize: Style.font.bodySmall
              MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -Style.space(6)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (listView.pending) root.notificationService.dismissPending(card.index)
                  else root.notificationService.dismissPast(card.index)
                }
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: listView.count === 0
          text: root.activeTab === "pending" ? "󰂚  Nothing waiting for you" : "󰂚  Nothing recent"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          color: root.dim
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}

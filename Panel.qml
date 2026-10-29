import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Popup: headset state, profile switch, reconnect/disconnect and the
// auto-reconnect watchdog toggle. All state comes from HeadsetService.
Panel {
  id: root
  moduleName: "j13y.bt-headset"
  ipcTarget: "j13y.bt-headset"
  manageIpc: false

  property var anchorItem: null
  readonly property alias headset: headsetService

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(contentForeground, 1.45)
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string heroMeta: {
    var parts = []
    if (headsetService.battery >= 0) parts.push("Battery " + headsetService.battery + "%")
    if (headsetService.micInUse) parts.push("Mic in use")
    return parts.join(" · ")
  }

  HeadsetService { id: headsetService }

  function open() {
    headsetService.refresh()
    root.controller.show()
  }

  function close() { root.controller.hide() }

  function toggle() {
    if (root.opened) close(); else open()
  }

  onOpenedChanged: if (opened) headsetService.refresh()

  KeyboardPanel {
    id: keyboardPanel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: keyboardPanel.fittedContentWidth(Style.space(340))
    contentHeight: keyboardPanel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(12)

      PanelHero {
        width: parent.width
        title: headsetService.name !== "" ? headsetService.name : "BT Headset"
        detail: headsetService.profileLabel + (headsetService.codecLabel !== "" ? " · " + headsetService.codecLabel : "")
        meta: root.heroMeta
        foreground: root.contentForeground
        fontFamily: root.contentFontFamily
        iconComponent: Component {
          Text {
            text: headsetService.profileKind === "hfp" ? "󰋎" : "󰋋"
            color: headsetService.micInUse ? root.urgent : root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
          }
        }
      }

      Text {
        visible: headsetService.actionStatus !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: headsetService.actionStatus
        color: root.dim
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { foreground: root.contentForeground }

      PanelSectionHeader {
        text: "Profile"
        foreground: root.contentForeground
      }

      Flow {
        width: parent.width
        spacing: Style.space(8)

        Button {
          text: "Hi-Fi"
          tooltipText: "A2DP: best sound quality, no microphone"
          selected: headsetService.profileKind === "a2dp"
          bordered: true
          foreground: root.contentForeground
          onClicked: headsetService.setProfile(headsetService.a2dpProfile)
        }

        Button {
          text: "Headset (mic)"
          tooltipText: "HFP: microphone enabled, lower sound quality"
          selected: headsetService.profileKind === "hfp"
          bordered: true
          foreground: root.contentForeground
          onClicked: headsetService.setProfile(headsetService.hfpProfile)
        }
      }

      PanelSeparator { foreground: root.contentForeground }

      Flow {
        width: parent.width
        spacing: Style.space(8)

        Button {
          text: "Reconnect"
          tooltipText: "Fixes a dead microphone after a Bluetooth transport failure (Super+Alt+B)"
          bordered: true
          foreground: root.contentForeground
          onClicked: headsetService.reconnect()
        }

        Button {
          text: "Disconnect"
          bordered: true
          foreground: root.contentForeground
          onClicked: headsetService.disconnect()
        }

        Button {
          text: "Sound settings"
          bordered: true
          foreground: root.contentForeground
          onClicked: {
            root.close()
            Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omarchy.audio"])
          }
        }
      }

      PanelSeparator {
        visible: headsetService.watchdogInstalled
        foreground: root.contentForeground
      }

      Item {
        visible: headsetService.watchdogInstalled
        width: parent.width
        implicitHeight: Math.max(watchdogText.implicitHeight, watchdogSwitch.implicitHeight)

        Column {
          id: watchdogText
          anchors.left: parent.left
          anchors.right: watchdogSwitch.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            width: parent.width
            text: "Auto-reconnect"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: {
              var s = headsetService.watchdogActive ? "Reconnects after a transport failure" : "Off"
              if (headsetService.lastFailure > 0) s += " · last failure " + headsetService.formatTime(headsetService.lastFailure)
              return s
            }
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }

        ToggleSwitch {
          id: watchdogSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: headsetService.watchdogActive
          busy: headsetService.busy
          foreground: root.contentForeground
          onToggled: headsetService.setWatchdog(!headsetService.watchdogActive)
        }
      }
    }
  }
}

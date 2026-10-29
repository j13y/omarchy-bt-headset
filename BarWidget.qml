import QtQuick
import qs.Commons
import qs.Ui

// Headphones icon, shown only while a Bluetooth audio device is connected.
// Same Loader pattern as j13y.diag-vpn: Panel.qml owns the popup and the
// HeadsetService.
BarWidget {
  id: root
  moduleName: "j13y.bt-headset"

  readonly property var headset: panelLoader.item ? panelLoader.item.headset : null
  readonly property bool connected: headset ? headset.connected : false

  visible: connected
  implicitWidth: connected ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  // nf-md-headphones / nf-md-headset
  readonly property string glyph: headset && headset.profileKind === "hfp" ? "󰋎" : "󰋋"

  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
  }

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    horizontalMargin: 8.75
    // Urgent colour while the mic is live or an action is running.
    active: root.headset ? (root.headset.micInUse || root.headset.busy) : false
    tooltipText: {
      var h = root.headset
      if (!h) return "BT Headset"
      var parts = [h.name, h.profileLabel + (h.codecLabel !== "" ? " · " + h.codecLabel : "")]
      if (h.battery >= 0) parts.push(h.battery + "%")
      if (h.micInUse) parts.push("mic in use")
      return parts.join(" · ") + "\nRight click: reconnect · Middle click: switch profile"
    }
    onPressed: function(b) {
      if (!root.headset) return
      if (b === Qt.RightButton) root.headset.reconnect()
      else if (b === Qt.MiddleButton) root.headset.toggleProfile()
      else root.togglePanel()
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Headset state polled from bin/bt-headset-status (PipeWire card, profile,
// codec, mic, watchdog). Battery comes straight from BlueZ. Actions shell out
// to bin/bt-headset-action.
Item {
  id: root

  readonly property string pluginId: "j13y.bt-headset"
  readonly property string binDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + pluginId + "/bin"

  property bool connected: false
  property string mac: ""
  property string name: ""
  property string card: ""
  property string profile: ""
  property string profileKind: "off"   // "a2dp" | "hfp" | "off"
  property string codec: ""
  property string a2dpProfile: ""
  property string hfpProfile: ""
  property bool micInUse: false
  property bool watchdogInstalled: false
  property bool watchdogEnabled: false
  property bool watchdogActive: false
  property int lastFailure: 0
  property string actionStatus: ""

  readonly property bool busy: actionProcess.running

  // BlueZ side: used for battery and to notice connects/disconnects instantly.
  readonly property var btDevices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var btDevice: {
    for (var i = 0; i < btDevices.length; i++) {
      var d = btDevices[i]
      if (d && d.address === root.mac) return d
    }
    return null
  }
  readonly property int connectedAudioCount: {
    var n = 0
    for (var i = 0; i < btDevices.length; i++) {
      var d = btDevices[i]
      if (d && d.connected && String(d.icon || "").indexOf("audio") === 0) n++
    }
    return n
  }
  readonly property int battery: btDevice && btDevice.batteryAvailable ? Math.round(btDevice.battery * 100) : -1

  readonly property string profileLabel: profileKind === "a2dp" ? "Hi-Fi" : (profileKind === "hfp" ? "Headset (mic)" : "Off")
  readonly property string codecLabel: codec !== "" ? codec.toUpperCase() : ""

  onConnectedAudioCountChanged: {
    refresh()
    settleRefresh.restart()
  }

  function refresh() {
    if (statusProcess.running) return
    statusProcess.running = true
  }

  function run(args, status) {
    if (actionProcess.running) return
    actionStatus = status || ""
    actionProcess.command = [root.binDir + "/bt-headset-action"].concat(args)
    actionProcess.running = true
  }

  function reconnect() { if (mac !== "") run(["reconnect", mac], "Reconnecting…") }
  function disconnect() { if (mac !== "") run(["disconnect", mac], "Disconnecting…") }
  function setProfile(p) { if (card !== "" && p !== "" && p !== profile) run(["profile", card, p], "Switching profile…") }
  function toggleProfile() { setProfile(profileKind === "a2dp" ? hfpProfile : a2dpProfile) }
  function setWatchdog(on) { run(["watchdog", on ? "on" : "off"], on ? "Enabling auto-reconnect…" : "Disabling auto-reconnect…") }

  function formatTime(unix) {
    if (!unix) return ""
    return Qt.formatTime(new Date(unix * 1000), "HH:mm")
  }

  function applyStatus(text) {
    var data
    try {
      data = JSON.parse(text)
    } catch (e) {
      console.warn("bt-headset: could not parse status:", e)
      return
    }
    connected = data.connected === true
    mac = String(data.mac || "")
    name = String(data.name || "")
    card = String(data.card || "")
    profile = String(data.profile || "")
    profileKind = String(data.profileKind || "off")
    codec = String(data.codec || "")
    a2dpProfile = String(data.a2dpProfile || "")
    hfpProfile = String(data.hfpProfile || "")
    micInUse = data.micInUse === true
    watchdogInstalled = data.watchdogInstalled === true
    watchdogEnabled = data.watchdogEnabled === true
    watchdogActive = data.watchdogActive === true
    lastFailure = Number(data.lastFailure || 0)
  }

  Timer {
    // Cheap poll while headphones are around; BlueZ change handler covers
    // the connect itself.
    interval: 4000
    repeat: true
    running: root.connected || root.connectedAudioCount > 0
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    // PipeWire creates the card a moment after BlueZ reports the connect.
    id: settleRefresh
    interval: 1500
    onTriggered: root.refresh()
  }

  Timer {
    id: actionStatusTimer
    interval: 4000
    onTriggered: root.actionStatus = ""
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProcess
    command: [root.binDir + "/bt-headset-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: actionProcess
    command: []
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.actionStatus = exitCode === 0 ? "" : (String(actionStderr.text).trim() || "Command failed (" + exitCode + ")")
      if (exitCode !== 0) actionStatusTimer.restart()
      root.refresh()
      settleRefresh.restart()
    }
  }
}

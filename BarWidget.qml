import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "slowburnaz.omascore"

  readonly property var panel: panelLoader.item

  readonly property bool opened: root.panel ? root.panel.opened === true : false
  readonly property bool popoutSwitchClosing: root.panel ? root.panel.popoutSwitchClosing === true : false

  function open() {
    if (root.panel) root.panel.open()
  }

  function close() {
    if (root.panel) root.panel.close()
  }

  function toggle() {
    if (root.panel) root.panel.toggle()
  }

  function closeForPopoutSwitch() {
    if (root.panel) root.panel.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!root.panel) return
    root.panel.bar = root.bar
    root.panel.anchorItem = button
    root.panel.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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
    text: root.panel && root.panel.favLive && root.panel.favLiveScore !== "" && !button.vertical
      ? "\u2605 " + root.panel.favLiveScore
      : "\uf091"
    dimmed: !root.panel || root.panel.games.length === 0
    active: root.panel ? root.panel.favLive : false
    foreground: root.panel && root.panel.favLive ? Color.accent : Color.foreground
    tooltipText: !root.panel || root.panel.games.length === 0
      ? "OmaScore"
      : (root.panel.favLive && root.panel.favLiveLabel !== ""
           ? root.panel.favLiveLabel
           : (root.panel.liveCount > 0
                ? root.panel.liveCount + " live"
                : "OmaScore"))
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}

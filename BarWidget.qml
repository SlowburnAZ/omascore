import QtQuick
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

BarWidget {
  id: root
  moduleName: "slowburnaz.omascore"

  // Language: plugin setting "language" (auto|en|es), fallback system locale.
  // langCode re-evaluates when the shell replaces settings; applyLang() runs
  // from the change handler — never inside a binding — and bumps langRev so
  // the tooltip binding repaints with the new lang.
  property int langRev: 0
  property string appliedLang: ""
  readonly property string langCode: String(root.settings && root.settings.language ? root.settings.language : "auto")
  onLangCodeChanged: root.applyLang()
  function applyLang() {
    var code = root.langCode
    I18n.setLang(code === "auto" ? Qt.locale().name.substring(0, 2) : code)
    var now = I18n.current()
    if (now !== root.appliedLang) {
      root.appliedLang = now
      root.langRev++
    }
  }
  readonly property var trFn: root.langRev >= 0 ? function(key) { return I18n.tr(key) } : null
  Component.onCompleted: root.applyLang()

  // Bar display mode: plugin setting "barMode" (favScore|liveCount|nextGame|icon).
  // nextGame behaves like favScore while a favorite is live, otherwise shows
  // the next favorite's start time ("BUF 7:30 PM").
  readonly property string barMode: String(root.settings && root.settings.barMode ? root.settings.barMode : "favScore")

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
    text: !root.panel || button.vertical || root.barMode === "icon" ? ""
      : root.barMode === "liveCount" && root.panel.liveCount > 0 ? "● " + root.panel.liveCount
      : root.panel.favLive && root.panel.favLiveScore !== "" ? "★ " + root.panel.favLiveScore
      : root.barMode === "nextGame" && root.panel.nextFavScore !== "" ? root.panel.nextFavScore
      : ""
    dimmed: !root.panel || root.panel.barGameCount === 0
    active: root.panel ? (root.panel.favLive || (root.barMode === "liveCount" && root.panel.liveCount > 0) || (root.barMode === "nextGame" && root.panel.nextFavScore !== "")) : false
    foreground: button.active ? Color.accent : Color.foreground
    tooltipText: !root.panel || root.panel.barGameCount === 0
      ? "OmaScore"
      : (root.panel.favLive && root.panel.favLiveLabel !== ""
           ? root.panel.favLiveLabel
           : (root.panel.liveCount > 0
                ? root.panel.liveCount + root.trFn(" live")
                : (root.barMode === "nextGame" && root.panel.nextFavLabel !== "" ? root.panel.nextFavLabel : "OmaScore")))
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}

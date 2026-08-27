import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "slowburnaz.omascore"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property var games: []
  property var favorites: ({})
  property int liveCount: 0
  property bool favLive: false
  property string lastError: ""

  readonly property string storePath: Quickshell.env("HOME") + "/.local/state/omarchy/omascore-favorites.json"
  readonly property string oldStorePath: Quickshell.env("HOME") + "/.local/state/omarchy/nfl-favorites.json"
  readonly property string apiUrl: Model.apiUrl
  readonly property color urgentColor: root.bar ? root.bar.urgent : Color.urgent

  property string currentLeagueId: Model.defaultLeagueId
  property var weekStart: null
  property var weekDateStrs: []
  property var weekDates: []
  property var hasGames: [false,false,false,false,false,false,false]
  property int selectedDay: 0
  property var selectedDate: null
  property string selectedDateStr: ""
  property var dayLabels: Model.dayLabels
  property var monthLabels: Model.monthLabels
  readonly property bool isWeekMode: true

  property var selectedGame: null
  property var detailStats: null
  property var detailTeams: null
  property var detailPlayers: null
  property var detailPlayerGroups: null
  property var detailBroadcasts: []
  property var detailOdds: null
  property var detailLeaders: []
  property var detailWinProb: []
  property var detailPlays: []
  property var detailDrives: []
  property var detailSituation: null
  property var detailStandings: null
  property var detailInjuries: []
  property var detailNews: []
  property var detailVideos: []
  property bool showOdds: true
  property bool detailLoading: false
  property bool detailStale: false
  property string detailError: ""
  property int detailTab: 0

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function isFav(abbr) { return Model.isFav(root.favorites, abbr, root.currentLeagueId) }
  function loadFavorites(raw) { root.favorites = Model.parseFavorites(raw) }
  function saveFavorites() { store.setText(JSON.stringify(root.favorites, null, 2) + "\n") }
  function toggleFav(abbr) {
    root.favorites = Model.toggleFavMap(root.favorites, root.currentLeagueId, abbr)
    root.saveFavorites()
    root.games = root.sorted(root.games)
    root.recount()
  }
  function isLeagueFav(id) { return Model.isLeagueFav(root.favorites, id) }
  function toggleLeagueFav(id) { root.favorites = Model.toggleLeagueFav(root.favorites, id); root.saveFavorites(); }
  function rank(g) { return Model.rank(g, root.favorites, root.currentLeagueId) }
  function sorted(list) { return Model.sorted(list, root.favorites, root.currentLeagueId) }
  function recount() {
    var r = Model.recount(root.games, root.favorites, root.currentLeagueId)
    root.liveCount = r.liveCount; root.favLive = r.favLive
  }
  function leads(game, side) { return Model.leads(game, side) }
  function titleize(s) { return Model.titleize(s) }
  function sundayOf(d) { return Model.sundayOf(d) }
  function ymd(d) { return Model.ymd(d) }
  function weekLabel() { return Model.weekLabel(root.weekDates) }
  function dayLabel() { return Model.dayLabel(root.selectedDate) }
  function leagueLabel(id) { return Model.leagueFor(id).label }
  function setLeague(id) {
    if (id == root.currentLeagueId) return
    root.currentLeagueId = id
    root.selectedGame = null; root.detailStats = null; root.detailTeams = null; root.detailPlayers = null; root.detailPlayerGroups = null
    root.games = []; root.lastError = ""
    if (root.isWeekMode) root.initWeek(); else root.initDay()
  }
  function initDay() {
    var today = new Date(); today.setHours(0,0,0,0)
    var d = Model.dayDataFor(today)
    root.selectedDate = d.selectedDate; root.selectedDateStr = d.selectedDateStr
    root.refreshSelected()
  }
  function shiftDay(delta) {
    if (!root.selectedDate) return
    var d = Model.shiftDay(root.selectedDate, delta)
    root.selectedDate = d.selectedDate; root.selectedDateStr = d.selectedDateStr
    root.refreshSelected()
  }

  function initWeek() {
    var today = new Date(); today.setHours(0,0,0,0)
    var w = Model.weekDataFor(today)
    root.weekStart = w.weekStart; root.weekDates = w.weekDates; root.weekDateStrs = w.weekDateStrs; root.selectedDay = w.selectedDay
    root.hasGames = [false,false,false,false,false,false,false]
    root.checkWeekGames(); root.refreshSelected()
  }
  function shiftWeek(delta) {
    if (!root.weekStart) return
    var today = new Date(); today.setHours(0,0,0,0)
    var w = Model.weekDataShift(root.weekStart, delta, today)
    root.weekStart = w.weekStart; root.weekDates = w.weekDates; root.weekDateStrs = w.weekDateStrs; root.selectedDay = w.selectedDay
    root.hasGames = [false,false,false,false,false,false,false]
    root.checkWeekGames(); root.refreshSelected()
  }
  function selectDay(idx) { if (idx < 0 || idx > 6) return; root.selectedDay = idx; root.refreshSelected() }
  function checkWeekGames() {
    if (!root.isWeekMode) return
    if (!root.weekDateStrs || root.weekDateStrs.length !== 7) return
    var cmd = Model.weekCurl(root.weekDateStrs, root.currentLeagueId)
    weekProc.running = false; weekProc.command = ["bash","-c",cmd]; weekProc.running = true
  }
  function parseWeek(raw) {
    if (!String(raw||"").trim()) return
    var r = Model.parseWeek(raw, root.weekDateStrs)
    root.hasGames = r.hasGames
    var nxt = Model.nextSelectedDay(r.hasGames, root.selectedDay)
    if (nxt >= 0) { root.selectedDay = nxt; root.refreshSelected() }
  }
  function refreshSelected() {
    var ds = root.isWeekMode ? (root.weekDateStrs[root.selectedDay] || "") : root.selectedDateStr
    if (!ds) return
    fetchProc.running = false; fetchProc.command = ["bash","-c", Model.fetchCurl(ds, root.currentLeagueId)]; fetchProc.running = true
  }
  function showDetail(game) {
    if (!game || !game.id) return
    root.selectedGame = game; root.detailStats = null; root.detailTeams = null; root.detailPlayers = null; root.detailPlayerGroups = null
    root.detailBroadcasts = []; root.detailOdds = null; root.detailLeaders = []; root.detailWinProb = []; root.detailPlays = []; root.detailDrives = []; root.detailSituation = null; root.detailStandings = null; root.detailInjuries = []; root.detailNews = []; root.detailVideos = []
    root.detailError = ""; root.detailLoading = true; root.detailTab = 0
    detailProc.running = false; detailProc.command = ["bash","-c","curl -fsS --max-time 10 '" + Model.summaryUrl(game.id, root.currentLeagueId) + "' 2>/dev/null"]; detailProc.running = true
  }
  function closeDetail() {
    root.selectedGame = null; root.detailStats = null; root.detailTeams = null; root.detailPlayers = null; root.detailPlayerGroups = null
    root.detailBroadcasts = []; root.detailOdds = null; root.detailLeaders = []; root.detailWinProb = []; root.detailPlays = []; root.detailDrives = []; root.detailSituation = null; root.detailStandings = null; root.detailInjuries = []; root.detailNews = []; root.detailVideos = []
    root.detailError = ""; root.detailLoading = false; root.detailStale = false
  }
  function loadDetail() { root.detailStale = false; root.detailError = ""; if (root.selectedGame) root.showDetail(root.selectedGame) }
  function parseDetail(raw) {
    var txt = String(raw||"").trim()
    if (!txt) { root.detailError = "No details"; root.detailLoading = false; return }
    try {
      var r = Model.parseDetail(raw, root.selectedGame, root.currentLeagueId)
      root.detailTeams = r.detailTeams; root.detailStats = r.detailStats; root.detailPlayers = r.detailPlayers; root.detailPlayerGroups = r.detailPlayerGroups
      root.detailBroadcasts = r.detailBroadcasts || []; root.detailOdds = r.detailOdds || null; root.detailLeaders = r.detailLeaders || []; root.detailWinProb = r.detailWinProb || []
      root.detailPlays = r.detailPlays || []; root.detailDrives = r.detailDrives || []; root.detailSituation = r.detailSituation || null; root.detailStandings = r.detailStandings || null; root.detailInjuries = r.detailInjuries || []
      root.detailNews = r.detailNews || []; root.detailVideos = r.detailVideos || []
      console.log("omascore detail", root.currentLeagueId, root.selectedGame ? root.selectedGame.id : "", "plays", root.detailPlays.length, "drives", root.detailDrives.length, "groups", root.detailPlayerGroups ? root.detailPlayerGroups.length : -1, "leaders", root.detailLeaders.length, "standings", !!root.detailStandings, "venue", r.detailTeams.venue)
      root.detailLoading = false
    } catch (e) {
      console.log("parseDetail failed", String(e))
      if (!root.detailStale) { root.detailError = "Stale data"; root.detailStale = true } else { root.detailError = "Failed to load: " + String(e.message || e) }
      root.detailLoading = false
    }
  }
  function refresh() { root.refreshSelected() }
  function parseGames(raw) {
    var txt = String(raw||"").trim()
    if (!txt) { root.games = []; root.lastError = ""; root.recount(); return }
    try {
      var r = Model.parseGames(txt)
      root.games = root.sorted(r.games)
      root.lastError = r.error
      root.recount()
    } catch (e) { root.lastError = "Parse error" }
  }
  function statusColor(state) { return Model.statusColor(state, root.urgentColor, root.barForeground) }
  function standingsStat(entry, names) {
    var s = (entry && entry.stats) ? entry.stats : []
    for (var i = 0; i < s.length; i++) if (names.indexOf(s[i].name) >= 0 || names.indexOf(s[i].abbreviation) >= 0) return s[i].displayValue != null ? s[i].displayValue : (s[i].value != null ? String(s[i].value) : "")
    return ""
  }

  FileView {
    id: store
    path: root.storePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.loadFavorites(text())
      if (Object.keys(root.favorites).length == 0) oldStore.reload()
      root.games = root.sorted(root.games)
      root.recount()
    }
    onLoadFailed: {
      root.loadFavorites("{}")
      oldStore.reload()
    }
    onFileChanged: reload()
  }
  FileView {
    id: oldStore
    path: root.oldStorePath
    watchChanges: false
    atomicWrites: false
    printErrors: false
    onLoaded: {
      var txt = text() || ""
      if (!txt.trim()) return
      if (Object.keys(root.favorites).length != 0) return
      try {
        var arr = JSON.parse(txt)
        if (Array.isArray(arr) && arr.length) {
          root.favorites = { nfl: arr }
          root.saveFavorites()
          root.games = root.sorted(root.games)
          root.recount()
        }
      } catch(e) {}
    }
  }

  Process {
    id: fetchProc
    command: ["curl", "-fsS", "--max-time", "10", root.apiUrl]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseGames(text)
    }
  }

  Process {
    id: weekProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseWeek(text)
    }
  }

  Process {
    id: detailProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseDetail(text)
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  function initForCurrent() { if (root.isWeekMode) root.initWeek(); else root.initDay() }
  Component.onCompleted: Qt.callLater(root.initForCurrent)

  onOpenedChanged: if (root.opened) {
    if (root.isWeekMode) { if (!root.weekStart) root.initWeek(); else root.refreshSelected() }
    else { if (!root.selectedDate) root.initDay(); else root.refreshSelected() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.selectedGame ? 760 : 440))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))
    Behavior on contentWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on contentHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        onCloseRequested: { if (root.selectedGame) root.closeDetail(); else root.close() }
        onTabRequested: function(direction) { if (root.selectedGame) root.closeDetail(); else root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: root.selectedGame ? ScrollBar.AlwaysOff : (panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff)

        Column {
          id: panelColumn
          width: scrollArea.availableWidth - Style.space(28)
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.horizontalCenterOffset: Style.space(4)
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: heroIcon.implicitHeight
            Text {
              id: heroIcon
              text: "\uD83C\uDFC6"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "OmaScore"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Flickable {
            width: parent.width
            height: Style.space(32)
            visible: !root.selectedGame
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            contentWidth: leagueRow.implicitWidth
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            Row {
              id: leagueRow
              spacing: Style.space(6)
              height: parent.height
              Repeater {
                model: Model.sortedLeagues(Model.leagues, root.favorites)
                delegate: Rectangle {
                  required property var modelData
                  width: row.implicitWidth + Style.space(16)
                  height: Style.space(28)
                  radius: Style.space(14)
                  color: root.currentLeagueId == modelData.id ? Color.accent : "transparent"
                  border.width: root.currentLeagueId == modelData.id ? 0 : 1
                  border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.18)
                  Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    z: 1
                    Text {
                      id: leagueText
                      text: modelData.label
                      color: root.currentLeagueId == modelData.id ? Color.background : root.barForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: root.currentLeagueId == modelData.id
                    }
                    Text {
                      text: root.isLeagueFav(modelData.id) ? "\u2605" : "\u2606"
                      color: root.currentLeagueId == modelData.id ? Color.background : (root.isLeagueFav(modelData.id) ? Color.accent : root.barForeground)
                      opacity: root.isLeagueFav(modelData.id) ? 1 : 0.6
                      font.pixelSize: Style.font.caption
                      MouseArea {
                        anchors.fill: parent
                        onClicked: function(mouse) { root.toggleLeagueFav(modelData.id); mouse.accepted = true }
                      }
                    }
                  }
                  MouseArea { anchors.fill: parent; onClicked: root.setLeague(modelData.id) }
                }
              }
            }
          }

          RowLayout {
            width: parent.width - Style.space(20)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(4)
            visible: root.isWeekMode && root.weekDates.length === 7 && !root.selectedGame

            Button {
              Layout.preferredWidth: Style.space(28)
              Layout.preferredHeight: Style.space(28)
              iconText: "\u2039"
              foreground: root.barForeground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.shiftWeek(-7)
            }

            Repeater {
              model: 7
              delegate: Rectangle {
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(52)
                radius: Style.space(6)
                color: root.selectedDay === index ? Color.accent : "transparent"
                border.width: root.selectedDay === index ? 0 : 1
                border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.18)
                clip: true

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.selectDay(index)
                }

                Column {
                  anchors.centerIn: parent
                  spacing: 2

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dayLabels[index]
                    color: root.selectedDay === index ? Color.background : root.barForeground
                    opacity: root.selectedDay === index ? 1 : 0.7
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: root.selectedDay === index
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.weekDates.length === 7 ? root.weekDates[index].getDate() : ""
                    color: root.selectedDay === index ? Color.background : root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.hasGames[index]
                    width: 6
                    height: 6
                    radius: 3
                    color: root.selectedDay === index ? Color.background : Color.accent
                    opacity: root.selectedDay === index ? 1 : 0.9
                  }
                }
              }
            }

            Button {
              Layout.preferredWidth: Style.space(28)
              Layout.preferredHeight: Style.space(28)
              iconText: "\u203A"
              foreground: root.barForeground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.shiftWeek(7)
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.weekLabel()
            color: root.barForeground
            opacity: 0.5
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            visible: root.isWeekMode && root.weekDates.length === 7 && !root.selectedGame
          }

          RowLayout {
            width: parent.width - Style.space(20)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)
            visible: !root.isWeekMode && !root.selectedGame
            Button {
              Layout.preferredWidth: Style.space(28)
              Layout.preferredHeight: Style.space(28)
              iconText: "\u2039"
              foreground: root.barForeground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.shiftDay(-1)
            }
            Text {
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
              text: root.dayLabel()
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Button {
              Layout.preferredWidth: Style.space(28)
              Layout.preferredHeight: Style.space(28)
              iconText: "\u203A"
              foreground: root.barForeground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.shiftDay(1)
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.lastError
            visible: root.lastError !== "" && root.games.length === 0 && !root.selectedGame
            color: root.urgentColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Loading scores\u2026"
            visible: root.games.length === 0 && root.lastError === "" && !root.selectedGame
            color: root.barForeground
            opacity: 0.6
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          Repeater {
            model: root.games
            visible: !root.selectedGame

            Column {
              required property var modelData
              visible: !root.selectedGame
              width: parent.width
              spacing: Style.space(4)

              TapHandler {
                onTapped: root.showDetail(modelData)
              }

              RowLayout {
                width: parent.width
                spacing: Style.spacing.controlGap
                visible: modelData && modelData.away
                Rectangle {
                  visible: modelData && (modelData.away.logo || "") !== ""
                  width: Style.space(20)
                  height: Style.space(20)
                  Layout.preferredWidth: Style.space(20)
                  Layout.preferredHeight: Style.space(20)
                  Layout.alignment: Qt.AlignVCenter
                  radius: Style.space(4)
                  color: "transparent"
                  clip: true

                  Image {
                    id: awayLogo
                    anchors.fill: parent
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 40
                    source: modelData && modelData.away ? (modelData.away.logo || "") : ""
                  }
                }
                Button {
                  iconText: modelData && root.isFav(modelData.away.abbr) ? "\u2605" : "\u2606"
                  foreground: modelData && root.isFav(modelData.away.abbr) ? Color.accent : root.barForeground
                  accent: Color.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: if (modelData) root.toggleFav(modelData.away.abbr)
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData ? modelData.away.abbr + "   " + modelData.away.name : ""
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: modelData && root.leads(modelData, "away")
                  elide: Text.ElideRight
                  HoverHandler { id: hoverGameAway }
                  PanelToolTip { visible: hoverGameAway.hovered && parent.truncated; text: parent.text }
                }
                Text {
                  text: modelData && modelData.away ? modelData.away.score || "-" : "-"
                  color: modelData && root.leads(modelData, "away") ? Color.accent : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }

              RowLayout {
                width: parent.width
                spacing: Style.spacing.controlGap
                visible: modelData && modelData.home
                Rectangle {
                  visible: modelData && (modelData.home.logo || "") !== ""
                  width: Style.space(20)
                  height: Style.space(20)
                  Layout.preferredWidth: Style.space(20)
                  Layout.preferredHeight: Style.space(20)
                  Layout.alignment: Qt.AlignVCenter
                  radius: Style.space(4)
                  color: "transparent"
                  clip: true

                  Image {
                    id: homeLogo
                    anchors.fill: parent
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 40
                    source: modelData && modelData.home ? (modelData.home.logo || "") : ""
                  }
                }
                Button {
                  iconText: modelData && root.isFav(modelData.home.abbr) ? "\u2605" : "\u2606"
                  foreground: modelData && root.isFav(modelData.home.abbr) ? Color.accent : root.barForeground
                  accent: Color.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: if (modelData) root.toggleFav(modelData.home.abbr)
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData ? modelData.home.abbr + "   " + modelData.home.name : ""
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: modelData && root.leads(modelData, "home")
                  elide: Text.ElideRight
                  HoverHandler { id: hoverGameHome }
                  PanelToolTip { visible: hoverGameHome.hovered && parent.truncated; text: parent.text }
                }
                Text {
                  text: modelData && modelData.home ? modelData.home.score || "-" : "-"
                  color: modelData && root.leads(modelData, "home") ? Color.accent : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: modelData ? modelData.detail : ""
                color: modelData ? root.statusColor(modelData.state) : root.barForeground
                opacity: modelData && modelData.state === "in" ? 1.0 : 0.6
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: modelData && modelData.state === "in"
              }

              PanelSeparator { foreground: root.barForeground }
            }
          }
          Column {
            visible: root.selectedGame !== null
            width: parent.width
            spacing: Style.space(12)

            RowLayout {
              width: parent.width
              spacing: Style.space(8)
              Button {
                iconText: "\u2039"
                text: "Back"
                foreground: root.barForeground
                accent: Color.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.closeDetail()
              }
              Text {
                Layout.fillWidth: true
                text: root.selectedGame ? root.selectedGame.away.abbr + " @ " + root.selectedGame.home.abbr : ""
                color: root.barForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                text: root.selectedGame ? root.selectedGame.detail : ""
                color: root.barForeground
                opacity: 0.6
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)
              visible: root.detailTeams !== null
              Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: Style.space(2)
                Rectangle {
                  width: Style.space(32); height: Style.space(32); radius: Style.space(6); color: "transparent"; clip: true; anchors.horizontalCenter: parent.horizontalCenter
                  Image {
                    anchors.fill: parent
                    source: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.logo : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 64
                  }
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.abbr : ""
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(6)
                  Text {
                    text: root.selectedGame && root.selectedGame.away ? root.selectedGame.away.score : ""
                    color: root.leads(root.selectedGame, "away") ? Color.accent : root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Text {
                    visible: root.selectedGame && root.selectedGame.away && root.selectedGame.away.record
                    text: root.selectedGame && root.selectedGame.away ? "(" + root.selectedGame.away.record + ")" : ""
                    color: root.barForeground
                    opacity: 0.45
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                Text {
                  visible: root.detailTeams && root.detailTeams.away && root.detailTeams.away.name
                  text: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.name : ""
                  color: root.barForeground
                  opacity: 0.45
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  HoverHandler { id: hoverDetailAway }
                  PanelToolTip { visible: hoverDetailAway.hovered && parent.truncated; text: parent.text }
                }
              }
              Rectangle {
                width: 1
                Layout.fillHeight: true
                Layout.preferredHeight: Style.space(56)
                Layout.alignment: Qt.AlignVCenter
                color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
              }
              Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: Style.space(2)
                Rectangle {
                  width: Style.space(32); height: Style.space(32); radius: Style.space(6); color: "transparent"; clip: true; anchors.horizontalCenter: parent.horizontalCenter
                  Image {
                    anchors.fill: parent
                    source: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.logo : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 64
                  }
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.abbr : ""
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(6)
                  Text {
                    text: root.selectedGame && root.selectedGame.home ? root.selectedGame.home.score : ""
                    color: root.leads(root.selectedGame, "home") ? Color.accent : root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Text {
                    visible: root.selectedGame && root.selectedGame.home && root.selectedGame.home.record
                    text: root.selectedGame && root.selectedGame.home ? "(" + root.selectedGame.home.record + ")" : ""
                    color: root.barForeground
                    opacity: 0.45
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                Text {
                  visible: root.detailTeams && root.detailTeams.home && root.detailTeams.home.name
                  text: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.name : ""
                  color: root.barForeground
                  opacity: 0.45
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  HoverHandler { id: hoverDetailHome }
                  PanelToolTip { visible: hoverDetailHome.hovered && parent.truncated; text: parent.text }
                }
              }
            }

            Text {
              visible: root.detailTeams && root.detailTeams.venue
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.detailTeams ? (root.detailTeams.venue + (root.detailTeams.addr ? " – " + root.detailTeams.addr : "") + (root.detailTeams.status ? " · " + root.detailTeams.status : "")) : ""
              color: root.barForeground
              opacity: 0.5
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            PanelSeparator { foreground: root.barForeground; visible: (root.detailStats && root.detailStats.length > 0) || (root.detailPlayers && root.detailPlayers.length > 0) }

            RowLayout {
              width: parent.width
              spacing: Style.space(6)
              visible: !root.detailLoading && root.detailError === ""
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(28)
                radius: Style.space(6)
                color: root.detailTab === 0 ? Color.accent : "transparent"
                border.width: root.detailTab === 0 ? 0 : 1
                border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.18)
                Text {
                  anchors.centerIn: parent
                  text: "Overall"
                  color: root.detailTab === 0 ? Color.background : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: root.detailTab === 0
                }
                MouseArea { anchors.fill: parent; onClicked: root.detailTab = 0 }
              }
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(28)
                radius: Style.space(6)
                color: root.detailTab === 1 ? Color.accent : "transparent"
                border.width: root.detailTab === 1 ? 0 : 1
                border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.18)
                Text {
                  anchors.centerIn: parent
                  text: "Players"
                  color: root.detailTab === 1 ? Color.background : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: root.detailTab === 1
                }
                MouseArea { anchors.fill: parent; onClicked: root.detailTab = 1 }
              }
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(28)
                radius: Style.space(6)
                color: root.detailTab === 2 ? Color.accent : "transparent"
                border.width: root.detailTab === 2 ? 0 : 1
                border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.18)
                Text {
                  anchors.centerIn: parent
                  text: "Plays"
                  color: root.detailTab === 2 ? Color.background : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: root.detailTab === 2
                }
                MouseArea { anchors.fill: parent; onClicked: root.detailTab = 2 }
              }
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(28)
                radius: Style.space(6)
                color: root.detailTab === 3 ? Color.accent : "transparent"
                border.width: root.detailTab === 3 ? 0 : 1
                border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.18)
                Text {
                  anchors.centerIn: parent
                  text: "Insights"
                  color: root.detailTab === 3 ? Color.background : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: root.detailTab === 3
                }
                MouseArea { anchors.fill: parent; onClicked: root.detailTab = 3 }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)
              visible: root.detailLoading
              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Loading stats\u2026"
                color: root.barForeground
                opacity: 0.6
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              visible: root.detailError !== ""
              text: root.detailError
              color: root.urgentColor
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Button {
              visible: root.detailStale
              text: "Retry"
              foreground: root.barForeground
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.loadDetail()
            }

            Column {
                id: detailStatsContent
                width: parent.width
                spacing: Style.space(12)
                visible: !root.detailLoading && root.detailError === "" 

                Column {
                  width: parent.width
                  spacing: Style.space(12)
                  visible: root.detailTab === 0
                  height: visible ? implicitHeight : 0
                  clip: true
                  Column {
                    width: parent.width
                    visible: root.detailStats && root.detailStats.length > 0
                    spacing: 0
                    RowLayout {
                      width: parent.width
                      spacing: Style.space(8)
                      Text { Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignRight; text: root.detailTeams ? root.detailTeams.away.abbr : ""; color: root.barForeground; font.bold: true; font.pixelSize: Style.font.caption; opacity: 0.7 }
                      Text { Layout.preferredWidth: Style.space(160); horizontalAlignment: Text.AlignHCenter; text: ""; }
                      Text { Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignLeft; text: root.detailTeams ? root.detailTeams.home.abbr : ""; color: root.barForeground; font.bold: true; font.pixelSize: Style.font.caption; opacity: 0.7 }
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.08) }
                    Repeater {
                      model: root.detailStats
                      delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: row.implicitHeight + Style.space(4)
                        color: index % 2 === 1 ? Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.04) : "transparent"
                        radius: 2
                        RowLayout {
                          id: row
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(4)
                          anchors.rightMargin: Style.space(4)
                          spacing: Style.space(8)
                          Text { Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignRight; text: modelData.away; color: root.barForeground; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.family: "Monospace" }
                          Text { Layout.preferredWidth: Style.space(160); horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: root.barForeground; opacity: 0.5; font.pixelSize: Style.font.caption; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                          Text { Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignLeft; text: modelData.home; color: root.barForeground; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.family: "Monospace" }
                        }
                      }
                    }
                  }
                  Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: !root.detailStats || root.detailStats.length === 0
                    text: "No stats available"
                    color: root.barForeground
                    opacity: 0.5
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                            Column {
              width: parent.width
              spacing: Style.space(12)
              visible: root.detailTab === 1
              // height guard breaks Layout sizing inside ScrollView — visible alone suffices
Repeater {
                model: root.detailPlayerGroups
                delegate: Column {
                  required property var modelData
                  property var groupData: modelData
                  width: parent.width
                  spacing: Style.space(6)
                  Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.titleize(groupData.name || groupData.displayName || "")
                    color: root.barForeground
                    opacity: 0.9
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }
                  RowLayout {
                    width: parent.width
                    spacing: 0
                    // Away side - simple table with fixed name and scrollable stats
                    Column {
                      Layout.fillWidth: true
                      Layout.preferredWidth: 1
                      Layout.alignment: Qt.AlignTop
                      Layout.leftMargin: Style.space(6)
                      Layout.rightMargin: Style.space(6)
                      spacing: Style.space(4)
                      RowLayout {
                        width: parent.width
                        spacing: Style.space(6)
                        Column {
                          spacing: Style.space(6)
                          Rectangle {
                            width: Style.space(110)
                            height: Style.space(20)
                            color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.07)
                            radius: 2
                            Text {
                              anchors.centerIn: parent
                              text: "Player"
                              font.bold: true
                              font.pixelSize: Style.font.caption
                              color: root.barForeground
                              opacity: 0.8
                            }
                          }
                          Repeater {
                            model: groupData.away
                            delegate: Text {
                              required property var modelData
                              property var athleteData: modelData
                              width: Style.space(110)
                              height: Style.space(20)
                              verticalAlignment: Text.AlignVCenter
                              text: athleteData.athlete ? (athleteData.athlete.shortName || athleteData.athlete.displayName) : ""
                              color: root.barForeground
                              font.family: root.bar ? root.bar.fontFamily : Style.font.family
                              font.pixelSize: Style.font.caption
                              elide: Text.ElideRight
                              HoverHandler { id: hoverPlayerAway }
                              PanelToolTip { visible: hoverPlayerAway.hovered && parent.truncated; text: parent.text }
                            }
                          }
                        }
                        Flickable {
                          width: parent.width - Style.space(116)
                          height: flickAwayContent.implicitHeight
                          clip: true
                          flickableDirection: Flickable.HorizontalFlick
                          contentWidth: flickAwayContent.implicitWidth
                          contentHeight: flickAwayContent.implicitHeight
                          Column {
                            id: flickAwayContent
                            spacing: Style.space(6)
                            Row {
                              spacing: Style.space(6)
                              Repeater {
                                model: groupData.labels || []
                                delegate: Text {
                                  width: Style.space(55)
                                  height: Style.space(20)
                                  verticalAlignment: Text.AlignVCenter
                                  text: modelData
                                  font.bold: true
                                  font.pixelSize: Style.font.caption
                                  color: root.barForeground
                                  opacity: 0.7
                                  horizontalAlignment: Text.AlignHCenter
                                }
                              }
                            }
                            Repeater {
                              model: groupData.away
                              delegate: Row {
                                required property var modelData
                                property var athleteData: modelData
                                spacing: Style.space(6)
                                Repeater {
                                  model: athleteData.stats
                                  delegate: Text {
                                    width: Style.space(55)
                                    height: Style.space(20)
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    font.family: "Monospace"
                                    font.pixelSize: Style.font.caption
                                    color: root.barForeground
                                    horizontalAlignment: Text.AlignHCenter
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                    Rectangle {
                      width: 1
                      Layout.fillHeight: true
                      Layout.alignment: Qt.AlignVCenter
                      color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.15)
                    }
                    // Home side
                    Column {
                      Layout.fillWidth: true
                      Layout.preferredWidth: 1
                      Layout.alignment: Qt.AlignTop
                      Layout.leftMargin: Style.space(6)
                      Layout.rightMargin: Style.space(6)
                      spacing: Style.space(4)
                      RowLayout {
                        width: parent.width
                        spacing: Style.space(6)
                        Column {
                          spacing: Style.space(6)
                          Rectangle {
                            width: Style.space(110)
                            height: Style.space(20)
                            color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.07)
                            radius: 2
                            Text {
                              anchors.centerIn: parent
                              text: "Player"
                              font.bold: true
                              font.pixelSize: Style.font.caption
                              color: root.barForeground
                              opacity: 0.8
                            }
                          }
                          Repeater {
                            model: groupData.home
                            delegate: Text {
                              required property var modelData
                              property var athleteData: modelData
                              width: Style.space(110)
                              height: Style.space(20)
                              verticalAlignment: Text.AlignVCenter
                              text: athleteData.athlete ? (athleteData.athlete.shortName || athleteData.athlete.displayName) : ""
                              color: root.barForeground
                              font.family: root.bar ? root.bar.fontFamily : Style.font.family
                              font.pixelSize: Style.font.caption
                              elide: Text.ElideRight
                              HoverHandler { id: hoverPlayerHome }
                              PanelToolTip { visible: hoverPlayerHome.hovered && parent.truncated; text: parent.text }
                            }
                          }
                        }
                        Flickable {
                          width: parent.width - Style.space(116)
                          height: flickHomeContent.implicitHeight
                          clip: true
                          flickableDirection: Flickable.HorizontalFlick
                          contentWidth: flickHomeContent.implicitWidth
                          contentHeight: flickHomeContent.implicitHeight
                          Column {
                            id: flickHomeContent
                            spacing: Style.space(6)
                            Row {
                              spacing: Style.space(6)
                              Repeater {
                                model: groupData.labels || []
                                delegate: Text {
                                  width: Style.space(55)
                                  height: Style.space(20)
                                  verticalAlignment: Text.AlignVCenter
                                  text: modelData
                                  font.bold: true
                                  font.pixelSize: Style.font.caption
                                  color: root.barForeground
                                  opacity: 0.7
                                  horizontalAlignment: Text.AlignHCenter
                                }
                              }
                            }
                            Repeater {
                              model: groupData.home
                              delegate: Row {
                                required property var modelData
                                property var athleteData: modelData
                                spacing: Style.space(6)
                                Repeater {
                                  model: athleteData.stats
                                  delegate: Text {
                                    width: Style.space(55)
                                    height: Style.space(20)
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    font.family: "Monospace"
                                    font.pixelSize: Style.font.caption
                                    color: root.barForeground
                                    horizontalAlignment: Text.AlignHCenter
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
              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: !root.detailPlayerGroups                }
                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: !root.detailPlayerGroups || root.detailPlayerGroups.length === 0
                  text: "No player stats available"
                  color: root.barForeground
                  opacity: 0.5
                  font.pixelSize: Style.font.bodySmall
                }
              }
              // Plays tab (2) — full play-by-play, richer
              Column {
                width: parent.width
                spacing: Style.space(8)
                visible: root.detailTab === 2
                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: (!root.detailDrives || root.detailDrives.length === 0) && (!root.detailPlays || root.detailPlays.length === 0)
                  text: "No plays available"
                  color: root.barForeground
                  opacity: 0.5
                  font.pixelSize: Style.font.caption
                }
                // Drive-grouped when available (NFL)
                Column {
                  width: parent.width
                  spacing: Style.space(10)
                  visible: root.detailDrives && root.detailDrives.length > 0
                  Repeater {
                    model: root.detailDrives.length > 12 ? root.detailDrives.slice(root.detailDrives.length - 12) : root.detailDrives
                    delegate: Column {
                      required property var modelData
                      width: parent.width
                      spacing: Style.space(4)
                      RowLayout {
                        width: parent.width
                        spacing: Style.space(8)
                        Text {
                          text: modelData.team ? (modelData.team.abbreviation || modelData.team.displayName) : ""
                          color: root.barForeground
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                        Text {
                          Layout.fillWidth: true
                          text: (modelData.description || "") + (modelData.displayResult ? " \u00b7 " + modelData.displayResult : (modelData.result ? " \u00b7 " + modelData.result : ""))
                          color: root.barForeground
                          opacity: 0.55
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                        }
                        Rectangle {
                          Layout.preferredWidth: resultText.implicitWidth + Style.space(8)
                          height: Style.space(16)
                          radius: 3
                          color: modelData.isScore ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.08)
                          visible: modelData.displayResult || modelData.result || modelData.shortDisplayResult
                          Text {
                            id: resultText
                            anchors.centerIn: parent
                            text: modelData.displayResult || modelData.shortDisplayResult || modelData.result || ""
                            color: modelData.isScore ? Color.accent : root.barForeground
                            opacity: modelData.isScore ? 1 : 0.7
                            font.pixelSize: Style.font.caption
                            font.bold: modelData.isScore
                          }
                        }
                      }
                      Repeater {
                        model: modelData.plays || []
                        delegate: Rectangle {
                          required property var modelData
                          required property int index
                          width: parent.width
                          height: drivePlayRow.implicitHeight + Style.space(6)
                          color: modelData.scoringPlay ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.10) : (index % 2 === 1 ? Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.04) : "transparent")
                          radius: 4
                          border.width: modelData.scoringPlay ? 1 : 0
                          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                          RowLayout {
                            id: drivePlayRow
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            anchors.topMargin: Style.space(4)
                            anchors.bottomMargin: Style.space(4)
                            spacing: Style.space(8)
                            Rectangle {
                              Layout.preferredWidth: Style.space(44)
                              Layout.alignment: Qt.AlignTop
                              height: Style.space(16)
                              radius: 3
                              color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.08)
                              visible: (modelData.clock && modelData.clock.displayValue) || (modelData.period && modelData.period.displayValue)
                              Text {
                                anchors.centerIn: parent
                                text: (modelData.period && modelData.period.displayValue ? modelData.period.displayValue + " " : (modelData.period && modelData.period.number ? "Q" + modelData.period.number + " " : "")) + (modelData.clock && modelData.clock.displayValue ? modelData.clock.displayValue : "")
                                color: root.barForeground
                                opacity: 0.7
                                font.pixelSize: Style.font.caption
                                font.family: "Monospace"
                              }
                            }
                            Text {
                              Layout.fillWidth: true
                              text: modelData.text || modelData.description || ""
                              color: modelData.scoringPlay ? Color.accent : root.barForeground
                              font.pixelSize: Style.font.caption
                              wrapMode: Text.WordWrap
                              opacity: modelData.scoringPlay ? 1 : 0.85
                            }
                            Text { visible: modelData.scoringPlay; text: "\u25CF"; color: Color.accent; font.pixelSize: Style.font.caption; Layout.alignment: Qt.AlignTop }
                          }
                        }
                      }
                    }
                  }
                }
                // Flat fallback (NBA/MLB/Soccer or when drives empty)
                Column {
                  width: parent.width
                  spacing: Style.space(4)
                  visible: (!root.detailDrives || root.detailDrives.length === 0) && root.detailPlays && root.detailPlays.length > 0
                  Repeater {
                    model: root.detailPlays && root.detailPlays.length > 60 ? root.detailPlays.slice(root.detailPlays.length - 60) : (root.detailPlays || [])
                    delegate: Rectangle {
                      required property var modelData
                      required property int index
                      width: parent.width
                      height: playRow.implicitHeight + Style.space(6)
                      color: modelData.scoringPlay ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.10) : (index % 2 === 1 ? Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.04) : "transparent")
                      radius: 4
                      border.width: modelData.scoringPlay ? 1 : 0
                      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                      RowLayout {
                        id: playRow
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(6)
                        anchors.rightMargin: Style.space(6)
                        anchors.topMargin: Style.space(4)
                        anchors.bottomMargin: Style.space(4)
                        spacing: Style.space(8)
                        Rectangle {
                          Layout.preferredWidth: Style.space(44)
                          Layout.alignment: Qt.AlignTop
                          height: Style.space(16)
                          radius: 3
                          color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.08)
                          visible: (modelData.clock && modelData.clock.displayValue) || (modelData.period && modelData.period.displayValue)
                          Text {
                            anchors.centerIn: parent
                            text: (modelData.period && modelData.period.displayValue ? modelData.period.displayValue + " " : (modelData.period && modelData.period.number ? "Q" + modelData.period.number + " " : "")) + (modelData.clock && modelData.clock.displayValue ? modelData.clock.displayValue : "")
                            color: root.barForeground
                            opacity: 0.7
                            font.pixelSize: Style.font.caption
                            font.family: "Monospace"
                          }
                        }
                        Text {
                          Layout.fillWidth: true
                          text: modelData.text || modelData.description || modelData.shortText || ""
                          color: modelData.scoringPlay ? Color.accent : root.barForeground
                          font.pixelSize: Style.font.caption
                          wrapMode: Text.WordWrap
                          opacity: modelData.scoringPlay ? 1 : 0.85
                        }
                        Text {
                          visible: modelData.scoringPlay
                          text: "\u25CF"
                          color: Color.accent
                          font.pixelSize: Style.font.caption
                          Layout.alignment: Qt.AlignTop
                        }
                      }
                    }
                  }
                }
              }
              // Insights tab (3) — B, F preview, H, I, J with richer visuals
              Column {
                width: parent.width
                spacing: Style.space(12)
                visible: root.detailTab === 3
                // B: Leaders with headshots
                Column {
                  width: parent.width
                  spacing: Style.space(6)
                  visible: root.detailLeaders && root.detailLeaders.length > 0
                  Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Leaders"; color: root.barForeground; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailLeaders
                    delegate: Column {
                      required property var modelData
                      width: parent.width
                      spacing: Style.space(6)
                      RowLayout {
                        width: parent.width
                        spacing: Style.space(8)
                        Rectangle { width: Style.space(24); height: Style.space(24); radius: 12; clip: true; color: "transparent"; visible: modelData.team && modelData.team.logo; Image { anchors.fill: parent; source: modelData.team.logo || ""; fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true } }
                        Text { text: modelData.team ? (modelData.team.abbreviation || modelData.team.displayName) : ""; color: root.barForeground; opacity: 0.6; font.pixelSize: Style.font.caption; font.bold: true; Layout.fillWidth: true }
                      }
                      Repeater {
                        model: modelData.leaders || []
                        delegate: RowLayout {
                          required property var modelData
                          property var leader: modelData.leaders && modelData.leaders.length ? modelData.leaders[0] : null
                          width: parent.width
                          spacing: Style.space(8)
                          Rectangle {
                            Layout.preferredWidth: Style.space(28); Layout.preferredHeight: Style.space(28); radius: 14; clip: true; color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.08)
                            Image {
                              anchors.fill: parent
                              source: leader && leader.athlete && leader.athlete.headshot ? leader.athlete.headshot.href : ""
                              fillMode: Image.PreserveAspectCrop
                              asynchronous: true; cache: true
                            }
                          }
                          Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: leader && leader.athlete ? (leader.athlete.displayName || leader.athlete.shortName) : ""; color: root.barForeground; font.pixelSize: Style.font.caption; elide: Text.ElideRight; font.bold: true }
                            Text { text: (leader && leader.athlete && leader.athlete.position ? leader.athlete.position.abbreviation + " \u00b7 " : "") + (modelData.displayName || modelData.name || ""); color: root.barForeground; opacity: 0.5; font.pixelSize: Style.font.caption }
                          }
                          Text { text: leader ? (leader.displayValue || leader.value || "") : ""; color: Color.accent; font.pixelSize: Style.font.caption; font.bold: true; font.family: "Monospace" }
                        }
                      }
                    }
                  }
                }
                // F preview in Insights (compact)
                Column {
                  width: parent.width
                  spacing: Style.space(6)
                  visible: root.detailPlays && root.detailPlays.length > 0
                  PanelSeparator { foreground: root.barForeground }
                  Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Recent Plays"; color: root.barForeground; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailPlays.length > 5 ? root.detailPlays.slice(root.detailPlays.length - 5) : (root.detailPlays || [])
                    delegate: Rectangle {
                      required property var modelData
                      required property int index
                      width: parent.width
                      height: miniPlay.implicitHeight + Style.space(6)
                      color: index % 2 === 1 ? Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.04) : "transparent"
                      radius: 2
                      Text {
                        id: miniPlay
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        text: (modelData.clock ? modelData.clock.displayValue + " " : "") + (modelData.text || modelData.description || "")
                        color: modelData.scoringPlay ? Color.accent : root.barForeground
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        opacity: modelData.scoringPlay ? 1 : 0.7
                      }
                    }
                  }
                  Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.detailPlays && root.detailPlays.length > 5 ? "See Plays tab for full list \u2192" : ""
                    color: Color.accent
                    opacity: 0.6
                    font.pixelSize: Style.font.caption
                    visible: root.detailPlays && root.detailPlays.length > 5
                    MouseArea { anchors.fill: parent; onClicked: root.detailTab = 2; cursorShape: Qt.PointingHandCursor }
                  }
                }
                // H: Standings with conference + W/L/T headers
                Column {
                  width: parent.width
                  spacing: Style.space(6)
                  visible: root.detailStandings && root.detailStandings.groups && root.detailStandings.groups.length > 0
                  PanelSeparator { foreground: root.barForeground }
                  Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Standings"; color: root.barForeground; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailStandings ? root.detailStandings.groups : []
                    delegate: Column {
                      required property var modelData
                      required property int index
                      width: parent.width
                      spacing: Style.space(2)
                      Item { width: parent.width; height: index === 0 ? 0 : Style.space(10) }
                      Rectangle {
                        width: parent.width
                        height: Style.space(16)
                        color: "transparent"
                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(8)
                          Text { Layout.fillWidth: true; text: modelData.conferenceHeader || modelData.divisionHeader || modelData.header || ""; color: root.barForeground; opacity: 0.5; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                          Text { Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: "W"; color: root.barForeground; opacity: 0.45; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: "L"; color: root.barForeground; opacity: 0.45; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: "T"; color: root.barForeground; opacity: 0.45; font.pixelSize: Style.font.caption; font.bold: true }
                        }
                      }
                      Repeater {
                        model: modelData.standings ? modelData.standings.entries.slice(0, 5) : []
                        delegate: Rectangle {
                          required property var modelData
                          required property int index
                          width: parent.width
                          height: Style.space(20)
                          property bool isCurrent: (root.selectedGame && ((String(modelData.id) === String(root.selectedGame.away.id)) || (String(modelData.id) === String(root.selectedGame.home.id)))) || (modelData.team && root.selectedGame && (modelData.team.indexOf(root.selectedGame.away.abbr) >= 0 || modelData.team.indexOf(root.selectedGame.home.abbr) >= 0))
                          color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : (index % 2 === 1 ? Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.04) : "transparent")
                          radius: 2
                          border.width: isCurrent ? 1 : 0
                          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(8)
                            Text { Layout.fillWidth: true; text: modelData.team || modelData.displayName || ""; color: isCurrent ? Color.accent : root.barForeground; font.pixelSize: Style.font.caption; elide: Text.ElideRight; font.bold: isCurrent }
                            Text { Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.standingsStat(modelData, ["wins","W"]); color: isCurrent ? Color.accent : root.barForeground; opacity: isCurrent ? 1 : 0.6; font.pixelSize: Style.font.caption; font.family: "Monospace"; font.bold: isCurrent }
                            Text { Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.standingsStat(modelData, ["losses","L"]); color: isCurrent ? Color.accent : root.barForeground; opacity: isCurrent ? 1 : 0.6; font.pixelSize: Style.font.caption; font.family: "Monospace"; font.bold: isCurrent }
                            Text { Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.standingsStat(modelData, ["ties","T"]); color: isCurrent ? Color.accent : root.barForeground; opacity: isCurrent ? 1 : 0.6; font.pixelSize: Style.font.caption; font.family: "Monospace"; font.bold: isCurrent }
                          }
                        }
                      }
                    }
                  }
                }
                // I: Injuries
                Column {
                  width: parent.width
                  spacing: Style.space(6)
                  visible: root.detailInjuries && root.detailInjuries.length > 0
                  PanelSeparator { foreground: root.barForeground }
                  Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Injuries"; color: root.barForeground; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailInjuries
                    delegate: Column {
                      required property var modelData
                      width: parent.width
                      spacing: Style.space(2)
                      Text { width: parent.width; text: modelData.team ? modelData.team.abbreviation : ""; color: root.barForeground; opacity: 0.5; font.pixelSize: Style.font.caption; font.bold: true }
                      Repeater {
                        model: (modelData.injuries || modelData.players || []).slice(0, 3)
                        delegate: Text {
                          required property var modelData
                          width: parent.width
                          text: (modelData.athlete ? modelData.athlete.displayName : modelData.displayName || "") + (modelData.status ? " \u2013 " + modelData.status : "")
                          color: root.barForeground
                          opacity: 0.6
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                          wrapMode: Text.WordWrap
                        }
                      }
                    }
                  }
                }
                // J: News / Videos
                Column {
                  width: parent.width
                  spacing: Style.space(6)
                  visible: (root.detailNews && root.detailNews.length > 0) || (root.detailVideos && root.detailVideos.length > 0)
                  PanelSeparator { foreground: root.barForeground }
                  Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Related"; color: root.barForeground; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailNews
                    delegate: Text {
                      required property var modelData
                      width: parent.width
                      text: "\u25B6 " + (modelData.headline || modelData.title || "")
                      color: Color.accent
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      wrapMode: Text.WordWrap
                      maximumLineCount: 2
                      MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally(modelData.links && modelData.links.web ? modelData.links.web.href : modelData.link ? modelData.link.href : "") ; cursorShape: Qt.PointingHandCursor }
                    }
                  }
                  Repeater {
                    model: root.detailVideos
                    delegate: Text {
                      required property var modelData
                      width: parent.width
                      text: "\u25B6 " + (modelData.headline || modelData.description || "")
                      color: Color.accent
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      wrapMode: Text.WordWrap
                      maximumLineCount: 2
                      MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally(modelData.links && modelData.links.source ? modelData.links.source.href : modelData.link ? modelData.link.href : "") ; cursorShape: Qt.PointingHandCursor }
                    }
                  }
                }
                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: (!root.detailLeaders || root.detailLeaders.length === 0) && (!root.detailPlays || root.detailPlays.length === 0) && (!root.detailStandings || !root.detailStandings.groups) && (!root.detailInjuries || root.detailInjuries.length === 0) && (!root.detailNews || root.detailNews.length === 0) && (!root.detailVideos || root.detailVideos.length === 0)
                  text: "No insights for this game"
                  color: root.barForeground
                  opacity: 0.4
                  font.pixelSize: Style.font.caption
                }
              }
            }
        }
      }
    }
  }
}

}

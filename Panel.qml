import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "chris.nfl"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property var games: []
  property var favorites: []
  property int liveCount: 0
  property bool favLive: false
  property string lastError: ""

  readonly property string storePath: Quickshell.env("HOME") + "/.local/state/omarchy/nfl-favorites.json"
  readonly property string apiUrl: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
  readonly property color urgentColor: root.bar ? root.bar.urgent : Color.urgent

  property var weekStart: null
  property var weekDateStrs: []
  property var weekDates: []
  property var hasGames: [false,false,false,false,false,false,false]
  property int selectedDay: 0
  property var dayLabels: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
  property var monthLabels: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

  property var selectedGame: null
  property var detailStats: null
  property var detailTeams: null
  property var detailPlayers: null
  property var detailPlayerGroups: null
  property bool detailLoading: false
  property string detailError: ""
  property int detailTab: 0

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function isFav(abbr) {
    return root.favorites.indexOf(abbr) >= 0
  }

  function loadFavorites(raw) {
    var parsed = []
    try { parsed = JSON.parse(raw || "[]") } catch (e) { parsed = [] }
    if (!Array.isArray(parsed)) parsed = []
    root.favorites = parsed
  }

  function saveFavorites() {
    store.setText(JSON.stringify(root.favorites, null, 2) + "\n")
  }

  function toggleFav(abbr) {
    var arr = root.favorites.slice()
    var idx = arr.indexOf(abbr)
    if (idx >= 0) arr.splice(idx, 1)
    else arr.push(abbr)
    root.favorites = arr
    root.saveFavorites()
    root.games = root.sorted(root.games)
    root.recount()
  }

  function rank(g) {
    var fav = root.isFav(g.away.abbr) || root.isFav(g.home.abbr)
    if (g.state === "in") return fav ? 0 : 2
    if (fav) return 1
    if (g.state === "pre") return 3
    return 4
  }

  function sorted(list) {
    var arr = list.slice()
    arr.sort(function(a, b) { return root.rank(a) - root.rank(b) })
    return arr
  }

  function recount() {
    var live = 0
    var favPlaying = false
    for (var i = 0; i < root.games.length; i++) {
      var g = root.games[i]
      if (g.state === "in") {
        live++
        if (root.isFav(g.away.abbr) || root.isFav(g.home.abbr)) favPlaying = true
      }
    }
    root.liveCount = live
    root.favLive = favPlaying
  }

  function leads(game, side) {
    if (!game || !game[side] || game.state === "pre") return false
    var mine = parseInt(game[side].score) || 0
    var other = parseInt(game[side === "away" ? "home" : "away"].score) || 0
    return mine > other
  }

  function titleize(s) {
    var t = String(s || "").trim()
    if (!t) return ""
    return t.split(/[\s_\/]+/).map(function(w){ return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase() }).join(" ")
  }

  function sundayOf(d) {
    var nd = new Date(d)
    nd.setHours(0, 0, 0, 0)
    nd.setDate(nd.getDate() - nd.getDay())
    return nd
  }

  function ymd(d) {
    var y = d.getFullYear(), m = d.getMonth() + 1, dd = d.getDate()
    return y + (m < 10 ? "0" + m : m) + (dd < 10 ? "0" + dd : dd)
  }

  function weekLabel() {
    if (!root.weekDates || root.weekDates.length !== 7) return ""
    var s = root.weekDates[0], e = root.weekDates[6]
    var sm = root.monthLabels[s.getMonth()], em = root.monthLabels[e.getMonth()]
    if (s.getMonth() === e.getMonth()) return sm + " " + s.getDate() + " \u2013 " + e.getDate()
    return sm + " " + s.getDate() + " \u2013 " + em + " " + e.getDate()
  }

  function initWeek() {
    var today = new Date()
    today.setHours(0, 0, 0, 0)
    var s = root.sundayOf(today)
    root.weekStart = s
    var dates = [], strs = []
    for (var i = 0; i < 7; i++) {
      var dd = new Date(s)
      dd.setDate(s.getDate() + i)
      dates.push(dd)
      strs.push(root.ymd(dd))
    }
    root.weekDates = dates
    root.weekDateStrs = strs
    root.selectedDay = today.getDay()
    root.hasGames = [false,false,false,false,false,false,false]
    root.checkWeekGames()
    root.refreshSelected()
  }

  function shiftWeek(delta) {
    if (!root.weekStart) return
    var ns = new Date(root.weekStart)
    ns.setDate(ns.getDate() + delta)
    root.weekStart = ns
    var dates = [], strs = []
    for (var i = 0; i < 7; i++) {
      var dd = new Date(ns)
      dd.setDate(ns.getDate() + i)
      dates.push(dd)
      strs.push(root.ymd(dd))
    }
    root.weekDates = dates
    root.weekDateStrs = strs
    var today = new Date()
    today.setHours(0, 0, 0, 0)
    var tStr = root.ymd(today)
    var idx = strs.indexOf(tStr)
    root.selectedDay = idx >= 0 ? idx : 0
    root.hasGames = [false,false,false,false,false,false,false]
    root.checkWeekGames()
    root.refreshSelected()
  }

  function selectDay(idx) {
    if (idx < 0 || idx > 6) return
    root.selectedDay = idx
    root.refreshSelected()
  }

  function checkWeekGames() {
    if (!root.weekDateStrs || root.weekDateStrs.length !== 7) return
    var cmd = "for d in " + root.weekDateStrs.join(" ") + "; do c=$(curl -fsS --max-time 5 '" + root.apiUrl + "?dates='\"$d\" 2>/dev/null | jq -r '.events | length' 2>/dev/null); [ -z \"$c\" ] && c=0; echo \"$d:$c\"; done"
    weekProc.command = ["bash", "-c", cmd]
    weekProc.running = true
  }

  function parseWeek(raw) {
    var txt = String(raw || "").trim()
    if (!txt) return
    var lines = txt.split("\n")
    var arr = [false,false,false,false,false,false,false]
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split(":")
      if (parts.length < 2) continue
      var d = parts[0], c = parseInt(parts[1]) || 0
      var idx = root.weekDateStrs.indexOf(d)
      if (idx >= 0) arr[idx] = c > 0
    }
    root.hasGames = arr
  }

  function refreshSelected() {
    if (!root.weekDateStrs || !root.weekDateStrs[root.selectedDay]) return
    var ds = root.weekDateStrs[root.selectedDay]
    fetchProc.command = ["bash", "-c", "curl -fsS --max-time 10 '" + root.apiUrl + "?dates='\""+ds+"\" 2>/dev/null | tee /tmp/nfl-scores.json"]
    fetchProc.running = true
  }

  function showDetail(game) {
    if (!game || !game.id) return
    root.selectedGame = game
    root.detailStats = null
    root.detailTeams = null
    root.detailPlayers = null
    root.detailPlayerGroups = null
    root.detailError = ""
    root.detailLoading = true
    root.detailTab = 0
    var id = game.id
    detailProc.command = ["bash", "-c", "curl -fsS --max-time 10 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=" + id + "' 2>/dev/null"]
    detailProc.running = true
  }

  function closeDetail() {
    root.selectedGame = null
    root.detailStats = null
    root.detailTeams = null
    root.detailPlayers = null
    root.detailPlayerGroups = null
    root.detailError = ""
    root.detailLoading = false
  }

  function parseDetail(raw) {
    var txt = String(raw || "").trim()
    if (!txt) { root.detailError = "No details"; root.detailLoading = false; return }
    try {
      var d = JSON.parse(txt)
      var header = d.header || {}
      var comp = header.competitions && header.competitions[0]
      if (!comp) { root.detailError = "No details"; root.detailLoading = false; return }
      var box = d.boxscore || {}
      var teams = box.teams || []
      var away = root.selectedGame ? root.selectedGame.away : null
      var home = root.selectedGame ? root.selectedGame.home : null
      var awayId = away ? away.id : null, homeId = home ? home.id : null
      var tAway = null, tHome = null
      for (var i = 0; i < teams.length; i++) {
        var t = teams[i]
        var tid = t.team ? t.team.id : null
        var abbr = t.team ? t.team.abbreviation : null
        if (tid && awayId && String(tid) === String(awayId)) tAway = t
        else if (abbr && away && abbr === away.abbr) tAway = t
        else if (tid && homeId && String(tid) === String(homeId)) tHome = t
        else if (abbr && home && abbr === home.abbr) tHome = t
      }
      if (!tAway && teams.length > 0) tAway = teams[0]
      if (!tHome && teams.length > 1) tHome = teams[1]
      var statsA = tAway ? tAway.statistics || [] : []
      var statsH = tHome ? tHome.statistics || [] : []
      var paired = []
      var mapH = {}
      for (var j = 0; j < statsH.length; j++) mapH[statsH[j].name] = statsH[j]
      for (var k = 0; k < statsA.length; k++) {
        var sA = statsA[k]
        var sH = mapH[sA.name]
        paired.push({ label: sA.label || sA.name, away: sA.displayValue || sA.value, home: sH ? (sH.displayValue || sH.value) : "-" })
      }
      if (paired.length === 0) {
        var compAway = null, compHome = null
        for (var c = 0; c < comp.competitors.length; c++) {
          if (comp.competitors[c].homeAway === "away") compAway = comp.competitors[c]
          else compHome = comp.competitors[c]
        }
        if (compAway && compHome) {
          var qtrs = Math.max(compAway.linescores ? compAway.linescores.length : 0, compHome.linescores ? compHome.linescores.length : 0)
          for (var q = 0; q < qtrs; q++) {
            var la = compAway.linescores && compAway.linescores[q] ? compAway.linescores[q].displayValue : "-"
            var lh = compHome.linescores && compHome.linescores[q] ? compHome.linescores[q].displayValue : "-"
            paired.push({ label: "Q" + (q+1), away: la, home: lh })
          }
          paired.push({ label: "Total", away: compAway.score || "0", home: compHome.score || "0" })
          if (compAway.records && compAway.records[0]) paired.push({ label: "Record", away: compAway.records[0].summary, home: compHome.records && compHome.records[0] ? compHome.records[0].summary : "-" })
        }
      }
      // venue and status// venue and status
      var venue = comp.venue ? (comp.venue.fullName || "") : ""
      var addr = ""
      if (comp.venue && comp.venue.address) addr = comp.venue.address.city + (comp.venue.address.state ? ", " + comp.venue.address.state : "")
      root.detailTeams = { away: away, home: home, venue: venue, addr: addr, status: comp.status ? comp.status.type.detail : "" }
      root.detailStats = paired
      root.detailPlayers = box.players || null
      // Build grouped player stats for the Players tab (unified by stat name)// Build grouped player stats for the Players tab (unified by stat name)
      var groups = []
      var groupMap = {}
      var order = []
      if (box.players) {
        for (var pi = 0; pi < box.players.length; pi++) {
          var teamEntry = box.players[pi]
          var tAbbr = teamEntry.team ? teamEntry.team.abbreviation : ""
          var isAway = away && tAbbr === away.abbr
          var isHome = home && tAbbr === home.abbr
          var stats = teamEntry.statistics || []
          for (var si = 0; si < stats.length; si++) {
            var s = stats[si]
            var gname = s.name || s.text || ""
            if (!gname) continue
            if (!groupMap[gname]) {
              groupMap[gname] = { name: gname, displayName: s.displayName || s.shortDisplayName || gname, labels: s.labels || s.keys || [], keys: s.keys || [], away: [], home: [] }
              order.push(gname)
            }
            var list = s.athletes || []
            if (isAway) groupMap[gname].away = list
            else if (isHome) groupMap[gname].home = list
            else {
              if (pi === 0) groupMap[gname].away = list
              else groupMap[gname].home = list
            }
            // Prefer labels from any entry// Prefer labels from any entry
            if ((!groupMap[gname].labels || groupMap[gname].labels.length === 0) && s.labels) groupMap[gname].labels = s.labels
          }
        }
        for (var gi = 0; gi < order.length; gi++) groups.push(groupMap[order[gi]])
      }
      root.detailPlayerGroups = groups
      root.detailLoading = false
    } catch (e) {
      root.detailError = "Failed to load"
      root.detailLoading = false
    }
  }

  function refresh() {
    root.refreshSelected()
  }

  function parseGames(raw) {
    var parsed = String(raw || "").trim()
    if (!parsed) {
      root.games = []
      root.lastError = ""
      root.recount()
      return
    }
    try {
      var data = JSON.parse(parsed)
      var events = data.events || []
      var out = []
      for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        var comp = ev.competitions && ev.competitions[0]
        if (!comp) continue
        var g = {
          id: ev.id,
          state: ev.status.type.state,
          detail: ev.status.type.shortDetail,
          away: null,
          home: null
        }
        var cs = comp.competitors || []
        for (var j = 0; j < cs.length; j++) {
          var c = cs[j]
          g[c.homeAway] = { id: c.team.id, abbr: c.team.abbreviation, name: c.team.displayName, score: c.score, logo: c.team.logo, color: c.team.color, record: c.records && c.records[0] ? c.records[0].summary : "" }
        }
        if (g.away && g.home) out.push(g)
      }
      root.games = root.sorted(out)
      root.lastError = events.length ? "" : "No games scheduled"
      root.recount()
    } catch (e) {
      root.lastError = "Parse error"
    }
  }

  function statusColor(state) {
    if (state === "in") return root.urgentColor
    return root.barForeground
  }

  FileView {
    id: store
    path: root.storePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.loadFavorites(text())
      root.games = root.sorted(root.games)
      root.recount()
    }
    onLoadFailed: root.loadFavorites("[]")
    onFileChanged: reload()
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

  Component.onCompleted: Qt.callLater(root.initWeek)

  onOpenedChanged: if (root.opened) { if (!root.weekStart) root.initWeek(); else root.refreshSelected() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(760))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

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
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth - Style.space(20)
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: heroIcon.implicitHeight
            Text {
              id: heroIcon
              text: "\uD83C\uDFC8"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "NFL Scores"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          RowLayout {
            width: parent.width - Style.space(20)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(4)
            visible: root.weekDates.length === 7 && !root.selectedGame

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
            visible: root.weekDates.length === 7 && !root.selectedGame
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
              spacing: 0
              visible: root.detailTeams !== null
              Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: Style.space(6)
                Rectangle {
                  width: Style.space(48); height: Style.space(48); radius: Style.space(8); color: "transparent"; clip: true; anchors.horizontalCenter: parent.horizontalCenter
                  Image {
                    anchors.fill: parent
                    source: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.logo : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 96
                  }
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.abbr : ""
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
                Text {
                  text: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.name : ""
                  color: root.barForeground
                  opacity: 0.6
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.selectedGame && root.selectedGame.away ? root.selectedGame.away.score : ""
                  color: root.leads(root.selectedGame, "away") ? Color.accent : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.selectedGame && root.selectedGame.away && root.selectedGame.away.record ? root.selectedGame.away.record : ""
                  color: root.barForeground
                  opacity: 0.5
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
              Rectangle {
                width: 1
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.15)
              }
              Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: Style.space(6)
                Rectangle {
                  width: Style.space(48); height: Style.space(48); radius: Style.space(8); color: "transparent"; clip: true; anchors.horizontalCenter: parent.horizontalCenter
                  Image {
                    anchors.fill: parent
                    source: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.logo : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 96
                  }
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.abbr : ""
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
                Text {
                  text: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.name : ""
                  color: root.barForeground
                  opacity: 0.6
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.selectedGame && root.selectedGame.home ? root.selectedGame.home.score : ""
                  color: root.leads(root.selectedGame, "home") ? Color.accent : root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.selectedGame && root.selectedGame.home && root.selectedGame.home.record ? root.selectedGame.home.record : ""
                  color: root.barForeground
                  opacity: 0.5
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Text {
              visible: root.detailTeams && root.detailTeams.venue
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.detailTeams ? (root.detailTeams.venue + (root.detailTeams.addr ? " \u2013 " + root.detailTeams.addr : "") + (root.detailTeams.status ? " \u00b7 " + root.detailTeams.status : "")) : ""
              color: root.barForeground
              opacity: 0.5
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            PanelSeparator { foreground: root.barForeground; visible: (root.detailStats && root.detailStats.length > 0) || (root.detailPlayers && root.detailPlayers.length > 0) }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)
              visible: !root.detailLoading && root.detailError === "" && ( (root.detailStats && root.detailStats.length > 0) || (root.detailPlayers && root.detailPlayers.length > 0) )
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(32)
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
                height: Style.space(32)
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

            ScrollView {
              id: detailStatsScroll
              width: parent.width
              height: Math.min(detailStatsContent.implicitHeight, Style.space(380))
              clip: true
              visible: !root.detailLoading && root.detailError === ""
              ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
              ScrollBar.vertical.policy: detailStatsContent.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

              Column {
                id: detailStatsContent
                width: detailStatsScroll.availableWidth
                spacing: Style.space(12)

                Column {
                  width: parent.width
                  spacing: 0
                  visible: root.detailTab === 0 && root.detailStats && root.detailStats.length > 0
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
                    delegate: RowLayout {
                      required property var modelData
                      width: parent.width
                      spacing: Style.space(8)
                      Text { Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignRight; text: modelData.away; color: root.barForeground; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.family: "Monospace" }
                      Text { Layout.preferredWidth: Style.space(160); horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: root.barForeground; opacity: 0.5; font.pixelSize: Style.font.caption; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                      Text { Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignLeft; text: modelData.home; color: root.barForeground; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.family: "Monospace" }
                    }
                  }
                }

                            Column {
              width: parent.width
              spacing: Style.space(12)
              visible: root.detailTab === 1 && !root.detailLoading && root.detailError === ""
              Repeater {
                model: root.detailPlayerGroups
                delegate: Column {
                  required property var groupData
                  width: parent.width
                  spacing: Style.space(6)
                  Text {
                    width: parent.width
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
                      Rectangle {
                        width: parent.width
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
                        delegate: RowLayout {
                          required property var athleteData
                          width: parent.width
                          spacing: Style.space(6)
                          Text {
                            Layout.preferredWidth: Style.space(110)
                            text: athleteData.athlete ? (athleteData.athlete.shortName || athleteData.athlete.displayName) : ""
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                          }
                          // Stats as a single Flickable row
                          Flickable {
                            Layout.fillWidth: true
                            height: Style.space(20)
                            contentWidth: statsRow.implicitWidth
                            clip: true
                            Row {
                              id: statsRow
                              spacing: Style.space(6)
                              Repeater {
                                model: athleteData.stats
                                delegate: Text {
                                  width: Style.space(55)
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
                      // Header for stats labels
                      RowLayout {
                        width: parent.width
                        spacing: Style.space(6)
                        Text {
                          Layout.preferredWidth: Style.space(110)
                          text: ""
                        }
                        Repeater {
                          model: groupData.labels || []
                          delegate: Text {
                            Layout.preferredWidth: Style.space(55)
                            text: modelData
                            font.bold: true
                            font.pixelSize: Style.font.caption
                            color: root.barForeground
                            opacity: 0.7
                            horizontalAlignment: Text.AlignHCenter
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
                      Rectangle {
                        width: parent.width
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
                        delegate: RowLayout {
                          required property var athleteData
                          width: parent.width
                          spacing: Style.space(6)
                          Text {
                            Layout.preferredWidth: Style.space(110)
                            text: athleteData.athlete ? (athleteData.athlete.shortName || athleteData.athlete.displayName) : ""
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                          }
                          Flickable {
                            Layout.fillWidth: true
                            height: Style.space(20)
                            contentWidth: statsRowH.implicitWidth
                            clip: true
                            Row {
                              id: statsRowH
                              spacing: Style.space(6)
                              Repeater {
                                model: athleteData.stats
                                delegate: Text {
                                  width: Style.space(55)
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
                      RowLayout {
                        width: parent.width
                        spacing: Style.space(6)
                        Text {
                          Layout.preferredWidth: Style.space(110)
                          text: ""
                        }
                        Repeater {
                          model: groupData.labels || []
                          delegate: Text {
                            Layout.preferredWidth: Style.space(55)
                            text: modelData
                            font.bold: true
                            font.pixelSize: Style.font.caption
                            color: root.barForeground
                            opacity: 0.7
                            horizontalAlignment: Text.AlignHCenter
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
                visible: !root.detailPlayerGroups || root.detailPlayerGroups.length === 0
                text: "No player stats available"
                color: root.barForeground
                opacity: 0.5
                font.pixelSize: Style.font.bodySmall
              }
            }
                }
              }
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

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: root.detailTab === 0 && root.detailStats && root.detailStats.length === 0
                  text: "No stats available"
                  color: root.barForeground
                  opacity: 0.5
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }
        }
      }
    
  


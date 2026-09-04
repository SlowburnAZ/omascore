import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model
import "I18n.js" as I18n

Panel {
  id: root
  moduleName: "slowburnaz.omascore"
  manageIpc: false

  // Language: plugin setting "language" (auto|en|es), falling back to the
  // system locale. langCode is a binding on hostWidget's settings (re-evaluates
  // when the shell injects or replaces them); applyLang() runs from the change
  // handler — never inside a binding — and bumps langRev so every tx() text
  // binding repaints with the new lang.
  property int langRev: 0
  // What THIS instance last painted with — NOT the shared I18n state: the bar
  // sets the shared lang before panels construct, so a shared-state comparison
  // skips the bump and bindings stay on their construction-time (English) eval
  property string appliedLang: ""
  readonly property string langCode: {
    var w = root.hostWidget
    var v = (w && typeof w.setting === "function") ? w.setting("language", "auto") : "auto"
    return String(v || "auto")
  }
  onLangCodeChanged: {
    root.applyLang()
    // refetch an open detail so plays/stats render in the new language
    if (root.selectedGame) root.loadDetail()
  }
  function applyLang() {
    var code = root.langCode
    I18n.setLang(code === "auto" ? Qt.locale().name.substring(0, 2) : code)
    var now = I18n.current()
    if (now !== root.appliedLang) {
      root.appliedLang = now
      root.langRev++
    }
  }
  // Translator as a var property, NOT a method: text bindings read root.trFn
  // (a property read — always captured), and langRev++ rebuilds it with a new
  // identity, re-running every binding that holds it. A tx() method would
  // capture nothing (method access isn't tracked; the langRev read inside is
  // dead-code-eliminated), which is why texts stayed English.
  readonly property var trFn: root.langRev >= 0 ? function(key) { return I18n.tr.apply(null, arguments) } : null

  property var anchorItem: null
  property var hostWidget: null

  property var games: []
  property var favorites: ({})
  property int liveCount: 0
  property bool favLive: false
  property int barGameCount: 0    // games on the shared today board; drives bar dimming
  readonly property int pollInterval: root.favLive ? 25000 : (root.liveCount > 0 ? 60000 : 120000)
  property bool leagueRestored: false
  property var scoreFlash: ({})
  property int flashTick: 0
  readonly property bool detailFlashing: root.flashTick >= 0 && root.selectedGame !== null && (root.scoreFlash[root.selectedGame.id] || 0) > 0 && new Date().getTime() - root.scoreFlash[root.selectedGame.id] < 700
  onDetailFlashingChanged: if (root.detailFlashing) detailFlashExpire.restart()
  property int cursorIndex: -1
  property string confFetchLeague: ""
  property var confGroups: null
  property string confGroupsLeague: ""
  property string lastFetchedDay: ""    // day of the payload parseGames is about to receive
  readonly property int liveBoardMaxAge: 150000  // shared board older than this is stale
  // Leagues the bar covers: every league with a favorited team, plus whatever
  // this panel browses (keeps the browsed league's "N live"/dimming semantics).
  function barLeagues() {
    var out = []
    // the browsed league only counts when it is a real league — the "favs"
    // aggregate view is not fetchable and must not pollute the shared board
    if (Model.leagueFor(root.currentLeagueId).id === root.currentLeagueId) out.push(root.currentLeagueId)
    var favs = Model.favLeagues(Model.favorites)
    for (var i = 0; i < favs.length; i++) if (out.indexOf(favs[i]) < 0) out.push(favs[i])
    return out
  }
  // Shared board slots the bar reads, one per covered league. The day is
  // computed per call, NOT from the todayYmd property — panels that stay
  // closed for days (shell up across midnight) would otherwise read a days-old
  // slot and never see live favorites (issue: bar only lit on the monitor
  // whose panel had been opened). A missing/stale slot falls back to this
  // instance's list only for the league it browses; other covered leagues
  // contribute nothing until refreshBarFeed lands their slot.
  function barSlots() {
    var today = Model.ymd(new Date())
    var leagues = root.barLeagues()
    var out = []
    for (var i = 0; i < leagues.length; i++) {
      var lg = leagues[i]
      var e = Model.liveBoardEntry(lg, today, root.liveBoardMaxAge)
      out.push({ lg: lg, games: e ? e.games : (lg === root.currentLeagueId ? root.games : []) })
    }
    return out
  }
  readonly property var favLiveGames: {
    var out = []
    var slots = root.barSlots()
    for (var i = 0; i < slots.length; i++) {
      var games = slots[i].games
      for (var j = 0; j < games.length; j++) {
        var g = games[j]
        if (g.state === "in" && (Model.isFav(root.favorites, g.away.abbr, slots[i].lg) || Model.isFav(root.favorites, g.home.abbr, slots[i].lg)))
          out.push({ g: g, lg: slots[i].lg })
      }
    }
    return out
  }
  property int favLiveRotate: 0
  readonly property var favLiveGame: root.favLiveGames.length ? root.favLiveGames[root.favLiveRotate % root.favLiveGames.length] : null
  Timer {
    running: root.favLiveGames.length > 1
    interval: 4000
    repeat: true
    onTriggered: root.favLiveRotate = (root.favLiveRotate + 1) % root.favLiveGames.length
  }
  readonly property string favLiveScore: {
    var e = root.favLiveGame
    var g = e ? e.g : null
    if (!g || !g.away || !g.home) return ""
    return Model.isFav(root.favorites, g.away.abbr, e.lg)
      ? g.away.abbr + " " + (g.away.score || "0") + "-" + (g.home.score || "0")
      : g.home.abbr + " " + (g.home.score || "0") + "-" + (g.away.score || "0")
  }
  readonly property string favLiveLabel: {
    var e = root.favLiveGame
    return e ? Model.leagueFor(e.lg).label + " \u00b7 " + e.g.away.abbr + " " + (e.g.away.score || "0") + " \u2014 " + e.g.home.abbr + " " + (e.g.home.score || "0") + " \u00b7 " + e.g.detail : ""
  }
  readonly property bool notifyEnabled: {
    var w = root.hostWidget
    if (!w || typeof w.setting !== "function") return true
    var v = w.setting("notifications", true)
    return v !== false && v !== "false"
  }
  readonly property bool notifyFinalsOnly: {
    var w = root.hostWidget
    if (!w || typeof w.setting !== "function") return false
    var v = w.setting("notifyFinalsOnly", false)
    return v === true || v === "true"
  }
  readonly property int kickoffWindow: {
    var w = root.hostWidget
    if (!w || typeof w.setting !== "function") return 10
    var v = parseInt(w.setting("kickoffWindow", 10))
    return isNaN(v) ? 10 : v
  }
  readonly property bool showOdds: {
    var w = root.hostWidget
    if (!w || typeof w.setting !== "function") return true
    var v = w.setting("showOdds", true)
    return v !== false && v !== "false"
  }
  function setSetting(key, val) {
    var w = root.hostWidget
    if (!w) return
    var entry = { id: w.moduleName }
    for (var k in w.settings) if (k !== "id") entry[k] = w.settings[k]
    entry[key] = val
    w.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(w.moduleName, entry)
  }
  function currentLanguage() {
    var w = root.hostWidget
    var v = (w && typeof w.setting === "function") ? w.setting("language", "auto") : "auto"
    return String(v || "auto")
  }
  function currentBarMode() {
    var w = root.hostWidget
    var v = (w && typeof w.setting === "function") ? w.setting("barMode", "favScore") : "favScore"
    return String(v || "favScore")
  }
  property string lastError: ""

  // Favorites persist in dconf (see saveFavorites); the pre-dconf state files
  // are no longer read or written. Notification claims + kickoff marks live in
  // Model (shared across panels) — see requestNotification.
  property var sessionCache: ({})       // per-league scoreboard paint cache, session-only
  readonly property string apiUrl: Model.apiUrl
  readonly property color urgentColor: root.bar ? root.bar.urgent : Color.urgent
  // Panel-surface text color. The inherited barForeground tracks the bar's
  // wallpaper-tuned color when the bar runs transparent (dark text over dark
  // wallpaper), which vanishes on this panel's solid popup surface — the
  // shell's own panels read bar.foreground (theme text) for that reason.
  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground

  property string currentLeagueId: Model.defaultLeagueId
  // Aggregate view id: shows today's favorited-team games across every league
  // with favorites (painted from the shared board — no extra fetches). It is
  // never persisted as lastLeague and never enters barLeagues().
  readonly property bool favView: root.currentLeagueId === "favs"
  readonly property bool hideFinished: {
    var w = root.hostWidget
    if (!w || typeof w.setting !== "function") return false
    var v = w.setting("hideFinished", false)
    return v === true || v === "true"
  }
  property bool showSettings: false
  property var prevScores: ({})
  readonly property var shownGames: root.hideFinished
    ? root.games.filter(function(g) { return g.state !== "post" })
    : root.games
  // Team search: matches abbr or name on either side, case-insensitive.
  property string filterText: ""
  onFilterTextChanged: root.cursorIndex = -1
  readonly property var filteredGames: root.filterText === ""
    ? root.shownGames
    : root.shownGames.filter(function(g) {
        var q = root.filterText.toLowerCase()
        return ((g.away.abbr || "") + " " + (g.away.name || "") + " " + (g.home.abbr || "") + " " + (g.home.name || "")).toLowerCase().indexOf(q) >= 0
      })
  // ListView-backed games list: delegate data lives in this model so reorders
  // animate as real row moves (move/displaced transitions) instead of a reset
  ListModel { id: gamesModel; dynamicRoles: true }
  onFilteredGamesChanged: reconcileGames()
  readonly property bool listVisible: root.selectedGame === null && !root.showSettings
  property var weekStart: null
  property var weekDateStrs: []
  property var weekDates: []
  property var hasGames: [false,false,false,false,false,false,false]
  property int selectedDay: 0
  // refreshed on open: `new Date()` inside a binding never re-evaluates, so a
  // panel running past midnight would otherwise pin "today" to its start date
  property string todayYmd: Model.ymd(new Date())
  readonly property int todayIndex: root.weekDateStrs.indexOf(root.todayYmd)
  readonly property var dayLabels: root.langRev >= 0 ? Model.dayLabels.map(function(d) { return I18n.tr(d) }) : []
  property var monthLabels: Model.monthLabels
  // week fetch: one week-range scoreboard request, dots computed locally
  property string weekFetchLeague: ""

  property var selectedGame: null
  property var detailStats: null
  property var detailTeams: null
  property var detailPlayers: null
  property var detailPlayerGroups: null
  property var detailLeaders: []
  property var detailPlays: []
  property var detailDrives: []
  property var detailStandings: null
  property var detailInjuries: []
  property var detailNews: []
  property var detailVideos: []
  property bool detailLoading: false
  property bool detailRefreshing: false   // live background refetch in flight; old stats stay painted
  property bool detailStale: false
  property string detailError: ""
  property int detailTab: 0

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function isFav(abbr, lg) { return Model.isFav(root.favorites, abbr, lg || root.currentLeagueId) }
  function applyFavorites() {
    if (root.favView) root.refreshFavs()
    else root.games = root.sorted(root.games)
    root.recount(); root.refreshBarFeed()
  }
  function saveFavorites() { dconfWrite(Model.DCONF_FAVORITES, JSON.stringify(root.favorites)) }
  // Per-panel sync: shared Model.favorites notifies these watchers on every
  // change from any panel. The source panel is skipped (it applied its own
  // update). Deregistration matters — hot reload destroys instances.
  property var favWatcher: null
  // Restore: read favorites from dconf once at startup. Empty on first run —
  // no legacy file migration, the pre-dconf state files are dead.
  property bool favoritesRestored: false
  function restoreFavorites() {
    if (root.favoritesRestored) return
    root.favoritesRestored = true
    dconfRead(Model.DCONF_FAVORITES, function(raw) {
      root.favorites = Model.setFavorites(Model.parseFavorites(Model.dconfUnescape(raw)), root.favWatcher)
      root.applyFavorites()
    })
  }
  function toggleFav(abbr, lg) {
    var L = lg || root.currentLeagueId
    root.favorites = Model.setFavorites(Model.toggleFavMap(Model.favorites, L, abbr), root.favWatcher)
    root.saveFavorites()
    // no immediate re-sort: rows jumping under the finger reads as a glitch —
    // the reorder lands with the next fresh fetch instead (but the favs view
    // drops unstarred rows right away, since they no longer belong there)
    root.recount()
    if (root.favView) root.refreshFavs()
    root.refresh()
  }
  function isLeagueFav(id) { return Model.isLeagueFav(root.favorites, id) }
  function toggleLeagueFav(id) {
    root.favorites = Model.setFavorites(Model.toggleLeagueFav(Model.favorites, id), root.favWatcher)
    root.saveFavorites()
  }
  function rank(g) { return Model.rank(g, root.favorites, root.currentLeagueId) }
  function sorted(list) { return Model.sorted(list, root.favorites, root.currentLeagueId) }
  function recount() {
    var slots = root.barSlots()
    var live = 0, fav = false, count = 0
    for (var i = 0; i < slots.length; i++) {
      var r = Model.recount(slots[i].games, root.favorites, slots[i].lg)
      live += r.liveCount; fav = fav || r.favLive; count += slots[i].games.length
    }
    root.liveCount = live; root.favLive = fav
    root.barGameCount = count
  }
  function leads(game, side) { return Model.leads(game, side) }
  function titleize(s) { return Model.titleize(s) }
  function sundayOf(d) { return Model.sundayOf(d) }
  function ymd(d) { return Model.ymd(d) }
  readonly property string weekLabelText: root.langRev >= 0 ? Model.weekLabel(root.weekDates) : ""
  function leagueLabel(id) { return Model.leagueFor(id).label }
  function setLeague(id) {
    if (id == root.currentLeagueId) return
    root.currentLeagueId = id
    root.filterText = ""
    root.selectedGame = null; root.detailStats = null; root.detailTeams = null; root.detailPlayers = null; root.detailPlayerGroups = null
    root.games = []; root.lastError = ""
    root.prevScores = ({})
    Model.resetKickoffMarks()
    root.scoreFlash = ({})
    root.cursorIndex = -1
    root.confGroups = null
    root.confGroupsLeague = ""
    root.initWeek()
    if (id !== "favs") root.setSetting("lastLeague", id)
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
  function selectDay(idx) { if (idx < 0 || idx > 6) return; root.selectedDay = idx; root.cursorIndex = -1; root.refreshSelected() }
  function goToday() { if (root.todayIndex >= 0) root.selectDay(root.todayIndex); else root.initWeek() }
  function checkWeekGames() {
    if (root.favView) return
    if (!root.weekDateStrs || root.weekDateStrs.length !== 7) return
    var args = Model.weekArgs(root.weekDateStrs, root.currentLeagueId)
    if (!args) return
    root.weekFetchLeague = root.currentLeagueId
    weekProc.running = false; weekProc.command = args; weekProc.running = true
  }
  function refreshSelected() {
    // favs view paints today's favorites from the shared board and tops up
    // every covered league — the day selector does not apply to it
    if (root.favView) { root.refreshFavs(); root.refreshBarFeed(); return }
    var ds = root.weekDateStrs[root.selectedDay] || ""
    if (!ds) return
    root.lastFetchedDay = ds
    // session cache: paint the last payload for this league while the fresh fetch runs
    if (root.games.length === 0 && root.sessionCache[root.currentLeagueId]) root.parseGames(root.sessionCache[root.currentLeagueId], true)
    var args = Model.fetchArgs(ds, root.currentLeagueId)
    if (!args) return
    fetchProc.running = false; fetchProc.command = args; fetchProc.running = true
  }
  // Favorites aggregate: today's favorited-team games from every covered
  // league's board slot. Rows are shallow copies tagged with _lg (their real
  // league) so detail, fav toggles, and labels resolve per-game — the shared
  // board objects are never mutated.
  function sortedFav(list) {
    var arr = list.slice()
    var ord = { "in": 0, "pre": 1, "post": 2 }
    arr.sort(function(a, b) {
      var ao = ord[a.state] !== undefined ? ord[a.state] : 3
      var bo = ord[b.state] !== undefined ? ord[b.state] : 3
      if (ao !== bo) return ao - bo
      return String(a.date) < String(b.date) ? -1 : (String(a.date) > String(b.date) ? 1 : 0)
    })
    return arr
  }
  function refreshFavs() {
    var out = []
    var slots = root.barSlots()
    for (var i = 0; i < slots.length; i++) {
      var games = slots[i].games
      for (var j = 0; j < games.length; j++) {
        var g = games[j]
        if (!g.away || !g.home) continue
        if (!(Model.isFav(root.favorites, g.away.abbr, slots[i].lg) || Model.isFav(root.favorites, g.home.abbr, slots[i].lg))) continue
        var c = {}
        for (var k in g) c[k] = g[k]
        c._lg = slots[i].lg
        out.push(c)
      }
    }
    root.games = root.sortedFav(out)
  }
  function showDetail(game) {
    if (!game || !Model.validEventId(game.id)) return
    var lg = game._lg || root.currentLeagueId
    var url = Model.summaryUrl(game.id, lg)
    if (!url) return
    root.selectedGame = game; root.detailStats = null; root.detailTeams = null; root.detailPlayers = null; root.detailPlayerGroups = null
    // detail replaces the list in the same scroll area: drop any list scroll offset
    if (scrollArea.contentItem) scrollArea.contentItem.contentY = 0
    root.detailLeaders = []; root.detailPlays = []; root.detailDrives = []; root.detailStandings = null; root.detailInjuries = []; root.detailNews = []; root.detailVideos = []
    root.detailError = ""; root.detailLoading = true; root.detailTab = 0; root.detailRefreshing = false
    detailProc.running = false; detailProc.command = ["curl", "-fsS", "--max-time", "10", "--max-filesize", Model.MAX_BYTES, url]; detailProc.running = true
    if (Model.leagueFor(lg).sport === "soccer") {
      root.confFetchLeague = lg
      var L = Model.leagueFor(lg)
      standingsProc.running = false
      standingsProc.command = ["curl", "-fsS", "--max-time", "10", "--max-filesize", Model.MAX_BYTES, Model.standingsUrlFor(L.sport, L.league)]
      standingsProc.running = true
    }
  }
  function closeDetail() {
    root.selectedGame = null; root.detailStats = null; root.detailTeams = null; root.detailPlayers = null; root.detailPlayerGroups = null
    if (scrollArea.contentItem) scrollArea.contentItem.contentY = 0
    root.detailLeaders = []; root.detailPlays = []; root.detailDrives = []; root.detailStandings = null; root.detailInjuries = []; root.detailNews = []; root.detailVideos = []
    root.detailError = ""; root.detailLoading = false; root.detailRefreshing = false; root.detailStale = false
  }
  function loadDetail() { root.detailStale = false; root.detailError = ""; if (root.selectedGame) root.showDetail(root.selectedGame) }
  // Background refresh for a live game: refetch the summary without clearing
  // the painted stats, resetting the tab, or jumping the scroll — parseDetail
  // swaps the data in place when the payload lands. Failures keep old data.
  function refreshDetailQuiet() {
    if (!root.selectedGame || !Model.validEventId(root.selectedGame.id)) return
    if (detailProc.running || root.detailLoading || root.detailRefreshing) return
    var url = Model.summaryUrl(root.selectedGame.id, root.selectedGame._lg || root.currentLeagueId)
    if (!url) return
    root.detailRefreshing = true
    detailProc.running = false; detailProc.command = ["curl", "-fsS", "--max-time", "10", "--max-filesize", Model.MAX_BYTES, url]; detailProc.running = true
  }
  function parseDetail(raw) {
    var quiet = root.detailRefreshing
    var txt = String(raw||"").trim()
    if (!txt) {
      if (quiet) { root.detailRefreshing = false; return }
      root.detailError = root.trFn("No details"); root.detailLoading = false; return
    }
    try {
      var r = Model.parseDetail(raw, root.selectedGame, (root.selectedGame && root.selectedGame._lg) || root.currentLeagueId)
      root.detailTeams = r.detailTeams; root.detailStats = r.detailStats; root.detailPlayers = r.detailPlayers; root.detailPlayerGroups = r.detailPlayerGroups
      root.detailLeaders = r.detailLeaders || []; root.detailPlays = r.detailPlays || []; root.detailDrives = r.detailDrives || []; root.detailStandings = (root.confGroupsLeague === ((root.selectedGame && root.selectedGame._lg) || root.currentLeagueId) && root.confGroups) ? { groups: root.confGroups } : (r.detailStandings || null); root.detailInjuries = r.detailInjuries || []
      root.detailNews = r.detailNews || []; root.detailVideos = r.detailVideos || []
      root.detailLoading = false; root.detailRefreshing = false
    } catch (e) {
      if (quiet) { root.detailRefreshing = false; return }
      if (!root.detailStale) { root.detailError = root.trFn("Stale data"); root.detailStale = true } else { root.detailError = root.trFn("Failed to load: ") + root.trFn(String(e.message || e)) }
      root.detailLoading = false
    }
  }
  function refresh() {
    root.refreshSelected()
    root.refreshBarFeed()
  }
  // Keeps the shared board fresh for every bar-covered league even when no
  // panel is browsing that league; the needsFetch stagger costs ~one request
  // per covered league per poll interval across the whole process.
  property var barFeedQueue: []
  property string barFeedLeague: ""
  function refreshBarFeed() {
    var today = Model.ymd(new Date())
    var leagues = root.barLeagues()
    var queue = []
    for (var i = 0; i < leagues.length; i++) {
      if (!Model.liveBoardNeedsFetch(leagues[i], today, root.pollInterval - 2000)) continue
      var args = Model.fetchArgs(today, leagues[i])
      if (args) queue.push({ lg: leagues[i], args: args })
    }
    root.barFeedQueue = queue
    root.pumpBarFeed()
  }
  function pumpBarFeed() {
    if (barFeedProc.running || root.barFeedQueue.length === 0) return
    var next = root.barFeedQueue.shift()
    root.barFeedLeague = next.lg
    barFeedProc.command = next.args
    barFeedProc.running = true
  }
  Process {
    id: barFeedProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = root.gated(text)
        if (t !== null && t.trim()) {
          try {
            var r = Model.parseGames(t)
            Model.noteScoreboard(root.barFeedLeague, Model.ymd(new Date()), r.games)
            root.recount()
            if (root.favView) root.refreshFavs()
          } catch (e) {}
        }
        root.pumpBarFeed()
      }
    }
  }
  // Collector-side cap (security baseline #2934): curl's --max-filesize enforces the
  // producer cap; this gates every parse path so oversized output never reaches
  // JSON.parse even if the producer cap were bypassed. Returns null when over cap.
  function gated(raw) {
    var s = String(raw || "")
    if (s.length > Model.MAX_TEXT) return null
    return s
  }
  // Remote hrefs open only if https — no file:/custom-handler schemes on click
  function safeHref(u) { u = String(u || ""); return /^https:\/\//.test(u) ? u : "" }
  // Diff shownGames into gamesModel in place: setProperty refreshes scores
  // without recreating delegates, move() slides rows to their new position
  function reconcileGames() {
    var want = root.filteredGames
    var ids = {}
    for (var i = 0; i < want.length; i++) ids[want[i].id] = true
    for (var i = gamesModel.count - 1; i >= 0; i--) {
      var cur = gamesModel.get(i).game
      if (!cur || !ids[cur.id]) gamesModel.remove(i)
    }
    for (var i = 0; i < want.length; i++) {
      var g = want[i]
      var pos = -1
      for (var j = i; j < gamesModel.count; j++) {
        var m = gamesModel.get(j).game
        if (m && m.id === g.id) { pos = j; break }
      }
      if (pos === -1) {
        gamesModel.insert(i, { game: g })
      } else {
        if (pos !== i) gamesModel.move(pos, i, 1)
        gamesModel.setProperty(i, "game", g)
      }
    }
  }
  function parseGames(raw, silent) {
    var txt = String(raw||"").trim()
    // empty response = failed fetch (curl -f swallows HTTP errors): keep last good list
    if (!txt) { root.recount(); return }
    try {
      var r = Model.parseGames(txt)
      root.games = root.sorted(r.games)
      // share the fresh scoreboard process-wide (silent parses paint stale
      // session data and must not pollute the shared board)
      if (!silent) Model.noteScoreboard(root.currentLeagueId, root.lastFetchedDay, r.games)
      root.lastError = r.error
      // keep the open detail's score/status current; the header reads selectedGame
      if (root.selectedGame !== null) {
        for (var i = 0; i < r.games.length; i++) {
          if (r.games[i].id === root.selectedGame.id) {
            root.selectedGame.away.score = r.games[i].away.score
            root.selectedGame.home.score = r.games[i].home.score
            root.selectedGame.state = r.games[i].state
            root.selectedGame.detail = r.games[i].detail
            break
          }
        }
      }
      root.recount()
      if (!silent) root.checkScoreNotifications(r.games)
    } catch (e) { root.lastError = "Parse error" }
  }
  // dconf is persistence only: write-through on change, one read at startup.
  // Cross-panel sync is in-process — all panels share one engine and land
  // every change through Model.setFavorites — so no watch process exists.
  property var dconfQueue: []
  property var curDconf: null
  function dconfRead(key, cb) { root.dconfQueue.push({ key: key, cb: cb, write: null }); root.pumpDconf() }
  function dconfWrite(key, str, cb) { root.dconfQueue.push({ key: key, cb: cb, write: str }); root.pumpDconf() }
  function pumpDconf() {
    if (dconfProc.running || !root.dconfQueue.length) return
    var job = root.dconfQueue.shift()
    root.curDconf = job
    dconfProc.running = false
    dconfProc.command = job.write !== null
      ? ["/usr/bin/dconf", "write", job.key, Model.dconfEscape(job.write)]
      : ["/usr/bin/dconf", "read", job.key]
    dconfProc.running = true
  }
  Process {
    id: dconfProc
    command: []
    stdout: StdioCollector { id: dconfOut; waitForEnd: true }
    onExited: function(exitCode) {
      var job = root.curDconf
      root.curDconf = null
      if (!job) return
      if (job.write !== null) {
        if (exitCode !== 0) console.log("OmaScore: dconf write failed; favorites session-only this run")
        if (job.cb) job.cb(exitCode === 0)
      } else {
        job.cb(exitCode === 0 ? String(dconfOut.text) : "")
      }
    }
  }
  // Cross-instance notification dedup. Every bar hosts its own Panel (one per
  // screen), each polling ESPN independently, so a score transition fires once
  // per instance. All panels share ONE engine, so claims live in Model
  // (Model.claimNotification) — per-panel maps here would let every instance
  // fire its own copy, which is exactly the stacked-notification bug.
  function requestNotification(key, cmd, kickoffId) {
    if (!Model.claimNotification(key, new Date().getTime())) return
    if (kickoffId) Model.kickoffNotified[kickoffId] = true
    if (!notifProc.running) { notifProc.command = cmd; notifProc.running = true }
  }
  function checkScoreNotifications(games) {
    var next = {}
    for (var i = 0; i < games.length; i++) {
      var g = games[i]
      if (!g.away || !g.home) continue
      var cur = (g.away.score || "") + "|" + (g.home.score || "") + "|" + g.state
      next[g.id] = cur
      var old = root.prevScores[g.id]
      if (old !== undefined && old !== cur) {
        var oldParts = old.split("|")
        if (oldParts[0] !== String(g.away.score || "") || oldParts[1] !== String(g.home.score || "")) {
          root.scoreFlash[g.id] = new Date().getTime()
          root.flashTick++
        }
      }
      if (!root.notifyEnabled) continue
      if (!(root.isFav(g.away.abbr) || root.isFav(g.home.abbr))) continue
      var koMin = root.kickoffWindow > 0 ? Model.kickoffMinutes(g.date, g.state, new Date(), root.kickoffWindow) : -1
      if (koMin > 0 && !Model.kickoffNotified[g.id] && !notifProc.running) {
        root.requestNotification("ko|" + root.currentLeagueId + "|" + g.id + "|" + koMin,
          ["notify-send", "-a", "OmaScore",
            root.trFn("%1 @ %2 kicks off in %3 min", g.away.abbr, g.home.abbr, koMin),
            root.leagueLabel(root.currentLeagueId) + " \u00b7 " + root.gameStatus(g)], g.id)
      }
      if (old === undefined || old === cur) continue
      var ev = Model.scoreEvent(old, g)
      if (!ev) continue
      if (root.notifyFinalsOnly && ev !== "final") continue
      if (notifProc.running) continue
      root.requestNotification(root.currentLeagueId + "|" + g.id + "|" + ev + "|" + (g.away.score || "") + "|" + (g.home.score || ""),
        ev === "final"
        ? ["notify-send", "-a", "OmaScore",
            "Final \u2014 " + g.away.abbr + " " + (g.away.score || "0") + " \u00b7 " + g.home.abbr + " " + (g.home.score || "0"),
            root.leagueLabel(root.currentLeagueId) + " \u00b7 " + (g.detail || "")]
        : ["notify-send", "-a", "OmaScore",
            g.away.abbr + " " + (g.away.score || "0") + " \u2014 " + g.home.abbr + " " + (g.home.score || "0"),
            root.leagueLabel(root.currentLeagueId) + " \u00b7 " + g.detail])
    }
    root.prevScores = next
  }
  function statusColor(state) { return Model.statusColor(state, root.urgentColor, root.fg) }
  // ESPN colors are 6-hex without "#" and often near-black; blend toward the theme
  // foreground until the hue passes 4.5:1 contrast on the actual panel surface, so
  // any team color stays legible (dark navy lifts, bright colors pass unchanged)
  function teamColor(hex) {
    var h = (hex || "").replace("#", "")
    if (!/^[0-9a-fA-F]{6}$/.test(h)) return Color.accent
    var c = Qt.rgba(parseInt(h.substring(0, 2), 16) / 255, parseInt(h.substring(2, 4), 16) / 255, parseInt(h.substring(4, 6), 16) / 255, 1)
    var bg = Color.popups.background
    for (var i = 0; i < 4 && contrastRatio(c, bg) < 4.5; i++)
      c = Qt.rgba(c.r + (root.fg.r - c.r) * 0.35, c.g + (root.fg.g - c.g) * 0.35, c.b + (root.fg.b - c.b) * 0.35, 1)
    return c
  }
  function luminance(c) {
    function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
  }
  function contrastRatio(a, b) {
    var la = luminance(a), lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
  }
  function statNum(s) { var t = (s || "").trim(); return /^-?\d+(\.\d+)?$/.test(t) ? parseFloat(t) : 0 }
  function moveCursor(dy) {
    if (!root.listVisible) return
    root.cursorIndex = Math.max(-1, Math.min(root.filteredGames.length - 1, root.cursorIndex + dy))
  }
  function activateCursor() {
    if (root.listVisible && root.cursorIndex >= 0 && root.cursorIndex < root.filteredGames.length)
      root.showDetail(root.filteredGames[root.cursorIndex])
  }
  function gameStatus(g) {
    if (!g) return ""
    var base = (g.state === "pre" && g.date) ? Qt.formatDateTime(new Date(g.date), "M/d - h:mm AP") : (g.detail || "")
    return base + (root.showOdds && g.state === "pre" && g.odds ? "  \u00b7  " + g.odds : "")
  }
  function periodChip(n) {
    var lbl = Model.periodLabelFor((root.selectedGame && root.selectedGame._lg) || root.currentLeagueId)
    return (lbl === "Q" && n > 4) ? (n === 5 ? "OT" : "OT" + (n - 4)) : lbl + n
  }
  function playChipText(p) {
    if (!p) return ""
    var t = (p.period && p.period.number) ? root.periodChip(p.period.number) : ((p.period && p.period.displayValue) ? p.period.displayValue : "")
    if (p.clock && p.clock.displayValue) t += " " + p.clock.displayValue
    return t
  }
  function standingsStat(entry, names) {
    var s = (entry && entry.stats) ? entry.stats : []
    for (var i = 0; i < s.length; i++) if (names.indexOf(s[i].name) >= 0 || names.indexOf(s[i].abbreviation) >= 0) return s[i].displayValue != null ? s[i].displayValue : (s[i].value != null ? String(s[i].value) : "")
    return ""
  }

  Process {
    id: fetchProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = root.gated(text)
        if (t === null) return
        root.parseGames(t)
        // session paint cache (memory-only; nothing hits disk)
        if (t.trim()) root.sessionCache[root.currentLeagueId] = t
      }
    }
  }

  Process {
    id: weekProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // abandon a scan for a league we've already left
        if (root.weekFetchLeague !== root.currentLeagueId) return
        var t = root.gated(text)
        if (t === null) return
        root.hasGames = Model.parseWeekRange(t, root.weekDateStrs)
        var nxt = Model.nextSelectedDay(root.hasGames, root.selectedDay)
        if (nxt >= 0) { root.selectedDay = nxt; root.refreshSelected() }
      }
    }
  }

  Process {
    id: detailProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = root.gated(text)
        if (t === null) {
          if (root.detailRefreshing) { root.detailRefreshing = false; return }
          root.detailError = root.trFn("Response too large"); root.detailLoading = false; return
        }
        root.parseDetail(t)
      }
    }
  }

  Process {
    id: notifProc
  }

  Process {
    id: standingsProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = root.gated(text)
        if (t === null) return
        try {
          if (root.selectedGame && root.confFetchLeague === root.currentLeagueId) {
            var r = Model.parseStandingsGroups(t)
            if (r.groups.length) {
              root.confGroups = r.groups
              root.confGroupsLeague = root.currentLeagueId
              root.detailStandings = r
            }
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  // Live detail follows the game without user action: same adaptive cadence
  // as the list poll, background-swapped so the tab and scroll never jump.
  Timer {
    id: detailPollTimer
    interval: root.pollInterval
    repeat: true
    running: root.selectedGame !== null && root.selectedGame.state === "in" && !root.showSettings
    onTriggered: root.refreshDetailQuiet()
  }

  Timer {
    id: detailFlashExpire
    interval: 700
    onTriggered: root.flashTick++
  }
  onPollIntervalChanged: { pollTimer.restart(); detailPollTimer.restart() }

  function restoreLastLeague() {
    if (root.leagueRestored) return
    var w = root.hostWidget
    if (!w || typeof w.setting !== "function") return
    var saved = w.setting("lastLeague", "")
    if (!saved) return
    root.leagueRestored = true
    if (saved !== root.currentLeagueId && Model.leagueFor(saved).id === saved) root.setLeague(saved)
  }
  function initForCurrent() { root.restoreFavorites(); root.restoreLastLeague(); root.initWeek() }
  Component.onCompleted: {
    root.favWatcher = function(f) { root.favorites = f; root.applyFavorites() }
    Model.favWatchers.push(root.favWatcher)
    root.applyLang()
    Qt.callLater(root.initForCurrent)
  }
  Component.onDestruction: {
    var i = Model.favWatchers.indexOf(root.favWatcher)
    if (i >= 0) Model.favWatchers.splice(i, 1)
  }

  onOpenedChanged: if (root.opened) {
    root.todayYmd = Model.ymd(new Date())
    root.restoreLastLeague()
    if (!root.weekStart) root.initWeek(); else root.refreshSelected()
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
        // let the team filter receive keys while editing (see filterField)
        blocked: filterField.activeFocus
        onCloseRequested: { if (root.showSettings) root.showSettings = false; else if (root.selectedGame) root.closeDetail(); else if (root.cursorIndex >= 0) root.cursorIndex = -1; else root.close() }
        onTabRequested: function(direction) { if (root.selectedGame) root.closeDetail(); else root.switchPanel(direction) }
        onMoveRequested: function(dx, dy) { root.moveCursor(dy) }
        onActivateRequested: root.activateCursor()

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: root.selectedGame ? ScrollBar.AlwaysOff : (panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff)

        Column {
          id: panelColumn
          width: scrollArea.availableWidth - Style.space(28)
          // horizontalCenter anchor is inert inside the ScrollView's content
          // item — position explicitly so the 28px inset splits evenly
          x: (scrollArea.availableWidth - width) / 2
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: heroIcon.implicitHeight
            Text {
              textFormat: Text.PlainText
              id: heroIcon
              text: "\uf091"
              color: root.fg
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: "OmaScore"
              color: root.fg
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
            }
            Button {
              id: refreshButton
              anchors.right: settingsButton.left
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              visible: root.listVisible
              iconText: ""
              tooltipText: root.trFn("Refresh")
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.refresh()
            }
            Button {
              id: todayButton
              anchors.right: refreshButton.left
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              visible: root.listVisible
              iconText: ""
              tooltipText: root.trFn("Show Today")
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.goToday()
            }
            Button {
              id: settingsButton
              anchors.right: parent.right
              // cancel the Button's internal padding so the gear glyph's right
              // edge lines up with the score column instead of floating inset
              anchors.rightMargin: -settingsButton.horizontalPadding
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uf013"
              tooltipText: root.trFn("Settings")
              foreground: root.showSettings ? Color.accent : root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: {
                if (root.showSettings) { root.showSettings = false; return }
                root.showSettings = true
                root.closeDetail()
              }
            }
          }

          Flickable {
            width: parent.width
            height: Style.space(32)
            visible: root.listVisible
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
                // "★ Favorites" is an aggregate view, not a league: no
                // league-fav star, week dots, or lastLeague persistence
                model: [{ id: "favs", label: "\u2605 " + root.trFn("Favorites") }].concat(Model.sortedLeagues(Model.leagues, root.favorites))
                delegate: Rectangle {
                  required property var modelData
                  width: row.implicitWidth + Style.space(16)
                  height: Style.space(28)
                  radius: Style.space(14)
                  color: root.currentLeagueId == modelData.id ? Color.accent : "transparent"
                  border.width: root.currentLeagueId == modelData.id ? 0 : 1
                  border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                  Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    z: 1
                    Text {
                      textFormat: Text.PlainText
                      id: leagueText
                      text: modelData.label
                      color: root.currentLeagueId == modelData.id ? Color.background : root.fg
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: root.currentLeagueId == modelData.id
                    }
                    Text {
                      textFormat: Text.PlainText
                      visible: modelData.id !== "favs"
                      text: root.isLeagueFav(modelData.id) ? "\u2605" : "\u2606"
                      color: root.currentLeagueId == modelData.id ? Color.background : (root.isLeagueFav(modelData.id) ? Color.accent : root.fg)
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
            visible: root.weekDates.length === 7 && root.listVisible && !root.favView

            Button {
              Layout.preferredWidth: Style.space(28)
              Layout.preferredHeight: Style.space(28)
              iconText: "\u2039"
              foreground: root.fg
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
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                clip: true

                MouseArea {
                  anchors.fill: parent
                  onClicked: root.selectDay(index)
                }

                Column {
                  anchors.centerIn: parent
                  spacing: 2

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dayLabels[index]
                    color: root.selectedDay === index ? Color.background : root.fg
                    opacity: root.selectedDay === index ? 1 : 0.7
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: root.selectedDay === index
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.weekDates.length === 7 ? root.weekDates[index].getDate() : ""
                    color: root.selectedDay === index ? Color.background : root.fg
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

                // today marker, independent of the selection
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  width: parent.width / 2
                  height: 2
                  radius: 1
                  visible: index === root.todayIndex && root.selectedDay !== index
                  color: root.fg
                  opacity: 0.55
                }
              }
            }

            Button {
              Layout.preferredWidth: Style.space(28)
              Layout.preferredHeight: Style.space(28)
              iconText: "\u203A"
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.shiftWeek(7)
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.weekLabelText
            color: root.fg
            opacity: 0.5
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            visible: root.weekDates.length === 7 && root.listVisible && !root.favView
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.trFn("No favorite games today \u2014 tap \u2606 on a team to follow it")
            visible: root.favView && root.games.length === 0 && root.listVisible
            color: root.fg
            opacity: 0.6
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: {
              if (root.lastError !== "No games scheduled") return root.trFn(root.lastError)
              var day = root.weekDates.length === 7 ? root.dayLabels[root.selectedDay] + " " + root.weekDates[root.selectedDay].getDate() : root.trFn("this day")
              var nxt = Model.nextSelectedDay(root.hasGames, root.selectedDay)
              if (nxt >= 0) return root.trFn("No games %1 \u2014 next up %2", day, root.dayLabels[nxt])
              return root.trFn("No games %1 \u2014 try \u203A for next week", day)
            }
            visible: root.lastError !== "" && root.games.length === 0 && root.listVisible
            color: root.lastError === "No games scheduled" ? root.fg : root.urgentColor
            opacity: root.lastError === "No games scheduled" ? 0.6 : 1
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          // skeleton rows shaped like game rows; visible only while waiting on the first load
          Column {
            id: loadingSkeleton
            width: parent.width
            spacing: Style.space(12)
            visible: root.games.length === 0 && root.lastError === "" && root.listVisible

            Repeater {
              model: 3
              delegate: Column {
                required property int index
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: 2
                  delegate: Row {
                    required property int index
                    width: parent.width
                    spacing: Style.space(8)
                    Rectangle { width: Style.space(20); height: Style.space(20); radius: Style.space(10); color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.09) }
                    Rectangle { width: parent.width - Style.space(64); height: Style.space(9); radius: Style.space(4); anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07) }
                    Rectangle { width: Style.space(28); height: Style.space(9); radius: Style.space(4); anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05) }
                  }
                }
                Rectangle {
                  width: Style.space(64); height: Style.space(7); radius: Style.space(3)
                  anchors.right: parent.right
                  color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                }

                SequentialAnimation on opacity {
                  running: loadingSkeleton.visible
                  loops: Animation.Infinite
                  PauseAnimation { duration: index * 180 }
                  NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
                  NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutQuad }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.trFn("All games finished \u2014 unhide them in Settings")
            visible: root.games.length > 0 && root.shownGames.length === 0 && root.listVisible
            color: root.fg
            opacity: 0.5
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          TextField {
            id: filterField
            width: parent.width
            visible: root.listVisible && root.shownGames.length > 1
            height: visible ? implicitHeight : 0
            placeholderText: root.trFn("Filter teams\u2026")
            text: root.filterText
            onTextChanged: root.filterText = text
            onAccepted: filterField.focus = false
            foreground: root.fg
            accent: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.trFn("No matches for \"%1\"", root.filterText)
            visible: root.listVisible && root.shownGames.length > 0 && root.filteredGames.length === 0
            color: root.fg
            opacity: 0.5
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          ListView {
            id: gamesHost
            width: parent.width
            height: contentHeight
            interactive: false
            clip: true
            spacing: Style.space(14)
            visible: root.listVisible
            model: gamesModel

            // real row movement: a reordered game slides to its spot while
            // the rows it displaces slide out of the way
            move: Transition { NumberAnimation { property: "y"; duration: 280; easing.type: Easing.OutCubic } }
            displaced: Transition { NumberAnimation { property: "y"; duration: 280; easing.type: Easing.OutCubic } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }

            delegate: Column {
              required property var game
              required property int index
              readonly property var modelData: game
              readonly property bool isFinal: modelData && modelData.state === "post"
              readonly property bool awayLeads: modelData ? root.leads(modelData, "away") : false
              readonly property bool homeLeads: modelData ? root.leads(modelData, "home") : false
              visible: root.listVisible
              width: parent.width
              spacing: Style.space(4)

              // anchor host: positioner Columns forbid anchors on direct children,
              // so flashRect anchors to this zero-height flow item instead
              Item {
                width: parent.width
                implicitHeight: 0
                Rectangle {
                  id: flashRect
                  anchors.fill: parent
                  anchors.margins: -Style.space(4)
                  z: -1
                  readonly property string gid: modelData ? modelData.id : ""
                  readonly property bool flashing: root.flashTick >= 0 && (root.scoreFlash[gid] || 0) > 0 && new Date().getTime() - root.scoreFlash[gid] < 700
                  onFlashingChanged: if (flashing) flashExpire.restart()
                  visible: index === root.cursorIndex || flashing || color.a > 0 || (modelData && modelData.state === "in")
                  color: index === root.cursorIndex
                    ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                    : (flashing ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.28) : "transparent")
                  radius: Style.space(6)
                  Behavior on color { ColorAnimation { duration: 350 } }
                  Timer {
                    id: flashExpire
                    interval: 700
                    onTriggered: root.flashTick++
                  }
                  // live-only pulse strip: sweep the list for "on now" without reading status text
                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 1.5
                    visible: modelData && modelData.state === "in"
                    color: root.urgentColor
                    SequentialAnimation on opacity {
                      running: parent.visible
                      loops: Animation.Infinite
                      NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutQuad }
                      NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
                    }
                  }
                }
              }

              TapHandler {
                onTapped: root.showDetail(modelData)
              }

              RowLayout {
                width: parent.width
                spacing: Style.spacing.controlGap
                visible: modelData && modelData.away
                Rectangle {
                  visible: modelData && (modelData.away.logo || "") !== ""
                  opacity: isFinal && homeLeads ? 0.45 : 1
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
                    source: Model.safeMedia(modelData && modelData.away ? modelData.away.logo : "")
                  }
                }
                Button {
                  iconText: modelData && root.isFav(modelData.away.abbr, modelData._lg) ? "\u2605" : "\u2606"
                  foreground: modelData && root.isFav(modelData.away.abbr, modelData._lg) ? Color.accent : root.fg
                  accent: Color.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: if (modelData) root.toggleFav(modelData.away.abbr, modelData._lg)
                }
                Text {
                  textFormat: Text.PlainText
                  Layout.fillWidth: true
                  text: modelData ? modelData.away.abbr + "   " + modelData.away.name : ""
                  color: root.fg
                  opacity: isFinal && homeLeads ? 0.45 : 1
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: modelData && root.leads(modelData, "away")
                  elide: Text.ElideRight
                  HoverHandler { id: hoverGameAway }
                  PanelToolTip { visible: hoverGameAway.hovered && parent.truncated; text: parent.text }
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData && modelData.away ? modelData.away.score || "-" : "-"
                  color: modelData && root.leads(modelData, "away") ? Color.accent : root.fg
                  opacity: isFinal && homeLeads ? 0.45 : 1
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
                  opacity: isFinal && awayLeads ? 0.45 : 1
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
                    source: Model.safeMedia(modelData && modelData.home ? modelData.home.logo : "")
                  }
                }
                Button {
                  iconText: modelData && root.isFav(modelData.home.abbr, modelData._lg) ? "\u2605" : "\u2606"
                  foreground: modelData && root.isFav(modelData.home.abbr, modelData._lg) ? Color.accent : root.fg
                  accent: Color.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: if (modelData) root.toggleFav(modelData.home.abbr, modelData._lg)
                }
                Text {
                  textFormat: Text.PlainText
                  Layout.fillWidth: true
                  text: modelData ? modelData.home.abbr + "   " + modelData.home.name : ""
                  color: root.fg
                  opacity: isFinal && awayLeads ? 0.45 : 1
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: modelData && root.leads(modelData, "home")
                  elide: Text.ElideRight
                  HoverHandler { id: hoverGameHome }
                  PanelToolTip { visible: hoverGameHome.hovered && parent.truncated; text: parent.text }
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData && modelData.home ? modelData.home.score || "-" : "-"
                  color: modelData && root.leads(modelData, "home") ? Color.accent : root.fg
                  opacity: isFinal && awayLeads ? 0.45 : 1
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: (root.favView && modelData && modelData._lg ? root.leagueLabel(modelData._lg) + " \u00b7 " : "") + root.gameStatus(modelData)
                color: modelData ? root.statusColor(modelData.state) : root.fg
                opacity: modelData && modelData.state === "in" ? 1.0 : 0.6
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: modelData && modelData.state === "in"
              }

              PanelSeparator { foreground: root.fg }
            }
          }
          Column {
            visible: root.showSettings
            width: parent.width
            spacing: Style.space(12)

            RowLayout {
              width: parent.width
              spacing: Style.space(8)
              Button {
                iconText: "\u2039"
                text: root.trFn("Back")
                foreground: root.fg
                accent: Color.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.showSettings = false
              }
              Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: root.trFn("Settings")
                color: root.fg
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
              }
            }

            Toggle {
              width: parent.width
              label: root.trFn("Score notifications")
              description: root.trFn("Notify when a favorited team's score changes")
              checked: root.notifyEnabled
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.setSetting("notifications", !root.notifyEnabled)
            }

            Toggle {
              width: parent.width
              label: root.trFn("Finals only")
              description: root.trFn("Only notify for final scores")
              checked: root.notifyFinalsOnly
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.setSetting("notifyFinalsOnly", !root.notifyFinalsOnly)
            }

            Dropdown {
              width: parent.width
              label: root.trFn("Kickoff reminders")
              value: String(root.kickoffWindow)
              options: [
                { value: "0", label: root.trFn("Off") },
                { value: "10", label: "10 min" },
                { value: "30", label: "30 min" },
                { value: "60", label: "60 min" }
              ]
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onChanged: function(v) { root.setSetting("kickoffWindow", parseInt(v)) }
            }

            Toggle {
              width: parent.width
              label: root.trFn("Show pre-game odds")
              description: root.trFn("Spread and over/under on upcoming games")
              checked: root.showOdds
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.setSetting("showOdds", !root.showOdds)
            }

            Toggle {
              width: parent.width
              label: root.trFn("Hide finished games")
              description: root.trFn("Hide games that have already ended")
              checked: root.hideFinished
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.setSetting("hideFinished", !root.hideFinished)
            }

            Dropdown {
              width: parent.width
              label: root.trFn("Bar display")
              value: root.currentBarMode()
              options: [
                { value: "favScore", label: "Favorite score" },
                { value: "liveCount", label: "Live count" },
                { value: "icon", label: "Icon only" }
              ]
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onChanged: function(v) { root.setSetting("barMode", v) }
            }

            Dropdown {
              width: parent.width
              label: root.trFn("Language")
              value: root.currentLanguage()
              options: [
                { value: "auto", label: "Auto" },
                { value: "en", label: "English" },
                { value: "es", label: "Español" },
                { value: "pt", label: "Português" },
                { value: "nl", label: "Nederlands" }
              ]
              foreground: root.fg
              accent: Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onChanged: function(v) { root.setSetting("language", v) }
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
                text: root.trFn("Back")
                foreground: root.fg
                accent: Color.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.closeDetail()
              }
              Row {
                Layout.fillWidth: true
                spacing: Style.space(6)
                Text {
                  textFormat: Text.PlainText
                  text: root.selectedGame ? root.selectedGame.away.abbr : ""
                  color: root.selectedGame && (root.selectedGame.away.color || "") !== "" ? root.teamColor(root.selectedGame.away.color) : root.fg
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: "@"
                  color: root.fg
                  opacity: 0.5
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: root.selectedGame ? root.selectedGame.home.abbr : ""
                  color: root.selectedGame && (root.selectedGame.home.color || "") !== "" ? root.teamColor(root.selectedGame.home.color) : root.fg
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
              }
              Text {
                textFormat: Text.PlainText
                text: root.selectedGame ? root.selectedGame.detail : ""
                color: root.statusColor(root.selectedGame ? root.selectedGame.state : "")
                opacity: root.selectedGame && root.selectedGame.state === "in" ? 1 : 0.6
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
                    source: Model.safeMedia(root.detailTeams && root.detailTeams.away ? root.detailTeams.away.logo : "")
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 64
                  }
                }
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: 36; height: 3; radius: 1.5
                  visible: root.detailTeams && root.detailTeams.away && (root.detailTeams.away.color || "") !== ""
                  color: root.detailTeams && root.detailTeams.away ? root.teamColor(root.detailTeams.away.color) : Color.accent
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.abbr : ""
                  color: root.fg
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(6)
                  Text {
                    textFormat: Text.PlainText
                    text: root.selectedGame && root.selectedGame.away ? root.selectedGame.away.score : ""
                    color: root.detailFlashing || root.leads(root.selectedGame, "away") ? Color.accent : root.fg
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Text {
                    textFormat: Text.PlainText
                    visible: root.selectedGame && root.selectedGame.away && root.selectedGame.away.record
                    text: root.selectedGame && root.selectedGame.away ? "(" + root.selectedGame.away.record + ")" : ""
                    color: root.fg
                    opacity: 0.45
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                Text {
                  textFormat: Text.PlainText
                  visible: root.detailTeams && root.detailTeams.away && root.detailTeams.away.name
                  text: root.detailTeams && root.detailTeams.away ? root.detailTeams.away.name : ""
                  color: root.fg
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
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
              }
              Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: Style.space(2)
                Rectangle {
                  width: Style.space(32); height: Style.space(32); radius: Style.space(6); color: "transparent"; clip: true; anchors.horizontalCenter: parent.horizontalCenter
                  Image {
                    anchors.fill: parent
                    source: Model.safeMedia(root.detailTeams && root.detailTeams.home ? root.detailTeams.home.logo : "")
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 64
                  }
                }
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: 36; height: 3; radius: 1.5
                  visible: root.detailTeams && root.detailTeams.home && (root.detailTeams.home.color || "") !== ""
                  color: root.detailTeams && root.detailTeams.home ? root.teamColor(root.detailTeams.home.color) : Color.accent
                }
                Text {
                  textFormat: Text.PlainText
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.abbr : ""
                  color: root.fg
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(6)
                  Text {
                    textFormat: Text.PlainText
                    text: root.selectedGame && root.selectedGame.home ? root.selectedGame.home.score : ""
                    color: root.detailFlashing || root.leads(root.selectedGame, "home") ? Color.accent : root.fg
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Text {
                    textFormat: Text.PlainText
                    visible: root.selectedGame && root.selectedGame.home && root.selectedGame.home.record
                    text: root.selectedGame && root.selectedGame.home ? "(" + root.selectedGame.home.record + ")" : ""
                    color: root.fg
                    opacity: 0.45
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                Text {
                  textFormat: Text.PlainText
                  visible: root.detailTeams && root.detailTeams.home && root.detailTeams.home.name
                  text: root.detailTeams && root.detailTeams.home ? root.detailTeams.home.name : ""
                  color: root.fg
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
              textFormat: Text.PlainText
              visible: root.detailTeams && root.detailTeams.venue
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.detailTeams ? (root.detailTeams.venue + (root.detailTeams.addr ? " – " + root.detailTeams.addr : "") + (root.detailTeams.status ? " · " + root.detailTeams.status : "")) : ""
              color: root.fg
              opacity: 0.5
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Text {
              textFormat: Text.PlainText
              visible: root.detailTeams && root.detailTeams.situation !== ""
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: root.detailTeams ? root.detailTeams.situation : ""
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            PanelSeparator { foreground: root.fg; visible: (root.detailStats && root.detailStats.length > 0) || (root.detailPlayers && root.detailPlayers.length > 0) }

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
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: root.trFn("Overall")
                  color: root.detailTab === 0 ? Color.background : root.fg
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
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: root.trFn("Players")
                  color: root.detailTab === 1 ? Color.background : root.fg
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
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: root.trFn("Plays")
                  color: root.detailTab === 2 ? Color.background : root.fg
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
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: root.trFn("Insights")
                  color: root.detailTab === 3 ? Color.background : root.fg
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: root.detailTab === 3
                }
                MouseArea { anchors.fill: parent; onClicked: root.detailTab = 3 }
              }
            }

            // stats region scrolls under the pinned team header; height fills the
            // panel cap minus whatever the positioner stacked above it (flick.y)
            Flickable {
              id: statsFlick
              width: parent.width
              height: Math.min(statsContent.implicitHeight,
                Math.max(Style.space(160), Math.min(panel.availableCardHeight, Style.space(560)) - panel.verticalContentInset - y))
              clip: true
              contentWidth: width
              contentHeight: statsContent.implicitHeight
              boundsBehavior: Flickable.StopAtBounds
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              Column {
                id: statsContent
                width: statsFlick.width
                spacing: Style.space(14)

                Column {
                  width: parent.width
                  spacing: Style.space(6)
                  visible: root.detailLoading
                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.trFn("Loading stats\u2026")
                    color: root.fg
                    opacity: 0.6
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                }

            Text {
              textFormat: Text.PlainText
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
              text: root.trFn("Retry")
              foreground: root.fg
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
                      Text { textFormat: Text.PlainText; Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignRight; text: root.detailTeams ? root.detailTeams.away.abbr : ""; color: root.detailTeams && (root.detailTeams.away.color || "") !== "" ? root.teamColor(root.detailTeams.away.color) : root.fg; font.bold: true; font.pixelSize: Style.font.caption; opacity: 0.9 }
                      Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(160); horizontalAlignment: Text.AlignHCenter; text: ""; }
                      Text { textFormat: Text.PlainText; Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignLeft; text: root.detailTeams ? root.detailTeams.home.abbr : ""; color: root.detailTeams && (root.detailTeams.home.color || "") !== "" ? root.teamColor(root.detailTeams.home.color) : root.fg; font.bold: true; font.pixelSize: Style.font.caption; opacity: 0.9 }
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08) }
                    Repeater {
                      model: root.detailStats
                      delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property real numA: Math.max(0, root.statNum(modelData.away))
                        readonly property real numH: Math.max(0, root.statNum(modelData.home))
                        readonly property real shareA: numA + numH > 0 ? numA / (numA + numH) : 0
                        readonly property color awayCol: root.detailTeams && (root.detailTeams.away.color || "") !== "" ? root.teamColor(root.detailTeams.away.color) : Color.accent
                        readonly property color homeCol: root.detailTeams && (root.detailTeams.home.color || "") !== "" ? root.teamColor(root.detailTeams.home.color) : Color.accent
                        width: parent.width
                        height: row.implicitHeight + Style.space(4)
                        color: index % 2 === 1 ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04) : "transparent"
                        radius: 2
                        // diverging bars: grow outward from the center divider, length = share of the stat
                        Rectangle {
                          anchors.bottom: parent.bottom
                          anchors.right: parent.horizontalCenter
                          anchors.rightMargin: Style.space(88)
                          visible: shareA > 0
                          width: visible ? Math.max(2, shareA * (parent.width / 2 - Style.space(92))) : 0
                          height: 2
                          radius: 1
                          color: Qt.rgba(awayCol.r, awayCol.g, awayCol.b, 0.8)
                        }
                        Rectangle {
                          anchors.bottom: parent.bottom
                          anchors.left: parent.horizontalCenter
                          anchors.leftMargin: Style.space(88)
                          visible: numH > 0
                          width: visible ? Math.max(2, (1 - shareA) * (parent.width / 2 - Style.space(92))) : 0
                          height: 2
                          radius: 1
                          color: Qt.rgba(homeCol.r, homeCol.g, homeCol.b, 0.8)
                        }
                        RowLayout {
                          id: row
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(4)
                          anchors.rightMargin: Style.space(4)
                          spacing: Style.space(8)
                          Text { textFormat: Text.PlainText; Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignRight; text: modelData.away; color: numA > numH ? awayCol : root.fg; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.family: "Monospace" }
                          Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(160); horizontalAlignment: Text.AlignHCenter; text: root.trFn(modelData.label); color: root.fg; opacity: 0.5; font.pixelSize: Style.font.caption; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                          Text { textFormat: Text.PlainText; Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignLeft; text: modelData.home; color: numH > numA ? homeCol : root.fg; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.family: "Monospace" }
                        }
                      }
                    }
                  }
                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: !root.detailStats || root.detailStats.length === 0
                    text: root.trFn("No stats available")
                    color: root.fg
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
                    textFormat: Text.PlainText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.titleize(groupData.name || groupData.displayName || "")
                    color: root.fg
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
                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
                            radius: 2
                            Text {
                              textFormat: Text.PlainText
                              anchors.centerIn: parent
                              text: root.trFn("Player")
                              font.bold: true
                              font.pixelSize: Style.font.caption
                              color: root.fg
                              opacity: 0.8
                            }
                          }
                          Repeater {
                            model: groupData.away
                            delegate: Text {
                              textFormat: Text.PlainText
                              required property var modelData
                              property var athleteData: modelData
                              width: Style.space(110)
                              height: Style.space(20)
                              verticalAlignment: Text.AlignVCenter
                              text: athleteData.athlete ? (athleteData.athlete.shortName || athleteData.athlete.displayName) : ""
                              color: root.fg
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
                                  textFormat: Text.PlainText
                                  width: Style.space(55)
                                  height: Style.space(20)
                                  verticalAlignment: Text.AlignVCenter
                                  text: modelData
                                  font.bold: true
                                  font.pixelSize: Style.font.caption
                                  color: root.fg
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
                                    textFormat: Text.PlainText
                                    width: Style.space(55)
                                    height: Style.space(20)
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    font.family: "Monospace"
                                    font.pixelSize: Style.font.caption
                                    color: root.fg
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
                      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
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
                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
                            radius: 2
                            Text {
                              textFormat: Text.PlainText
                              anchors.centerIn: parent
                              text: root.trFn("Player")
                              font.bold: true
                              font.pixelSize: Style.font.caption
                              color: root.fg
                              opacity: 0.8
                            }
                          }
                          Repeater {
                            model: groupData.home
                            delegate: Text {
                              textFormat: Text.PlainText
                              required property var modelData
                              property var athleteData: modelData
                              width: Style.space(110)
                              height: Style.space(20)
                              verticalAlignment: Text.AlignVCenter
                              text: athleteData.athlete ? (athleteData.athlete.shortName || athleteData.athlete.displayName) : ""
                              color: root.fg
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
                                  textFormat: Text.PlainText
                                  width: Style.space(55)
                                  height: Style.space(20)
                                  verticalAlignment: Text.AlignVCenter
                                  text: modelData
                                  font.bold: true
                                  font.pixelSize: Style.font.caption
                                  color: root.fg
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
                                    textFormat: Text.PlainText
                                    width: Style.space(55)
                                    height: Style.space(20)
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    font.family: "Monospace"
                                    font.pixelSize: Style.font.caption
                                    color: root.fg
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
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: !root.detailPlayerGroups || root.detailPlayerGroups.length === 0
                  text: root.trFn("No player stats available")
                color: root.fg
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
                  textFormat: Text.PlainText
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: (!root.detailDrives || root.detailDrives.length === 0) && (!root.detailPlays || root.detailPlays.length === 0)
                  text: root.trFn("No plays available")
                  color: root.fg
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
                          textFormat: Text.PlainText
                          text: modelData.team ? (modelData.team.abbreviation || modelData.team.displayName) : ""
                          color: root.fg
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                        Text {
                          textFormat: Text.PlainText
                          Layout.fillWidth: true
                          text: (modelData.description || "") + (modelData.displayResult ? " \u00b7 " + modelData.displayResult : (modelData.result ? " \u00b7 " + modelData.result : ""))
                          color: root.fg
                          opacity: 0.55
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                        }
                        Rectangle {
                          Layout.preferredWidth: resultText.implicitWidth + Style.space(8)
                          height: Style.space(16)
                          radius: 3
                          color: modelData.isScore ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                          visible: modelData.displayResult || modelData.result || modelData.shortDisplayResult
                          Text {
                            textFormat: Text.PlainText
                            id: resultText
                            anchors.centerIn: parent
                            text: modelData.displayResult || modelData.shortDisplayResult || modelData.result || ""
                            color: modelData.isScore ? Color.accent : root.fg
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
                        color: modelData.scoringPlay ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.10) : "transparent"
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
                              Layout.preferredWidth: Math.max(Style.space(40), chipText.implicitWidth + Style.space(8))
                              Layout.alignment: Qt.AlignTop
                              height: Style.space(16)
                              radius: 3
                              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                              visible: root.playChipText(modelData) !== ""
                              Text {
                                textFormat: Text.PlainText
                                id: chipText
                                anchors.centerIn: parent
                                text: root.playChipText(modelData)
                                color: root.fg
                                opacity: 0.7
                                font.pixelSize: Style.font.caption
                                font.family: "Monospace"
                              }
                            }
                            Text {
                              textFormat: Text.PlainText
                              Layout.fillWidth: true
                              text: modelData.text || modelData.description || ""
                              color: modelData.scoringPlay ? Color.accent : root.fg
                              font.pixelSize: Style.font.caption
                              wrapMode: Text.WordWrap
                              opacity: modelData.scoringPlay ? 1 : 0.85
                            }
                            Text { textFormat: Text.PlainText; visible: modelData.scoringPlay; text: "\u25CF"; color: Color.accent; font.pixelSize: Style.font.caption; Layout.alignment: Qt.AlignTop }
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
                      color: modelData.scoringPlay ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.10) : "transparent"
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
                          Layout.preferredWidth: Math.max(Style.space(40), chipText.implicitWidth + Style.space(8))
                          Layout.alignment: Qt.AlignTop
                          height: Style.space(16)
                          radius: 3
                          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                          visible: root.playChipText(modelData) !== ""
                          Text {
                            textFormat: Text.PlainText
                            id: chipText
                            anchors.centerIn: parent
                            text: root.playChipText(modelData)
                            color: root.fg
                            opacity: 0.7
                            font.pixelSize: Style.font.caption
                            font.family: "Monospace"
                          }
                        }
                        Text {
                          textFormat: Text.PlainText
                          Layout.fillWidth: true
                          text: modelData.text || modelData.description || modelData.shortText || ""
                          color: modelData.scoringPlay ? Color.accent : root.fg
                          font.pixelSize: Style.font.caption
                          wrapMode: Text.WordWrap
                          opacity: modelData.scoringPlay ? 1 : 0.85
                        }
                        Text {
                          textFormat: Text.PlainText
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
                  Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.trFn("Leaders"); color: root.fg; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailLeaders
                    delegate: Column {
                      required property var modelData
                      width: parent.width
                      spacing: Style.space(6)
                      RowLayout {
                        width: parent.width
                        spacing: Style.space(8)
                        Rectangle { width: Style.space(24); height: Style.space(24); radius: 12; clip: true; color: "transparent"; visible: modelData.team && modelData.team.logo; Image { anchors.fill: parent; source: Model.safeMedia(modelData.team.logo); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true } }
                        Text { textFormat: Text.PlainText; text: modelData.team ? (modelData.team.abbreviation || modelData.team.displayName) : ""; color: root.fg; opacity: 0.6; font.pixelSize: Style.font.caption; font.bold: true; Layout.fillWidth: true }
                      }
                      Repeater {
                        model: modelData.leaders || []
                        delegate: RowLayout {
                          required property var modelData
                          property var leader: modelData.leaders && modelData.leaders.length ? modelData.leaders[0] : null
                          width: parent.width
                          spacing: Style.space(8)
                          Rectangle {
                            Layout.preferredWidth: Style.space(28); Layout.preferredHeight: Style.space(28); radius: 14; clip: true; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                            Image {
                              anchors.fill: parent
                              source: Model.safeMedia(leader && leader.athlete && leader.athlete.headshot ? leader.athlete.headshot.href : "")
                              fillMode: Image.PreserveAspectCrop
                              asynchronous: true; cache: true
                            }
                          }
                          Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { textFormat: Text.PlainText; text: leader && leader.athlete ? (leader.athlete.displayName || leader.athlete.shortName) : ""; color: root.fg; font.pixelSize: Style.font.caption; elide: Text.ElideRight; font.bold: true }
                            Text { textFormat: Text.PlainText; text: (leader && leader.athlete && leader.athlete.position ? leader.athlete.position.abbreviation + " \u00b7 " : "") + (modelData.displayName || modelData.name || ""); color: root.fg; opacity: 0.5; font.pixelSize: Style.font.caption }
                          }
                          Text { textFormat: Text.PlainText; text: leader ? (leader.displayValue || leader.value || "") : ""; color: Color.accent; font.pixelSize: Style.font.caption; font.bold: true; font.family: "Monospace" }
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
                  PanelSeparator { foreground: root.fg }
                  Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.trFn("Recent Plays"); color: root.fg; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailPlays.length > 5 ? root.detailPlays.slice(root.detailPlays.length - 5) : (root.detailPlays || [])
                    delegate: Rectangle {
                      required property var modelData
                      required property int index
                      width: parent.width
                      height: miniPlay.implicitHeight + Style.space(6)
                      color: index % 2 === 1 ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04) : "transparent"
                      radius: 2
                      Text {
                        textFormat: Text.PlainText
                        id: miniPlay
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        text: (modelData.clock ? modelData.clock.displayValue + " " : "") + (modelData.text || modelData.description || "")
                        color: modelData.scoringPlay ? Color.accent : root.fg
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        opacity: modelData.scoringPlay ? 1 : 0.7
                      }
                    }
                  }
                  Text {
                    textFormat: Text.PlainText
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
                  PanelSeparator { foreground: root.fg }
                  Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.trFn("Standings"); color: root.fg; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
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
                          Text { textFormat: Text.PlainText; Layout.fillWidth: true; text: (modelData.divisionHeader || modelData.header || modelData.conferenceHeader || "").replace(/^\d{4}(-\d{2,4})? /, ""); color: root.fg; opacity: 0.5; font.pixelSize: Style.font.caption; font.bold: true; elide: Text.ElideRight }
                          Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.trFn("W"); color: root.fg; opacity: 0.45; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.trFn("L"); color: root.fg; opacity: 0.45; font.pixelSize: Style.font.caption; font.bold: true }
                          Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.trFn("T"); color: root.fg; opacity: 0.45; font.pixelSize: Style.font.caption; font.bold: true }
                        }
                      }
                      Repeater {
                        model: {
                          var es = modelData.standings ? modelData.standings.entries : []
                          var rows = []
                          for (var i = 0; i < es.length; i++) { es[i]._rank = i + 1; if (i < 5) rows.push(es[i]) }
                          if (root.selectedGame) {
                            var ids = [String(root.selectedGame.away.id), String(root.selectedGame.home.id)]
                            for (var j = 5; j < es.length; j++) {
                              if (ids.indexOf(String(es[j].id)) >= 0) rows.push(es[j])
                            }
                          }
                          return rows
                        }
                        delegate: Rectangle {
                          required property var modelData
                          required property int index
                          width: parent.width
                          height: Style.space(20)
                          property bool isCurrent: (root.selectedGame && ((String(modelData.id) === String(root.selectedGame.away.id)) || (String(modelData.id) === String(root.selectedGame.home.id)))) || (modelData.team && root.selectedGame && (modelData.team.indexOf(root.selectedGame.away.abbr) >= 0 || modelData.team.indexOf(root.selectedGame.home.abbr) >= 0))
                          color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : "transparent"
                          radius: 2
                          border.width: isCurrent ? 1 : 0
                          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(6)
                            anchors.rightMargin: Style.space(6)
                            spacing: Style.space(8)
                            Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(16); horizontalAlignment: Text.AlignHCenter; text: root.standingsStat(modelData, ["rank"]) !== "" ? root.standingsStat(modelData, ["rank"]) : String(modelData._rank); color: isCurrent ? Color.accent : root.fg; opacity: isCurrent ? 1 : 0.5; font.pixelSize: Style.font.caption; font.family: "Monospace" }
                            Text { textFormat: Text.PlainText; Layout.fillWidth: true; text: modelData.team || modelData.displayName || ""; color: isCurrent ? Color.accent : root.fg; font.pixelSize: Style.font.caption; elide: Text.ElideRight; font.bold: isCurrent }
                            Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.standingsStat(modelData, ["wins","W"]); color: isCurrent ? Color.accent : root.fg; opacity: isCurrent ? 1 : 0.6; font.pixelSize: Style.font.caption; font.family: "Monospace"; font.bold: isCurrent }
                            Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.standingsStat(modelData, ["losses","L"]); color: isCurrent ? Color.accent : root.fg; opacity: isCurrent ? 1 : 0.6; font.pixelSize: Style.font.caption; font.family: "Monospace"; font.bold: isCurrent }
                            Text { textFormat: Text.PlainText; Layout.preferredWidth: Style.space(20); horizontalAlignment: Text.AlignHCenter; text: root.standingsStat(modelData, ["ties","T"]); color: isCurrent ? Color.accent : root.fg; opacity: isCurrent ? 1 : 0.6; font.pixelSize: Style.font.caption; font.family: "Monospace"; font.bold: isCurrent }
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
                  PanelSeparator { foreground: root.fg }
                  Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.trFn("Injuries"); color: root.fg; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailInjuries
                    delegate: Column {
                      required property var modelData
                      width: parent.width
                      spacing: Style.space(2)
                      Text { textFormat: Text.PlainText; width: parent.width; text: modelData.team ? modelData.team.abbreviation : ""; color: root.fg; opacity: 0.5; font.pixelSize: Style.font.caption; font.bold: true }
                      Repeater {
                        model: (modelData.injuries || modelData.players || []).slice(0, 3)
                        delegate: Text {
                          textFormat: Text.PlainText
                          required property var modelData
                          width: parent.width
                          text: (modelData.athlete ? modelData.athlete.displayName : modelData.displayName || "") + (modelData.status ? " \u2013 " + modelData.status : "")
                          color: root.fg
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
                  PanelSeparator { foreground: root.fg }
                  Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.trFn("Related"); color: root.fg; opacity: 0.7; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Repeater {
                    model: root.detailNews
                    delegate: Text {
                      textFormat: Text.PlainText
                      required property var modelData
                      width: parent.width
                      text: "\u25B6 " + (modelData.headline || modelData.title || "")
                      color: Color.accent
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      wrapMode: Text.WordWrap
                      maximumLineCount: 2
                      MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally(root.safeHref(modelData.links && modelData.links.web ? modelData.links.web.href : modelData.link ? modelData.link.href : "")) ; cursorShape: Qt.PointingHandCursor }
                    }
                  }
                  Repeater {
                    model: root.detailVideos
                    delegate: Text {
                      textFormat: Text.PlainText
                      required property var modelData
                      width: parent.width
                      text: "\u25B6 " + (modelData.headline || modelData.description || "")
                      color: Color.accent
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      wrapMode: Text.WordWrap
                      maximumLineCount: 2
                      MouseArea { anchors.fill: parent; onClicked: Qt.openUrlExternally(root.safeHref(modelData.links && modelData.links.source ? modelData.links.source.href : modelData.link ? modelData.link.href : "")) ; cursorShape: Qt.PointingHandCursor }
                    }
                  }
                }
                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: (!root.detailLeaders || root.detailLeaders.length === 0) && (!root.detailPlays || root.detailPlays.length === 0) && (!root.detailStandings || !root.detailStandings.groups) && (!root.detailInjuries || root.detailInjuries.length === 0) && (!root.detailNews || root.detailNews.length === 0) && (!root.detailVideos || root.detailVideos.length === 0)
                  text: root.trFn("No insights for this game")
                  color: root.fg
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
}
}

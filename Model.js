.pragma library

// Shared model for OmaScore — pure logic, no QML dependencies.
// Import as `import "Model.js" as Model` from any QML file.

var dayLabels = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
var monthLabels = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

// Leagues: Tier1 + college + soccer — all use 7-day selector
var leagues = [
    { id: "nfl",   sport: "football",   league: "nfl",                        label: "NFL",     mode: "week" },
    { id: "cfb",   sport: "football",   league: "college-football",           label: "CFB",     mode: "week" },
    { id: "nba",   sport: "basketball", league: "nba",                        label: "NBA",     mode: "week" },
    { id: "wnba",  sport: "basketball", league: "wnba",                       label: "WNBA",    mode: "week" },
    { id: "ncaam", sport: "basketball", league: "mens-college-basketball",    label: "NCAAM",   mode: "week" },
    { id: "ncaaw", sport: "basketball", league: "womens-college-basketball",  label: "NCAAW",   mode: "week" },
    { id: "mlb",   sport: "baseball",   league: "mlb",                        label: "MLB",     mode: "week" },
    { id: "nhl",   sport: "hockey",     league: "nhl",                        label: "NHL",     mode: "week" },
    { id: "mls",   sport: "soccer",     league: "usa.1",                      label: "MLS",     mode: "week" },
    { id: "epl",   sport: "soccer",     league: "eng.1",                      label: "EPL",     mode: "week" },
    { id: "laliga",sport: "soccer",     league: "esp.1",                      label: "LaLiga",  mode: "week" },
    { id: "bundes",sport: "soccer",     league: "ger.1",                      label: "Bundes",  mode: "week" },
    { id: "seriea",sport: "soccer",     league: "ita.1",                      label: "Serie A", mode: "week" },
    { id: "ligue1",sport: "soccer",     league: "fra.1",                      label: "Ligue 1", mode: "week" },
    { id: "ucl",   sport: "soccer",     league: "uefa.champions",             label: "UCL",     mode: "week" }
]
var defaultLeagueId = "nfl"
// Back-compat: old single-league URL
var apiUrl = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
var summaryBase = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary"

function leagueFor(id) {
    for (var i = 0; i < leagues.length; i++) if (leagues[i].id === id) return leagues[i]
    return leagues[0]
}
function apiUrlFor(sport, league) { return "https://site.api.espn.com/apis/site/v2/sports/" + sport + "/" + league + "/scoreboard" }
function summaryBaseFor(sport, league) { return "https://site.api.espn.com/apis/site/v2/sports/" + sport + "/" + league + "/summary" }

function ymd(d) {
    var y = d.getFullYear(), m = d.getMonth() + 1, dd = d.getDate()
    return y + (m < 10 ? "0" + m : m) + (dd < 10 ? "0" + dd : dd)
}

function sundayOf(d) {
    var nd = new Date(d)
    nd.setHours(0, 0, 0, 0)
    nd.setDate(nd.getDate() - nd.getDay())
    return nd
}

function weekDataFor(today) {
    var s = sundayOf(today)
    var dates = [], strs = []
    for (var i = 0; i < 7; i++) { var dd = new Date(s); dd.setDate(s.getDate() + i); dates.push(dd); strs.push(ymd(dd)) }
    return { weekStart: s, weekDates: dates, weekDateStrs: strs, selectedDay: today.getDay() }
}

function weekDataShift(weekStart, delta, today) {
    var ns = new Date(weekStart)
    ns.setDate(ns.getDate() + delta)
    var dates = [], strs = []
    for (var i = 0; i < 7; i++) { var dd = new Date(ns); dd.setDate(ns.getDate() + i); dates.push(dd); strs.push(ymd(dd)) }
    var idx = strs.indexOf(ymd(today))
    return { weekStart: ns, weekDates: dates, weekDateStrs: strs, selectedDay: idx >= 0 ? idx : 0 }
}

function weekLabel(weekDates) {
    if (!weekDates || weekDates.length !== 7) return ""
    var s = weekDates[0], e = weekDates[6]
    var sm = monthLabels[s.getMonth()], em = monthLabels[e.getMonth()]
    if (s.getMonth() === e.getMonth()) return sm + " " + s.getDate() + " \u2013 " + e.getDate()
    return sm + " " + s.getDate() + " \u2013 " + em + " " + e.getDate()
}

function titleize(s) {
    var t = String(s || "").trim().replace(/([a-z])([A-Z])/g, "$1 $2")
    if (!t) return ""
    return t.split(/[\s_\/]+/).map(function(w){ return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase() }).join(" ")
}

// Favorites: new format { nfl:[...], nba:[...] }  old format ["BUF"] -> migrate to {nfl:[...]}
function parseFavorites(raw) {
    var parsed
    try { parsed = JSON.parse(raw || "{}") } catch (e) { return {} }
    if (Array.isArray(parsed)) {
        // migrate old flat array -> nfl
        return parsed.length ? { nfl: parsed } : {}
    }
    if (parsed && typeof parsed === "object") {
        // ensure values are arrays
        var out = {}
        for (var k in parsed) if (Array.isArray(parsed[k])) out[k] = parsed[k].slice()
        return out
    }
    return {}
}
function isFav(favMapOrArray, abbr, leagueId) {
    if (Array.isArray(favMapOrArray)) return favMapOrArray.indexOf(abbr) >= 0
    if (!leagueId) return false
    var arr = favMapOrArray[leagueId] || []
    return arr.indexOf(abbr) >= 0
}
function toggleFavMap(favMap, leagueId, abbr) {
    var out = {}
    for (var k in favMap) out[k] = favMap[k].slice()
    var arr = out[leagueId] ? out[leagueId].slice() : []
    var idx = arr.indexOf(abbr)
    if (idx >= 0) arr.splice(idx, 1); else arr.push(abbr)
    if (arr.length) out[leagueId] = arr; else delete out[leagueId]
    return out
}
function isLeagueFav(favMap, leagueId) { var arr = favMap["favoriteLeagues"] || []; return arr.indexOf(leagueId) >= 0 }
function toggleLeagueFav(favMap, leagueId) {
    var out = {}
    for (var k in favMap) out[k] = favMap[k].slice()
    var arr = out["favoriteLeagues"] ? out["favoriteLeagues"].slice() : []
    var idx = arr.indexOf(leagueId)
    if (idx >= 0) arr.splice(idx, 1); else arr.push(leagueId)
    if (arr.length) out["favoriteLeagues"] = arr; else delete out["favoriteLeagues"]
    return out
}
var leagueTier = { nfl:1, nba:1, mlb:1, nhl:1, wnba:1, mls:1, cfb:2, ncaam:2, ncaaw:2, epl:2, ucl:2, laliga:3, bundes:3, seriea:3, ligue1:3 }
function sortedLeagues(leagues, favMap) {
    var favs = favMap["favoriteLeagues"] || []
    var arr = leagues.slice()
    arr.sort(function(a,b){
        var aIdx = favs.indexOf(a.id), bIdx = favs.indexOf(b.id)
        var aFav = aIdx >= 0, bFav = bIdx >= 0
        if (aFav !== bFav) return aFav ? -1 : 1
        if (aFav && bFav) return aIdx - bIdx // earliest favorited first
        var at = leagueTier[a.id] || 99, bt = leagueTier[b.id] || 99
        if (at !== bt) return at - bt
        return 0 // stable within tier (preserves leagues array order)
    })
    return arr
}

function rank(game, favMap, leagueId) {
    // favMap may be array (legacy) or map
    var fav = false
    if (Array.isArray(favMap)) fav = favMap.indexOf(game.away.abbr) >= 0 || favMap.indexOf(game.home.abbr) >= 0
    else fav = isFav(favMap, game.away.abbr, leagueId) || isFav(favMap, game.home.abbr, leagueId)
    if (game.state === "in") return fav ? 0 : 2
    if (fav) return 1
    if (game.state === "pre") return 3
    return 4
}

function sorted(list, favMap, leagueId) {
    var arr = list.slice()
    arr.sort(function(a,b){ return rank(a, favMap, leagueId) - rank(b, favMap, leagueId) })
    return arr
}

function recount(games, favMap, leagueId) {
    var live = 0, favPlaying = false
    for (var i = 0; i < games.length; i++) {
        var g = games[i]
        if (g.state === "in") {
            live++
            var isF = Array.isArray(favMap) ? (favMap.indexOf(g.away.abbr) >= 0 || favMap.indexOf(g.home.abbr) >= 0)
                    : (isFav(favMap, g.away.abbr, leagueId) || isFav(favMap, g.home.abbr, leagueId))
            if (isF) favPlaying = true
        }
    }
    return { liveCount: live, favLive: favPlaying }
}

function leads(game, side) {
    if (!game || !game[side] || game.state === "pre") return false
    var mine = parseInt(game[side].score) || 0
    var other = parseInt(game[side === "away" ? "home" : "away"].score) || 0
    return mine > other
}

// Classify a tracked game's transition from its previous composite key ("a|b|state"):
// "final" on a real in->post flip (postponed/suspended/canceled also report "post" —
// those are NOT finals), "score" when the score moved, null otherwise.
function scoreEvent(prev, g) {
    if (!prev || !g || !g.away || !g.home) return null
    var parts = prev.split("|")
    var scoreChanged = parts[0] !== String(g.away.score || "") || parts[1] !== String(g.home.score || "")
    var isFinal = parts[2] === "in" && g.state === "post" && !/postponed|suspended|delayed|cancel/i.test(g.detail || "")
    if (isFinal) return "final"
    return scoreChanged ? "score" : null
}

// Minutes until kickoff when a pre-game reminder should fire (inside the 10-minute
// window), else -1. state comes from ESPN ("pre"|"in"|"post").
function kickoffMinutes(dateStr, state, now) {
    if (state !== "pre" || !dateStr) return -1
    var t = new Date(dateStr)
    if (isNaN(t.getTime())) return -1
    var mins = Math.round((t.getTime() - now.getTime()) / 60000)
    return (mins > 0 && mins <= 10) ? mins : -1
}

function statusColor(state, urgent, defCol) { return state === "in" ? urgent : defCol }

// --- Security budgets (omarchy-plugin-marketplace#2934) ---
// Remote responses are treated as hostile: every curl runs from a fixed argument
// array with a producer-side --max-filesize (MAX_BYTES), every collector output
// passes Panel.gated() before JSON.parse, and everything retained from a parsed
// payload goes through sanitize()/clip() so per-list sizes, nesting depth,
// string lengths and total node count are all bounded.
var MAX_BYTES = "8388608"      // curl --max-filesize: 8 MB hard producer cap
var MAX_TEXT = 8388608         // pre-parse gate enforced in Panel.gated() (chars)
var MAX_EVENTS = 128           // games per scoreboard response
var MAX_LIST = 64              // generic per-list cap in sanitize()
var MAX_PLAYERS = 120          // athlete rows per team side
var MAX_STATS = 32             // statistics per team
var MAX_PLAYS = 120            // plays retained (also caps per-drive play lists)
var MAX_DRIVES = 24
var MAX_INJURIES = 24
var MAX_STR = 300              // default string cap in sanitize()
var SANITIZE_DEPTH = 12        // max nesting depth retained
var SANITIZE_NODES = 10000     // max total nodes retained

// --- Favorites state (dconf) ---
// Favorites persist through the desktop dconf daemon: the plugin only runs
// fixed-argv `dconf read/write` (same trust shape as the curl/stat/dd baseline)
// and holds no state-file paths of its own. Values are GVariant text-format
// strings, so the JSON payload is wrapped in single quotes with \ and '
// escaped; dconf-service serializes concurrent writers for us.
var DCONF_FAVORITES = "/net/slowburnaz/omascore/favorites"
function dconfEscape(s) {
    return "'" + String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'"
}
function dconfUnescape(s) {
    s = String(s || "").trim()
    // dconf read returns canonical GVariant text: the wrapper may be ' or "
    if (s.length >= 2 && ((s.charAt(0) === "'" && s.charAt(s.length - 1) === "'") || (s.charAt(0) === '"' && s.charAt(s.length - 1) === '"'))) s = s.slice(1, -1)
    var out = ""
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i)
        if (c === "\\" && i + 1 < s.length) { i++; c = s.charAt(i) }
        out += c
    }
    return out
}

// --- Shared live board (bar state) ---
// Every per-screen panel instance imports this library into the SAME engine,
// so a plain object here is shared process-wide. Each instance notes its
// scoreboard fetches under its own (league, day) slot; bar state reads the
// slot for today, so browsing other days never clobbers the live view.
var liveBoard = {}
function noteScoreboard(leagueId, day, games) {
    if (!leagueId || !day || !games) return
    var board = liveBoard
    board[leagueId + "|" + day] = { at: new Date().getTime(), games: games }
    var keys = Object.keys(board)
    if (keys.length > 64) {           // keep memory bounded on long sessions
        keys.sort(function(a, b) { return board[a].at - board[b].at })
        for (var i = 0; i < keys.length - 64; i++) delete board[keys[i]]
    }
}
function liveBoardEntry(leagueId, todayYmd, maxAgeMs) {
    var e = liveBoard[leagueId + "|" + todayYmd]
    if (!e || new Date().getTime() - e.at > maxAgeMs) return null
    return e
}
function liveBoardNeedsFetch(leagueId, todayYmd, maxAgeMs) {
    var e = liveBoard[leagueId + "|" + todayYmd]
    return !(e && new Date().getTime() - e.at < maxAgeMs)
}

// --- Shared notification claims ---
// Exact-once sends process-wide: every panel's requestNotification claims its
// key here first. All panels share this one engine, so within a poll cycle
// exactly one instance wins. 45s TTL absorbs poll stagger between panels, so
// a genuinely new recurrence of the same key can notify again; entries are
// pruned after 24h to stay bounded. No claim file exists — nothing on disk.
var notifClaims = {}
function claimNotification(key, now) {
    for (var k in notifClaims) if (now - notifClaims[k] >= 86400000) delete notifClaims[k]
    if (notifClaims[key] && now - notifClaims[key] < 45000) return false
    notifClaims[key] = now
    return true
}
// Kickoff reminders already requested/sent, keyed by game id (shared so
// another panel's earlier reminder suppresses re-requests at later minutes).
// Cleared in place (no rebinding) so external Model.kickoffNotified reads
// always see the live object.
var kickoffNotified = {}
function resetKickoffMarks() { for (var k in kickoffNotified) delete kickoffNotified[k] }

// --- Shared favorites state ---
// All per-screen panels import this library into the SAME engine, so favorites
// live here process-wide: every toggle or startup restore lands through
// setFavorites, which notifies the other panels' watchers. dconf is
// persistence only — panels write through on change and read once at startup;
// there is no watch process. The source panel of a change is skipped (it
// already applied its own UI update).
var favorites = {}
var favWatchers = []
function setFavorites(f, source) {
    favorites = f || {}
    for (var i = 0; i < favWatchers.length; i++)
        if (favWatchers[i] !== source) favWatchers[i](favorites)
    return favorites
}

// Truncate to n chars and neutralize tag-like content so QML's Text.AutoText
// (the default on every Text in the plugin) never renders remote data as rich
// text (see security baseline above). A soft hyphen (U+00AD) right after each
// '<' makes Qt::mightBeRichText's tag scan hit its "that's not a tag" bail
// (non-space, non-letter, non-digit char before any tag name), which also
// defuses leading tags and <!doc / <?xml prologues; splitting "&lt;" closes
// its literal-entity trigger. All raw-hostile fixtures verified against the
// real Qt::mightBeRichText: RICH before, plain after, benign strings unchanged.
function clip(s, n) {
    s = String(s == null ? "" : s).replace(/</g, "<\u00AD").replace(/&lt;/g, "&\u00ADlt;")
    return s.length > n ? s.substring(0, n) : s
}

// Bounded deep copy of remote JSON: per-list cap, depth cap, string cap and a
// total-node budget. Non-object leaves pass through unchanged.
function sanitize(v, listCap, strCap) {
    listCap = listCap || MAX_LIST
    strCap = strCap || MAX_STR
    var budget = SANITIZE_NODES
    function walk(x, depth) {
        if (budget-- <= 0 || depth > SANITIZE_DEPTH) return null
        if (x == null || typeof x !== "object") {
            if (typeof x === "string") return clip(x, strCap)
            return x
        }
        if (Array.isArray(x)) {
            var a = []
            for (var i = 0; i < x.length && i < listCap; i++) {
                var w = walk(x[i], depth + 1)
                if (w !== null) a.push(w)
            }
            return a
        }
        var o = {}
        for (var k in x) {
            if (!x.hasOwnProperty(k)) continue
            o[k] = walk(x[k], depth + 1)
            if (budget <= 0) break
        }
        return o
    }
    return walk(v, 0)
}

// JSON.parse with a cheap pre-parse guard against depth bombs (runs of 50+
// consecutive open brackets in the first 4 KB).
function parseBoundedJson(txt) {
    if (/(\{|\[)(\s*(\{|\[)){50,}/.test(txt.substring(0, 4096))) return null
    try { return JSON.parse(txt) } catch (e) { return null }
}

function validEventId(id) { return /^\d{1,12}$/.test(String(id == null ? "" : id)) }

function summaryUrl(eventId, leagueId) {
    if (!validEventId(eventId)) return ""
    if (leagueId) { var L = leagueFor(leagueId); return summaryBaseFor(L.sport, L.league) + "?event=" + eventId }
    return summaryBase + "?event=" + eventId
}

function scoreboardUrl(dateStr, leagueId) {
    var L = leagueFor(leagueId)
    return apiUrlFor(L.sport, L.league) + "?dates=" + dateStr
}
// Argument-array curl for a one-day scoreboard fetch (no shell involved).
function fetchArgs(dateStr, leagueId) {
    if (!/^\d{8}$/.test(String(dateStr || ""))) return null
    return ["curl", "-fsS", "--max-time", "10", "--max-filesize", MAX_BYTES, scoreboardUrl(dateStr, leagueId)]
}
// Argument-array curl for one week-range scoreboard fetch (no shell involved).
function weekArgs(dateStrs, leagueId) {
    if (!Array.isArray(dateStrs) || dateStrs.length !== 7) return null
    if (!/^\d{8}$/.test(dateStrs[0]) || !/^\d{8}$/.test(dateStrs[6])) return null
    var L = leagueFor(leagueId)
    return ["curl", "-fsS", "--max-time", "8", "--max-filesize", MAX_BYTES, apiUrlFor(L.sport, L.league) + "?dates=" + dateStrs[0] + "-" + dateStrs[6]]
}
function standingsUrlFor(sport, league) { return "https://site.api.espn.com/apis/v2/sports/" + sport + "/" + league + "/standings" }

// Media URLs (team logos, athlete headshots) come from the response and are
// loaded by QML Image elements without user action. Only https on ESPN's own
// CDN is ever legitimate, so anything else — a hostile or compromised payload
// pointing at an arbitrary URL — loads nothing instead of beaconing.
function safeMedia(u) {
    u = String(u || "")
    return /^https:\/\/([a-z0-9-]+\.)*espncdn\.com\//.test(u) ? u : ""
}

// Convert the v2 league-standings payload (children = conferences) into the same
// group shape the summary standings use, so panels render both identically.
function parseStandingsGroups(raw) {
    var d = parseBoundedJson(String(raw || "{}"))
    if (!d || typeof d !== "object") return { groups: [] }
    var children = Array.isArray(d.children) ? d.children.slice(0, 8) : []
    var groups = []
    for (var i = 0; i < children.length; i++) {
        var ch = children[i]
        var es = (ch && ch.standings && Array.isArray(ch.standings.entries)) ? ch.standings.entries.slice(0, MAX_LIST) : []
        var entries = []
        for (var j = 0; j < es.length; j++) {
            var e = es[j]
            if (!e || !e.team) continue
            var stats = Array.isArray(e.stats) ? e.stats.slice(0, MAX_STATS) : []
            var bounded = []
            for (var s = 0; s < stats.length; s++) {
                var st = stats[s] || {}
                bounded.push({ name: clip(st.name, 60), abbreviation: clip(st.abbreviation, 16), displayValue: clip(st.displayValue, 60), value: st.value })
            }
            entries.push({ id: clip(e.team.id, 16), team: clip(e.team.displayName || e.team.name, 100), stats: bounded })
        }
        if (entries.length) groups.push({ header: clip(ch.name || ch.displayName, 100), standings: { entries: entries } })
    }
    return { groups: groups }
}

function periodLabelFor(leagueId) {
    var L = leagueFor(leagueId)
    if (L.sport === "hockey") return "P"
    if (L.sport === "baseball") return "Inn"
    if (L.sport === "soccer") return "Half"
    return "Q"
}

function parseGames(raw) {
    var txt = String(raw || "").trim()
    if (!txt) return { games: [], error: "" }
    var data = parseBoundedJson(txt)
    if (!data || typeof data !== "object") return { games: [], error: "Parse error" }
    var events = Array.isArray(data.events) ? data.events.slice(0, MAX_EVENTS) : []
    var out = []
    for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        if (!ev || typeof ev !== "object") continue
        var comps = Array.isArray(ev.competitions) ? ev.competitions : []
        var comp = comps[0]
        if (!comp || typeof comp !== "object") continue
        var st = (ev.status && ev.status.type) ? ev.status.type : null
        var g = { id: clip(ev.id, 16), state: st ? clip(st.state, 16) : "", detail: st ? clip(st.shortDetail, 100) : "", date: clip(ev.date, 40), away: null, home: null }
        var cs = Array.isArray(comp.competitors) ? comp.competitors : []
        for (var j = 0; j < cs.length && j < 4; j++) {
            var c = cs[j]
            if (!c || !c.team || (c.homeAway !== "away" && c.homeAway !== "home")) continue
            g[c.homeAway] = { id: clip(c.team.id, 16), abbr: clip(c.team.abbreviation, 16), name: clip(c.team.displayName, 100), score: clip(c.score, 16), logo: clip(c.team.logo, 500), color: clip(c.team.color, 16), record: c.records && c.records[0] ? clip(c.records[0].summary, 60) : "" }
        }
        var oddsArr = Array.isArray(comp.odds) ? comp.odds : []
        var o = oddsArr[0]
        if (o && o.details) g.odds = clip(o.details, 60) + " \u00b7 O/U " + clip(o.overUnder, 16)
        if (g.away && g.home) out.push(g)
    }
    return { games: out, error: out.length ? "" : "No games scheduled" }
}

// One week-range scoreboard fetch (?dates=A-B) covers the whole selector week;
// bucket each event by its LOCAL calendar day so dots match the panel's days.
function parseWeekRange(raw, weekDateStrs) {
    var out = [false, false, false, false, false, false, false]
    var txt = String(raw || "").trim()
    if (!txt) return out
    var d = parseBoundedJson(txt)
    if (!d || typeof d !== "object") return out
    var events = Array.isArray(d.events) ? d.events : []
    var cap = Math.min(events.length, MAX_EVENTS * 7)
    for (var i = 0; i < cap; i++) {
        var e = events[i]
        if (!e || !e.date) continue
        var idx = weekDateStrs.indexOf(ymd(new Date(e.date)))
        if (idx >= 0) out[idx] = true
    }
    return out
}

function nextSelectedDay(hasGames, selectedDay) {
    if (hasGames[selectedDay]) return -1
    for (var k = 0; k < 7; k++) { var idx = (selectedDay + k + 1) % 7; if (hasGames[idx]) return idx }
    return -1
}

function parseDetail(raw, selectedGame, leagueId) {
    var txt = String(raw || "").trim()
    if (!txt) throw new Error("No details")
    var d = parseBoundedJson(txt)
    if (!d || typeof d !== "object") throw new Error("No details")
    var header = d.header || {}
    var comp = header.competitions && header.competitions[0]
    if (!comp || typeof comp !== "object") throw new Error("No details")
    var box = d.boxscore || {}
    var teams = Array.isArray(box.teams) ? box.teams : []
    var away = selectedGame ? selectedGame.away : null
    var home = selectedGame ? selectedGame.home : null
    var awayId = away ? away.id : null, homeId = home ? home.id : null
    var tAway = null, tHome = null
    for (var i = 0; i < teams.length && i < 4; i++) {
        var t = teams[i], tid = t.team ? t.team.id : null, abbr = t.team ? t.team.abbreviation : null
        if (tid && awayId && String(tid) === String(awayId)) tAway = t
        else if (abbr && away && abbr === away.abbr) tAway = t
        else if (tid && homeId && String(tid) === String(homeId)) tHome = t
        else if (abbr && home && abbr === home.abbr) tHome = t
    }
    if (!tAway && teams.length > 0) tAway = teams[0]
    if (!tHome && teams.length > 1) tHome = teams[1]
    var statsA = tAway ? (Array.isArray(tAway.statistics) ? tAway.statistics : []).slice(0, MAX_STATS) : []
    var statsH = tHome ? (Array.isArray(tHome.statistics) ? tHome.statistics : []).slice(0, MAX_STATS) : []
    var paired = []
    // MLB/nested: statistics are categories with .stats array; NFL/NBA flat
    var isNested = statsA.length && statsA[0] && Array.isArray(statsA[0].stats)
    if (isNested) {
        var catMapH = {}
        for (var j = 0; j < statsH.length; j++) {
            var ch = statsH[j]
            var cmap = {}
            if (ch && Array.isArray(ch.stats)) for (var jj = 0; jj < ch.stats.length && jj < MAX_STATS; jj++) cmap[ch.stats[jj].name] = ch.stats[jj]
            catMapH[ch.name] = cmap
        }
        for (var k = 0; k < statsA.length; k++) {
            var ca = statsA[k]
            if (!ca || !Array.isArray(ca.stats) || !ca.stats.length) continue
            var cmapH = catMapH[ca.name] || {}
            var catPrefix = ca.displayName || ca.name || ""
            for (var kk = 0; kk < ca.stats.length && kk < MAX_STATS; kk++) {
                var nsA = ca.stats[kk]
                var nsH = cmapH[nsA.name]
                var lab = nsA.shortDisplayName || nsA.displayName || nsA.abbreviation || nsA.name
                if (!lab) lab = nsA.name
                // prefix with category for nested leagues (MLB etc.) to disambiguate
                if (catPrefix) lab = catPrefix + " " + lab
                paired.push({ label: lab, away: nsA.displayValue != null ? nsA.displayValue : (nsA.value != null ? String(nsA.value) : "-"), home: nsH ? (nsH.displayValue != null ? nsH.displayValue : (nsH.value != null ? String(nsH.value) : "-")) : "-" })
            }
        }
    } else {
        var mapH = {}
        for (var j = 0; j < statsH.length; j++) mapH[statsH[j].name] = statsH[j]
        for (var k = 0; k < statsA.length; k++) {
            var sA = statsA[k], sH = mapH[sA.name]
            paired.push({ label: sA.label || sA.displayName || sA.name, away: sA.displayValue != null ? sA.displayValue : (sA.value != null ? String(sA.value) : "-"), home: sH ? (sH.displayValue != null ? sH.displayValue : (sH.value != null ? String(sH.value) : "-")) : "-" })
        }
    }
    if (paired.length === 0) {
        var compAway = null, compHome = null
        var comps = Array.isArray(comp.competitors) ? comp.competitors : []
        for (var c = 0; c < comps.length && c < 4; c++) { if (comps[c].homeAway === "away") compAway = comps[c]; else if (comps[c].homeAway === "home") compHome = comps[c] }
        if (compAway && compHome) {
            var qtrs = Math.min(Math.max(compAway.linescores ? compAway.linescores.length : 0, compHome.linescores ? compHome.linescores.length : 0), MAX_STATS)
            var pLab = periodLabelFor(leagueId || defaultLeagueId)
            for (var q = 0; q < qtrs; q++) {
                var la = compAway.linescores && compAway.linescores[q] ? compAway.linescores[q].displayValue : "-"
                var lh = compHome.linescores && compHome.linescores[q] ? compHome.linescores[q].displayValue : "-"
                // soccer has no quarters — just show period number
                var lbl = (pLab === "Half" || pLab === "Inn") ? (pLab + " " + (q+1)) : (pLab + (q+1))
                paired.push({ label: lbl, away: la, home: lh })
            }
            paired.push({ label: "Total", away: clip(compAway.score, 16) || "0", home: clip(compHome.score, 16) || "0" })
            if (compAway.records && compAway.records[0]) paired.push({ label: "Record", away: clip(compAway.records[0].summary, 60), home: compHome.records && compHome.records[0] ? clip(compHome.records[0].summary, 60) : "-" })
        }
    }
    paired = sanitize(paired, 128, MAX_STR)
    var gv = (comp.venue && comp.venue.fullName) ? comp.venue : (d.gameInfo && d.gameInfo.venue) ? d.gameInfo.venue : null
    var venue = gv ? (gv.fullName || "") : ""
    var addr = ""
    if (gv && gv.address) addr = gv.address.city + (gv.address.state ? ", " + gv.address.state : "") + (gv.address.country && !gv.address.state ? ", " + gv.address.country : "")
    var st = comp.status || {}
    var stType = st.type || {}
    var detailLeaders = sanitize(Array.isArray(d.leaders) ? d.leaders : [], MAX_LIST, MAX_STR)
    var detailPlays = sanitize(Array.isArray(d.plays) ? d.plays : (Array.isArray(d.keyEvents) ? d.keyEvents : []), MAX_PLAYS, 1200)
    var detailDrives = []
    // NFL fallback: drives + scoringPlays when plays empty (preseason)
    if (!detailPlays.length && d.drives) {
        var dr = d.drives.previous || d.drives.drives || []
        if (!dr.length && d.drives.drives) dr = d.drives.drives
        if (dr.length && dr[0].plays) detailDrives = sanitize(dr.slice(0, MAX_DRIVES), MAX_PLAYS, 1200)
        var flat = []
        for (var di = 0; di < dr.length && flat.length < MAX_PLAYS; di++) {
            var dp = (dr[di] && Array.isArray(dr[di].plays)) ? dr[di].plays : []
            for (var pi = 0; pi < dp.length && flat.length < MAX_PLAYS; pi++) flat.push(dp[pi])
        }
        if (flat.length) detailPlays = sanitize(flat, MAX_PLAYS, 1200)
        else if (Array.isArray(d.scoringPlays) && d.scoringPlays.length) detailPlays = sanitize(d.scoringPlays.slice(0, MAX_PLAYS), MAX_PLAYS, 1200)
    }
    if (!detailPlays.length && Array.isArray(d.scoringPlays) && d.scoringPlays.length) detailPlays = sanitize(d.scoringPlays.slice(0, MAX_PLAYS), MAX_PLAYS, 1200)
    // keep drives for grouped display even when plays exist (regular season also has drives)
    if (!detailDrives.length && d.drives) {
        var dr2 = d.drives.previous || d.drives.drives || []
        if (dr2.length && dr2[0].plays) detailDrives = sanitize(dr2.slice(0, MAX_DRIVES), MAX_PLAYS, 1200)
    }
    // live NFL/CFB situation: down & distance + ball spot from the current drive
    var sit = ""
    var sitLeague = leagueId ? leagueFor(leagueId) : leagueFor(defaultLeagueId)
    if (sitLeague.sport === "football" && stType.state === "in") {
        var cur = (d.drives && d.drives.current) ? d.drives.current : null
        var curPlays = (cur && cur.plays) ? cur.plays : []
        var srcPlay = curPlays.length ? curPlays[curPlays.length - 1] : (detailPlays.length ? detailPlays[detailPlays.length - 1] : null)
        var validSit = function(s) { return s && s.down >= 1 && s.down <= 4 && s.distance >= 1 && (s.yardsToEndzone || 0) > 0 }
        var src = null
        var scan = curPlays.length ? curPlays : detailPlays
        for (var si = scan.length - 1; si >= 0 && si >= scan.length - 3 && !src; si--) {
            if (validSit(scan[si].end)) src = scan[si].end
            else if (validSit(scan[si].start)) src = scan[si].start
        }
        if (src) {
            var abbr = (cur && cur.team && cur.team.abbreviation) ? cur.team.abbreviation : ""
            var opp = (abbr && away && home) ? ((abbr === away.abbr) ? home.abbr : away.abbr) : ""
            var ord = ["", "1st", "2nd", "3rd", "4th"][src.down] || String(src.down)
            var distTxt = (src.yardsToEndzone <= src.distance) ? "Goal" : String(src.distance)
            var yl = src.yardLine || 0
            var ylTxt = ""
            if (yl === 50) ylTxt = "50"
            else if (abbr && opp && yl > 50) ylTxt = opp + " " + (100 - yl)
            else if (abbr && yl > 0 && yl < 50) ylTxt = abbr + " " + yl
            sit = (abbr ? abbr + " " : "") + ord + " & " + distTxt + (ylTxt ? " at " + ylTxt : "")
        }
    }
    var detailInjuries = sanitize(Array.isArray(d.injuries) ? d.injuries : [], MAX_INJURIES, MAX_STR)
    var detailStandings = d.standings ? sanitize(d.standings, MAX_LIST, MAX_STR) : null
    var detailNews = (d.news && Array.isArray(d.news.articles)) ? sanitize(d.news.articles.slice(0, 3), 8, MAX_STR) : []
    var detailVideos = Array.isArray(d.videos) ? sanitize(d.videos.slice(0, 2), 4, MAX_STR) : []
    var detailTeams = { away: away, home: home, venue: clip(venue, 200), addr: clip(addr, 200), status: clip(stType.detail, 100), situation: clip(sit, 120) }
    var detailPlayers = (Array.isArray(box.players) && box.players.length) ? box.players.slice(0, 8).map(function(te) {
        return { team: { abbreviation: clip(te.team ? te.team.abbreviation : "", 16) }, statistics: (Array.isArray(te.statistics) ? te.statistics : []).slice(0, MAX_STATS).map(function(sc) { return { labels: sanitize(Array.isArray(sc.labels) ? sc.labels : [], MAX_STATS, 60) } }) }
    }) : null
    var rosters = (Array.isArray(d.rosters) && d.rosters.length) ? d.rosters.slice(0, 4) : null
    var groups = [], groupMap = {}, order = []
    // Soccer uses d.rosters, not box.players
    if (rosters && rosters.length && (!box.players || !box.players.length)) {
        // Build single group for soccer from rosters
        var soccerLabels = null, soccerKeys = null
        // infer labels/keys from first player's stats
        for (var ri = 0; ri < rosters.length; ri++) {
            var r0 = rosters[ri]
            if (r0 && Array.isArray(r0.roster) && r0.roster.length && Array.isArray(r0.roster[0].stats) && r0.roster[0].stats.length) {
                var st0 = r0.roster[0].stats.slice(0, MAX_STATS)
                soccerLabels = st0.map(function(st){ return clip(st.shortDisplayName || st.abbreviation || st.displayName || st.name, 60) })
                soccerKeys = st0.map(function(st){ return clip(st.name, 60) })
                break
            }
        }
        if (!soccerLabels) soccerLabels = []
        if (!soccerKeys) soccerKeys = []
        var soccerGroup = { name: "players", displayName: "Players", labels: soccerLabels, keys: soccerKeys, away: [], home: [] }
        for (var rpi = 0; rpi < rosters.length; rpi++) {
            var rTeam = rosters[rpi]
            var rAbbr = rTeam && rTeam.team ? rTeam.team.abbreviation : ""
            var isRAway = away && rAbbr === away.abbr
            var isRHome = home && rAbbr === home.abbr
            var rList = []
            var rRoster = (rTeam && Array.isArray(rTeam.roster)) ? rTeam.roster : []
            for (var rj = 0; rj < rRoster.length && rList.length < MAX_PLAYERS; rj++) {
                var re = rRoster[rj]
                if (!re) continue
                // build stats array aligned to soccerLabels/keys
                var statMap = {}
                var reStats = Array.isArray(re.stats) ? re.stats.slice(0, MAX_STATS) : []
                for (var sk = 0; sk < reStats.length; sk++) statMap[reStats[sk].name] = reStats[sk].displayValue
                var aligned = []
                for (var kk = 0; kk < soccerKeys.length; kk++) {
                    var k = soccerKeys[kk]
                    aligned.push(clip(statMap[k] != null ? statMap[k] : "-", 60))
                }
                rList.push({ athlete: sanitize(re.athlete, 2, 200), stats: aligned, jersey: clip(re.jersey, 16), position: sanitize(re.position, 2, 100) })
            }
            if (isRAway) soccerGroup.away = rList
            else if (isRHome) soccerGroup.home = rList
            else { if (rpi === 0) soccerGroup.away = rList; else soccerGroup.home = rList }
        }
        groups.push(soccerGroup)
    } else if (Array.isArray(box.players) && box.players.length) {
        for (var pi = 0; pi < box.players.length && pi < 4; pi++) {
            var teamEntry = box.players[pi]
            var tAbbr = teamEntry && teamEntry.team ? teamEntry.team.abbreviation : ""
            var isAway = away && tAbbr === away.abbr
            var isHome = home && tAbbr === home.abbr
            var stats = (teamEntry && Array.isArray(teamEntry.statistics)) ? teamEntry.statistics.slice(0, MAX_STATS) : []
            for (var si = 0; si < stats.length; si++) {
                var s = stats[si]
                if (!s) continue
                var gname = clip(s.name || s.type || s.text || s.displayName || "stats", 60)
                if (!groupMap[gname]) { groupMap[gname] = { name: gname, displayName: clip(s.displayName || s.shortDisplayName || s.type || gname, 100), labels: sanitize(Array.isArray(s.labels) ? s.labels : (Array.isArray(s.keys) ? s.keys : []), MAX_STATS, 60), keys: sanitize(Array.isArray(s.keys) ? s.keys : [], MAX_STATS, 60), away: [], home: [] }; order.push(gname) }
                var list = Array.isArray(s.athletes) ? s.athletes : []
                if (isAway) groupMap[gname].away = sanitize(list, MAX_PLAYERS, MAX_STR)
                else if (isHome) groupMap[gname].home = sanitize(list, MAX_PLAYERS, MAX_STR)
                else { if (pi === 0) groupMap[gname].away = sanitize(list, MAX_PLAYERS, MAX_STR); else groupMap[gname].home = sanitize(list, MAX_PLAYERS, MAX_STR) }
                if ((!groupMap[gname].labels || groupMap[gname].labels.length === 0) && Array.isArray(s.labels)) groupMap[gname].labels = sanitize(s.labels, MAX_STATS, 60)
            }
        }
        for (var gi = 0; gi < order.length; gi++) groups.push(groupMap[order[gi]])
    }
    return { detailTeams: detailTeams, detailStats: paired, detailPlayers: detailPlayers, detailPlayerGroups: groups,
        detailLeaders: detailLeaders, detailPlays: detailPlays, detailDrives: detailDrives, detailStandings: detailStandings, detailInjuries: detailInjuries,
        detailNews: detailNews, detailVideos: detailVideos }
}

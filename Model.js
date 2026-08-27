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

function statusColor(state, urgent, defCol) { return state === "in" ? urgent : defCol }

function summaryUrl(eventId, leagueId) {
    if (leagueId) { var L = leagueFor(leagueId); return summaryBaseFor(L.sport, L.league) + "?event=" + eventId }
    return summaryBase + "?event=" + eventId
}
function fetchCurl(dateStr, leagueId) {
    var url = leagueId ? apiUrlFor(leagueFor(leagueId).sport, leagueFor(leagueId).league) : apiUrl
    var tmp = leagueId ? "/tmp/omascore-" + leagueId + "-scores.json" : "/tmp/nfl-scores.json"
    return "curl -fsS --max-time 10 '" + url + "?dates='\"" + dateStr + "\" 2>/dev/null | tee " + tmp
}
function weekCurl(dateStrs, leagueId) {
    var url = leagueId ? apiUrlFor(leagueFor(leagueId).sport, leagueFor(leagueId).league) : apiUrl
    return "for d in " + dateStrs.join(" ") + "; do c=$(curl -fsS --max-time 5 '" + url + "?dates='\"$d\" 2>/dev/null | jq -r '.events | length' 2>/dev/null); [ -z \"$c\" ] && c=0; echo \"$d:$c\"; done"
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
    var data = JSON.parse(txt)
    var events = data.events || []
    var out = []
    for (var i = 0; i < events.length; i++) {
        var ev = events[i]
        var comp = ev.competitions && ev.competitions[0]
        if (!comp) continue
        var g = { id: ev.id, state: ev.status.type.state, detail: ev.status.type.shortDetail, away: null, home: null }
        var cs = comp.competitors || []
        for (var j = 0; j < cs.length; j++) {
            var c = cs[j]
            g[c.homeAway] = { id: c.team.id, abbr: c.team.abbreviation, name: c.team.displayName, score: c.score, logo: c.team.logo, color: c.team.color, record: c.records && c.records[0] ? c.records[0].summary : "" }
        }
        if (g.away && g.home) out.push(g)
    }
    return { games: out, error: out.length ? "" : "No games scheduled" }
}

function parseWeek(raw, weekDateStrs) {
    var txt = String(raw || "").trim()
    if (!txt) return { hasGames: [false,false,false,false,false,false,false], nextSelected: -1 }
    var lines = txt.split("\n")
    var arr = [false,false,false,false,false,false,false]
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim(); if (!line) continue
        var parts = line.split(":"); if (parts.length < 2) continue
        var d = parts[0], c = parseInt(parts[1]) || 0
        var idx = weekDateStrs.indexOf(d)
        if (idx >= 0) arr[idx] = c > 0
    }
    return { hasGames: arr }
}

function nextSelectedDay(hasGames, selectedDay) {
    if (hasGames[selectedDay]) return -1
    for (var k = 0; k < 7; k++) { var idx = (selectedDay + k + 1) % 7; if (hasGames[idx]) return idx }
    return -1
}

function parseDetail(raw, selectedGame, leagueId) {
    var txt = String(raw || "").trim()
    if (!txt) throw new Error("No details")
    var d = JSON.parse(txt)
    var header = d.header || {}
    var comp = header.competitions && header.competitions[0]
    if (!comp) throw new Error("No details")
    var box = d.boxscore || {}
    var teams = box.teams || []
    var away = selectedGame ? selectedGame.away : null
    var home = selectedGame ? selectedGame.home : null
    var awayId = away ? away.id : null, homeId = home ? home.id : null
    var tAway = null, tHome = null
    for (var i = 0; i < teams.length; i++) {
        var t = teams[i], tid = t.team ? t.team.id : null, abbr = t.team ? t.team.abbreviation : null
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
    // MLB/nested: statistics are categories with .stats array; NFL/NBA flat
    var isNested = statsA.length && statsA[0] && Array.isArray(statsA[0].stats)
    if (isNested) {
        var catMapH = {}
        for (var j = 0; j < statsH.length; j++) {
            var ch = statsH[j]
            var cmap = {}
            if (ch.stats) for (var jj = 0; jj < ch.stats.length; jj++) cmap[ch.stats[jj].name] = ch.stats[jj]
            catMapH[ch.name] = cmap
        }
        for (var k = 0; k < statsA.length; k++) {
            var ca = statsA[k]
            if (!ca.stats || !ca.stats.length) continue
            var cmapH = catMapH[ca.name] || {}
            var catPrefix = ca.displayName || ca.name || ""
            for (var kk = 0; kk < ca.stats.length; kk++) {
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
        for (var c = 0; c < comp.competitors.length; c++) { if (comp.competitors[c].homeAway === "away") compAway = comp.competitors[c]; else compHome = comp.competitors[c] }
        if (compAway && compHome) {
            var qtrs = Math.max(compAway.linescores ? compAway.linescores.length : 0, compHome.linescores ? compHome.linescores.length : 0)
            var pLab = periodLabelFor(leagueId || defaultLeagueId)
            for (var q = 0; q < qtrs; q++) {
                var la = compAway.linescores && compAway.linescores[q] ? compAway.linescores[q].displayValue : "-"
                var lh = compHome.linescores && compHome.linescores[q] ? compHome.linescores[q].displayValue : "-"
                // soccer has no quarters — just show period number
                var lbl = (pLab === "Half" || pLab === "Inn") ? (pLab + " " + (q+1)) : (pLab + (q+1))
                paired.push({ label: lbl, away: la, home: lh })
            }
            paired.push({ label: "Total", away: compAway.score || "0", home: compHome.score || "0" })
            if (compAway.records && compAway.records[0]) paired.push({ label: "Record", away: compAway.records[0].summary, home: compHome.records && compHome.records[0] ? compHome.records[0].summary : "-" })
        }
    }
    var gv = (comp.venue && comp.venue.fullName) ? comp.venue : (d.gameInfo && d.gameInfo.venue) ? d.gameInfo.venue : null
    var venue = gv ? (gv.fullName || "") : ""
    var addr = ""
    if (gv && gv.address) addr = gv.address.city + (gv.address.state ? ", " + gv.address.state : "") + (gv.address.country && !gv.address.state ? ", " + gv.address.country : "")
    var st = comp.status || {}
    var stType = st.type || {}
    var detailLeaders = d.leaders || []
    var detailPlays = d.plays || d.keyEvents || []
    var detailDrives = []
    // NFL fallback: drives + scoringPlays when plays empty (preseason)
    if (!detailPlays.length && d.drives) {
        var dr = d.drives.previous || d.drives.drives || []
        if (!dr.length && d.drives.drives) dr = d.drives.drives
        if (dr.length && dr[0].plays) detailDrives = dr.slice()
        var flat = []
        for (var di = 0; di < dr.length; di++) {
            var dp = dr[di].plays || []
            for (var pi = 0; pi < dp.length; pi++) flat.push(dp[pi])
        }
        if (flat.length) detailPlays = flat
        else if (d.scoringPlays && d.scoringPlays.length) detailPlays = d.scoringPlays.slice()
    }
    if (!detailPlays.length && d.scoringPlays && d.scoringPlays.length) detailPlays = d.scoringPlays.slice()
    // keep drives for grouped display even when plays exist (regular season also has drives)
    if (!detailDrives.length && d.drives) {
        var dr2 = d.drives.previous || d.drives.drives || []
        if (dr2.length && dr2[0].plays) detailDrives = dr2.slice()
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
    var detailInjuries = d.injuries || []
    var detailStandings = d.standings || null
    var detailNews = (d.news && d.news.articles) ? d.news.articles.slice(0, 3) : []
    var detailVideos = d.videos ? d.videos.slice(0, 2) : []
    var detailTeams = { away: away, home: home, venue: venue, addr: addr, status: stType.detail || "", situation: sit }
    var detailPlayers = box.players || null
    var rosters = d.rosters || null
    var groups = [], groupMap = {}, order = []
    // Soccer uses d.rosters, not box.players
    if (rosters && rosters.length && (!box.players || !box.players.length)) {
        // Build single group for soccer from rosters
        var soccerLabels = null, soccerKeys = null
        // infer labels/keys from first player's stats
        for (var ri = 0; ri < rosters.length; ri++) {
            if (rosters[ri].roster && rosters[ri].roster.length && rosters[ri].roster[0].stats) {
                soccerLabels = rosters[ri].roster[0].stats.map(function(st){ return st.shortDisplayName || st.abbreviation || st.displayName || st.name })
                soccerKeys = rosters[ri].roster[0].stats.map(function(st){ return st.name })
                break
            }
        }
        if (!soccerLabels) soccerLabels = []
        if (!soccerKeys) soccerKeys = []
        var soccerGroup = { name: "players", displayName: "Players", labels: soccerLabels, keys: soccerKeys, away: [], home: [] }
        for (var rpi = 0; rpi < rosters.length; rpi++) {
            var rTeam = rosters[rpi]
            var rAbbr = rTeam.team ? rTeam.team.abbreviation : ""
            var isRAway = away && rAbbr === away.abbr
            var isRHome = home && rAbbr === home.abbr
            var rList = []
            for (var rj = 0; rj < (rTeam.roster || []).length; rj++) {
                var re = rTeam.roster[rj]
                // build stats array aligned to soccerLabels/keys
                var statMap = {}
                for (var sk = 0; sk < (re.stats || []).length; sk++) statMap[re.stats[sk].name] = re.stats[sk].displayValue
                var aligned = []
                for (var kk = 0; kk < soccerKeys.length; kk++) {
                    var k = soccerKeys[kk]
                    aligned.push(statMap[k] != null ? statMap[k] : "-")
                }
                rList.push({ athlete: re.athlete, stats: aligned, jersey: re.jersey, position: re.position })
            }
            if (isRAway) soccerGroup.away = rList
            else if (isRHome) soccerGroup.home = rList
            else { if (rpi === 0) soccerGroup.away = rList; else soccerGroup.home = rList }
        }
        groups.push(soccerGroup)
    } else if (box.players) {
        for (var pi = 0; pi < box.players.length; pi++) {
            var teamEntry = box.players[pi]
            var tAbbr = teamEntry.team ? teamEntry.team.abbreviation : ""
            var isAway = away && tAbbr === away.abbr
            var isHome = home && tAbbr === home.abbr
            var stats = teamEntry.statistics || []
            for (var si = 0; si < stats.length; si++) {
                var s = stats[si]
                var gname = s.name || s.type || s.text || s.displayName || "stats"
                if (!gname) gname = "stats"
                if (!groupMap[gname]) { groupMap[gname] = { name: gname, displayName: s.displayName || s.shortDisplayName || s.type || gname, labels: s.labels || s.keys || [], keys: s.keys || [], away: [], home: [] }; order.push(gname) }
                var list = s.athletes || []
                if (isAway) groupMap[gname].away = list
                else if (isHome) groupMap[gname].home = list
                else { if (pi === 0) groupMap[gname].away = list; else groupMap[gname].home = list }
                if ((!groupMap[gname].labels || groupMap[gname].labels.length === 0) && s.labels) groupMap[gname].labels = s.labels
            }
        }
        for (var gi = 0; gi < order.length; gi++) groups.push(groupMap[order[gi]])
    }
    return { detailTeams: detailTeams, detailStats: paired, detailPlayers: detailPlayers, detailPlayerGroups: groups,
        detailLeaders: detailLeaders, detailPlays: detailPlays, detailDrives: detailDrives, detailStandings: detailStandings, detailInjuries: detailInjuries,
        detailNews: detailNews, detailVideos: detailVideos }
}

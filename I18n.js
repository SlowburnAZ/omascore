.pragma library

// OmaScore i18n. English is the key language: unknown strings pass through
// unchanged, so en needs no entries and new languages are one dict entry.
// Locale detection lives in the QML files (Qt.locale() needs a QML context);
// each entry point calls setLang() once. Dictionary is shared per engine
// (.pragma library), so both BarWidget.qml and Panel.qml see the same lang.
// Strings compared in logic (e.g. lastError === "No games scheduled") stay
// English internally and are translated only at display time.

var lang = ""
var dict = {
  es: {
    // bar / panel chrome
    " live": " en vivo",
    "Back": "Atrás",
    "Settings": "Ajustes",
    "Retry": "Reintentar",
    // settings
    "Score notifications": "Notificaciones de puntuación",
    "Notify when a favorited team's score changes": "Avisa cuando cambie la puntuación de un equipo favorito",
    "Show pre-game odds": "Mostrar cuotas previas",
    "Spread and over/under on upcoming games": "Hándicap y total (O/U) de los próximos partidos",
    "Hide finished games": "Ocultar partidos terminados",
    "Hide games that have already ended": "Oculta los partidos que ya han terminado",
    "Language": "Idioma",
    // game list
    "No games scheduled": "No hay partidos programados",
    "No games %1 \u2014 next up %2": "Sin partidos %1 \u2014 siguiente %2",
    "No games %1 \u2014 try \u203A for next week": "Sin partidos %1 \u2014 pulsa \u203A para la próxima semana",
    "All games finished \u2014 unhide them in Settings": "Todos los partidos terminaron \u2014 muéstralos en Ajustes",
    "this day": "este día",
    "%1 @ %2 kicks off in %3 min": "%1 @ %2 comienza en %3 min",
    // detail tabs / sections
    "Overall": "General",
    "Players": "Jugadores",
    "Plays": "Jugadas",
    "Insights": "Análisis",
    "Leaders": "Líderes",
    "Recent Plays": "Jugadas recientes",
    "Standings": "Clasificación",
    "Injuries": "Lesionados",
    "Related": "Relacionados",
    "Player": "Jugador",
    "W": "G",
    "L": "P",
    "T": "E",
    // empty / error states
    "No details": "Sin detalles",
    "Stale data": "Datos desactualizados",
    "Response too large": "Respuesta demasiado grande",
    "Failed to load: ": "Error al cargar: ",
    "Parse error": "Error al procesar datos",
    "Loading stats\u2026": "Cargando estadísticas\u2026",
    "No stats available": "Sin estadísticas disponibles",
    "No plays available": "Sin jugadas disponibles",
    "No player stats available": "Sin estadísticas de jugadores",
    "No insights for this game": "Sin análisis para este partido",
    // dates
    "Sun": "dom", "Mon": "lun", "Tue": "mar", "Wed": "mié", "Thu": "jue", "Fri": "vie", "Sat": "sáb",
    "Jan": "ene", "Feb": "feb", "Mar": "mar", "Apr": "abr", "May": "may", "Jun": "jun",
    "Jul": "jul", "Aug": "ago", "Sep": "sep", "Oct": "oct", "Nov": "nov", "Dec": "dic",
    // ESPN stat labels (Overall table) — exact-match keys as ESPN sends them;
    // unknown labels pass through in English
    "Total": "Total",
    // soccer
    "Fouls": "Faltas", "Yellow Cards": "Tarjetas amarillas", "Red Cards": "Tarjetas rojas",
    "Offsides": "Fueras de juego", "Corner Kicks": "Tiros de esquina", "Won Corners": "Tiros de esquina",
    "Corners": "Tiros de esquina", "Saves": "Paradas", "Possession": "Posesión",
    "Ball Possession": "Posesión", "SHOTS": "TIROS", "ON GOAL": "A PUERTA",
    "Shots": "Tiros", "Shots on Goal": "Tiros a puerta", "On Target %": "% a puerta",
    "Penalty Goals": "Goles de penalti", "Penalty Kicks Taken": "Penaltis lanzados",
    "Hit Woodwork": "Al palo", "Substitutions": "Sustituciones", "Throw-ins": "Saque de banda",
    "Goal Kicks": "Saques de puerta", "Free Kicks": "Tiros libres", "Attacks": "Ataques",
    "Dangerous Attacks": "Ataques peligrosos",
    // basketball
    "Field Goals Made": "Tiros de campo anotados", "Field Goal %": "% tiros de campo",
    "3-Point FG Made": "Triples anotados", "3-Point FG %": "% triples",
    "Free Throws Made": "Tiros libres anotados", "Free Throw %": "% tiros libres",
    "Rebounds": "Rebotes", "Offensive Rebounds": "Rebotes ofensivos", "Defensive Rebounds": "Rebotes defensivos",
    "Assists": "Asistencias", "Turnovers": "Pérdidas", "Steals": "Robos", "Blocks": "Bloqueos",
    "Fast Break Points": "Puntos de contragolpe", "Points in the Paint": "Puntos en la zona",
    "Total Fouls": "Faltas", "Biggest Lead": "Mayor ventaja", "Lead Changes": "Cambios de ventaja",
    // football (NFL/CFB)
    "First Downs": "Primeros down", "Total Yards": "Yardas totales", "Passing Yards": "Yardas por pase",
    "Rushing Yards": "Yardas terrestres", "Penalties": "Penalizaciones", "Penalty Yards": "Yardas por penalización",
    "Possession Time": "Posesión", "Interceptions Thrown": "Intercepciones lanzadas",
    "Fumbles Lost": "Balones perdidos", "Sacks Allowed": "Sacks permitidos", "Third Down Eff.": "Ef. tercer down",
    "Fourth Down Eff.": "Ef. cuarto down", "Time of Possession": "Posesión",
    // hockey
    "Goals": "Goles", "Power Plays": "Jugadas de ventaja",
    "Power Play Goals": "Goles en ventaja", "Faceoffs Won": "Faceoffs ganados",
    "Penalty Minutes": "Minutos de penalización", "Hits": "Golpes", "Blocked Shots": "Tiros bloqueados",
    "Giveaways": "Pérdidas", "Takeaways": "Recuperaciones",
    // baseball
    "Hits": "Hits", "Runs": "Carreras", "Errors": "Errores", "Home Runs": "Home runs",
    "Batting Average": "Promedio de bateo", "At Bats": "Turnos al bate", "RBIs": "Carreras impulsadas",
    "Walks": "Bases por bolas", "Strikeouts": "Ponches", "Stolen Bases": "Bases robadas"
  }
}

function setLang(code) {
  lang = dict[code] ? code : ""
}

function current() {
  return lang
}

function tr(s) {
  var d = dict[lang]
  var t = (d && Object.prototype.hasOwnProperty.call(d, s)) ? d[s] : s
  for (var i = 1; i < arguments.length; i++)
    t = t.split("%" + i).join(String(arguments[i]))
  return t
}

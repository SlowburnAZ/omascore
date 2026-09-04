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
    "Refresh": "Actualizar",
    "Show Today": "Mostrar hoy",
    "Retry": "Reintentar",
    // settings
    "Score notifications": "Notificaciones de puntuación",
    "Notify when a favorited team's score changes": "Avisa cuando cambie la puntuación de un equipo favorito",
    "Finals only": "Solo finales",
    "Only notify for final scores": "Avisa solo de los resultados finales",
    "Kickoff reminders": "Avisos de inicio",
    "Off": "Desactivado",
    "Show pre-game odds": "Mostrar cuotas previas",
    "Spread and over/under on upcoming games": "Hándicap y total (O/U) de los próximos partidos",
    "Hide finished games": "Ocultar partidos terminados",
    "Hide games that have already ended": "Oculta los partidos que ya han terminado",
    "Bar display": "Visualización en la barra",
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
  },
  pt: {
    // bar / panel chrome
    " live": " ao vivo",
    "Back": "Voltar",
    "Settings": "Configurações",
    "Refresh": "Atualizar",
    "Show Today": "Mostrar hoje",
    "Retry": "Tentar novamente",
    // settings
    "Score notifications": "Notificações de placar",
    "Notify when a favorited team's score changes": "Avisa quando o placar de um time favorito mudar",
    "Finals only": "Somente finais",
    "Only notify for final scores": "Avisa apenas sobre os placares finais",
    "Kickoff reminders": "Lembretes de início",
    "Off": "Desligado",
    "Show pre-game odds": "Mostrar odds pré-jogo",
    "Spread and over/under on upcoming games": "Handicap e total (O/U) dos próximos jogos",
    "Hide finished games": "Ocultar jogos encerrados",
    "Hide games that have already ended": "Oculta os jogos que já terminaram",
    "Bar display": "Exibição na barra",
    "Language": "Idioma",
    // game list
    "No games scheduled": "Nenhum jogo agendado",
    "No games %1 \u2014 next up %2": "Sem jogos %1 \u2014 próximo %2",
    "No games %1 \u2014 try \u203A for next week": "Sem jogos %1 \u2014 toque \u203A para a próxima semana",
    "All games finished \u2014 unhide them in Settings": "Todos os jogos encerrados \u2014 reexiba-os em Configurações",
    "this day": "este dia",
    "%1 @ %2 kicks off in %3 min": "%1 @ %2 começa em %3 min",
    // detail tabs / sections
    "Overall": "Geral",
    "Players": "Jogadores",
    "Plays": "Jogadas",
    "Insights": "Análises",
    "Leaders": "Líderes",
    "Recent Plays": "Jogadas recentes",
    "Standings": "Classificação",
    "Injuries": "Lesionados",
    "Related": "Relacionados",
    "Player": "Jogador",
    "W": "V",
    "L": "D",
    "T": "E",
    // empty / error states
    "No details": "Sem detalhes",
    "Stale data": "Dados desatualizados",
    "Response too large": "Resposta muito grande",
    "Failed to load: ": "Falha ao carregar: ",
    "Parse error": "Erro ao processar dados",
    "Loading stats\u2026": "Carregando estatísticas\u2026",
    "No stats available": "Sem estatísticas disponíveis",
    "No plays available": "Sem jogadas disponíveis",
    "No player stats available": "Sem estatísticas de jogadores",
    "No insights for this game": "Sem análises para este jogo",
    // dates
    "Sun": "dom", "Mon": "seg", "Tue": "ter", "Wed": "qua", "Thu": "qui", "Fri": "sex", "Sat": "sáb",
    "Jan": "jan", "Feb": "fev", "Mar": "mar", "Apr": "abr", "May": "mai", "Jun": "jun",
    "Jul": "jul", "Aug": "ago", "Sep": "set", "Oct": "out", "Nov": "nov", "Dec": "dez",
    // ESPN stat labels — unknown labels pass through in English
    "Total": "Total",
    // soccer
    "Fouls": "Faltas", "Yellow Cards": "Cartões amarelos", "Red Cards": "Cartões vermelhos",
    "Offsides": "Impedimentos", "Corner Kicks": "Escanteios", "Won Corners": "Escanteios",
    "Corners": "Escanteios", "Saves": "Defesas", "Possession": "Posse",
    "Ball Possession": "Posse", "SHOTS": "FINALIZAÇÕES", "ON GOAL": "NO ALVO",
    "Shots": "Finalizações", "Shots on Goal": "Finalizações no alvo", "On Target %": "% no alvo",
    "Penalty Goals": "Gols de pênalti", "Penalty Kicks Taken": "Pênaltis cobrados",
    "Hit Woodwork": "Na trave", "Substitutions": "Substituições", "Throw-ins": "Laterais",
    "Goal Kicks": "Tiros de meta", "Free Kicks": "Faltas cobradas", "Attacks": "Ataques",
    "Dangerous Attacks": "Ataques perigosos",
    // basketball
    "Field Goals Made": "Cestas de quadra", "Field Goal %": "% de quadra",
    "3-Point FG Made": "Cestas de três", "3-Point FG %": "% de três",
    "Free Throws Made": "Lances livres", "Free Throw %": "% lances livres",
    "Rebounds": "Rebotes", "Offensive Rebounds": "Rebotes ofensivos", "Defensive Rebounds": "Rebotes defensivos",
    "Assists": "Assistências", "Turnovers": "Perdas", "Steals": "Roubos", "Blocks": "Tocos",
    "Fast Break Points": "Pontos de bola rápida", "Points in the Paint": "Pontos no garrafão",
    "Total Fouls": "Faltas", "Biggest Lead": "Maior vantagem", "Lead Changes": "Trocas de liderança",
    // football (NFL/CFB)
    "First Downs": "Primeiros downs", "Total Yards": "Jardas totais", "Passing Yards": "Jardas por passe",
    "Rushing Yards": "Jardas terrestres", "Penalties": "Penalidades", "Penalty Yards": "Jardas de penalidade",
    "Possession Time": "Posse", "Interceptions Thrown": "Interceptações lançadas",
    "Fumbles Lost": "Fumbles perdidos", "Sacks Allowed": "Sacks sofridos", "Third Down Eff.": "Ef. terceiro down",
    "Fourth Down Eff.": "Ef. quarto down", "Time of Possession": "Posse",
    // hockey
    "Goals": "Gols", "Power Plays": "Vantagens numéricas",
    "Power Play Goals": "Gols em vantagem", "Faceoffs Won": "Faceoffs ganhos",
    "Penalty Minutes": "Minutos de penalidade", "Hits": "Jogadas físicas", "Blocked Shots": "Finalizações bloqueadas",
    "Giveaways": "Perdas", "Takeaways": "Recuperações",
    // baseball
    "Hits": "Hits", "Runs": "Corridas", "Errors": "Erros", "Home Runs": "Home runs",
    "Batting Average": "Média de rebatidas", "At Bats": "Vezes ao bastão", "RBIs": "Corridas impulsionadas",
    "Walks": "Bases por bolas", "Strikeouts": "Eliminações", "Stolen Bases": "Bases roubadas"
  },
  nl: {
    // bar / panel chrome
    " live": " live",
    "Back": "Terug",
    "Settings": "Instellingen",
    "Refresh": "Vernieuwen",
    "Show Today": "Toon vandaag",
    "Retry": "Opnieuw proberen",
    // settings
    "Score notifications": "Scoormeldingen",
    "Notify when a favorited team's score changes": "Meldt wanneer de score van een favoriet team verandert",
    "Finals only": "Alleen eindstanden",
    "Only notify for final scores": "Meld alleen eindstanden",
    "Kickoff reminders": "Aftrapmeldingen",
    "Off": "Uit",
    "Show pre-game odds": "Wedkansen voor de wedstrijd tonen",
    "Spread and over/under on upcoming games": "Handicap en totaal (O/U) van komende wedstrijden",
    "Hide finished games": "Afgelopen wedstrijden verbergen",
    "Hide games that have already ended": "Verbergt wedstrijden die al zijn afgelopen",
    "Bar display": "Balkweergave",
    "Language": "Taal",
    // game list
    "No games scheduled": "Geen wedstrijden gepland",
    "No games %1 \u2014 next up %2": "Geen wedstrijden %1 \u2014 hierna %2",
    "No games %1 \u2014 try \u203A for next week": "Geen wedstrijden %1 \u2014 tik \u203A voor volgende week",
    "All games finished \u2014 unhide them in Settings": "Alle wedstrijden afgelopen \u2014 maak ze zichtbaar in Instellingen",
    "this day": "deze dag",
    "%1 @ %2 kicks off in %3 min": "%1 @ %2 begint over %3 min",
    // detail tabs / sections
    "Overall": "Algemeen",
    "Players": "Spelers",
    "Plays": "Spelmomenten",
    "Insights": "Analyses",
    "Leaders": "Leiders",
    "Recent Plays": "Recente spelmomenten",
    "Standings": "Stand",
    "Injuries": "Geblesseerden",
    "Related": "Gerelateerd",
    "Player": "Speler",
    "W": "W",
    "L": "V",
    "T": "G",
    // empty / error states
    "No details": "Geen details",
    "Stale data": "Verouderde gegevens",
    "Response too large": "Reactie te groot",
    "Failed to load: ": "Laden mislukt: ",
    "Parse error": "Fout bij verwerken gegevens",
    "Loading stats\u2026": "Statistieken laden\u2026",
    "No stats available": "Geen statistieken beschikbaar",
    "No plays available": "Geen spelmomenten beschikbaar",
    "No player stats available": "Geen spelerstatistieken beschikbaar",
    "No insights for this game": "Geen analyses voor deze wedstrijd",
    // dates
    "Sun": "zo", "Mon": "ma", "Tue": "di", "Wed": "wo", "Thu": "do", "Fri": "vr", "Sat": "za",
    "Jan": "jan", "Feb": "feb", "Mar": "mrt", "Apr": "apr", "May": "mei", "Jun": "jun",
    "Jul": "jul", "Aug": "aug", "Sep": "sep", "Oct": "okt", "Nov": "nov", "Dec": "dec",
    // ESPN stat labels — unknown labels pass through in English
    "Total": "Totaal",
    // soccer
    "Fouls": "Overtredingen", "Yellow Cards": "Gele kaarten", "Red Cards": "Rode kaarten",
    "Offsides": "Buitenspels", "Corner Kicks": "Corners", "Won Corners": "Corners",
    "Corners": "Corners", "Saves": "Reddingen", "Possession": "Balbezit",
    "Ball Possession": "Balbezit", "SHOTS": "SCHOT", "ON GOAL": "OP DOEL",
    "Shots": "Schoten", "Shots on Goal": "Schoten op doel", "On Target %": "% op doel",
    "Penalty Goals": "Penalty-doelpunten", "Penalty Kicks Taken": "Penalty's genomen",
    "Hit Woodwork": "Op de lat", "Substitutions": "Wissels", "Throw-ins": "Inworpen",
    "Goal Kicks": "Doelschoppen", "Free Kicks": "Vrije trappen", "Attacks": "Aanvallen",
    "Dangerous Attacks": "Gevaarlijke aanvallen",
    // basketball
    "Field Goals Made": "Veldscheentjes", "Field Goal %": "% veldscheentjes",
    "3-Point FG Made": "Drie-punters", "3-Point FG %": "% drie-punters",
    "Free Throws Made": "Vrije worpen", "Free Throw %": "% vrije worpen",
    "Rebounds": "Rebounds", "Offensive Rebounds": "Offensieve rebounds", "Defensive Rebounds": "Defensieve rebounds",
    "Assists": "Assists", "Turnovers": "Balverlies", "Steals": "Steals", "Blocks": "Blocks",
    "Fast Break Points": "Fastbreak-punten", "Points in the Paint": "Punten in de paint",
    "Total Fouls": "Overtredingen", "Biggest Lead": "Grootste voorsprong", "Lead Changes": "Wissels van voorsprong",
    // football (NFL/CFB)
    "First Downs": "First downs", "Total Yards": "Totale yards", "Passing Yards": "Passing yards",
    "Rushing Yards": "Rushing yards", "Penalties": "Penalties", "Penalty Yards": "Penalty-yards",
    "Possession Time": "Balbezit", "Interceptions Thrown": "Intercepties gegooid",
    "Fumbles Lost": "Fumbles verloren", "Sacks Allowed": "Sacks toegestaan", "Third Down Eff.": "Eff. derde down",
    "Fourth Down Eff.": "Eff. vierde down", "Time of Possession": "Balbezit",
    // hockey
    "Goals": "Doelpunten", "Power Plays": "Powerplays",
    "Power Play Goals": "Powerplay-doelpunten", "Faceoffs Won": "Faceoffs gewonnen",
    "Penalty Minutes": "Penaltyminuten", "Hits": "Hits", "Blocked Shots": "Schoten geblokkeerd",
    "Giveaways": "Balverlies", "Takeaways": "Pakkens",
    // baseball
    "Hits": "Hits", "Runs": "Punten", "Errors": "Fouten", "Home Runs": "Home runs",
    "Batting Average": "Slaggemiddelde", "At Bats": "Slagbeurten", "RBIs": "RBI's",
    "Walks": "Free walks", "Strikeouts": "Strikeouts", "Stolen Bases": "Geslagen bases"
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

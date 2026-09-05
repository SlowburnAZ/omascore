# OmaScore: live sports in your Omarchy bar

Live scores for **15 leagues** — NFL, CFB, NBA, WNBA, NCAAM, NCAAW, MLB, NHL, MLS, EPL, LaLiga, Bundesliga, Serie A, Ligue 1, UCL — with your favorite teams pinned, right in the Omarchy shell bar.

```
omarchy plugin add https://github.com/SlowburnAZ/omascore.git --enable
```

---

**The bar: your teams, at a glance**

The widget tints and shows your favorite team's live score the moment their game starts: `★ LV 0-0`. It rotates through multiple favorites at once and covers **every league you have a favorite in, on every monitor**. Tooltips carry the full game line. Prefer quieter? Settings switches the widget to live count, next-game start time, or icon-only.

*(attach: bar-live.png)*

**The panel: the whole slate**

Open the widget for the full scoreboard: a league switcher with favorites sorted first, a **★ Favorites** view spanning every league at once, a 7-day selector with game-count dots, a team filter on busy days, refresh and today shortcuts, team logos, live scores in accent, kickoff times in **your** timezone and locale format, and betting lines on upcoming games. Star a team and its row glides into place as the board updates.

*(attach: games_panel.png)*

**Tap a game for the full picture**

Team-colored head-to-head stats with a split bar per row, pre-game matchup predictor, player stat tables, full play-by-play, injuries, and conference standings — your two teams pinned in view, with live games refreshing in place. For NFL and CFB, a live situation line tracks the drive: `PIT 4th & 12 at BUF 31`.

*(attach: game_detail.png)*

**It watches the games so you don't have to**

Score, final, and kickoff-reminder notifications for your favorites, working with the panel closed — finals-only and a configurable reminder window keep them at the level you want. Adaptive polling runs every 25s for live favorites and backs off to 2 minutes when nothing is on.

**Also in the box**

- Fully keyboard-driven: `↑/↓` to move, `Enter` to open, `Esc` steps back
- Settings grouped into notifications, display, and language — in English, Spanish, Portuguese, or Dutch
- Reopens on your last league with favorites restored

Everything runs through the ESPN public API via `curl`. No keys, no accounts, no setup beyond favoriting your teams.

---

*Data provided by ESPN · Not affiliated with or endorsed by ESPN · for personal, non-commercial use.*

*Omarchy shell plugin · MIT · [github.com/SlowburnAZ/omascore](https://github.com/SlowburnAZ/omascore)*

# OmaScore: live sports in your Omarchy bar

Live scores for **15 leagues** — NFL, CFB, NBA, WNBA, NCAAM, NCAAW, MLB, NHL, MLS, EPL, LaLiga, Bundesliga, Serie A, Ligue 1, UCL — with your favorite teams pinned, right in the Omarchy shell bar.

```
omarchy plugin add https://github.com/SlowburnAZ/omascore.git --enable
```

---

**The bar: your teams, at a glance**

The widget tints and shows your favorite team's live score the moment their game starts: `★ LV 0-0`. It rotates through multiple favorites at once and covers **every league you have a favorite in, on every monitor**. Tooltips carry the full game line.

*(attach: bar-live.png)*

**The panel: the whole slate**

Open the widget for the full scoreboard: a league switcher with favorites sorted first, a 7-day selector with game-count dots, team logos, live scores in accent, kickoff times in **your** timezone, and betting lines on upcoming games. Star a team and its row glides into place as the board updates.

*(attach: games_panel.png)*

**Tap a game for the full picture**

Team-colored head-to-head stats with a split bar per row, player stat tables, full play-by-play, injuries, and conference standings — your two teams pinned in view. For NFL and CFB, a live situation line tracks the drive: `PIT 4th & 12 at BUF 31`.

*(attach: game_detail.png)*

**It watches the games so you don't have to**

Score, final, and kickoff-reminder notifications for your favorites, working with the panel closed. Adaptive polling runs every 25s for live favorites and backs off to 2 minutes when nothing is on.

**Also in the box**

- Fully keyboard-driven: `↑/↓` to move, `Enter` to open, `Esc` steps back
- Settings: notifications, odds, hiding finished games
- Reopens on your last league with favorites restored

Everything runs through the ESPN public API via `curl`. No keys, no accounts, no setup beyond favoriting your teams.

---

*Data provided by ESPN · Not affiliated with or endorsed by ESPN · for personal, non-commercial use.*

*Omarchy shell plugin · MIT · [github.com/SlowburnAZ/omascore](https://github.com/SlowburnAZ/omascore)*

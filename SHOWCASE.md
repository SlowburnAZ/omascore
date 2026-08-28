# OmaScore — live sports in your Omarchy bar

Live scores for **15 leagues** — NFL, CFB, NBA, WNBA, NCAAM, NCAAW, MLB, NHL, MLS, EPL, LaLiga, Bundesliga, Serie A, Ligue 1, UCL — with your favorite teams pinned, right in the Omarchy shell bar.

```
omarchy plugin add https://github.com/SlowburnAZ/omascore.git --enable
```

---

**The bar: your teams, at a glance**

The widget tints and shows your favorite team's live score the moment their game starts — `★ LV 0-0` — and rotates through multiple favorites if several are playing at once. Tooltips carry the full game line.

*(attach: bar-live.png)*

**The panel: the whole slate**

Open the widget for the full scoreboard: a league switcher with your favorite leagues sorted first, a 7-day selector with game-count dots, team logos, and every game's status — live scores in accent, kickoff times in **your** timezone, and betting lines (spread + O/U) on upcoming games.

*(attach: panel-games.png)*

**Tap a game for the full picture**

Team stats head-to-head, player stat tables, full play-by-play, injuries, and conference standings with your two teams always in view — even mid-table. For NFL and CFB, a live situation line tracks the drive: `PIT 4th & 12 at BUF 31`, updating as the game moves.

*(attach: game-detail.png)*

**It watches the games so you don't have to**

- Desktop notification the moment a favorited team **scores**
- **Final** score notification when their game ends (rainouts don't fool it)
- **Kickoff reminder** 10 minutes before a favorite takes the field
- Plays happen even with the panel closed — adaptive polling runs 25s for live favorites, backing off to 2 minutes when nothing is on

**Small things that add up**

- Reopens on your last league; scoreboard paints instantly from cache, even after a reboot
- Fully keyboard-driven panel: `↑/↓` to move, `Enter` to open, `Esc` steps back
- Settings screen (gear icon): toggle notifications, odds, and hiding finished games
- Scores flash accent in the panel the moment they change

Everything runs through the ESPN public API via `curl` — no keys, no accounts, no setup beyond favoriting your teams.

---

*Omarchy shell plugin · MIT · [github.com/SlowburnAZ/omascore](https://github.com/SlowburnAZ/omascore)*

# SPEC: Price Ticker + Hall of Shame

## Overview
Add a real-time pump.fun price ticker to the HUD, a "buy on pump.fun" link on the title screen, and a local-only "Hall of Shame" leaderboard tracking the player's best/worst stats across all saves. Zero backend, zero wallet, zero ongoing cost.

---

## 1. Price Ticker

### Data Source
- pump.fun public API: `https://frontend-api.pump.fun/api/coin/{MINT_ADDRESS}`
- Poll interval: 30 seconds
- Fallback: if API fails, show stale data with "(stale)" suffix

### Display
- HUD: new line in right column, below wanted stars
- Format: `CRUMB  $0.000034  |  MC $12.4K  |  LIQ 42 SOL`
- Color: dirty cream (`var(--cream)`), number in piss yellow (`var(--piss)`)
- Updates in-place, no animation

### Configuration
- `src/config/token.js` exports `TOKEN_MINT` (string, empty by default)
- Operator pastes mint address post-launch
- If empty, ticker hidden, buy link hidden

---

## 2. Buy Link

### Location
- Title screen: new line under `[ L ] load save`
- Text: `buy crumb on pump.fun`
- Click → `window.open('https://pump.fun/' + TOKEN_MINT, '_blank')`
- Style: same as `.load` link (dim, hover→piss yellow)

---

## 3. Hall of Shame

### Storage
- Key: `rockbottom_hall_of_shame` in `window.storage` (IndexedDB)
- Single object, updated on every `saveGame()` and relevant events
- Survives save deletion, browser restart, incognito (IndexedDB)

### Tracked Stats (Best — Higher is Better)
| Key | Source | Description |
|-----|--------|-------------|
| `mostRocksSmoked` | `P.lifetime.rocksSmoked` on save | Total real rocks smoked |
| `highestCred` | `P.cred` on save | Peak cred reached |
| `longestSurvival` | `state.day` on save | Highest day reached |
| `mostChipsBanked` | `P.chipsBanked` on save | Peak chips in cage |
| `mostCopperStripped` | `state.counters.copperStripped` on save | Total copper stripped |
| `mostRoutesFiled` | `P.lifetime.routesCompleted` on save | Block routes completed |
| `mostBossKills` | Count of {tony, brutus_older, omalley_fallen} dead | Unique bosses defeated |

### Tracked Stats (Worst — Higher is "Worse")
| Key | Source | Description |
|-----|--------|-------------|
| `mostDeaths` | Increment on `die()` | Times died to NPC/environment |
| `mostArrests` | Increment on `arrestScene()` | Times arrested |
| `mostSoapSmoked` | Increment on soap rock smoke | Soap rocks smoked |
| `highestShakesPeak` | Max `P.shakes` observed | Highest withdrawal |
| `mostMoneyLostToCops` | Sum of `lostCash` on arrest | Cash confiscated |
| `longestCrashStreak` | Consecutive crashes without smoking | Crash→crash→crash count |
| `mostTimesDogPet` | Increment on pet dog interaction | Dog pets given |
| `mostCrownAttempts` | Increment on `pigeon_crown` quest start | Crown quest attempts |
| `mostPotholeArgumentsLost` | Increment on pothole dialogue loss | Arguments lost to pothole |

### Save ID
- Each save gets persistent `saveId` (e.g., `save_1`, `save_2`) assigned on first save
- Stored in save file under `player.saveId`
- Hall of Shame records which `saveId` achieved each record

### UI
- Title screen: `[ HALL OF SHAME ]` button (between Start and Load)
- Opens panel (same style as inventory/quest panel)
- Two columns: **BEST CRACKHEAD** / **WORST CRACKHEAD**
- Each row: label + value + saveId + day
- Bottom: `[ CLEAR RECORD ]` — confirms, wipes hall, toast "the neighborhood forgets."

### Update Triggers
- `saveGame()` → evaluate all "best" stats
- `die()` → `mostDeaths++`, check `longestSurvival`, `highestShakesPeak`
- `arrestScene()` → `mostArrests++`, `mostMoneyLostToCops += lostCash`
- `smokeRockAt()` → if soap: `mostSoapSmoked++`; else: check `mostRocksSmoked`, reset `crashStreak`; if crash: `crashStreak++`, check `longestCrashStreak`
- Dog pet interaction → `mostTimesDogPet++`
- Pigeon crown quest start → `mostCrownAttempts++`
- Pothole argument lost → `mostPotholeArgumentsLost++`

---

## Files to Create
1. `src/config/token.js` — mint address config
2. `src/systems/hall_of_shame.js` — logic, storage, evaluation
3. `src/ui/hall_of_shame.js` — panel render

## Files to Modify
1. `src/main.js` — import/init new modules
2. `src/core/audio_save.js` — pass hall of shame update to saveGame
3. `src/systems/combat.js` — call hallOfShame on die/arrest
4. `src/systems/concessions.js` — call hallOfShame on smoke
5. `src/ui/hud.js` — render price ticker line
6. `src/core/update.js` — poll price ticker (or separate timer)
7. `index.html` — title screen button, panel CSS, buy link

---

## Invariants
- **No network requests in gameplay loop** — price poll is independent timer
- **No wallet, no signing, no transactions** — pure read + local write
- **Hall of Shame never affects gameplay** — purely cosmetic
- **Save compatible** — new fields additive, old saves work
- **VIBE tone** — lowercase, flat, specific, no celebration

---

## Edge Cases
- API rate limit / failure → show last good data + "(stale)"
- Mint address empty → hide ticker and buy link entirely
- Hall of Shame storage quota exceeded → silent fail, no game impact
- Multiple saves same day → each gets unique saveId
- Clear record → resets hall, generates new saveId on next save
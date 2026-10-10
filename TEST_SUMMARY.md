# 🧪 Test Summary — GRIDLOCK

## Result: ✅ 128 / 128 checks passing

| Suite | File | Checks | Status |
|-------|------|-------:|--------|
| Rules unit tests | `tests/test_runner.tscn` | 105 | ✅ PASS |
| Drag integration | `tests/smoke_drag.tscn` | 23 | ✅ PASS |

Run everything with:

```bash
./run_tests.sh
```

Each suite exits non-zero on failure, so the script is CI-safe.

---

## Suite 1 — Rules (`GameRules`)

Deterministic (`RandomNumberGenerator` seeded), no rendering required.

### Piece Library
- Every shape is normalised (minimum column/row are `0`).
- Every shape has at least one cell.
- Weights are positive.

### Placement
- The grid is 10×10.
- A line fits at the origin and is rejected past the right and bottom edges.
- A placed piece fills its cells.
- A filled cell blocks further placement.

### Line Clearing
- A row with a gap is not complete.
- Completing a row clears it immediately.
- Completing a column clears it immediately.

### Scoring & Streaks
- A single line scores 100.
- The streak starts at 1 after the first clear.
- Two lines score 300 (`2 × 100 × 1.5` multiline bonus).
- A consecutive clear grows the streak to 2 and applies the streak bonus.
- A non-clearing placement resets the streak to 0.

### Near-Complete Hints (`clearing_candidates`)
- An empty grid has no near-complete lines.
- A one-cell row gap reports exactly one candidate.
- The candidate names the correct row and pins the missing cell.
- Row and column gaps both report candidates.
- A row with two gaps reports nothing.
- Completing a row removes its candidate.

### Best Streak
- Best streak starts at zero, records the first clear, and grows with a chain.
- Best streak **survives** a streak reset (it is a high-water mark).

### Tray
- A new game deals exactly three pieces.
- Used pieces leave the tray.
- An emptied tray refills to three.

### Game Over
- A single empty cell still allows a dot.
- A checkerboard blocks every line piece (`has_any_move()` is false).
- `is_over` always mirrors `has_any_move()` after a placement.

---

## Suite 2 — Drag Integration (`smoke_drag`)

Boots the real `scenes/game.tscn` headlessly and verifies the wiring end to end.

- Tray shows three pieces.
- Board lays out with a positive cell pitch, a sensible size, and sits above the
  tray.
- Every tray piece is hit-testable and stays within the screen width.
- Grabbing a tray piece *by its rect* starts a drag (this caught a real layout
  bug where container sizing collapsed the pieces to 0×0).
- A ghost piece is created for the drag.
- Releasing drops the tile: it is drawn on the board, recorded in the rules and
  removed from the tray.
- The near-complete hints exposed by the rules refresh onto the board's pins.
- The pause overlay opens (and pauses the tree) and resume restores it.
- The game-over overlay builds and "restart" closes it; games-played stats
  advance across restarts.

---

## Why This Matters

The original project passed 301 assertions while being completely broken at
runtime, because the tests exercised the game manager in isolation and never
wired it into a scene. This suite adds a **headless integration test that boots
the real scene and performs a real drag**, which is what caught the tray layout
regression. Rules stay pure and fast; presentation is verified end-to-end.

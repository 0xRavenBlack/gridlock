# Project Plan

**Progress:** [██████████] 100% (8/8) — Phase 1 · [██████████] 100% (8/8) — Phase 2

**Objective:** Rebuild the broken original Godot project into a fully working,
polished, full-screen game, then give it a strong identity and a game-design
pass that makes it genuinely fun to plan around.

**Clean Code Commitment:** The rewrite follows Clean Code principles — pure
logic separated from presentation, small focused classes, a single source of
truth for tuning values, no duplicated style logic and no dead code.

## Phase 1 — Foundation

- [x] Step 1: Diagnose the original project and confirm the runtime failures
- [x] Step 2: Define the architecture (pure `GameRules` + autoload services + scene layer)
- [x] Step 3: Implement `scripts/core/` — constants, rules, pieces, bag, tones, styling
- [x] Step 4: Implement autoloads (`SaveManager`, `AudioManager`, `Game`) and the game scene
- [x] Step 5: Implement the neon UI — menu, settings, overlays, physics-style FX
- [x] Step 6: Replace the test suite with pure-rules tests + a headless drag integration test
- [x] Step 7: Rewrite `project.godot` (autoloads, 540×960, full-screen, Godot 4.7)
- [x] Step 8: Verify headlessly (113/113 checks) and export the Linux binary

## Phase 2 — Game Design Pass ("GRIDLOCK")

The brief: the game was mechanically complete but *flat* — no reason to plan
ahead, big clears didn't feel big, the background was static and there was no
music. Phase 2 answered that with a new identity and real feel upgrades.

- [x] Step 1: Rebrand to **GRIDLOCK — Chain the Lights** (name, docs, binary, save migration)
- [x] Step 2: Pure-rule **near-complete line hints** (`GameRules.clearing_candidates`)
- [x] Step 3: **Best-streak** tracking and lifetime stats (games / lines / blocks)
- [x] Step 4: Board presentation — pinned missing cells + pulsing hint frame
- [x] Step 5: Clear feedback — sweeping light beams, tiered DOUBLE/TRIPLE/MEGA banners
- [x] Step 6: Audio — tiered clear pitches, "mega"/"new best" stings, generated music loop
- [x] Step 7: Juiced background shader (drifting glows, rising lattice, dust, vignette)
- [x] Step 8: Extend tests (hints, best streak, hint refresh, stats) and verify 128/128

## Verification Evidence

- `./run_tests.sh` → 105 rules assertions + 23 integration checks (**128/128**).
- `godot --headless --path . --scene scenes/game.tscn --quit-after 120` → no
  errors, warnings or leaked objects (menu and settings likewise).

# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## What this is

A Godot 4.7 neon block puzzle inspired by the classic **1010!**. Portrait,
full-screen, smooth neon/glossy UI (no pixel art, no bitmap assets). Drag one of
three tray pieces onto a 10×10 board; complete rows/columns to clear them and
score; the run ends when no remaining piece fits — *gridlock*. Lines that are
one cell from clearing pulse the board and pin the missing cell.

The whole thing is built in GDScript and generated at runtime: artwork comes
from code-drawn `StyleBox`es plus one shader, and all sound — SFX *and* an
ambient music loop — is synthesized as PCM at startup. There are no
`.png`/`.wav`/font assets to manage.

## Quick commands

```bash
godot --path .                       # run from source (main menu, full-screen)
./run_tests.sh                       # all tests (rules + integration), CI-safe
./build.sh                           # test, then export a Linux release to build/
./build.sh --windows                 # cross-compile a Windows release (from Linux)
./build.sh --all                     # export both Linux and Windows
./build.sh --skip-tests --clean      # fast clean rebuild
./build.sh --help                    # all build options
godot --headless --path . --scene scenes/game.tscn --quit-after 90   # smoke-run a scene
```

`run_tests.sh` exits non-zero on failure. `build.sh` runs the tests as a gate
unless `--skip-tests` is passed.

## Environment

- **Godot 4.7+** (Forward Plus). The installed editor here is `4.7.2.stable`.
- The project declares `config/features=PackedStringArray("4.7", "Forward Plus")`.
- Everything except final visual checks can run **headless** (`--headless`).
- Exporting needs the matching export templates in
  `~/.local/share/godot/export_templates/<version>/` (`build.sh` checks this).
  Linux needs `linux_{release,debug}.x86_64`; Windows cross-exports need
  `windows_{release,debug}_x86_64.exe`.
- `wine` is only used to **smoke test** a Windows build (`build.sh --windows`);
  the cross-export itself does not need it. Pass `--no-verify` to skip.
- No GPU/X server is assumed in CI; do not add steps that require a display.

## Architecture

Hard separation between **rules** and **presentation**. This is the single most
important convention in the repo.

```
            input                       signals
   game/game.gd  ──►  Game (autoload)  ──►  game/game.gd
   (drag → placement)   .rules: GameRules     (draws + plays FX)
```

- **`GameRules`** (`scripts/core/game_rules.gd`, a `RefCounted`) is the
  authoritative game state: grid, tray, score, streak, best streak, near-complete
  line hints and game-over. It has **no node, input or rendering knowledge**. It
  emits `score_changed`, `streak_changed`, `tray_changed` and
  `placement_resolved`.
- **`Game`** (autoload, `scripts/autoload/game.gd`) owns one `GameRules`
  instance (`Game.rules`) plus the persisted best score and lifetime stats. All
  gameplay code goes through `Game.resolve_placement(...)`; never instantiate a
  second `GameRules` for a real game, or the UI will disagree with the rules.
- **`scripts/game/game.gd`** is the scene controller. It reads input, calls the
  rules, and renders the returned `result` Dictionary. It holds no rules.

Autoloads (declared in `project.godot`), in load order:

| Autoload | File | Responsibility |
|----------|------|----------------|
| `SaveManager` | `scripts/autoload/save_manager.gd` | `ConfigFile` persistence (`user://gridlock_save.cfg`, migrates the legacy 1010 save) |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | generated SFX bank + music loop + `AudioStreamPlayer` pool |
| `Game` | `scripts/autoload/game.gd` | current `GameRules` + best score + lifetime stats |

## Directory map

```
scripts/core/     Pure / engine-light helpers (RefCounted, static where possible)
  game_constants.gd  ALL tuning values + palette (single source of truth)
  game_rules.gd      ★ authoritative rules
  piece.gd           a piece: id, cells (Array[Vector2i]), colour
  piece_library.gd   shape catalogue + draw weights + colour-by-prefix
  piece_bag.gd       weighted shuffle-bag draw
  tone_factory.gd    runtime PCM `AudioStreamWAV` tones, arpeggios and the
                     stereo chill-out ambient bed
  neon_style.gd      cached glossy `StyleBoxFlat`s
  ui_kit.gd          themed Label/Button factory
  display_util.gd    full-screen persistence (headless-safe)
scripts/autoload/  Global services (see table above)
scripts/game/      Gameplay presentation
  board_cell.gd      one visual tile (fill / preview / hint pin; draw-only)
  board.gd           10×10 field; hints, grid↔screen coordinate mapping
  piece_view.gd      a piece drawn as a tile grid (tray + drag ghost)
  tray.gd            three-piece tray
  game.gd            scene controller: input, placement, FX, overlays
scripts/ui/        Screens
  overlay.gd         reusable modal card (pause / game over)
  main_menu.gd       animated title screen
  settings.gd        audio + display settings
scenes/            Minimal .tscn roots: a node + its script. UI is built in code.
tests/             Headless test suites (see Testing)
build/             Generated release artifacts — never edit, safe to delete
```

## Conventions

- **Clean Code first.** Small, single-purpose functions; intention-revealing
  names; no dead code; no magic numbers (put them in `GameConstants`).
- **GDScript style:** tabs for indentation, typed signatures
  (`func f(x: int) -> void`), `:=` inference where the type is obvious, one
  `class_name` per reusable class. Private members are prefixed `_`.
- **`##` doc comments** on classes and non-obvious methods.
- **Pure logic stays pure.** If a change is about *what the game does* it
  belongs in `GameRules`; if it is about *how it looks or feels* it belongs in
  `scripts/game/` or `scripts/ui/`.
- **Build UI in code**, not in `.tscn`. Scene files are intentionally just a
  root node plus a script reference (this avoids hand-authored `.tscn` bugs).
- **Reuse styling.** Add shared widget looks to `NeonStyle` / `UiKit` rather
  than styling ad hoc in a scene.
- **Prefer signals** over polling so the rules and views stay decoupled.

## Invariants and gotchas

- **Grid indexing is column-major: `grid[x][y]`.** Easy to get backwards.
  `Vector2i` is used as `(x, y)` throughout.
- **Design space is a fixed 540×960 logical canvas** with
  `stretch/mode=canvas_items`, `aspect=expand`. Lay out and reason in those
  units; the viewport scales to the window.
- **Full-screen is the default** and persisted. `DisplayUtil` guards against the
  headless display server (`DisplayServer.get_name() == "headless"`), so keep
  display calls behind it.
- **Drag is handled globally**, not per-piece: `scripts/game/game.gd` uses
  `_unhandled_input` + `get_global_mouse_position()`, and tray `PieceView`s have
  `mouse_filter = IGNORE`. Do not attach per-piece input handling.
- **A `PieceView` must set `custom_minimum_size`** to its content size. A plain
  `Control` reports a minimum of `0`, and `CenterContainer` will collapse it to
  `0×0` and make it unclickable (this was a real bug). The integration test
  guards it.
- **`GameRules` uses `tray.erase(piece)`** (identity), and refills the tray only
  when it becomes empty.
- **Determinism:** `GameRules.new()` randomizes the bag; pass a seeded
  `RandomNumberGenerator` in tests.
- Never edit generated files/dirs: `.godot/`, `*.uid`, `build/`.

## Common tasks

**Tune gameplay or layout** — edit `scripts/core/game_constants.gd`. Scoring,
grid size, tray size, gaps, palette and timing all live there. Do not scatter
these values.

**Add or adjust a piece** — edit `PieceLibrary.SHAPES` (cell offsets, in any
orientation; they are normalised to the origin) and set its frequency in
`PieceLibrary.WEIGHTS`. Colour is chosen from the shape's name prefix in
`PieceLibrary.color_for`; add a prefix branch if you introduce a new family.

**Add a sound** — add an entry to `AudioManager.SOUND_SPECS` (a `tone`, `chord`,
`rise` or `chillout` spec) and play it with `AudioManager.play("name")`. The
`chillout` spec drives the looping ambient bed and is the only sound built on a
worker thread (it is the expensive one). No audio files.

**Change a screen's look** — build/modify nodes in the relevant script; add
reusable looks to `NeonStyle`. Add new palette entries to `GameConstants`.

**Change scoring/clearing behaviour** — do it in `GameRules` and extend the
rules tests. Near-complete line hints come from `GameRules.clearing_candidates()`;
the board and `game.gd` only render that data.

## Testing

Two headless suites, both wired into `./run_tests.sh`:

1. **`tests/test_runner.tscn`** — pure `GameRules`/`PieceLibrary` unit tests
   (placement, clearing, scoring, streaks, hints, best streak, tray, game-over).
   Deterministic, seeded. Runs immediately and calls `get_tree().quit(status)`.
2. **`tests/smoke_drag.tscn`** — boots the **real** `scenes/game.tscn` and
   drives a full drag (grab by rect → ghost → drop), verifies hint refresh, then
   exercises the pause/game-over overlays and layout geometry.

Guidelines:

- Put rule changes behind assertions in `test_runner.gd`.
- Put wiring/rendering/layout changes behind assertions in `smoke_drag.gd`;
  this suite is what catches "logic passes but the game is broken" regressions.
- Keep checks deterministic; seed any RNG.
- A suite must `quit(0)` on success and `quit(1)` on failure.

**Definition of done for any change:**

```bash
./run_tests.sh        # 128 checks expected to pass (grow this when adding tests)
./build.sh --help     # sanity-check tooling if you touched scripts
```

For changes that affect runtime wiring, also smoke-run the scene:

```bash
godot --headless --path . --scene scenes/game.tscn --quit-after 90
```

## Build and export

`./build.sh` verifies Godot + export templates, optionally runs the tests,
imports resources, then exports. Targets are chosen with `--linux` (default),
`--windows` or `--all`:

- `build/gridlock_x86_64_linux` (+ `.pck`) — the `Linux/X11` preset.
- `build/gridlock_x86_64_windows.exe` (+ `.pck`) — the `Windows Desktop` preset,
  cross-compiled from Linux and smoke tested under `wine` when available.

The presets live in `export_presets.cfg`; keep their `export_path` pointing at
`build/`. Windows exports leave `application/modify_resources=false` so no
`rcedit`/wine resource step is required.

The export uses `export_filter="all_files"`, so anything committed (including
`tests/` and docs) is packed into the `.pck`. That is currently intentional and
harmless; if you add a large asset you do not want shipped, exclude it there.

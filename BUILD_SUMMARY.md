# 🎮 GRIDLOCK — Release Builds (Linux + Windows)

## ✅ Build Status: SUCCESSFUL

### 📦 Artifacts (`build/`)

| File | Size | Purpose |
|------|------|---------|
| `build/gridlock_x86_64_linux` | 71 MB | Engine + launcher (ELF 64-bit) |
| `build/gridlock_x86_64_linux.pck` | 83 KB | Game data pack (scripts, scenes, shader) |
| `build/gridlock_x86_64_windows.exe` | 105 MB | Engine + launcher (Windows PE) |
| `build/gridlock_x86_64_windows.pck` | 83 KB | Game data pack (scripts, scenes, shader) |

- **Engine:** Godot 4.7.2.stable.official (release export templates)
- **Targets:** GNU/Linux x86_64 and Windows x86_64, OpenGL 3.3+ / Vulkan
- Each launcher loads its `.pck` from the same directory, so keep the pair
  together. The Windows build is cross-compiled from Linux — no Windows host
  required.

### 🚀 Building

Everything is driven by `build.sh`:

```bash
./build.sh                # run tests, then export the Linux release
./build.sh --linux        # Linux only (same as the default)
./build.sh --windows      # Windows only (cross-compiled from Linux)
./build.sh --all          # both Linux and Windows
./build.sh --skip-tests   # export without running the test suites
./build.sh --debug        # export debug builds instead of release
./build.sh --clean        # delete build/ before exporting
./build.sh --no-verify    # skip the wine smoke test for Windows builds
./build.sh --help
```

The script is self-checking. Before exporting it:

1. Verifies `godot` is on `PATH` and prints its version.
2. Confirms the matching export template exists in
   `~/.local/share/godot/export_templates/<version>/` for every selected target.
3. Optionally runs `run_tests.sh` (128 checks) as a build gate.
4. Imports resources (`godot --headless --import`).
5. Exports each selected preset to `build/`.
6. Smoke tests the Windows `.exe` under `wine` (when installed), then prints the
   artifact sizes and run commands.

To bypass the script and export manually:

```bash
godot --headless --path . --export-release "Linux/X11" \
      "$PWD/build/gridlock_x86_64_linux"

godot --headless --path . --export-release "Windows Desktop" \
      "$PWD/build/gridlock_x86_64_windows.exe"
```

### 🚀 Running

```bash
cd /home/ravenblack/test/1010-godot
./build/gridlock_x86_64_linux              # Linux
wine build/gridlock_x86_64_windows.exe     # Windows (via wine)
```

On Windows, run `build\gridlock_x86_64_windows.exe` directly. The game starts
full-screen on the animated main menu, with the generated ambient loop already
playing.

### ✅ Verification

- Headless smoke-run of each exported binary exits `0` with no errors or
  warnings:

  ```bash
  ./build/gridlock_x86_64_linux --headless --quit-after 120
  wine build/gridlock_x86_64_windows.exe --headless --quit-after 120
  ```

- `./run_tests.sh` → **128 / 128 checks pass**.

### 📋 Shipped Source Layout

```
gridlock/
├── build.sh                               # release build script (Linux + Windows)
├── run_tests.sh                           # test runner
├── project.godot                          # autoloads, 540×960, full-screen
├── export_presets.cfg                     # Linux/X11 + Windows Desktop presets
├── assets/shaders/background.gdshader
├── scripts/{core,autoload,game,ui}/
├── scenes/{game.tscn, ui/*.tscn}
├── tests/{test_runner,smoke_drag}.{gd,tscn}
└── build/                                 # generated release artifacts
```

See `README.md` for the full breakdown.

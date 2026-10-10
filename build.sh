#!/usr/bin/env bash
#
# build.sh - Build GRIDLOCK releases for Linux and Windows.
#
# The script is intentionally self-checking: it verifies Godot is available,
# confirms the matching export templates are installed, optionally runs the test
# suites, imports resources, and only then exports. Windows exports are
# cross-compiled from Linux with the bundled template and, when wine is
# available, smoke tested by running the produced .exe headlessly.
#
# Usage:
#   ./build.sh                 Run tests, then export the Linux release
#   ./build.sh --linux         Export Linux only (same as the default)
#   ./build.sh --windows       Export Windows only
#   ./build.sh --all           Export both Linux and Windows
#   ./build.sh --skip-tests    Export without running the test suites
#   ./build.sh --debug         Export debug builds instead of release
#   ./build.sh --clean         Delete build/ before exporting
#   ./build.sh --no-verify     Skip the wine smoke test for Windows builds
#   ./build.sh --help
#
# Output:
#   build/gridlock_x86_64_linux       (+ .pck)
#   build/gridlock_x86_64_windows.exe (+ .pck)

set -euo pipefail

readonly LINUX_PRESET="Linux/X11"
readonly WINDOWS_PRESET="Windows Desktop"
readonly LINUX_OUTPUT="gridlock_x86_64_linux"
readonly WINDOWS_OUTPUT="gridlock_x86_64_windows.exe"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

MODE="release"
RUN_TESTS=1
CLEAN=0
VERIFY=1
TARGETS=()

usage() {
    cat <<'EOF'
build.sh - Build GRIDLOCK releases for Linux and Windows.

Usage:
  ./build.sh                 Run tests, then export the Linux release
  ./build.sh --linux         Export Linux only (same as the default)
  ./build.sh --windows       Export Windows only
  ./build.sh --all           Export both Linux and Windows
  ./build.sh --skip-tests    Export without running the test suites
  ./build.sh --debug         Export debug builds instead of release
  ./build.sh --clean         Delete build/ before exporting
  ./build.sh --no-verify     Skip the wine smoke test for Windows builds
  ./build.sh --help

Output:
  build/gridlock_x86_64_linux       (+ .pck)
  build/gridlock_x86_64_windows.exe (+ .pck)

Windows builds are cross-compiled from Linux. When `wine` is installed the
produced .exe is smoke tested headlessly; use --no-verify to skip that.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --linux)      TARGETS+=("linux") ;;
        --windows)    TARGETS+=("windows") ;;
        --all)        TARGETS=("linux" "windows") ;;
        --skip-tests) RUN_TESTS=0 ;;
        --debug)      MODE="debug" ;;
        --clean)      CLEAN=1 ;;
        --no-verify)  VERIFY=0 ;;
        -h|--help)    usage; exit 0 ;;
        *)            echo "Unknown option: $arg" >&2; echo; usage; exit 2 ;;
    esac
done

# Default to the host platform so plain `./build.sh` keeps building Linux.
if [ "${#TARGETS[@]}" -eq 0 ]; then
    TARGETS=("linux")
fi

echo "============================================================"
echo "  GRIDLOCK - Build"
echo "============================================================"

# --- 1. Toolchain ----------------------------------------------------------
if ! command -v godot >/dev/null 2>&1; then
    echo "ERROR: Godot is not installed or not in PATH." >&2
    echo "       Install Godot 4.7+ and ensure 'godot' resolves." >&2
    exit 1
fi

GODOT_VERSION="$(godot --version 2>/dev/null | head -n1)"
TEMPLATE_VERSION="$(echo "$GODOT_VERSION" | cut -d. -f1-4)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
TEMPLATE_DIR="$DATA_HOME/godot/export_templates/$TEMPLATE_VERSION"

echo "  Godot:      $GODOT_VERSION"
echo "  Project:    $PROJECT_DIR"
echo "  Mode:       $MODE"
echo "  Targets:    ${TARGETS[*]}"
echo ""

# --- 2. Export templates ---------------------------------------------------
## Prints the template filename Godot expects for a target/mode pair.
template_name() {
    local target="$1"
    case "$target:$MODE" in
        linux:release)   echo "linux_release.x86_64" ;;
        linux:debug)     echo "linux_debug.x86_64" ;;
        windows:release) echo "windows_release_x86_64.exe" ;;
        windows:debug)   echo "windows_debug_x86_64.exe" ;;
        *)               return 1 ;;
    esac
}

for target in "${TARGETS[@]}"; do
    tfile="$(template_name "$target")" || {
        echo "ERROR: unknown target '$target'." >&2
        exit 1
    }
    if [ ! -f "$TEMPLATE_DIR/$tfile" ]; then
        echo "ERROR: export template not found for '$target':" >&2
        echo "       $TEMPLATE_DIR/$tfile" >&2
        echo "       Install the $TEMPLATE_VERSION export templates from" >&2
        echo "       https://godotengine.org/download" >&2
        exit 1
    fi
    echo "  Template:   [$target] $(basename "$tfile")"
done

# --- 3. Optional clean -----------------------------------------------------
if [ "$CLEAN" -eq 1 ]; then
    echo "  Cleaning:   $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

## Removes any previous artifacts for a target so a stale file never lingers.
clear_artifacts() {
    case "$1" in
        linux)   rm -f "$BUILD_DIR/$LINUX_OUTPUT" "$BUILD_DIR/$LINUX_OUTPUT.pck" ;;
        windows) rm -f "$BUILD_DIR/$WINDOWS_OUTPUT" "$BUILD_DIR/${WINDOWS_OUTPUT%.exe}.pck" ;;
    esac
}

for target in "${TARGETS[@]}"; do
    clear_artifacts "$target"
done

# --- 4. Tests --------------------------------------------------------------
if [ "$RUN_TESTS" -eq 1 ]; then
    echo ""
    "$PROJECT_DIR/run_tests.sh"
fi

# --- 5. Import resources ---------------------------------------------------
echo ""
echo "Importing resources..."
if ! godot --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1; then
    echo "ERROR: resource import failed." >&2
    exit 1
fi

# --- 6. Export -------------------------------------------------------------
## Exports one target and returns the primary artifact path via $ARTIFACT.
export_target() {
    case "$1" in
        linux)
            ARTIFACT="$BUILD_DIR/$LINUX_OUTPUT"
            echo "Exporting Linux/$MODE build..."
            godot --headless --path "$PROJECT_DIR" "--export-$MODE" "$LINUX_PRESET" "$ARTIFACT"
            ;;
        windows)
            ARTIFACT="$BUILD_DIR/$WINDOWS_OUTPUT"
            echo "Exporting Windows/$MODE build..."
            godot --headless --path "$PROJECT_DIR" "--export-$MODE" "$WINDOWS_PRESET" "$ARTIFACT"
            ;;
    esac
    if [ ! -f "$ARTIFACT" ]; then
        echo "ERROR: export did not produce $ARTIFACT" >&2
        exit 1
    fi
}

## Runs the produced Windows .exe under wine headlessly to prove it boots.
verify_windows() {
    local exe="$BUILD_DIR/$WINDOWS_OUTPUT"
    if [ "$VERIFY" -eq 0 ]; then
        return
    fi
    if ! command -v wine >/dev/null 2>&1; then
        echo "  (wine not found - skipping Windows smoke test)"
        return
    fi

    local prefix="${GRIDLOCK_WINE_PREFIX:-$HOME/.cache/gridlock-wine}"
    if [ ! -d "$prefix" ]; then
        echo "  Initializing wine prefix: $prefix"
        WINEPREFIX="$prefix" WINEDEBUG=-all wineboot -i >/dev/null 2>&1 || true
    fi

    local log
    log="$(mktemp)"
    echo "  Smoke testing Windows build under wine..."
    if WINEPREFIX="$prefix" WINEDEBUG=-all wine "$exe" --headless --quit-after 120 >"$log" 2>&1; then
        echo "  Windows smoke test passed."
    else
        echo "ERROR: Windows build failed to run under wine:" >&2
        cat "$log" >&2
        rm -f "$log"
        exit 1
    fi
    rm -f "$log"
}

echo ""
for target in "${TARGETS[@]}"; do
    ARTIFACT=""
    export_target "$target"
    if [ "$target" = "windows" ]; then
        verify_windows
    fi
done

# --- 7. Report -------------------------------------------------------------
echo ""
echo "============================================================"
echo "  BUILD SUCCESSFUL"
echo "============================================================"
for target in "${TARGETS[@]}"; do
    case "$target" in
        linux)
            ls -lh "$BUILD_DIR/$LINUX_OUTPUT" "$BUILD_DIR/$LINUX_OUTPUT.pck" \
                | awk '{ printf "  %-8s %s\n", $5, $9 }'
            echo "  Run (Linux):   $BUILD_DIR/$LINUX_OUTPUT"
            ;;
        windows)
            ls -lh "$BUILD_DIR/$WINDOWS_OUTPUT" "$BUILD_DIR/${WINDOWS_OUTPUT%.exe}.pck" \
                | awk '{ printf "  %-8s %s\n", $5, $9 }'
            echo "  Run (Windows): build\\${WINDOWS_OUTPUT}"
            echo "  Run (wine):    wine $BUILD_DIR/$WINDOWS_OUTPUT"
            ;;
    esac
done
echo "============================================================"
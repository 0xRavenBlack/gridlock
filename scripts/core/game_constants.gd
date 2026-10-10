class_name GameConstants
extends RefCounted
## Single source of truth for tuning values and shared sizes.
## Contains no behaviour so it can be referenced from anywhere.

# --- Grid & tray ---
const GRID_SIZE := 10
const PIECES_PER_TRAY := 3

# --- Scoring ---
const POINTS_PER_LINE := 100
const MULTILINE_BONUS := 0.5   ## extra multiplier per extra line cleared at once
const STREAK_BONUS := 0.25     ## multiplier growth per consecutive clearing move

# --- Layout (logical units, 9:16 design space) ---
const DESIGN_WIDTH := 540.0
const DESIGN_HEIGHT := 960.0
const BOARD_SIZE := 500.0
const BOARD_PADDING := 16.0
const CELL_GAP := 4.0

const TRAY_CELL_SIZE := 22.0
const TRAY_CELL_GAP := 3.0
const TRAY_HEIGHT := 176.0

const HUD_HEIGHT := 104.0

# --- Feedback timing (seconds) ---
const CLEAR_FLASH_TIME := 0.16
const CLEAR_FADE_TIME := 0.20
const BEAM_TIME := 0.32

# --- Palette (smooth neon / glossy) ---
const BG_TOP := Color("0a0618")
const BG_BOTTOM := Color("1b0f33")
const ACCENT := Color("a25bff")
const ACCENT_HOT := Color("ff5fa2")
const TEXT_PRIMARY := Color("f3ecff")
const TEXT_MUTED := Color("9a86c4")
const PREVIEW_VALID := Color("2be0e0")
const PREVIEW_INVALID := Color("ff3b5c")
const OVERLAY_DIM := Color(0.02, 0.01, 0.05, 0.82)
const HINT_PIN := Color("8ff6ff")
const HINT_GLOW := Color("2be0e0")
const BEAM_CORE := Color("f4fbff")
const MEGA_ACCENT := Color("ffe23f")

# --- Clear banners ---
const BANNERS := ["LINE CLEAR!", "DOUBLE CLEAR!", "TRIPLE CLEAR!", "MEGA CLEAR!"]
const BANNER_COLORS := [Color("2be0e0"), Color("3be08b"), Color("a25bff"), Color("ffd23f")]
const BANNER_FONT := 48

## Sentinel for "no valid drop target".
const NO_CELL := Vector2i(-9999, -9999)

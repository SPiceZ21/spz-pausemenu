Config = {}

-- Keys that open the menu in place of GTA's own pause menu.
--   200 = INPUT_FRONTEND_PAUSE_ALTERNATE (Esc)
--   199 = INPUT_FRONTEND_PAUSE           (P, controller Start)
-- The GTA map and settings stay reachable from inside the menu.
Config.OpenControls = { 200, 199 }

-- A key press that just closed another menu (the leaderboard, the GTA map)
-- must not reopen this one on its release. Opening is ignored for this long
-- after any other NUI or the GTA pause menu last had the screen.
Config.ReopenGuardMs = 450

-- Frontend sounds on navigate / select / back.
Config.Sounds = true

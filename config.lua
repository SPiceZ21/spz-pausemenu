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

-- ── Teleport to hub ─────────────────────────────────────────────────────────
--
-- A way back to where everything is — the spawn menu's Pop's Diner — for a
-- player who has driven to the far end of the map in freeroam and does not
-- want the drive back.
--
-- NEVER offered during a race: the item is not built at all while
-- LocalPlayer.state.inRace is set, so it cannot be used to skip a track, and
-- there is no disabled row to invite the attempt.
--
-- The z is used EXACTLY as written, with no ground snap. These are interior
-- coords inside an MLO, and probing for ground there is what puts a player on
-- the roof of the building instead of inside it.
Config.Hub = {
  Enabled = true,
  Label   = 'Hub',
  Desc    = "Teleport back to Pop's Diner.",

  -- x, y, z, heading
  Coords  = vec4(1588.65, 6454.98, 26.01, 151.03),

  -- Fade out, move, fade back in. Long enough to hide the world popping in
  -- around the arrival, short enough not to feel like a loading screen.
  FadeOutMs = 350,
  FadeInMs  = 550,

  -- How long to wait for collision at the far end before letting go. The
  -- player is frozen for this: dropping them into a world that has not
  -- streamed yet is how you fall through it.
  CollisionTimeoutMs = 8000,
}

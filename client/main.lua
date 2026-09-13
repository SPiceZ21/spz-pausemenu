-- client/main.lua
-- SPiceZ pause menu. Takes over Esc / P from GTA's own pause menu with a short,
-- clean list: resume, the GTA map, the GTA settings, quit.
--
-- It deliberately does NOT list racing, garage, crew or leaderboard actions —
-- those live on the radial menu (spz-core/client/radial.lua), and a second copy
-- of them here would just be two places to keep in sync.
--
-- The NUI never sends a command. It sends an item id, looked up in the action
-- table built for this opening; an id the menu did not offer does nothing.

local isOpen     = false
local actions    = {}     -- [itemId] = fn
local lastBusyAt = 0      -- last frame another menu or the GTA pause menu had the screen

local function InRace() return LocalPlayer.state.inRace == true end

-- ── Menu model ────────────────────────────────────────────────────────────────

local function Build()
    local racing = InRace()

    actions = {
        resume   = function() end,
        map      = function() ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1) end,
        settings = function() ActivateFrontendMenu(`FE_MENU_VERSION_LANDING_MENU`, false, -1) end,
        disconnect = function() TriggerServerEvent('spz-pausemenu:disconnect') end,
    }

    return {
        { id = 'resume',   label = 'Resume',
          desc = racing and 'Back to the race — your car never stopped.' or 'Back to the session.' },
        { id = 'map',      label = 'Map',      desc = 'Waypoints, blips and the race route.' },
        { id = 'settings', label = 'Settings', desc = 'Graphics, audio, controls and key bindings.' },
        { id = 'disconnect', label = 'Quit', danger = true,
          desc    = racing and 'Leave the server. You are in a race — this counts as a DNF.' or 'Leave the server.',
          confirm = { title = 'Quit?', body = racing
              and 'You are in a live race. Leaving now will DNF you.'
              or  'You will leave the server.' } },
    }
end

local function Driver()
    local st = LocalPlayer.state
    local p  = type(st.profile) == 'table' and st.profile or {}
    local function pick(a, b) if a ~= nil then return a end return b end

    return {
        name       = pick(st.username, p.username) or GetPlayerName(PlayerId()),
        rank       = pick(st.rank, p.rank),
        crew       = pick(st.crewTag, p.crew_tag),
        nation     = pick(st.nation, p.nation),
        raceNumber = pick(st.raceNumber, p.race_number),
    }
end

-- ── Open / close ──────────────────────────────────────────────────────────────

local function Ready()
    local st = LocalPlayer.state
    return st.identityReady == true
       and st.firstTime ~= true
       and NetworkIsPlayerActive(PlayerId())
       and not IsScreenFadedOut()
       and not IsPlayerSwitchInProgress()
end

local SOUNDS = {
    nav    = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    select = { 'SELECT',      'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    back   = { 'BACK',        'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    open   = { 'FocusIn',     'HintCamSounds' },
    close  = { 'FocusOut',    'HintCamSounds' },
}

local function Sound(name)
    local s = Config.Sounds and SOUNDS[name]
    if s then PlaySoundFrontend(-1, s[1], s[2], true) end
end

local function Close(silent)
    if not isOpen then return end
    isOpen     = false
    lastBusyAt = GetGameTimer()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if not silent then Sound('close') end
end

local function Open()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        items  = Build(),
        player = Driver(),
        status = { live = InRace() },
    })
    Sound('open')
end

-- A race starting or ending under the open menu changes the Quit warning.
AddStateBagChangeHandler('inRace', ('player:%s'):format(GetPlayerServerId(PlayerId())), function()
    SetTimeout(0, function()
        if isOpen then
            SendNUIMessage({ action = 'menu', items = Build(), status = { live = InRace() } })
        end
    end)
end)

-- ── Key interception ──────────────────────────────────────────────────────────
--
-- GTA opens its pause menu on the same controls, so they are disabled every
-- frame and this menu opens on the RELEASE instead. The keys are handed back
-- whenever something else owns the screen:
--
--   * another NUI has focus (leaderboard, crew, chat) — Esc belongs to it;
--   * GTA's own pause menu is up (opened from here as Map / Settings);
--   * an ox_lib keyboard menu is open — those close on Esc without NUI focus.
--
-- Each stamps lastBusyAt, and a release inside the guard window after it is
-- ignored: it is the tail of the key press that closed them.

local function OxMenuOpen()
    return lib.getOpenMenu and lib.getOpenMenu() ~= nil
end

CreateThread(function()
    while true do
        local now = GetGameTimer()

        if isOpen then
            Wait(100)
        elseif IsNuiFocused() or IsPauseMenuActive() or OxMenuOpen() or not Ready() then
            lastBusyAt = now
            Wait(0)
        else
            for i = 1, #Config.OpenControls do
                local c = Config.OpenControls[i]
                DisableControlAction(0, c, true)
                if IsDisabledControlJustReleased(0, c) and (now - lastBusyAt) > Config.ReopenGuardMs then
                    Open()
                    break
                end
            end
            Wait(0)
        end
    end
end)

-- ── NUI callbacks ─────────────────────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb)
    Close()
    cb(1)
end)

RegisterNUICallback('sound', function(data, cb)
    Sound(data and data.name)
    cb(1)
end)

RegisterNUICallback('select', function(data, cb)
    cb(1)
    local run = data and actions[data.id]
    if not run then return end

    Sound('select')
    Close(true)

    -- Let focus actually leave this page before the GTA frontend takes over.
    SetTimeout(60, function()
        local ok, err = pcall(run)
        if not ok then print(('^1[spz-pausemenu] %s failed: %s^7'):format(data.id, tostring(err))) end
    end)
end)

-- ── Theme (server.cfg spz_theme_* convars via spz-core) ─────────────────────

local function pushTheme(theme)
    if theme and next(theme) then SendNUIMessage({ action = 'theme', theme = theme }) end
end

CreateThread(function()
    local ok, theme = pcall(function() return exports['spz-core']:GetTheme() end)
    if ok then pushTheme(theme) end
end)
AddEventHandler('SPZ:themeUpdated', pushTheme)

-- ── Exports / cleanup ─────────────────────────────────────────────────────────

exports('Open',   function() if Ready() then Open() end end)
exports('Close',  function() Close() end)
exports('IsOpen', function() return isOpen end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)

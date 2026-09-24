-- client/main.lua
-- SPiceZ pause menu. Takes over Esc / P from GTA's own pause menu with a short,
-- clean list: resume, the GTA map, the GTA settings, quit — plus one row that
-- changes with context: Hub in freeroam, Leave race during a race.
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

-- ── Teleport to hub ───────────────────────────────────────────────────────────
--
-- Freeroam convenience: a player who drove to Paleto and is done exploring
-- gets back to Pop's Diner without the drive. Never offered mid-race (see
-- Build), so it cannot be used to skip a track.
--
-- The three things that make a teleport feel finished rather than glitchy:
--
--   * FADE FIRST. Moving a player on a visible frame shows them the world
--     tearing in around the arrival.
--   * TAKE THE CAR, but only if they are driving it. Teleporting a vehicle
--     someone else is driving drags them across the map with you; a passenger
--     is dropped out of it instead.
--   * WAIT FOR COLLISION, frozen. Landing in a cell that has not streamed
--     means falling through the map, and the interior here is an MLO — the
--     worst case for arriving early.
local tpBusy = false

local function TeleportToHub()
    local hub = Config.Hub or {}
    local c   = hub.Coords
    if not c then return end
    if tpBusy then return end
    if InRace() then return end          -- belt and braces; Build hides it anyway
    tpBusy = true

    CreateThread(function()
        DoScreenFadeOut(hub.FadeOutMs or 350)
        local deadline = GetGameTimer() + 2000
        while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local driving = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

        -- Passenger in someone else's car: step out rather than ride along.
        if veh ~= 0 and not driving then
            ClearPedTasksImmediately(ped)
            Wait(50)
            ped = PlayerPedId()
            veh = 0
        end

        local ent = driving and veh or ped

        RequestCollisionAtCoord(c.x, c.y, c.z)
        FreezeEntityPosition(ent, true)
        SetEntityCoordsNoOffset(ent, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(ent, c.w or 0.0)
        if driving then SetVehicleOnGroundProperly(veh) end

        -- Frozen until the world around the arrival exists.
        local wait = GetGameTimer() + (hub.CollisionTimeoutMs or 8000)
        while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < wait do
            RequestCollisionAtCoord(c.x, c.y, c.z)
            Wait(0)
        end

        FreezeEntityPosition(ent, false)
        DoScreenFadeIn(hub.FadeInMs or 550)
        tpBusy = false
    end)
end

-- ── Menu model ────────────────────────────────────────────────────────────────

local function Build()
    local racing = InRace()

    local hub = Config.Hub or {}
    local showHub = hub.Enabled ~= false and hub.Coords ~= nil and not racing

    actions = {
        resume   = function() end,
        map      = function() ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1) end,
        settings = function() ActivateFrontendMenu(`FE_MENU_VERSION_LANDING_MENU`, false, -1) end,
        disconnect = function() TriggerServerEvent('spz-pausemenu:disconnect') end,
    }

    -- Registered only when they are offered. The NUI sends an item id that is
    -- looked up in this table, so an id the menu did not build does nothing —
    -- which means a stale page cannot teleport a player out of a race, and
    -- cannot DNF a player who is not in one.
    if showHub then actions.hub = TeleportToHub end

    -- Abandoning the race. The server owns what that means — mid-race it is a
    -- DNF, during warmup it is a clean withdrawal — so this sends the same
    -- event /leaverace does and lets spz-races decide (server/queue.lua,
    -- LeaveQueue). Nothing is done client-side first: the car despawn, bucket
    -- move and teleport out all come back from the server.
    if racing then
        actions.leave = function() TriggerServerEvent('SPZ:leaveQueue') end
    end

    local items = {
        { id = 'resume',   label = 'Resume',
          desc = racing and 'Back to the race — your car never stopped.' or 'Back to the session.' },
    }

    items[#items + 1] = { id = 'map',      label = 'Map',      desc = 'Waypoints, blips and the race route.' }

    -- Third, below Map: the map is where you go to decide you want to be
    -- somewhere else, so the teleport that acts on that decision sits under it.
    if showHub then
        items[#items + 1] = {
            id      = 'hub',
            label   = hub.Label or 'Hub',
            desc    = hub.Desc  or "Teleport back to Pop's Diner.",
            confirm = {
                title = 'Teleport to hub?',
                body  = 'You will be moved across the map. Your car comes with you if you are driving it.',
            },
        }
    end

    -- Same slot as Hub, and they are never offered together: Hub is freeroam
    -- only, this is race only. Whichever applies is the third row.
    if racing then
        items[#items + 1] = {
            id      = 'leave',
            label   = 'Leave race',
            danger  = true,
            desc    = 'Abandon the race and return to freeroam. Counts as a DNF.',
            confirm = {
                title = 'Leave the race?',
                body  = 'You will be marked DNF and moved out of the race world. You cannot rejoin this race.',
            },
        }
    end

    items[#items + 1] = { id = 'settings', label = 'Settings', desc = 'Graphics, audio, controls and key bindings.' }
    items[#items + 1] = {
        id = 'disconnect', label = 'Quit', danger = true,
        desc    = racing and 'Leave the server. You are in a race — this counts as a DNF.' or 'Leave the server.',
        confirm = { title = 'Quit?', body = racing
            and 'You are in a live race. Leaving now will DNF you.'
            or  'You will leave the server.' },
    }

    return items
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

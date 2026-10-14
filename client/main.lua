-- client/main.lua
-- SPiceZ pause menu. Takes over Esc / P from GTA's own pause menu with a
-- bento grid: resume, the GTA map, the GTA settings, quit — plus rows that
-- change with context (Hub, Leave race / queue / minigame) and a quick-access
-- strip that runs the same commands as the radial menu (spz-core/client/radial.lua).
--
-- The NUI never sends a command. It sends an item id, looked up in the action
-- table built for this opening; an id the menu did not offer does nothing.

local isOpen     = false
local actions    = {}     -- [itemId] = fn
local lastBusyAt = 0      -- last frame another menu or the GTA pause menu had the screen

local function InRace() return LocalPlayer.state.inRace == true end
local function InQueue() return LocalPlayer.state.inQueue == true end
local function Has(res) return GetResourceState(res) == 'started' end
-- Set by each minigame (pursuit, colorrush, hideseek) to its display name.
local function Minigame()
    local m = LocalPlayer.state.inMinigame
    return (type(m) == 'string' and m ~= '') and m or nil
end

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
    local game   = not racing and Minigame() or nil

    local hub = Config.Hub or {}
    -- Never teleport out of a minigame's world: leave it properly instead.
    local showHub = hub.Enabled ~= false and hub.Coords ~= nil and not racing and not game

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
    -- The minigame that set the flag handles this and sends us home.
    if game then
        actions.leave_minigame = function() TriggerEvent('spz:leaveMinigame') end
    end
    -- Queued but not racing yet: leaving costs nothing (same as the radial's Leave Queue).
    local queued = not racing and InQueue()
    if queued then
        actions.leave_queue = function() ExecuteCommand('leaverace') end
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
            -- Badge on the tile: Config.Hub.Place, else the place named in Desc
            -- ("Teleport back to <place>.").
            badge   = hub.Place or (hub.Desc and hub.Desc:match('[Bb]ack to (.-)%.?$')) or nil,
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

    if game then
        items[#items + 1] = {
            id      = 'leave_minigame',
            label   = 'Leave minigame',
            danger  = true,
            desc    = ('Quit %s and return to freeroam.'):format(game),
            confirm = {
                title = ('Leave %s?'):format(game),
                body  = 'You will forfeit this round and be sent back to where you were.',
            },
        }
    end

    if queued then
        items[#items + 1] = {
            id = 'leave_queue', label = 'Leave queue', danger = true,
            desc = 'Drop out of the race queue. No penalty.',
        }
    end

    items[#items + 1] = { id = 'settings', label = 'Settings', desc = 'Graphics, audio, controls and key bindings.' }

    -- ── Quick access ─────────────────────────────────────────────────────────
    -- Shortcuts to the same commands the radial menu runs (spz-core/client/radial.lua),
    -- shown as a strip of small tiles. Each is offered only when its resource is
    -- running and it makes sense in the current context.
    local free = not racing and not game
    local function quick(id, label, cmd, cond)
        if cond == false then return end
        actions[id] = function() ExecuteCommand(cmd) end
        items[#items + 1] = { id = id, label = label, quick = true }
    end
    quick('q_join',    'Join race',   'joinrace',    free and not queued and Has('spz-races'))
    quick('q_car',     'Spawn car',   'car',         free and Has('spz-carspawner'))
    quick('q_board',   'Leaderboard', 'leaderboard', Has('spz-leaderboard'))
    quick('q_results', 'Results',     'raceresults', Has('spz-leaderboard'))
    quick('q_crew',    'Crew',        'crew',        Has('spz-crew'))
    quick('q_char',    'Character',   'appearance',  free and Has('spz-appearance'))

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
        -- racing record for the driver card (spz-identity's profile row)
        stats = {
            iRating  = pick(st.iRating, p.i_rating),
            sr       = pick(st.sr, p.sr),
            license  = pick(st.licenseTier, p.license_tier),
            podiums  = p.top3_count,
            xp       = p.xp,
            points   = p.alltime_points,
            credits  = p.credits,
            playtime = p.playtime,
        },
    }
end

-- ── Character headshot ────────────────────────────────────────────────────────
-- Same trick as spz-speedcam: a transparent ped headshot served to NUI as
-- https://nui-img/<txd>/<txd>. Taken on open, released on close.
local headshot = nil

local function ReleaseHeadshot()
    if headshot then UnregisterPedheadshot(headshot); headshot = nil end
end

local function SendHeadshot()
    ReleaseHeadshot()
    CreateThread(function()
        local h = RegisterPedheadshotTransparent(PlayerPedId())
        local deadline = GetGameTimer() + 1500
        while not (IsPedheadshotValid(h) and IsPedheadshotReady(h)) do
            if GetGameTimer() > deadline or not isOpen then UnregisterPedheadshot(h); return end
            Wait(0)
        end
        headshot = h
        SendNUIMessage({ action = 'face', txd = GetPedheadshotTxdString(h) })
    end)
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

-- ── Live map in the Map tile ──────────────────────────────────────────────────
-- The tile draws GTA's own map art (ui/map.webp, stitched from the game's
-- minimap textures) and centres it on the player. All it needs from here is
-- where we are, which way we face, and the waypoint, a few times a second.
local function SendMapPos()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local c = GetEntityCoords(ent)
    local msg = { action = 'pos', x = c.x, y = c.y, h = GetEntityHeading(ent), span = Config.MapSpan }
    local wp = GetFirstBlipInfoId(8)                  -- the player's waypoint
    if wp ~= 0 and DoesBlipExist(wp) then
        local w = GetBlipInfoIdCoord(wp)
        msg.wx, msg.wy = w.x, w.y
    end
    SendNUIMessage(msg)
end

local function Close(silent)
    if not isOpen then return end
    isOpen     = false
    lastBusyAt = GetGameTimer()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    ReleaseHeadshot()
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
    SendHeadshot()
    SendMapPos()
    CreateThread(function()
        while isOpen do
            Wait(250)
            if isOpen then SendMapPos() end
        end
    end)
    Sound('open')
end

AddEventHandler('spz:minigameChanged', function()
    if isOpen then SendNUIMessage({ action = 'menu', items = Build(), status = { live = InRace() } }) end
end)

-- A race starting or ending under the open menu changes the Quit warning.
-- Joining / leaving the queue swaps Leave queue and Join race.
for _, key in ipairs({ 'inRace', 'inQueue', 'inMinigame' }) do
    AddStateBagChangeHandler(key, ('player:%s'):format(GetPlayerServerId(PlayerId())), function()
        SetTimeout(0, function()
            if isOpen then
                SendNUIMessage({ action = 'menu', items = Build(), status = { live = InRace() } })
            end
        end)
    end)
end

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
                    -- Protected: an error inside Open() used to kill this thread,
                    -- and from then on Esc fell through to GTA's own pause menu.
                    local ok, err = pcall(Open)
                    if not ok then
                        print('^1[spz-pausemenu] open failed: ' .. tostring(err) .. '^7')
                        isOpen = false
                        SetNuiFocus(false, false)
                    end
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
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    isOpen = false
    ReleaseHeadshot()
end)

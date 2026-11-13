LockFeedback = {}

local FOB_DICT, FOB_CLIP = 'anim@mp_player_intmenu@key_fob@', 'fob_click'
local SOUND_SET = 'PI_Menu_Sounds'
local LIGHT_RANGE = 100.0
local textUiHandle, textUiToken = nil, 0

local function options()
    return Config.lockFeedback or {}
end

local function playSound(vehicle, locked, nearby)
    local name = locked and 'Remote_Control_Close' or 'Remote_Control_Open'
    if nearby then
        PlaySoundFromEntity(-1, name, vehicle, SOUND_SET, true, 0)
    else
        PlaySoundFrontend(-1, name, SOUND_SET, true)
    end
end

local function flashLights(vehicle)
    CreateThread(function()
        for _ = 1, 2 do
            if not DoesEntityExist(vehicle) then
                break
            end
            SetVehicleLights(vehicle, 2)
            SetVehicleIndicatorLights(vehicle, 0, true)
            SetVehicleIndicatorLights(vehicle, 1, true)
            Wait(200)
            if not DoesEntityExist(vehicle) then
                break
            end
            SetVehicleLights(vehicle, 0)
            SetVehicleIndicatorLights(vehicle, 0, false)
            SetVehicleIndicatorLights(vehicle, 1, false)
            Wait(150)
        end
    end)
end

local function playFobAnimation()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    CreateThread(function()
        pcall(Kora.stream.loadAnimDict, FOB_DICT, function()
            TaskPlayAnim(ped, FOB_DICT, FOB_CLIP, 8.0, -8.0, 1000, 48, 0.0, false, false, false)
        end, { timeout = 1000 })
    end)
end

local function showStatus(locked)
    textUiToken = textUiToken + 1
    local token = textUiToken
    if textUiHandle then
        Kora.textui.hide(textUiHandle)
    end
    textUiHandle = Kora.textui.show(Kora.lang(locked and 'locked' or 'unlocked'), {
        position = 'bottom-center',
        icon = locked and 'Lock' or 'LockOpen',
    })
    SetTimeout(1500, function()
        if token == textUiToken and textUiHandle then
            Kora.textui.hide(textUiHandle)
            textUiHandle = nil
        end
    end)
end

function LockFeedback.localToggle(vehicle, locked)
    local cfg = options()
    if cfg.sound == true then
        playSound(vehicle, locked, false)
    end
    if cfg.animation == true then
        playFobAnimation()
    end
    if cfg.textUI == true then
        showStatus(locked)
    end
end

function LockFeedback.remote(vehicle, locked, source)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local cfg = options()
    local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle))
    if cfg.lights == true and distance <= LIGHT_RANGE then
        flashLights(vehicle)
    end
    local isSource = source == GetPlayerServerId(PlayerId())
    if cfg.soundNearby == true and not isSource and distance <= (cfg.soundRange or 10.0) then
        playSound(vehicle, locked, true)
    end
end


local placingProp = false
local updatingModel = false
local currentlyModifying = 1
local _isplayingAnim = false
local modifiers = {
    'x', 'y', 'z', 'Rx', 'Ry', 'Rz'
}
local helpButtonScaleform = 0

local hash = 0
local handle = 0
local bone = 0

local x, y, z, Rx, Ry, Rz = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0

RegisterCommand('prop', function(src, args, raw)
    if placingProp then return end
    EnablePlacement()
end)

RegisterNuiCallback('updatePlacement', function(data, cb)
    if handle > 0 then
        ReceivePlacementUpdate(data)
    end
    cb('ok')
end)

RegisterNuiCallback('updateModel', function(data, cb)
    ReceiveModelUpdate(data[1], data[2])
    cb('ok')
end)

RegisterNuiCallback('updateAnim', function(data, cb)
    ReceiveAnimRequest(data[1], data[2])
    cb('ok')
end)

RegisterNuiCallback('close', function(data, cb)
    DisablePlacement()
    cb('ok')
end)

function EnablePlacement()
    placingProp = true
    SetNuiFocus(true, true)
    SendNuiMessage(json.encode({
        ["OP"] = "ENABLE",
        ["DATA"] = 1
    }))
end

function DisablePlacement()
    Cleanup()
    SendNuiMessage(json.encode({
        ["OP"] = "ENABLE",
        ["DATA"] = 0
    }))
    SetNuiFocus(false, false)
    placingProp = false
end

function ReceiveModelUpdate(nameOrHash, boneIndex)
    if updatingModel then return end
    updatingModel = true
    if handle > 0 then Cleanup() end
    hash = tonumber(0) or 0
    if type(nameOrHash) == 'string' then
        hash = tonumber(GetHashKey(nameOrHash)) or 0
    else
        hash = tonumber(nameOrHash) or 0
    end

    if type(boneIndex) ~= "number" then
        boneIndex = tonumber(boneIndex) or 0
    end

    local ped = GetPlayerPed(-1)
    bone = GetPedBoneIndex(GetPlayerPed(-1), boneIndex)

    Citizen.CreateThread(function()

        print('loading')

        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) do
            Wait(100)
            timeout = timeout + 1
            if timeout > 10 then
                SendNUIMessage({
                    ["OP"] = "SHOW_ERROR",
                    ["DATA"] = "Could not load model: " .. nameOrHash
                })
                updatingModel = false
                return
            end
        end

        handle = CreateObject(hash, 1.0, 1.0, 1.0, true, true, false)

        timeout = 0
        while not handle do
            Wait(100)
            timeout = timeout + 1
            if timeout > 10 then

                SendNUIMessage({
                    ["OP"] = "SHOW_ERROR",
                    ["DATA"] = "Could not spawn prop: " .. nameOrHash
                })
                updatingModel = false
                return
            end
        end

        SendNUIMessage({
            ["OP"] = "CLEAR_ERROR",
            ["DATA"] = ""
        })
        AttachEntityToEntity(handle, ped, bone, x, y, z, Rx, Ry, Rz, 1, 1, 0, 0, 1, 1)
        updatingModel = false
    end)
end

function ReceiveAnimRequest(dict, anim)
    if _isplayingAnim then return end
    RequestAnimDict(dict)
    local attempts = 0
    while not HasAnimDictLoaded(dict) and attempts < 10 do
        RequestAnimDict(dict)
        attempts = attempts + 1
        Wait(100)
    end
    if not HasAnimDictLoaded(dict) then
        SendNUIMessage({
            ["OP"] = "SHOW_ERROR",
            ["DATA"] = "Could not load anim dict."
        })
        return
    end
    _isplayingAnim = true
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, -1, 1, 1.0, false, false, false)
    Wait(GetAnimDuration(dict, anim) * 1000)
    _isplayingAnim = false
    RemoveAnimDict(dict)
end

function Cleanup()
    if handle == 0 then return end
    DetachEntity(handle)
    SetEntityAsNoLongerNeeded(handle)
    SetEntityCoords(handle, -5000.0, -5000.0, -100.0)
    DeleteEntity(handle)
    handle = 0
end

function ReceivePlacementUpdate(placementCoordinates)
    x = tonumber(placementCoordinates[1]) + 0.0
    y = tonumber(placementCoordinates[2]) + 0.0
    z = tonumber(placementCoordinates[3]) + 0.0
    Rx = tonumber(placementCoordinates[4]) + 0.0
    Ry = tonumber(placementCoordinates[5]) + 0.0
    Rz = tonumber(placementCoordinates[6]) + 0.0

    ToFloat()
    UpdatePlacement()
end

function UpdatePlacement()

    Citizen.CreateThread(function()
        SetEntityCoords(handle, x, y, z)
        SetEntityRotation(handle, Rx, Ry, Rz)

        DetachEntity(handle, false, false)
        AttachEntityToEntity(handle, GetPlayerPed(-1), bone, x, y, z, Rx, Ry, Rz, 1, 1, 0, 0, 1, 1)

    end)
end

local keyboardPassthrough = false

------------------------ Left Alt NUI Focus Fix ------------------------
RegisterNUICallback('AltLeftDown', function(data, cb)
    if not keyboardPassthrough then
        EnableKeyboardPassthrough()
        local lastInput = GetGameTimer()
        Citizen.CreateThread(function()
            while keyboardPassthrough do
                Citizen.Wait(0)
                -- DisableControlAction(0, 1, display) -- LookLeftRight
                -- DisableControlAction(0, 2, display) -- LookUpDown
                DisableControlAction(0, 142, display) -- MeleeAttackAlternate
                DisableControlAction(0, 18, display) -- Enter
                DisableControlAction(0, 322, display) -- ESC
                DisableControlAction(0, 106, display) -- VehicleMouseControlOverride
                if GetGameTimer() - lastInput > 500 and GetTimeSinceLastInput(0) > 500 then -- If they haven't touched their controls, A.K.A Tabbed out
                    DisableKeyboardPassthrough()
                end
            end
        end)
    end
    cb(true)
end)

RegisterNUICallback('AltLeftUp', function(data, cb)
    if keyboardPassthrough then
        DisableKeyboardPassthrough()
    end
    cb(true)
end)

function DisableKeyboardPassthrough()
    SetNuiFocusKeepInput(false)
    -- SetNuiFocus(true, true)

    keyboardPassthrough = false
end

function EnableKeyboardPassthrough()
    SetNuiFocusKeepInput(true)
    -- SetNuiFocus(true, false)
    keyboardPassthrough = true
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        Cleanup()
    end
end)

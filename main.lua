---@diagnostic disable: unused-function
-- DragMP Server
-- author: cloudenum
-- version: 0.0.1

require 'utils.MessagePack'
local inspect = require 'utils.inspect'
local flatdb = require 'utils.flatdb'

print('DragMP initiating...')

-- ConnectedPlayers = MP.GetPlayers()

-- local ConnectedPlayersMetatable =
-- {
-- 	__len = function(table)
-- 		return MP.GetPlayerCount()
-- 	end,
-- 	__pairs = function(t)
-- 		return function(t,k)
-- 			local v
-- 			repeat
-- 				k, v = next(t, k)
-- 			until k == nil or (type(k) == "number" and type(v) == "table")
-- 			return k, v
-- 		end, t, nil
-- 	end
-- }

-- setmetatable(ConnectedPlayers, ConnectedPlayersMetatable)

function script_path()
    local str = debug.getinfo(2, "S").source
    return str:match("(.*[/\\])") or "."
end

RootDirectory = script_path()

if not FS.Exists(RootDirectory .. 'database') then
    local error, error_message = FS.CreateDirectory(RootDirectory .. 'database')

    if error then
        print('Error creating database directory: ' .. error_message)
        return
    end
end

local db = flatdb(RootDirectory .. 'database')

if db == nil then
    print('Error creating database')
    return
end

if not db.Leaderboard then
    db.Leaderboard = {}
end

print('DragMP initiated')

local function broadcastsClientEvent(eventName, data)
    print('Broadcasted Clients: ')
    for playerID, playerName in pairs(MP.GetPlayers()) do
        MP.TriggerClientEventJson(playerID, eventName, data)
        print(playerID .. ': ' .. playerName)
    end
end

-- function PlayerJoinHandler(playerID)
--     print(type(playerID))
--     if playerID then
--         -- table.insert(ConnectedPlayers, MP.GetPlayerName(playerID))
--         ConnectedPlayers[playerID] = MP.GetPlayerName(ID)
--         -- ConnectedPlayers = MP.GetPlayers()
--     end
--     print(inspect(ConnectedPlayers))
-- end

-- function PlayerDisconnectHandler(playerID)
--     table.remove(ConnectedPlayers, playerID)
--     -- ConnectedPlayers = MP.GetPlayers()
--     print(inspect(ConnectedPlayers))
-- end

-- Broadcasts to all players
function RaceInitiatedHandler(initiatorPlayerID)
    print("Race Initiated By: ", MP.GetPlayerName(initiatorPlayerID))
    broadcastsClientEvent('DragMP_RaceInitiated', {
        initiatorPlayerID = initiatorPlayerID
    })
end

-- local function raceStartedHandler(data)
--     MP.TriggerClientEvent('DragMP:RaceStarted', data)
-- end

function DispatchSyncDisplay(playerID, data) 
    print("Syncing Display: " .. data)
    local decodedData = Util.JsonDecode(data)
    if not decodedData then
        print("DispatchSyncDisplay: decodedData is nil")
        return
    end
    broadcastsClientEvent('DragMP_SyncDisplay', decodedData)
end

function RaceFinishedHandler(playerID, data)
    local decodedData = Util.JsonDecode(data)
    if not decodedData then
        print("raceFinishedHandler: decodedData is nil")
        return
    end

    if not decodedData.result then 
        print("result is nil")
        return
    end

    print("playerFinishedRace: " .. MP.GetPlayerName(playerID))
    local playerName = MP.GetPlayerName(playerID)
    local result = decodedData.result
    db.Leaderboard[playerName] = {
        time = result.time,
        speed = result.speed,
        reactionTime = result.reactionTime
        -- vehicleName = vehicle.name
    }

    db:save()
    broadcastsClientEvent('DragMP_RaceFinished', {
        playerID = playerID,
        playerName = playerName,
        time = result.time,
        speed = result.speed,
        reactionTime = result.reactionTime
    })

    local displayTime = string.format("%.3f", result.time)
    local displayReactionTime = string.format("%.3f", result.reactionTime)
    local displaySpeed = string.format("%.2f", result.speed)

    MP.SendChatMessage(-1, playerName .. ': ' .. displayTime .. 's@' .. displaySpeed .. 'mph')
    MP.SendChatMessage(playerID, 'Your Reaction Time: ' .. displayReactionTime .. 's')
end

-- MP.RegisterEvent('onInit', 'initHandler')
MP.RegisterEvent('onPlayerJoin', 'PlayerJoinHandler')
MP.RegisterEvent('onPlayerDisconnect', 'PlayerDisconnectHandler')

MP.RegisterEvent('onRaceInitiated', 'RaceInitiatedHandler')
-- MP.RegisterEvent('onRaceStarted', 'raceStartedHandler')
MP.RegisterEvent('onSyncDisplay', 'DispatchSyncDisplay')
MP.RegisterEvent('onRaceFinished', 'RaceFinishedHandler')

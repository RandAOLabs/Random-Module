-- You no longer need these single global variables at the top:
-- RafflePullCount          = RafflePullCount or 0
-- RafflePulls              = RafflePulls or {}
-- RaffleEntryList          = RaffleEntryList or {}
-- RaffleEntryCount         = RaffleEntryCount or 0

local ao           = require('ao')
local json         = require('json')
local randomModule = require('random')(json)

-- This table will map: userId -> {
--    RafflePullCount  = <number>,
--    RafflePulls      = <table>,
--    RaffleEntryList  = <table>,
--    RaffleEntryCount = <number>
-- }
UserRaffleData = UserRaffleData or {}

LastRaffleTime = LastRaffleTime or {}

-- This table maps callbackId -> userId,
-- so we know which user to associate the random response with
CallbackToUser = CallbackToUser or {}

RaffleWhitelist = {
    ["ld4ncW8yLSkckjia3cw6qO7silUdEe1nsdiEvMoLg-0"] = true,
    ["9U_MDLfzf-sdww7d7ydaApDiQz3nyHJ4kTS2-9K4AGA"] = true
}

-- Utility function to get or initialize a user's raffle data
function GetUserRaffleData(userId)
    if not UserRaffleData[userId] then
        UserRaffleData[userId] = {
            RafflePullCount  = 0,
            RafflePulls      = {},
            RaffleEntryList  = {},
            RaffleEntryCount = 0,
        }
    end
    return UserRaffleData[userId]
end

-- DrawNumber now only updates the raffle data for the given user
function DrawNumber(user)
    print("DrawNumber called with user: " .. tostring(user))

    local data = GetUserRaffleData(user)
    data.RafflePullCount = data.RafflePullCount + 1
    local pullId = data.RafflePullCount

    -- Generate CallbackId
    local callbackId = randomModule.generateUUID()
    if not callbackId then
        error("Error: randomModule.generateUUID returned nil")
    end
    print("Generated CallbackId: " .. callbackId)

    -- Request a random number
    randomModule.requestRandom(callbackId)

    -- Map this callbackId to the user, so we can retrieve the user's data
    CallbackToUser[callbackId] = user

    print("Inserting into RafflePulls for user: " .. tostring(user))
    print("PullId: " .. tostring(pullId) .. ", value: " .. json.encode({
        User       = user,
        Id         = pullId,
        CallbackId = callbackId,
        Winner     = nil
    }))

    data.RafflePulls[pullId] = {
        User       = user,
        Id         = pullId,
        CallbackId = callbackId,
        Winner     = nil
    }

    print("Pull created: " .. json.encode(data.RafflePulls[pullId]))
    return pullId, callbackId
end

-- If you need a “request random” by callbackId outside of creation
function RequestRandomNumber(callbackId)
    print("entered request random")
    randomModule.requestRandom(callbackId)
end

-- Function to update a specific user's raffle entry list
function UpdateRaffleEntryList(userId, newList)
    local data = GetUserRaffleData(userId)
    data.RaffleEntryCount = 0
    data.RaffleEntryList  = {} -- reset
    print("UpdateRaffleEntryList called for user " .. tostring(userId) .. " with new list: " .. json.encode(newList))

    for _, entry in ipairs(newList) do
        table.insert(data.RaffleEntryList, entry)
        data.RaffleEntryCount = data.RaffleEntryCount + 1
    end
end

-- Function to find the pullId by callbackId within a single user's data
local function FindPullIdByCallbackId(userData, callbackId)
    print("Entered FindPullIdByCallbackId with callbackId: " .. tostring(callbackId))
    print("User's RafflePulls Table: " .. json.encode(userData.RafflePulls))
    for pullId, pull in pairs(userData.RafflePulls) do
        print("Checking PullId: " .. pullId .. ", Stored CallbackId: " .. tostring(pull.CallbackId))
        if pull.CallbackId == callbackId then
            return pullId
        end
    end
    print("No matching PullId found for CallbackId: " .. tostring(callbackId))
    return nil
end

function GetTimeDisplay(seconds)
    -- e.g. 70 seconds -> "1 minute and 10 seconds"
    local s = math.floor(seconds) % 60
    local m = math.floor(math.floor(seconds) / 60)

    local parts = {}
    if m > 0 then
        table.insert(parts, m .. (m == 1 and " minute" or " minutes"))
    end
    if s > 0 then
        table.insert(parts, s .. (s == 1 and " second" or " seconds"))
    end

    if #parts == 0 then
        return "0 seconds"
    elseif #parts == 1 then
        return parts[1]
    else
        return parts[1] .. " and " .. parts[2]
    end
end

Handlers.add(
    "updateRaffleEntryList",
    Handlers.utils.hasMatchingTag('Action', 'Update-Raffle-Entry-List'),
    function(msg)
        print("entered update raffle entry list")
        -- Update the raffle entry list only for the user who sent the message
        UpdateRaffleEntryList(msg.From, json.decode(msg.Data))
    end
)

Handlers.add(
    "Raffle",
    Handlers.utils.hasMatchingTag('Action', 'Raffle'),
    function(msg)
        print("entered raffle")

        local userId             = msg.From
        local userData = GetUserRaffleData(userId)

        if userData.RaffleEntryCount == 0 or #userData.RaffleEntryList == 0 then
            print("User " .. userId .. " tried to pull a raffle but has no entrants!")
            ao.send({
                Target = userId,
                Action = "Raffle Pull Denied",
                Tags   = {
                    Reason = "No entrants have been set up for your raffle."
                }
            })
            return
        end

        if not RaffleWhitelist[userId] then
            print("User " .. userId .. " is not in the whitelist.")
            -- current time in seconds (using msg.Timestamp which is in ms)
            local currentTimeSec = msg.Timestamp / 1000
            local lastTime = LastRaffleTime[userId] or 0
            local elapsed = currentTimeSec - lastTime

            -- Update the last time the user sent a raffle request
            print("Last time: " .. lastTime .. " Current time: " .. currentTimeSec .. " Elapsed: " .. elapsed)
            -- Check if 5 minutes have passed since last pull
            if elapsed < 60 then
                local timeRemaining = 60 - elapsed
                print("User " .. userId .. " must wait. " .. timeRemaining .. " seconds left.")

                ao.send({
                    Target = userId,
                    Action = "Raffle Pull Denied",
                    Tags   = {
                        WaitTime = GetTimeDisplay(timeRemaining)
                    }
                })
                return
            end
            LastRaffleTime[userId] = currentTimeSec
        end

        local pullId, callbackId = DrawNumber(userId)
        ao.send({
            Target = userId,
            Action = "Raffle Pull Created",
            Tags   = {
                PullId     = tostring(pullId),
                CallbackId = callbackId,
            }
        }).receive()
    end
)

Handlers.add(
    'randomResponse',
    Handlers.utils.hasMatchingTag('Action', 'Random-Response'),
    function(msg)
        print("entered randomResponse")
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, msg.Data)
        print("CallbackId: " .. callbackId .. " Entropy: " .. entropy)

        -- Determine which user this callbackId is for
        local user = CallbackToUser[callbackId]
        if not user then
            print("No user found for callbackId: " .. callbackId)
            return
        end
        local userData = GetUserRaffleData(user)
        local pullId = FindPullIdByCallbackId(userData, callbackId)
        local userId = userData.RafflePulls[pullId].User

        print("PullId: " .. tostring(pullId))

        if not pullId then
            print("No valid pullId found; ignoring randomResponse.")
            return
        end

        -- Example usage:
        local randomNumber   = math.floor(tonumber(entropy) % 10)
        print("Random Number: " .. randomNumber)
        --local winningIndex   = math.floor(tonumber(entropy) % userData.RaffleEntryCount) -- 0-based?

        -- Adjust as needed. For example, if your code expects 1-based indexing:
        local winningIndex = math.floor(tonumber(entropy) % userData.RaffleEntryCount) + 1

        print("Winning Index: " .. winningIndex)

        local winner = userData.RaffleEntryList[winningIndex]
        print("Winner: " .. tostring(winner))

        userData.RafflePulls[pullId].Winner = winner

        -- If you want to remove that winner from the list
        if winner then
            -- remove the element from the list so it won't be sparse
            table.remove(userData.RaffleEntryList, winningIndex)
            userData.RaffleEntryCount = userData.RaffleEntryCount - 1
        end

        ao.send({
            Target = userId,
            Action = "Raffle-Winner",
            Tags   = {
                Winner = winner,
                CallbackId = callbackId,
                PullId = tostring(pullId),
                UserId = userId
            }
        })
    end
)

Handlers.add(
    'View Pull',
    Handlers.utils.hasMatchingTag('Action', 'View-Pull'),
    function(msg)
        print("entered view pull")
        local user = msg.Tags.UserId or msg.From
        local data = GetUserRaffleData(user)

        local pullId = tonumber(msg.Tags.PullId)
        if data.RafflePulls[pullId] then
            print(json.encode(data.RafflePulls[pullId]))
            ao.send({
                Target = user,
                Action = "View-Pull-Response",
                Data   = json.encode(data.RafflePulls[pullId])
            })
        else
            ao.send({
                Target = user,
                Action = "View-Pull-Response",
                Data   = "No pull found for pullId = " .. tostring(pullId)
            })
        end
    end
)

Handlers.add(
    'View Pulls',
    Handlers.utils.hasMatchingTag('Action', 'View-Pulls'),
    function(msg)
        print("entered view pulls")
        local user = msg.Tags.UserId or msg.From
        local data = GetUserRaffleData(user)

        print(json.encode(data.RafflePulls))
        ao.send({
            Target = user,
            Action = "View-Pulls-Response",
            Data   = json.encode(data.RafflePulls)
        })
    end
)

Handlers.add(
    "View Entrants",
    Handlers.utils.hasMatchingTag("Action", "View-Entrants"),
    function(msg)
        print("Entered View Entrants")

        -- `msg.Tags.UserId` is who "owns" the raffle we want to view.
        -- If none is provided, fall back to the user making the request.
        local raffleOwnerId = msg.Tags.UserId or msg.From

        -- Retrieve that user’s raffle data
        local data = GetUserRaffleData(raffleOwnerId)

        -- Log or debug-print
        print("RaffleEntryList for user: " .. raffleOwnerId .. " -> " .. json.encode(data.RaffleEntryList))

        -- Send response back to the requester, containing the entrant list
        msg.reply({
            Action = "View-Entrants-Response",
            Data   = json.encode(data.RaffleEntryList)
        })
    end
)

Handlers.add(
    "View Raffle Owners",
    Handlers.utils.hasMatchingTag("Action", "View-Raffle-Owners"),
    function(msg)
        print("Entered View Raffle Owners")

        -- Gather a list of userIds that have raffle data
        local userIds = {}
        for userId, _ in pairs(UserRaffleData) do
            table.insert(userIds, userId)
        end

        -- Send them back to the requestor
        msg.reply({
            Action = "View-Raffle-Owners-Response",
            Data   = json.encode(userIds)
        })
    end
)

print("Loaded Raffle.lua")

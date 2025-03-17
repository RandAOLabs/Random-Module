--local ao           = require('ao')
local json         = require('json')
local randomModule = require('random')(json)

RafflePullCount          = RafflePullCount or 0
RafflePulls              = RafflePulls or {}
RaffleEntryList          = RaffleEntryList or {}
RaffleEntryCount         = RaffleEntryCount or 0

function DrawNumber(user, guess)
    print("CreateGame called with user: " .. tostring(user) .. ", guess: " .. tostring(guess))

    -- Ensure Games table is initialized
    RafflePulls = RafflePulls or {}

    -- Increment GameCount
    RafflePullCount = RafflePullCount + 1
    local pullId = RafflePullCount

    -- Generate CallbackId
    local callbackId = randomModule.generateUUID()
    if not callbackId then
        error("Error: randomModule.generateUUID returned nil")
    end
    print("Generated CallbackId: " .. callbackId)

    -- Request a random number
    randomModule.requestRandom(callbackId)

    if type(callbackId) ~= "string" then
        print("Invalid callbackId: " .. tostring(callbackId))
    end

    print("Inserting into RafflePulls: ")
    print(tostring(pullId) .. " and value: " .. json.encode({
        User = user,
        Id = pullId,
        CallbackId = callbackId,
        Winner = nil
    }))

    -- Create Pull and add to RafflePulls table
    RafflePulls[pullId] = {
        User = user,
        Id = pullId,
        CallbackId = callbackId,
        Winner = nil
    }

    -- Log the created game
    if not RafflePulls[pullId] then
        print("Error: Failed to insert game into RafflePulls table")
    end
    print("Pull created: " .. json.encode(RafflePulls[pullId]))

    return pullId, callbackId
end

function RequestRandomNumber(callbackId)
    print("entered request random")
    randomModule.requestRandom(callbackId)
end

-- Function to update the raffle entry list
function UpdateRaffleEntryList(newList)
    RaffleEntryCount = 0
    print("UpdateRaffleEntryList called with new list: " .. json.encode(newList))
    for _, entry in pairs(newList) do
        table.insert(RaffleEntryList, entry)
        RaffleEntryCount = RaffleEntryCount + 1
    end
end

-- Function to find the pullId by callbackId
function FindPullIdByCallbackId(callbackId)
    print("Entered FindPullIdByCallbackId with callbackId: " .. tostring(callbackId))
    print("Current RafflePulls Table: " .. json.encode(RafflePulls))
    for pullId, pull in pairs(RafflePulls) do
        print("Checking PullId: " .. pullId .. ", Stored CallbackId: " .. tostring(pull.CallbackId))
        if pull.CallbackId == callbackId then
            return pullId
        end
    end
    print("No matching PullId found for CallbackId: " .. tostring(callbackId))
    return nil
end

Handlers.add(
    "updateRaffleEntryList",
    Handlers.utils.hasMatchingTag('Action', 'Update-Raffle-Entry-List'),
    function(msg)
        print("entered update raffle entry list")
        UpdateRaffleEntryList(json.decode(msg.Data))
    end
)

Handlers.add(
    "Raffle",
    Handlers.utils.hasMatchingTag('Action', 'Raffle'),
    function(msg)
        print("entered raffle")

        local userId                      = msg.From
        local pullId, callbackId = DrawNumber(userId)
        ao.send({
            Target = msg.From,
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
        print("CalllbackId: " .. callbackId .. " Entropy: " .. entropy)

        local pullId = FindPullIdByCallbackId(callbackId)
        print("PullId: " .. pullId)

        local randomNumber = math.floor(tonumber(entropy) % 10)
        print("Random Number: " .. randomNumber)
        local winningNumber = math.floor(tonumber(entropy) % RaffleEntryCount - 1)
        print("Winning Number: " .. winningNumber)

        local winner = RaffleEntryList[winningNumber]
        print("Winner: " .. winner)

        RafflePulls[pullId].Winner = winner
        RaffleEntryList[winningNumber] = nil
        RaffleEntryCount = RaffleEntryCount - 1

        ao.send({
            Target = RafflePulls[pullId].User,
            Action = "Raffle-Winner",
            Tags = {
                Winner = winner
            }
        })
    end
)

Handlers.add(
    'View Pull',
    Handlers.utils.hasMatchingTag('Action', 'View-Pull'),
    function(msg)
        print("entered view pull")
        local pullId = tonumber(msg.Tags.PullId)
        print(json.encode(RafflePulls[pullId]))
        ao.send({
            Target = msg.From,
            Action = "View-Pull-Response",
            Data = json.encode(RafflePulls[pullId])
        })
    end
)

Handlers.add(
    'View Pulls',
    Handlers.utils.hasMatchingTag('Action', 'View-Pulls'),
    function(msg)
        print("entered view pulls")
        print(json.encode(RafflePulls))
        ao.send({
            Target = msg.From,
            Action = "View-Pulls-Response",
            Data = json.encode(RafflePulls)
        })
    end
)

print("Loaded Raffle.lua")
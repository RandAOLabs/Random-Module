--local ao            = require('ao')
local json          = require('json')
local randomModule  = require('src.Random')()

Games = Games or {}
GameCount = GameCount or 0

function CreateGame(user, guess)
    GameCount           = GameCount + 1
    local gameId        = GameCount
    local callbackId    = randomModule.generateUUID()
    RequestRandomNumber(callbackId)
    Games[gameId]       = {
        User            = user,
        Id              = gameId,
        CallbackId      = callbackId,
        Guess           = guess,
        Result          = nil
    }
    return gameId, callbackId
end

function RequestRandomNumber(callbackId)
    print("entered request random")
    local providers = json.encode({provider_ids = {"ld4ncW8yLSkckjia3cw6qO7silUdEe1nsdiEvMoLg-0"}})
    randomModule.requestRandom(providers, callbackId)
end

function FindGameIdByCallbackId(callbackId)
    for gameId, game in pairs(Games) do
        if game.CallbackId == callbackId then
            return gameId
        end
    end
    return nil -- Return nil if no game is found
end

Handlers.add(
    "High-or-Low",
    Handlers.utils.hasMatchingTag('Action', 'High-or-Low'),
    function(msg)
        print("entered high or low")
        local userId                = msg.From
        local guess                 = msg.Tags.Guess
        local gameId, callbackId    = CreateGame(userId, guess)
        ao.send({
            Target  = msg.From,
            Action  = "Game Created",
            Tags    = {
                GameId      = gameId,
                CallbackId  = callbackId,
                Guess       = guess
            }
        })
    end
)

Handlers.add(
    'randomResponse',
    Handlers.utils.hasMatchingTag('Action', 'Random-Response'),
    function(msg)
        print("entered randomResponse")
        print(msg.Data)
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, json.decode(msg.Data))
        print("CalllbackId: " .. callbackId .. " Entropy: " .. entropy)

        local gameId        = FindGameIdByCallbackId(callbackId)
        local randomNumber  = math.floor(tonumber(entropy) % 10)
        local result        = nil

        -- Retrieve the player's guess
        local guess = Games[gameId].Guess

        -- Determine the result
        if (guess == "Higher" and randomNumber >= 5) or (guess == "Lower" and randomNumber < 5) then
            result = "Won"
        else
            result = "Lost"
        end

        Games[gameId].Result = result
        ao.send({
            Target = Games[gameId].User,
            Action = "HL-Result",
            Tags = {
                Result = result
            }
        })
    end
)

Handlers.add(
    'View Game',
    Handlers.utils.hasMatchingTag('Action', 'View-Game'),
    function(msg)
        print("entered view game")
        local gameId = msg.Tags.GameId
        print(json.encode(Games[gameId]))
        ao.send({
            Target = msg.From,
            Action = "View Game Response",
            Data = json.encode(Games[gameId])
        })
    end
)
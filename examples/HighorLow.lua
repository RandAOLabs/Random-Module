--local ao           = require('ao')
local json         = require('json')
local randomModule = require('random')(json)

Games              = Games or {}
GameCount          = GameCount or 0

function Init()
    randomModule.initialize()
end

function CreateGame(user, guess)
    print("CreateGame called with user: " .. tostring(user) .. ", guess: " .. tostring(guess))

    -- Ensure Games table is initialized
    Games = Games or {}

    -- Increment GameCount
    GameCount = GameCount + 1
    local gameId = GameCount

    -- Generate CallbackId
    local callbackId = randomModule.generateUUID()
    if not callbackId then
        error("Error: randomModule.generateUUID returned nil")
    end
    print("Generated CallbackId: " .. callbackId)

    -- Request a random number
    randomModule.requestRandom(callbackId)

    if type(user) ~= "string" then
        print("Invalid user: " .. tostring(user))
    end

    if guess ~= "Higher" and guess ~= "Lower" then
        print("Invalid guess: " .. tostring(guess))
    end

    if type(callbackId) ~= "string" then
        print("Invalid callbackId: " .. tostring(callbackId))
    end

    print("Inserting into Games: ")
    print(tostring(gameId) .. " and value: " .. json.encode({
        User = user,
        Id = gameId,
        CallbackId = callbackId,
        Guess = guess
    }))

    -- Create game and add to Games table
    Games[GameCount] = {
        User = user,
        Id = gameId,
        CallbackId = callbackId,
        Guess = guess
    }

    -- Log the created game
    if not Games[gameId] then
        print("Error: Failed to insert game into Games table")
    end
    print("Game created: " .. json.encode(Games[gameId]))

    return gameId, callbackId
end

function RequestRandomNumber(callbackId)
    print("entered request random")
    randomModule.requestRandom(callbackId)
end

function FindGameIdByCallbackId(callbackId)
    print("Entered FindGameIdByCallbackId with callbackId: " .. tostring(callbackId))
    print("Current Games Table: " .. json.encode(Games))
    for gameId, game in pairs(Games) do
        print("Checking GameId: " .. gameId .. ", Stored CallbackId: " .. tostring(game.CallbackId))
        if game.CallbackId == callbackId then
            return gameId
        end
    end
    print("No matching GameId found for CallbackId: " .. tostring(callbackId))
    return nil
end

Handlers.add(
    "High-or-Low",
    Handlers.utils.hasMatchingTag('Action', 'High-or-Low'),
    function(msg)
        print("entered high or low")
        ao.send({
            Target = msg.From,
            Action = "200"
        })
        local userId                      = msg.From
        local guess                       = msg.Tags.Guess
        local gameId, callbackId = CreateGame(userId, guess)
        ao.send({
            Target = msg.From,
            Action = "Game Created",
            Tags   = {
                GameId     = tostring(gameId),
                CallbackId = callbackId,
                Guess      = guess
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

        local gameId = FindGameIdByCallbackId(callbackId)
        print("GameId: " .. gameId)

        local randomNumber = math.floor(tonumber(entropy) % 10)
        print("Random Number: " .. randomNumber)

        local result = nil

        print("Random Number: " .. randomNumber)
        -- Retrieve the player's guess
        local guess = Games[gameId].Guess
        print("Guess: " .. guess)
        -- Determine the result
        if (guess == "Higher" and randomNumber >= 5) or (guess == "Lower" and randomNumber < 5) then
            result = "Won"
        else
            result = "Lost"
        end

        Games[gameId].Result = result
        print("Game: " .. json.encode(Games[gameId]))
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

print("Loaded HighOrLow.lua")
-- Example: RandomExample.lua

local ao           = require('ao')
local json         = require('json')
local randomModule = require('random')()

-- Map each callbackId -> the user who requested it
local callbackToUser = {}

-- Handler to request a random number
Handlers.add(
    "RequestRandom",
    Handlers.utils.hasMatchingTag("Action", "Request-Random"),
    function(msg)
        print("RequestRandom handler entered")

        -- Generate unique callbackId and store who asked for it
        local callbackId = randomModule.generateUUID()
        callbackToUser[callbackId] = msg.From

        print("Generated CallbackId: " .. tostring(callbackId))

        -- Now request the random from the random module
        randomModule.requestRandom(callbackId)
        print("Requested random for CallbackId: " .. callbackId)

        -- Optionally, we can let the user know we've started the request
        ao.send({
            Target = msg.From,
            Action = "RequestedRandomOk",
            Tags   = {
                CallbackId = callbackId
            }
        })
    end
)

-- Handler that receives the random number from the random module
Handlers.add(
    "randomResponse",
    Handlers.utils.hasMatchingTag("Action", "Random-Response"),
    function(msg)
        print("entered randomResponse")

        -- Process the random module’s response
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, msg.Data)
        print("CallbackId: " .. tostring(callbackId) .. ", Entropy: " .. tostring(entropy))

        -- Find which user originally requested this random number
        local user = callbackToUser[callbackId]
        if not user then
            print("No user found for callbackId: " .. tostring(callbackId))
            return
        end

        -- Compute a “dumb” random number, e.g. mod 10
        local randomNumber = math.floor(tonumber(entropy) % 10) + 1  -- +1 so it's 1-10
        print("Random Number: " .. randomNumber)

        -- Send that random number back to the user
        ao.send({
            Target = user,
            Action = "RandomNumberResult",
            Tags   = {
                RandomNumber = randomNumber
            }
        })

        -- (Optional) remove the callback from the table so it doesn't grow indefinitely
        callbackToUser[callbackId] = nil
    end
)

print("Loaded RandomExample.lua")

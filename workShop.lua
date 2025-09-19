local json = require('json')
local randomModule = require('random')(json)


State = State or {
    Requests = {
        -- CallbackId -> { user, entropy, timestamp }   
    },
}

NameCount = 2400
Cooldown = 6000
LastRequestTime = LastRequestTime or 0

Handlers.add(
    "RequestRandom",
    Handlers.utils.hasMatchingTag("Action", "Request-Random"),
    function(msg)
        print("RequestRandom handler entered")

        local now = msg.Timestamp / 1000
        local elapsed = now - LastRequestTime
        if elapsed < Cooldown then
            print("User " .. msg.From .. " must wait " .. (Cooldown - elapsed) .. " seconds to request again.")
            return
        end

        local callbackId = randomModule.generateUUID()
        randomModule.requestRandom(callbackId)

        State.Requests[callbackId] = {
            user = msg.From,
            Entropy = nil,
            Timestamp = msg.Timestamp / 1000
        }

        LastRequestTime = msg.Timestamp / 1000
    end
)

-- Handler for random number responses
Handlers.add(
    "RandomResponse",
    Handlers.utils.hasMatchingTag("Action", "Random-Response"),
    function(msg)
        -- Process the random module's response
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, msg.Data)
        print("Random Number Received!")
        print("CallbackId: " .. tostring(callbackId))
        print("Entropy: " .. tostring(entropy))

        -- Do something with the random number here!
        State.Requests[callbackId].Entropy = entropy
    end
)

Handlers.add(
    "ViewRandom",
    Handlers.utils.hasMatchingTag("Action", "View-Random"),
    function(msg)
        print("ViewRandom handler entered")

        local callbackId = msg.Tags.CallbackId
        local entropy = State.Requests[callbackId].Entropy
        print("Entropy: " .. tostring(entropy))

        ao.send({
            Target = msg.From,
            Action = "Random-Response",
            Data   = json.encode({
                entropy = entropy
            })
        })
    end
)
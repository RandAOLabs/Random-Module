local ao           = require('ao')
local json         = require('json')
local randomModule = require('random')(json)

-- GLOBALS:
CallbackDetails    = CallbackDetails or {}   -- map callbackId -> { user, min, max }
LastRequestTime    = LastRequestTime or {}   -- map userId -> last time (in seconds) they requested a random
UserGeneratedLogs  = UserGeneratedLogs or {} -- map userId -> array of {number, timestamp}

Whitelist = {
    ["ld4ncW8yLSkckjia3cw6qO7silUdEe1nsdiEvMoLg-0"] = true,
    [ao.id] = true
}

function UpdateProviderList()
    local providerList = {
        "XUo8jZtUDBFLtp5okR12oLrqIZ4ewNlTpqnqmriihJE",
        "vJnpGjZrOetokWpgV50-xBxanCGP1N9Bjtj-kH1E_Ac",
        "oFmKGpZpBB8TKI3qMyaJduRqe9mJ3kb98lS9xnfsFTA"
    }
    randomModule.setProviderList(providerList)
end

function GetTimeDisplay(totalSeconds)
    local seconds = math.floor(totalSeconds % 60)
    local minutes = math.floor(totalSeconds / 60)
    local parts   = {}

    if minutes > 0 then
        table.insert(parts, minutes .. (minutes == 1 and " minute" or " minutes"))
    end
    if seconds > 0 then
        table.insert(parts, seconds .. (seconds == 1 and " second" or " seconds"))
    end

    if #parts == 0 then
        return "0 seconds"
    elseif #parts == 1 then
        return parts[1]
    else
        return table.concat(parts, " and ")
    end
end

Handlers.add(
    "RequestRandom",
    Handlers.utils.hasMatchingTag("Action", "Request-Random"),
    function(msg)
        print("RequestRandom handler entered")

        local user = msg.From
        local now  = msg.Timestamp / 1000  -- convert ms to seconds

        -- If they're not whitelisted, enforce 60-second cooldown
        if not Whitelist[user] then
            local lastTime = LastRequestTime[user] or 0
            local elapsed  = now - lastTime
            if elapsed < 60 then
                local remain = 60 - elapsed
                print("User " .. user .. " must wait " .. remain .. " seconds to request again.")

                ao.send({
                    Target = user,
                    Action = "RandomRequestDenied",
                    Tags   = {
                        WaitTime = GetTimeDisplay(remain)
                    }
                })
                return
            end
        end

        -- Record this request time
        LastRequestTime[user] = now

        -- Read the requested min/max from the message tags (default to 1..10)
        local minVal = tonumber(msg.Tags.Minimum) or 1
        local maxVal = tonumber(msg.Tags.Maximum) or 100
        print("User " .. user .. " requested random range: " .. minVal .. " to " .. maxVal)

        -- Generate unique callbackId
        local callbackId = randomModule.generateUUID()

        -- Store all necessary details so we know how to handle the random later
        CallbackDetails[callbackId] = {
            user = user,
            min  = minVal,
            max  = maxVal,
            timestamp = now  -- Store the time when request was made
        }

        print("Generated CallbackId: " .. tostring(callbackId))

        -- Request the random from the random module
        randomModule.requestRandom(callbackId)
        print("Requested random for CallbackId: " .. callbackId)

        -- Let the user know we've started the request
        ao.send({
            Target = user,
            Action = "RequestedRandomOk",
            Tags   = {
                CallbackId = callbackId
            }
        })
    end
)

Handlers.add(
    "randomResponse",
    Handlers.utils.hasMatchingTag("Action", "Random-Response"),
    function(msg)
        print("entered randomResponse")

        -- Process the random module’s response
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, msg.Data)
        print("CallbackId: " .. tostring(callbackId) .. ", Entropy: " .. tostring(entropy))

        -- Retrieve the stored details for this callback
        local details = CallbackDetails[callbackId]
        if not details then
            print("No details found for callbackId: " .. tostring(callbackId))
            return
        end

        local user = details.user
        local min  = details.min
        local max  = details.max
        local timestamp = details.timestamp  -- Retrieve stored request time

        -- Compute a random number in the [min..max] range
        local rangeSize = max - min + 1
        if rangeSize <= 0 then
            -- Edge case: if max < min or they are equal
            -- Default to 1..10 instead
            print("Invalid range requested; defaulting to 1..10")
            rangeSize = 10
            min, max  = 1, 10
        end

        local rawNum       = math.floor(tonumber(entropy) % rangeSize)
        local randomNumber = min + rawNum
        print("Generated random number in range: " .. min .. " - " .. max .. " => " .. randomNumber)

        -- Add this number and its request time to the user's log
        UserGeneratedLogs[user] = UserGeneratedLogs[user] or {}
        table.insert(UserGeneratedLogs[user], {
            number = randomNumber,
            timestamp = timestamp
        })

        -- Send that random number back to the user
        ao.send({
            Target = user,
            Action = "RandomNumberResult",
            Tags   = {
                RandomNumber = randomNumber
            }
        })

        -- Clean up the callback details
        CallbackDetails[callbackId] = nil
    end
)

-- Handler to view the most recently generated number for a user
Handlers.add(
    "ViewLastRandom",
    Handlers.utils.hasMatchingTag("Action", "View-Last-Random"),
    function(msg)
        print("Entered ViewLastRandom")

        -- The user we want to check
        local userId = msg.Tags.UserId or msg.From

        local logs = UserGeneratedLogs[userId]
        if not logs or #logs == 0 then
            print("No logs for user: " .. userId)
            ao.send({
                Target = msg.From,
                Action = "ViewLastRandom-Response",
                Data   = json.encode({
                    userId      = userId,
                    lastRandom  = nil,
                    timestamp   = nil,
                    message     = "No random numbers found for this user."
                })
            })
            return
        end

        local lastEntry = logs[#logs]  -- Get the last generated number and timestamp
        local lastRandom = lastEntry.number
        local lastTimestamp = lastEntry.timestamp

        print("Last random for user " .. userId .. " => " .. tostring(lastRandom) .. " at " .. tostring(lastTimestamp))

        ao.send({
            Target = msg.From,
            Action = "ViewLastRandom-Response",
            Data   = json.encode({
                userId     = userId,
                lastRandom = lastRandom,
                timestamp  = lastTimestamp or 0
            })
        })
    end
)

Handlers.add(
    "ViewAllRandom",
    Handlers.utils.hasMatchingTag("Action", "View-All-Random"),
    function(msg)
        print("Entered ViewAllRandom")

        -- Determine which user we're checking: either specified, or the message sender
        local userId = msg.Tags.UserId or msg.From

        -- Retrieve the logs for this user
        local logs = UserGeneratedLogs[userId]
        if not logs or #logs == 0 then
            print("No logs for user: " .. userId)
            ao.send({
                Target = msg.From,
                Action = "ViewAllRandom-Response",
                Data   = json.encode({
                    userId  = userId,
                    logs    = {},
                    message = "No random numbers found for this user."
                })
            })
            return
        end

        -- If logs exist, return the entire array
        print("Returning all random entries for user: " .. userId)
        ao.send({
            Target = msg.From,
            Action = "ViewAllRandom-Response",
            Data   = json.encode({
                userId = userId,
                logs   = logs
            })
        })
    end
)

print("Loaded RandomNumber.lua")
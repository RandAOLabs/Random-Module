-- You no longer need these single global variables at the top:
-- SweepstakesPullCount          = SweepstakesPullCount or 0
-- SweepstakesPulls              = SweepstakesPulls or {}
-- SweepstakesEntryList          = SweepstakesEntryList or {}
-- SweepstakesEntryCount         = SweepstakesEntryCount or 0

local ao           = require('ao')
local json         = require('json')
local randomModule = require('random')(json)

-- This table will map: userId -> {
--    SweepstakesPullCount  = <number>,
--    SweepstakesPulls      = <table>,
--    SweepstakesEntryList  = <table>,
--    SweepstakesEntryCount = <number>
-- }
UserSweepstakesData = UserSweepstakesData or {}

LastSweepstakesTime = LastSweepstakesTime or {}

PaymentToken  = "5ZR9uegKoEhE9fJMbs-MvWLIztMNCVxgpzfeBVE3vqI" -- xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10
Cost          = 100000000000

-- This table maps callbackId -> userId,
-- so we know which user to associate the random response with
CallbackToUser = CallbackToUser or {}

SweepstakesWhitelist = SweepstakesWhitelist or {}

-- Utility function to show random module configuration
function ShowConfig()
    randomModule.showConfig()
end

-- Utility function to check if a user is in the whitelist
function WhitelistedUser(userId)
   for _, user in pairs(SweepstakesWhitelist) do
      if user == userId then
         return true
      end
   end
   return false
end

-- Utility function to get or initialize a user's sweepstakes data
function GetUserSweepstakesData(userId)
    if not UserSweepstakesData[userId] then
        UserSweepstakesData[userId] = {
            SweepstakesPullCount  = 0,
            SweepstakesPulls      = {},
            SweepstakesEntryList  = {},
            SweepstakesEntryCount = 0,
        }
    end
    local userData = UserSweepstakesData[userId]
    return userData
end

-- DrawNumber now only updates the sweepstakes data for the given user
function DrawNumber(user)
    print("DrawNumber called with user: " .. tostring(user))

    local data = GetUserSweepstakesData(user)
    data.SweepstakesPullCount = data.SweepstakesPullCount + 1
    local pullId = data.SweepstakesPullCount

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

    print("Inserting into SweepstakesPulls for user: " .. tostring(user))
    print("PullId: " .. tostring(pullId) .. ", value: " .. json.encode({
        User       = user,
        Id         = pullId,
        CallbackId = callbackId,
        Winner     = nil
    }))

    data.SweepstakesPulls[pullId] = {
        User       = user,
        Id         = pullId,
        CallbackId = callbackId,
        Winner     = nil
    }

    print("Pull created: " .. json.encode(data.SweepstakesPulls[pullId]))
    return pullId, callbackId
end

-- Function to request a random number
function RequestRandomNumber(callbackId)
    print("entered request random")
    randomModule.requestRandom(callbackId)
end

-- Function to update a specific user's sweepstakes entry list
function UpdateSweepstakesEntryList(userId, newList)
    local data = GetUserSweepstakesData(userId)
    data.SweepstakesEntryCount = 0
    data.SweepstakesEntryList  = {} -- reset
    print("UpdateSweepstakesEntryList called for user " .. tostring(userId) .. " with new list: " .. json.encode(newList))

    for _, entry in ipairs(newList) do
        table.insert(data.SweepstakesEntryList, entry)
        data.SweepstakesEntryCount = data.SweepstakesEntryCount + 1
    end
end

-- Function to find the pullId by callbackId within a single user's data
function FindPullIdByCallbackId(userData, callbackId)
    print("Entered FindPullIdByCallbackId with callbackId: " .. tostring(callbackId))
    print("User's SweepstakesPulls Table: " .. json.encode(userData.SweepstakesPulls))
    for pullId, pull in pairs(userData.SweepstakesPulls) do
        print("Checking PullId: " .. pullId .. ", Stored CallbackId: " .. tostring(pull.CallbackId))
        if pull.CallbackId == callbackId then
            return pullId
        end
    end
    print("No matching PullId found for CallbackId: " .. tostring(callbackId))
    return nil
end

-- Utility function to display time in a human-readable format
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

-- Utility function to return tokens
function ReturnTokens(token, userId, quantity)
    ao.send({
      Target = token,
      Action = "Transfer",
      Recipient = userId,
      Quantity = tostring(quantity),
      ["X-Note"] = "Wrong token or quantity"
    })
end

Handlers.add(
  "CreditNoticeHandler",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  function(msg)
    print("credit-notice")

    local userId = msg.Tags.Sender
    local quantity = tonumber(msg.Tags.Quantity)
    local entrants = msg.Tags["X-Entrants"] or nil
    print(msg.From)
    assert(msg.From == PaymentToken, "Payment token should be " .. PaymentToken)
    assert(quantity == Cost, "Cost should be " .. tostring(Cost))
    assert(not WhitelistedUser(userId), "User should be whitelisted")
    if msg.From ~= PaymentToken or quantity ~= Cost or WhitelistedUser(userId) then
        print("Returning tokens")
        ReturnTokens(msg.From, userId, quantity)
        return
    end

    print("Adding user to whitelist")
    table.insert(SweepstakesWhitelist, userId)

    if entrants then
        UpdateSweepstakesEntryList(userId, json.decode(entrants))
    end
end
)

Handlers.add(
    "updateSweepstakesEntryList",
    Handlers.utils.hasMatchingTag('Action', 'Update-Sweepstakes-Entry-List'),
    function(msg)
        print("entered update sweepstakes entry list")
        -- Update the sweepstakes entry list only for the user who sent the message
        UpdateSweepstakesEntryList(msg.From, json.decode(msg.Data))
    end
)

Handlers.add(
    "Sweepstakes",
    Handlers.utils.hasMatchingTag('Action', 'Pull-Sweepstakes'),
    function(msg)
        print("entered pull sweepstakes")

        local userId             = msg.From
        local userData = GetUserSweepstakesData(userId)

        if userData.SweepstakesEntryCount == 0 or #userData.SweepstakesEntryList == 0 or not WhitelistedUser(userId) then
            print("User " .. userId .. " tried to pull a sweepstakes but has no entrants!")
            ao.send({
                Target = userId,
                Action = "Sweepstakes Pull Denied",
                Tags   = {
                    Reason = "No entrants have been set up for your sweepstakes."
                }
            })
            return
        end

        local pullId, callbackId = DrawNumber(userId)
        ao.send({
            Target = userId,
            Action = "Sweepstakes Pull Created",
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
        local userData = GetUserSweepstakesData(user)
        local pullId = FindPullIdByCallbackId(userData, callbackId)
        local userId = userData.SweepstakesPulls[pullId].User

        print("PullId: " .. tostring(pullId))

        if not pullId then
            print("No valid pullId found; ignoring randomResponse.")
            return
        end

        -- Example usage:
        local randomNumber   = math.floor(tonumber(entropy) % 10)
        print("Random Number: " .. randomNumber)
        --local winningIndex   = math.floor(tonumber(entropy) % userData.SweepstakesEntryCount) -- 0-based?

        -- Adjust as needed. For example, if your code expects 1-based indexing:
        local winningIndex = math.floor(tonumber(entropy) % userData.SweepstakesEntryCount) + 1

        print("Winning Index: " .. winningIndex)

        local winner = userData.SweepstakesEntryList[winningIndex]
        print("Winner: " .. tostring(winner))

        userData.SweepstakesPulls[pullId].Winner = winner

        -- If you want to remove that winner from the list
        if winner then
            -- remove the element from the list so it won't be sparse
            table.remove(userData.SweepstakesEntryList, winningIndex)
            userData.SweepstakesEntryCount = userData.SweepstakesEntryCount - 1
        end

        ao.send({
            Target = userId,
            Action = "Sweepstakes-Winner",
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
        local data = GetUserSweepstakesData(user)

        local pullId = tonumber(msg.Tags.PullId)
        if data.SweepstakesPulls[pullId] then
            print(json.encode(data.SweepstakesPulls[pullId]))
            ao.send({
                Target = user,
                Action = "View-Pull-Response",
                Data   = json.encode(data.SweepstakesPulls[pullId])
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
    'Get Sweepstakes',
    Handlers.utils.hasMatchingTag('Action', 'Get-Sweepstakes'),
    function(msg)
        print("entered get sweepstakes")
        local user = msg.Tags.UserId
        ao.send({
            Target = user,
            Action = "Get-Sweepstakes-Response",
            Data   = json.encode(UserSweepstakesData[user])
        })
    end
)

Handlers.add(
    'Get All Sweepstakes',
    Handlers.utils.hasMatchingTag('Action', 'Get-All-Sweepstakes'),
    function(msg)
        print("entered get all sweepstakes")
        print(json.encode(UserSweepstakesData))
        ao.send({
            Target = msg.From,
            Action = "Get-All-Sweepstakes-Response",
            Data = json.encode(UserSweepstakesData)
        })
    end
)

Handlers.add(
    "View Entrants",
    Handlers.utils.hasMatchingTag("Action", "View-Entrants"),
    function(msg)
        print("Entered View Entrants")

        -- `msg.Tags.UserId` is who "owns" the sweepstakes we want to view.
        -- If none is provided, fall back to the user making the request.
        local sweepstakesOwnerId = msg.Tags.UserId or msg.From

        -- Retrieve that user’s sweepstakes data
        local data = GetUserSweepstakesData(sweepstakesOwnerId)

        -- Log or debug-print
        print("SweepstakesEntryList for user: " .. sweepstakesOwnerId .. " -> " .. json.encode(data.SweepstakesEntryList))

        -- Send response back to the requester, containing the entrant list
        msg.reply({
            Action = "View-Entrants-Response",
            Data   = json.encode(data.SweepstakesEntryList)
        })
    end
)

Handlers.add(
    "View Sweepstakes Whitelist",
    Handlers.utils.hasMatchingTag("Action", "View-Sweepstakes-Whitelist"),
    function(msg)
        print("Entered View Sweepstakes Whitelist")
        -- Send them back to the requestor
        msg.reply({
            Action = "View-Sweepstakes-Whitelist-Response",
            Data   = json.encode(SweepstakesWhitelist)
        })
    end
)

print("Loaded Sweepstakes.lua")
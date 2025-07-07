-- Sweepstakes.lua
local ao = require('ao')
local json = require('json')
local random = require('random')(json)

-- Persistent storage
SweepstakesData = SweepstakesData or {}
CallbackToSweep = CallbackToSweep or {}

-- Constants
Admin           = "N90q65iT59dCo01-gtZRUlLMX0w6_ylFHv2uHaSUFNk"
PaymentToken    = "0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc"
Cost            = 100000000000

-- Utility: count pending pulls
local function pendingPulls(sweep)
    local cnt = 0
    for _, pull in pairs(sweep.Pulls) do
      if not pull.Winner then cnt = cnt + 1 end
    end
    return cnt
end

-- Utility: initialize or retrieve a sweepstakes
local function getSweep(sweepId)
    if not SweepstakesData[sweepId] then
        SweepstakesData[sweepId] = {
            Creator = nil,
            Details = nil,
            Entries = {},
            EntryCount = 0,
            Pulls = {},
            PullCount = 0
        }
    end
    return SweepstakesData[sweepId]
end

-- Utility: find pullId by callback in a sweep
local function findPull(sweep, callbackId)
    for pid, pull in pairs(sweep.Pulls) do
        if pull.CallbackId == callbackId then
            return pid
        end
    end
    return nil
end

-- Utility: return tokens on error
local function returnTokens(token, userId, qty)
    ao.send({
        Target = token,
        Action = "Transfer",
        Recipient = userId,
        Quantity = tostring(qty),
        ["X-Note"] = "Invalid sweepstakes purchase"
    })
end

-- Handler: purchase sweepstakes (with optional entrants list)
Handlers.add(
    "PurchaseSweepstakes",
    Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
    function(msg)
        local userId = msg.Tags.Sender
        local qty = tonumber(msg.Tags.Quantity)

        -- validate payment
        if msg.From ~= PaymentToken or qty ~= Cost then
            returnTokens(msg.From, userId, qty)
            return
        end

        -- create new sweepstakes id
        local sweepId = random.generateUUID()
        assert(sweepId, "Failed to generate sweepstakes ID")

        -- init sweep
        local sweep = getSweep(sweepId)
        sweep.Creator = userId

        -- parse and store initial entrants (if provided)
        if msg.Tags["X-Entrants"] and msg.Tags["X-Entrants"] ~= "" then
            local list = json.decode(msg.Tags["X-Entrants"])
            sweep.Entries = list
            sweep.EntryCount = #list
        end

        -- parse and store details (if provided)
        if msg.Tags["X-Details"] and msg.Tags["X-Details"] ~= "" then
            sweep.Details = msg.Tags["X-Details"]
        end

        -- respond with new sweepstakes ID
        ao.send({
            Target = userId,
            Action = "Sweepstakes-Purchased",
            Tags = { SweepstakesId = sweepId }
        })
    end
)

-- Handler: add a single entry to sweepstakes
Handlers.add(
    "AddSweepstakesEntry",
    Handlers.utils.hasMatchingTag("Action", "Add-Sweepstakes-Entry"),
    function(msg)
        local userId = msg.From
        local sweepId = msg.Tags.SweepstakesId
        assert(SweepstakesData[sweepId] ~= nil, "Sweepstakes does not exist")
        local sweep = getSweep(sweepId)
        -- only creator can add
        if sweep.Creator ~= userId then return end
        -- no modifications after pull
        if sweep.PullCount > 0 then
            ao.send({ Target = userId, Action = "Entry-Add-Denied", Tags = { Reason = "Cannot add entries after pull" } })
            return
        end
        -- add entry
        local entry = msg.Tags.Entry
        table.insert(sweep.Entries, entry)
        sweep.EntryCount = #sweep.Entries
        ao.send({ Target = userId, Action = "Entry-Added", Tags = { SweepstakesId = sweepId, Entry = entry } })
    end
)

-- Handler: bulk update entries before pull
Handlers.add(
    "UpdateSweepstakesEntryList",
    Handlers.utils.hasMatchingTag("Action", "Update-Sweepstakes-Entry-List"),
    function(msg)
        local userId = msg.From
        local sweepId = msg.Tags.SweepstakesId
        assert(SweepstakesData[sweepId] ~= nil, "Sweepstakes does not exist")
        local sweep = getSweep(sweepId)
        -- only creator can bulk update
        if sweep.Creator ~= userId then return end

        -- prevent after pull
        if sweep.PullCount > 0 then
            ao.send({ Target = userId, Action = "Entries-Update-Denied", Tags = { Reason = "Cannot update entries after pull" } })
            return
        end

        -- replace entire entrants list
        local newList = {}
        if msg.Data and msg.Data ~= "" then
            newList = json.decode(msg.Data)
        end

        sweep.Entries = newList
        sweep.EntryCount = #newList
        ao.send({ Target = userId, Action = "Entries-Updated", Tags = { SweepstakesId = sweepId }, Data = msg.Data })
    end
)

-- Handler: pull winner
Handlers.add(
    "PullSweepstakes",
    Handlers.utils.hasMatchingTag("Action", "Pull-Sweepstakes"),
    function(msg)
        local userId = msg.From
        local sweepId = msg.Tags.SweepstakesId or nil
        if not sweepId then return end

        -- parse pull-details
        local details = msg.Tags.Details or nil

        assert(SweepstakesData[sweepId] ~= nil, "Sweepstakes does not exist")
        local sweep = getSweep(sweepId)

        -- auth & entries check
        if sweep.Creator ~= userId then
            ao.send({ Target = userId, Action = "Sweepstakes-Pull-Denied", Tags = { Reason = "Not authorized" } })
            return
        end

        -- refuse if no entries left to pull
        local avail = sweep.EntryCount - pendingPulls(sweep)
        if avail <= 0 then
            ao.send({
                Target = userId,
                Action = "Sweepstakes-Pull-Denied",
                Tags   = { Reason = "No entries left to pull" }
            })
            return
        end

        -- record pull
        sweep.PullCount = sweep.PullCount + 1
        local pullId = sweep.PullCount
        local callbackId = random.generateUUID()

        sweep.Pulls[pullId] = { Id = pullId, CallbackId = callbackId, Details = details, Winner = nil }
        CallbackToSweep[callbackId] = { SweepId = sweepId, User = userId }
        random.requestRandom(callbackId)
        ao.send({ Target = userId, Action = "Sweepstakes-Pull-Created", Tags = { SweepstakesId = sweepId, PullId = tostring(pullId) }, Data = json.encode(details) })
    end
)

-- Handler: process random response
Handlers.add(
    "RandomResponse",
    Handlers.utils.hasMatchingTag("Action", "Random-Response"),
    function(msg)
        local callbackId, entropy = random.processRandomResponse(msg.From, msg.Data)
        local map = CallbackToSweep[callbackId]

        if not map then return end

        local sweep = getSweep(map.SweepId)
        local pullId = findPull(sweep, callbackId)

        if not pullId then return end

        local pull = sweep.Pulls[pullId]

        -- select winner
        local idx = math.floor(tonumber(entropy) % (#sweep.Entries)) + 1
        local winner = sweep.Entries[idx]
        pull.Winner = winner
        -- remove winner
        table.remove(sweep.Entries, idx)
        sweep.EntryCount = #sweep.Entries
        ao.send({
            Target = map.User,
            Action = "Sweepstakes-Winner",
            Tags = { SweepstakesId = map.SweepId, PullId = tostring(pullId), Details = pull.Details, CallbackId = callbackId, Winner = winner },
        })
    end
)

-- Handler: view single pull
Handlers.add(
    "ViewPull",
    Handlers.utils.hasMatchingTag("Action", "View-Pull"),
    function(msg)
        local sweepId = msg.Tags.SweepstakesId
        local pullId = tonumber(msg.Tags.PullId)
        local sweep = getSweep(sweepId)
        local pull = sweep.Pulls[pullId]
        if pull then
            ao.send({ Target = msg.From, Action = "View-Pull-Response", Data = json.encode(pull) })
        else
            ao.send({ Target = msg.From, Action = "View-Pull-Response", Data = "No pull found" })
        end
    end
)

-- Handler: get sweep data
Handlers.add(
    "GetSweepstakes",
    Handlers.utils.hasMatchingTag("Action", "Get-Sweepstakes"),
    function(msg)
        local sweepId = msg.Tags.SweepstakesId
        local sweep = getSweep(sweepId)
        ao.send({ Target = msg.From, Action = "Get-Sweepstakes-Response", Data = json.encode(sweep) })
    end
)

-- Handler: get all sweeps
Handlers.add(
    "GetAllSweepstakes",
    Handlers.utils.hasMatchingTag("Action", "Get-All-Sweepstakes"),
    function(msg)
        ao.send({ Target = msg.From, Action = "Get-All-Sweepstakes-Response", Data = json.encode(SweepstakesData) })
    end
)

Handlers.add(
    "Delete",
    Handlers.utils.hasMatchingTag("Action", "Delete"),
    function(msg)
        assert(msg.From == Admin, "Unauthorized")

        local sweepId = msg.Tags.SweepstakesId or nil
        local pullId = msg.Tags.PullId or nil
        local callbackId = msg.Tags.CallbackId or nil

        if sweepId and not pullId then
           SweepstakesData[sweepId] = nil
        end

        if pullId and sweepId then
           local sweep = getSweep(sweepId)
           sweep.Pulls[tonumber(pullId)] = nil
        end

        if callbackId then
           CallbackToSweep[callbackId] = nil
        end
    end
)


function helper()
    random.showConfig()
end

print("Loaded Sweepstakes.lua")

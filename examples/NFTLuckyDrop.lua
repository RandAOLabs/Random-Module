local ao           = require('ao')
local randomModule = require('random')()
local json         = require('json')

-- GLOBALS:
CallbackDetails    = CallbackDetails or {}   -- map callbackId -> { user, min, max }
UserGeneratedLogs  = UserGeneratedLogs or {} -- map userId -> array of {number, timestamp}

LuckyNft         = 'J65FF96wfJQ6vJvbxYDlk9igok-BzZKVT4G_G0qmsd0'
UnluckyNft       = 'iy-3Mt2kiIS61pXkr1a8iA8BBigu1xKe0AtuyU-KwDw'
MintToken        = '7W3Hsb2PmY2LqOV9AhuvebH9fzGFwXBA8dTduvdFYGY'

function SendTransfer(target, recipient)
    assert(type(target) == 'string', 'Target is required!')
    assert(type(recipient) == 'string', 'Recipient is required!')

    ao.send({
        Target = target,
        Action = "Transfer",
        Tags = {
            Recipient = recipient,
            Quantity = "1"
        }
    })
end

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

        local recipient = details.recipient

        local rawNum       = math.floor(tonumber(entropy) % 10) + 1
        local lucky        = rawNum >= 7
        print("Generated random number in range: 1 - 10 => " .. rawNum)

        -- Add this number and its request time to the user's log
        UserGeneratedLogs[recipient] = UserGeneratedLogs[recipient] or {}
        table.insert(UserGeneratedLogs[recipient], {
            number = rawNum,
            lucky = lucky
        })

        -- Send lucky/unlucky back to user based on random number
        if lucky then
           -- Send lucky NFT back to user
           SendTransfer(LuckyNft, recipient)
           print("Sent lucky NFT back to user: " .. recipient)
        else
           -- Send unlucky NFT back to user
           SendTransfer(UnluckyNft, recipient)
           print("Sent unlucky NFT back to user: " .. recipient)
        end
    end
)

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

    if msg.From == "5ZR9uegKoEhE9fJMbs-MvWLIztMNCVxgpzfeBVE3vqI" then
      print("Funded for requests")
      return
    end

    local userId = msg.Tags['X-Bazar-Profile'] or msg.Tags.Sender
    local quantity = tonumber(msg.Tags.Quantity)

    if msg.From ~= MintToken or quantity ~= 1 then
      print("Returning tokens")
      ReturnTokens(msg.From, userId, quantity)
      return
    end

    print("Sending random request for user: " .. userId)

    -- Generate unique callbackId
    local callbackId = randomModule.generateUUID()
    -- Store all necessary details so we know how to handle the random later
    CallbackDetails[callbackId] = {
        recipient = userId,
    }

    -- Request a random number
    randomModule.requestRandom(callbackId)
  end
)

Handlers.add(
    "ViewReceivedItems",
    Handlers.utils.hasMatchingTag("Action", "View-Received-Items"),
    function(msg)
        print("Entered ViewReceivedItems")

        local userId = msg.Tags.UserId or msg.From

        -- Check if user has received anything
        local logs = UserGeneratedLogs[userId]
        if not logs or #logs == 0 then
            print("No received items for user: " .. userId)
            ao.send({
                Target = msg.From,
                Action = "ViewReceivedItems-Response",
                Data   = json.encode({
                    userId      = userId,
                    received    = {},
                    message     = "You have not received any items yet."
                })
            })
            return
        end

        -- Send back the list of received items
        print("Returning received items for user: " .. userId)
        ao.send({
            Target = msg.From,
            Action = "ViewReceivedItems-Response",
            Data   = json.encode({
                userId   = userId,
                received = logs  -- Includes { number, lucky } for each entry
            })
        })
    end
)

print("Loaded NFTLuckyDrop.lua")
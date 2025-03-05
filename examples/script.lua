local json = require('json')
local randomModule = require('random')(json)

function Records()
    ao.send({
        Target = "byaUfQzuojukjWPIQd9-qpGPrO9Nrlqqfib4879LyCE",
        Action = "Records"
    })
end

function Controllers()
    ao.send({
        Target = "byaUfQzuojukjWPIQd9-qpGPrO9Nrlqqfib4879LyCE",
        Action = "Controllers"
    })
end

function Init()
    randomModule.initialize()
end

function SetConfig(paymentToken, randomCost, randomProcess)
    randomModule.setConfig(paymentToken, randomCost, randomProcess)
end

function Config()
    randomModule.showConfig()
end
# RandAO Module

The **RandAO Module** is a pure Lua library designed to enable seamless interaction with the RandAO randomness protocol. This module provides two core functionalities: 

1. **Request Random**: Send a request for random values by transferring tokens to the randomness protocol.
2. **View Random**: Check the status of a previously requested random value using a callback ID.

---

## Features
- **Pure Lua**: No external dependencies required—built specifically for the AO platform.
- **Token-Backed Randomness**: Utilizes RandAO tokens to securely generate random values.
- **Asynchronous Status Tracking**: Retrieve the status of your randomness request with ease.

---

## Installation

Add the `random.lua` file to your project directory. You can then import the module and require it in your code passing the `json` library as an argument:
```lua
local randomModule = require('random')(json)
```
You can then use the `randomModule.init()` function to initialize the module with the most recent configuration.

---

## Usage

### Request Random
To request random values from the active provider pool:
- Call `requestRandom` with a `callbackId` parameter.

To request random with your own provider pool:
- Call `setProviderList` with a list of provider IDs as the `providerList` parameter to set your provider list pool.
- Call `requestRandomFromProviders` with a `callbackId` parameter, this uses the set `Providers` list to request the value, allowing more control for the customer.

These actions deduct **100 RandAO tokens** from the caller's account.
### View Random
To view the status of a random request:
- Call `viewRandomStatus` with the `callbackId` you received from your `requestRandom` action.
- Possible statuses:
  - **PENDING**: The randomness request is in progress.
  - **CACKING**: The randomness request is being computed.
  - **SUCCESS**: The randomness request has been completed.
  - **FAILED**: The randomness request failed.

> The expected time to complete a randomness request is approximately **10 seconds** and dropping fast as AO network improvements are made.

---

## Code Examples

### Using the RandAO Module

Setting up the module:
```lua
  local randomModule = require('random')(json)
  randomModule.init()
```

Setting custom provider list:
```lua
  local providerList = {
      "XUo8jZtUDBFLtp5okR12oLrqIZ4ewNlTpqnqmriihJE",
      "vJnpGjZrOetokWpgV50-xBxanCGP1N9Bjtj-kH1E_Ac",
      "oFmKGpZpBB8TKI3qMyaJduRqe9mJ3kb98lS9xnfsFTA"
  }
  randomModule.setProviderList(providerList)
```
Generating a unique callbackId:
```lua
  local callbackId = randomModule.generateUUID()
```

Requesting random from default provider pool:
```lua
  randomModule.requestRandom(callbackId)
```

Requesting random from custom provider pool:
```lua
  randomModule.requestRandomFromProviders(callbackId)
```

Basic handler for receiving random responses:
```lua
  Handlers.add(
      "RandomResponse",
      Handlers.utils.hasMatchingTag("Action", "RandomResponse"),
      function(msg)
        -- Process the random module’s response
        local callbackId, entropy = randomModule.processRandomResponse(msg.From, msg.Data)
        print("CallbackId: " .. tostring(callbackId) .. ", Entropy: " .. tostring(entropy))
      end
  )
```
---

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for more details.

---

## Contributing

Contributions are welcome! If you'd like to improve this module, please:
- Open an issue to report bugs or suggest features.
- Submit a pull request with your changes.

Happy randomizing! 🎲

# RandAO Module

The **RandAO Module** is a pure Lua library designed to enable seamless interaction with the RandAO randomness protocol. This module provides five core functionalities:

1. **Request Random**: Send a request for fresh random values by transferring tokens to the randomness protocol.  
2. **Request Random from Providers**: Send a request for random values using a custom list of entropy providers.  
3. **Prepay for Randomness Credits**: Purchase “units” of randomness in advance, so future random requests draw from prepaid credit.  
4. **Redeem Random Credit**: Use prepaid randomness credits to make a request, with optional provider selection.  
5. **View Random Status**: Check the status of a previously requested random value using a callback ID.  

---

## Features
- **Pure Lua**: No external dependencies required—built specifically for the AO platform.  
- **Token-Backed Randomness**: Utilizes RandAO tokens to securely generate random values.  
- **Prepaid Credits**: Pay up front for multiple requests to streamline batching and reduce on-the-fly token transfers.  
- **Optional Provider Control**: Choose which registered entropy providers contribute to your random result.  
- **Asynchronous Status Tracking**: Retrieve the status of your randomness request with ease.  

---

## Installation

Add the `random.lua` file to your project directory. You can then import the module and require it in your code, passing in the `json` library as an argument:

```lua
local randomModule = require('random')(json)
randomModule.init()
```

After initialization, the module reads your on-chain configuration (token address, cost per unit, process ID, etc.) and exposes the functions below.

---

## Usage

### 1. Request Random
Deducts **1 unit** (cost defined by on-chain `RandomCost`) and sends a `Request-Random` transfer to the protocol.

```lua
randomModule.requestRandom(callbackId)
```

- **Arguments**:
  - `callbackId` (string): Unique identifier to correlate the eventual response.

---

### 2. Request Random from Custom Providers
First set your desired provider list, then request random using those providers.

```lua
randomModule.setProviderList(providerList)
randomModule.requestRandomFromProviders(callbackId)
```

- **Arguments**:
  - `providerList` (table of strings): List of provider IDs to use.  
  - `callbackId` (string): Unique identifier for this request.

---

### 3. Prepay for Randomness Credits

```lua
randomModule.prepayForRandom(units)
```

Sends a token transfer to the configured `RandomProcess` to pre-pay for a specified number of future random requests.

- **Arguments**:
  - `units` (number): Number of randomness units to purchase.  
- **Behavior**:
  - Computes `quantity = units * RandomCost` (on-chain value).  
  - Sends a `"Transfer"` action to `RandomProcess` with header `X-Prepayment = "true"`.  

---

### 4. Redeem Random Credit

```lua
randomModule.redeemRandomCredit(callbackId)
-- or
randomModule.redeemRandomCredit(callbackId, providerList)
```

Uses prepaid randomness credits to make a randomness request.

- **Arguments**:
  - `callbackId` (string): Unique identifier to correlate the response.  
  - `providerList` (optional, table of strings): If provided, limits entropy generation to this subset of providers.  
- **Behavior**:
  - If `providerList` is **nil**, sends `Redeem-Random-Credit` with only `CallbackId`.  
  - If provided, includes header `X-Providers = providerList`.  

**Examples**:
```lua
-- Redeem credit without specifying providers:
local tx1 = randomModule.redeemRandomCredit("cb-1234")

-- Redeem credit using a custom provider list:
local providers = {
  "ProviderA_ID",
  "ProviderB_ID"
}
local tx2 = randomModule.redeemRandomCredit("cb-5678", providers)
```

---

### 5. View Random Status

```lua
randomModule.viewRandomStatus(callbackId)
```

Check the status of a previously submitted randomness request.

- **Arguments**:
  - `callbackId` (string): The callback ID from your request.  
- **Possible Return Values**:
  - `"PENDING"`: Your request is queued.  
  - `"CACKING"`: Entropy is being computed/collected.  
  - `"SUCCESS"`: Randomness is ready.  
  - `"FAILED"`: The request did not complete successfully.  

---

## Code Examples

```lua
local randomModule = require('random')(json)
randomModule.init()

-- Generate a unique callback ID:
local cbId = randomModule.generateUUID()

-- 1) Prepay for 3 random requests:
randomModule.prepayForRandom(3)

-- 2) Immediately redeem one of those credits:
randomModule.redeemRandomCredit(cbId)

-- 3) Later, check status:
local status = randomModule.viewRandomStatus(cbId)
print("Request status:", status)
```

---

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for more details.

---

## Contributing

Contributions are welcome! To help improve this module:

- Open an issue to report bugs or suggest features.  
- Submit a pull request with clear tests and documentation updates.  

Happy randomizing! 🎲

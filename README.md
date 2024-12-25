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

*TODO: Add installation instructions here.*

---

## Usage

### Request Random
To request random values:
- Call `request_random` with a `providers` parameter, which is a JSON-encoded string of the random providers you wish to include in the randomness generation process.
- This action deducts **100 RandAO tokens** from the caller's account.

### View Random
To view the status of a random request:
- Call `view_random` with the `callback_id` you received from your `request_random` action.
- Possible statuses:
  - **PENDING**: The randomness request is in progress.
  - **CACKING**: The randomness request is being computed.
  - **SUCCESS**: The randomness request has been completed.
  - **FAILED**: The randomness request failed.

> The expected time to complete a randomness request is approximately **under 2 seconds**.

---

## Code Examples

### Using the RandAO Module

*TODO: Provide examples of how to use `request_random` and `view_random` here.*

### Required Code for Integration

*TODO: Include snippets for integrating the module into user projects.*

---

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for more details.

---

## Contributing

Contributions are welcome! If you'd like to improve this module, please:
- Open an issue to report bugs or suggest features.
- Submit a pull request with your changes.

Happy randomizing! 🎲

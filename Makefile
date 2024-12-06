# Variables
ROCKSPEC = random-1.0-1.rockspec

.PHONY: all build test install clean upload

# Default target
all: build

# Build the module (no-op for Lua code)
build:
	@echo "Building random module..."
	luarocks make $(ROCKSPEC)

# Install the module locally
install:
	@echo "Installing random module..."
	luarocks install $(ROCKSPEC)

# Run tests
test:
	@echo "Running tests..."
	lua tests/test_random.lua

# Clean up
clean:
	@echo "Cleaning up..."
	rm -rf *.rock *.rockspec

# Upload to LuaRocks
upload:
	@echo "Uploading $(ROCKSPEC) to LuaRocks..."
	luarocks upload $(ROCKSPEC) --api-key="your_api_key"

# Variables
ROCK_NAME = randao_random_module
ROCK_VERSION = 1.0-1
SOURCE_FILE = $(ROCK_NAME)-$(ROCK_VERSION).tar.gz
ROCKSPEC_FILE = $(ROCK_NAME)-$(ROCK_VERSION).rockspec
UPLOAD_URL = https://yourserver.com/path/to/upload/directory/
LUAROCKS_SERVER = https://yourserver.com/luarocks

# LuaRocks commands
LUAROCKS = luarocks

# Default target: create and upload the module
all: package upload

# Package the Lua module
package:
	@echo "Packaging $(ROCK_NAME)..."
	tar -czvf $(SOURCE_FILE) $(ROCK_NAME).lua
	@echo "Package created: $(SOURCE_FILE)"

# Generate the .rockspec file
rockspec:
	@echo "Creating .rockspec file..."
	echo 'package = "$(ROCK_NAME)"' > $(ROCKSPEC_FILE)
	echo 'version = "$(ROCK_VERSION)"' >> $(ROCKSPEC_FILE)
	echo 'source = { url = "$(UPLOAD_URL)$(SOURCE_FILE)" }' >> $(ROCKSPEC_FILE)
	echo 'description = { summary = "A simple Lua module.", license = "MIT" }' >> $(ROCKSPEC_FILE)
	echo 'dependencies = { "lua >= 5.1" }' >> $(ROCKSPEC_FILE)
	echo 'build = { type = "builtin", modules = { ["$(ROCK_NAME)"] = "$(ROCK_NAME).lua" } }' >> $(ROCKSPEC_FILE)
	@echo ".rockspec file created: $(ROCKSPEC_FILE)"

# Upload both the .tar.gz and .rockspec files to the server
upload: package rockspec
	@echo "Uploading $(SOURCE_FILE) and $(ROCKSPEC_FILE) to server..."
	curl -T $(SOURCE_FILE) $(UPLOAD_URL)
	curl -T $(ROCKSPEC_FILE) $(UPLOAD_URL)
	@echo "Upload complete."

# Clean up generated files
clean:
	rm -f $(SOURCE_FILE) $(ROCKSPEC_FILE)
	@echo "Cleaned up generated files."

# Local installation for testing
install: rockspec
	@echo "Installing locally for testing..."
	$(LUAROCKS) install $(ROCKSPEC_FILE) --server=$(LUAROCKS_SERVER)

# Phony targets
.PHONY: all package rockspec upload clean install
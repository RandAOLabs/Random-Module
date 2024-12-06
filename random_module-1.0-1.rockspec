package = "randao_random_module"
version = "1.0-1"
source = {
   url = "https://example.com/random_module-1.0.tar.gz"  -- Replace with the actual URL if hosting
}

description = {
   summary = "A simple Lua module for handling random-related parameters.",
   detailed = [[
      randomModule is a Lua module that accepts PaymentToken, RandomCost, and RandomProcess parameters,
      defaulting to empty strings if not provided.
   ]],
   homepage = "https://example.com/random_module",  -- Replace with the actual homepage if hosting
   license = "MIT"
}

dependencies = {
   "lua >= 5.1"
}

build = {
   type = "builtin",
   modules = {
      ["random_module"] = "random_module.lua"
   }
}

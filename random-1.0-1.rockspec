package = "random"
version = "1.0-1"
source = {
   url = "file://./"
}
description = {
   summary = "RandAO randomness module built for the AO Computer",
   detailed = "This module provides helper functions for interacting the RandAO protocol.",
   homepage = "https://randao.ar.satoshispalace.casino/",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["random"] = "src/random.lua"
   }
}

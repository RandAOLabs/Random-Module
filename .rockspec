package = "randao-random-module"
version = "1.0-1"
source = {
   url = "file://./"
}
description = {
   summary = "A short description of your module.",
   detailed = "A more detailed description.",
   homepage = "http://your-module-homepage.com",
   license = "MIT"
}
dependencies = {
   "lua >= 5.3"
}
build = {
   type = "builtin",
   modules = {
      ["your.module.name"] = "src/your_module.lua"
   }
}

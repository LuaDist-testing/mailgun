-- This file was automatically generated for the LuaDist project.

package = "mailgun"
version = "1.1.0-1"

-- LuaDist source
source = {
  tag = "1.1.0-1",
  url = "git://github.com/LuaDist-testing/mailgun.git"
}
-- Original source
-- source = {
--   url = "git://github.com/leafo/lua-mailgun.git",
--   branch = "v1.1.0"
-- }

description = {
  summary = "Send email with Mailgun",
  homepage = "https://github.com/leafo/lua-mailgun",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1",
  "lpeg",
  "luasocket",
  "lua-cjson",
  "luasec",
}

build = {
  type = "builtin",
  modules = {
    ["mailgun"] = "mailgun/init.lua",
    ["mailgun1util"] = "mailgun/util.lua",
  }
}

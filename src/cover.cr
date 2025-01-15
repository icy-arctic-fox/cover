require "log"

Log.setup_from_env

# TODO: Write documentation for `Cover`
module Cover
  VERSION = "0.1.0"

  Log = ::Log.for(self)
end

require "./cover/*"

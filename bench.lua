local socket = require "socket"

local func = loadfile(arg[1])
local start_time = socket.gettime()
func()
local end_time = socket.gettime()
print(("Completed in %f seconds"):format(end_time - start_time))

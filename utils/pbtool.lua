local pbtool = require "pb"

assert(pbtool.loadfile "./config/pb/game_pb.bytes")

return pbtool

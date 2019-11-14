local Physics = require 'physics' -- You would use the full 'https://...' raw URI to 'physics.lua' here


love.physics.setMeter(64)


MAIN_RELIABLE_CHANNEL = 0
TOUCHES_CHANNEL = 50


-- Define

function GameCommon:define()
    --
    -- User
    --

    -- Client sends user profile info when it connects, forwarded to all and self
    self:defineMessageKind('me', {
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
        forward = true,
    })

    --
    -- Players
    --

    -- Server sends add or remove player events to all
    self:defineMessageKind('addPlayer', {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
    })
    self:defineMessageKind('removePlayer', {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = true,
    })

    self:defineMessageKind('score', {
        to = 'all',
        reliable = true,
        channel = MAIN_RELIABLE_CHANNEL,
        selfSend = false
    });

end


function GameCommon:getTableDimensions()

    return 0, 0, 800, 450;

end

-- Start / stop

function GameCommon:start()
    self.mes = {}

    self.physics = Physics.new({
        game = self,

        -- Let's send physics reliable messages on the main channel so that we can be sure
        -- the body is available in `addPlayer` receiver etc.
        reliableChannel = MAIN_RELIABLE_CHANNEL,

        -- Allow quicker ownership transfers
        softOwnershipSetDelay = 0.1,
    })

    self.players = {}
end


-- Mes

function GameCommon.receivers:me(time, clientId, me)
    self.mes[clientId] = me
end

local function clamp(val, lo, hi)
    if (val < lo) then return lo elseif (val > hi) then return hi else
        return val;
    end
end


function GameCommon:constrainPlayer(x, y, sideB)

    local tx,ty,tw,th = self:getTableDimensions();
    --return x, y;

    local x1 = 0;
    local x2 = tw/2 - 10;

    if (sideB) then
        x1 = tw / 2 + 10;
        x2 = tw;
    end

    return clamp(x, x1, x2), y;

end

-- Players

function GameCommon.receivers:addPlayer(time, clientId, bodyId, sideB)
    local player = {
        clientId = clientId,
        bodyId = bodyId,
        sideB = sideB
    }

    self.players[clientId] = player
end


function GameClient.receivers:score(scoreA, scoreB)
   self.scoreA = scoreA;
   self.scoreB = scoreB; 
end

function GameCommon.receivers:removePlayer(time, clientId)
    self.players[clientId] = nil
end


-- Update

function GameCommon:update(dt)
    -- Update physics
    local worldId, world = self.physics:getWorld()
    if worldId then
        self.physics:updateWorld(worldId, dt)
    end
end
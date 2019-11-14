require 'server' -- You would use the full 'https://...' raw URI to 'server.lua' here


require 'AirHockeyCommon'


-- Start / stop

function GameServer:start()
    GameCommon.start(self)


    local worldId = self.physics:newWorld(0, 0, true)


    -- Walls

    local function createWall(x, y, width, height)
        local bodyId = self.physics:newBody(worldId, x, y)
        local shapeId = self.physics:newRectangleShape(width, height)
        local fixtureId = self.physics:newFixture(bodyId, shapeId)
        self.physics:destroyObject(shapeId)
    end

    local wallThickness = 30

    local tx, ty, tw, th = self:getTableDimensions();

    createWall(tw / 2, wallThickness / 2, tw, wallThickness)
    createWall(tw / 2, th - wallThickness / 2, tw, wallThickness)

    createWall(wallThickness / 2, th / 10, wallThickness, th / 2)
    createWall(tw - wallThickness / 2, th / 10, wallThickness, th / 2)
    
    createWall(wallThickness / 2, th - th / 10, wallThickness, th / 2)
    createWall(tw - wallThickness / 2, th - th / 10, wallThickness, th / 2)

    -- Corners

    local function createCorner(x, y)
        local bodyId = self.physics:newBody(worldId, x, y)
        local shapeId = self.physics:newPolygonShape(
            0, -2 * wallThickness,
            2 * wallThickness, 0,
            0, 2 * wallThickness,
            -2 * wallThickness, 0)
        local fixtureId = self.physics:newFixture(bodyId, shapeId)
        self.physics:destroyObject(shapeId)
    end

    createCorner(wallThickness, wallThickness)
    createCorner(tw - wallThickness, wallThickness)
    createCorner(tw - wallThickness, th - wallThickness)
    createCorner(wallThickness, th - wallThickness)


    -- Dynamic bodies

    local function createDynamicBody(shapeId)
        local bodyId = self.physics:newBody(worldId, tw / 2, th / 2, 'dynamic')
        local fixtureId = self.physics:newFixture(bodyId, shapeId, 1)
        self.physics:destroyObject(shapeId)
        self.physics:setFriction(fixtureId, 1.2)
        self.physics:setRestitution(fixtureId, 0.7)
        self.physics:setLinearDamping(bodyId, 1.5)
        return bodyId
    end

    self.ballBodyId = createDynamicBody(self.physics:newCircleShape(15))

    self.scoreA = 0;
    self.scoreB = 0;
end


-- Connect / disconnect

function GameServer:connect(clientId)

    local sideB = false;

    self.numPlayers = (self.numPlayers or 0) + 1;

    if (self.numPlayers == 2) then
        sideB = true;
    end

    if (self.numPlayers > 2) then
        return;
    end

    local function send(kind, ...) -- Shorthand to send messages to this client only
        self:send({
            kind = kind,
            to = clientId,
            selfSend = false,
            channel = MAIN_RELIABLE_CHANNEL,
        }, ...)
    end

    -- Sync physics (do this before stuff below so that the physics world exists)
    self.physics:syncNewClient({
        clientId = clientId,
        channel = MAIN_RELIABLE_CHANNEL,
    })

    -- Sync mes
    for clientId, me in pairs(self.mes) do
        send('me', clientId, me)
    end

    -- Sync players
    for clientId, player in pairs(self.players) do
        send('addPlayer', clientId, player.bodyId)
    end

    -- Add player body and table entry
    local x, y;

    local tx, ty, tw, th = self:getTableDimensions();
    y = th * 0.5;

    if (sideB) then
        x = tw * 0.8;
    else
        x = tw * 0.2;
    end

    local bodyId = self.physics:newBody(self.physics:getWorld(), x, y, 'dynamic')
    local shapeId = self.physics:newCircleShape(20)
    local fixtureId = self.physics:newFixture(bodyId, shapeId, 0)
    self.physics:setFriction(fixtureId, 1.2)
    self.physics:setLinearDamping(bodyId, 2.8)
    self.physics:setFixedRotation(bodyId, true)
    self.physics:setOwner(bodyId, clientId, true)
    self:send({ kind = 'addPlayer' }, clientId, bodyId, sideB)
end

function GameServer:disconnect(clientId)

    local player = self.players[clientId];
    local bodyId = player.bodyId;
    self.physics:destroyObject(bodyId);
    self:send({ kind = 'removePlayer' }, 0, clientId)

end

function GameServer:syncScore()
    self:send({kind = 'score'}, self.scoreA, self.scoreB);
end

function GameServer:awardPoint(sideB)

    if (sideB) then
        self.scoreB = self.scoreB + 1;
    else
        self.scoreA = self.scoreA + 1;
    end

    self:syncScore();

end

-- Update

function GameServer:update(dt)
    -- Common update
    GameCommon.update(self, dt)

    -- Check scoring
    local ballBody = self.physics:objectForId(self.ballBodyId)
    local ballX, ballY = ballBody:getPosition()

    local tx, ty, tw, th = self:getTableDimensions();

    if ballX < 0 or ballX > tw then


        if (ballX < 0) then
            self:awardPoint(true);
        else
            self:awardPoint(false);
        end

        self.physics:setOwner(self.ballBodyId, nil, false)
        ballBody:setPosition(tw / 2, th / 2)
        ballBody:setAngle(0)
        ballBody:setLinearVelocity(0, 0)
        ballBody:setAngularVelocity(0)
    end



    -- Send physics syncs
    local worldId, world = self.physics:getWorld()
    if worldId then
        self.physics:sendSyncs(worldId)
    end
end

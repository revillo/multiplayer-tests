require 'client' -- You would use the full 'https://...' raw URI to 'client.lua' here


require 'AirHockeyCommon'


-- Start / stop

function GameClient:start()
    GameCommon.start(self)

    self.photoImages = {}
end


-- Connect / disconnect

function GameClient:connect()
    GameCommon.connect(self)

    self.connectTime = love.timer.getTime()

    -- Send `me`
    local me = castle.user.getMe()
    self:send({ kind = 'me' }, self.clientId, me)
end


-- Mes

function GameClient.receivers:me(time, clientId, me)
    GameCommon.receivers.me(self, time, clientId, me)

    local photoUrl = self.mes[clientId].photoUrl
    if photoUrl then
        network.async(function()
            self.photoImages[clientId] = love.graphics.newImage(photoUrl)
        end)
    end
end


local mouseState = {
    x = 0,
    y = 0,
    pressed = false
};

function GameClient:mousepressed(x,y)

    mouseState.x, mouseState.y = x,y;
    mouseState.pressed = true;
    mouseState.pressedFlag = true;

end

function GameClient:mousemoved(x, y)
    mouseState.x, mouseState.y = x,y;
end

function GameClient:mousereleased()
    mouseState.pressed = false;
end



-- Update

function GameClient:queryPoint(x, y)
    local worldId, world = self.physics:getWorld();
    local body, bodyId = nil, nil;

    local gameClient = self;

    world:queryBoundingBox(
            x - 1, y - 1, x + 1, y + 1,
            function(fixture)
                -- The query only tests AABB overlap -- check if we've actually touched the shape
                if fixture:testPoint(x, y) then
                    local candidateBody = fixture:getBody()
                    local candidateBodyId = self.physics:idForObject(candidateBody)

                    -- Skip if the body isn't networked
                    if not candidateBodyId then
                        return true
                    end


                    if (candidateBodyId ~= gameClient.players[gameClient.clientId].bodyId) then
                        return true;
                    end
                    -- Skip if owned by someone else
                    --[[
                    for _, touch in pairs(self.touches) do
                        if touch.bodyId == candidateBodyId and touch.clientId ~= self.clientId then
                            return true
                        end
                    end
                    ]]

                    -- Seems good!
                    body, bodyId = candidateBody, candidateBodyId
                    return false
                end
                return true
            end)

    return body,  bodyId;

end

function GameClient:getThisPlayer()
    return self.players[self.clientId];
end

function GameClient:update(dt)
    -- Not connected?
    if not self.connected then
        return
    end

    -- Keep a reference to our own player
    local ownPlayer = self:getThisPlayer();
    local ownPlayerBody = ownPlayer and self.physics:objectForId(ownPlayer.bodyId)


    if (mouseState.pressedFlag) then

        mouseState.pressedFlag = false;

        local body, bodyId = self:queryPoint(mouseState.x, mouseState.y);
        if (body) then
            self.touchJoint = love.physics.newMouseJoint(body, mouseState.x, mouseState.y);
        end

    end


    if (mouseState.pressed and self.touchJoint) then

        local mx, my = self:constrainPlayer(mouseState.x, mouseState.y, ownPlayer.sideB);

        self.touchJoint:setTarget(mx, my);
    end

    if (not mouseState.pressed and self.touchJoint) then
        self.touchJoint:destroy();
        self.touchJoint = nil;
    end

    -- Own player walking
    --[[
    if ownPlayer then
        local left = love.keyboard.isDown('left') or love.keyboard.isDown('a')
        local right = love.keyboard.isDown('right') or love.keyboard.isDown('d')

        if left or right and not (left and right) then
            local MAX_VELOCITY, ACCELERATION = 280, 3200

            local vx, vy = ownPlayerBody:getLinearVelocity()
            if vx < MAX_VELOCITY and right then
                newVx = math.min(MAX_VELOCITY, vx + ACCELERATION * dt)
            end
            if vx > -MAX_VELOCITY and left then
                newVx = math.max(-MAX_VELOCITY, vx - ACCELERATION * dt)
            end

            ownPlayerBody:applyLinearImpulse(newVx - vx, 0)
        end

        local up = love.keyboard.isDown('up') or love.keyboard.isDown('w')
        local down = love.keyboard.isDown('down') or love.keyboard.isDown('s')

        if up or down and not (up and down) then
            local MAX_VELOCITY, ACCELERATION = 280, 3200

            local vx, vy = ownPlayerBody:getLinearVelocity()
            if vy < MAX_VELOCITY and down then
                newVy = math.min(MAX_VELOCITY, vy + ACCELERATION * dt)
            end
            if vy > -MAX_VELOCITY and up then
                newVy = math.max(-MAX_VELOCITY, vy - ACCELERATION * dt)
            end

            ownPlayerBody:applyLinearImpulse(0, newVy - vy)
        end
    end
    ]]



    -- Common update
    GameCommon.update(self, dt)

    -- Keep player in bounds
    if ownPlayer then
        local ownPlayerX, ownPlayerY = ownPlayerBody:getPosition()
        if ownPlayerX > 800 - 10 then
            ownPlayerBody:setPosition(800 - 10, ownPlayerY)
        end
        if ownPlayerX < 10 then
            ownPlayerBody:setPosition(10, ownPlayerY)
        end
    end

    -- Send physics syncs
    local worldId, world = self.physics:getWorld()
    if worldId then
        self.physics:sendSyncs(worldId)
    end
end


-- Keyboard

function GameClient:keypressed(key)
    if key == 'up' or key == 'return' then
        self.jumpRequestTime = love.timer.getTime()
    end
end


local function drawImageCircle(img, x, y, r)
	
    local function stencil()
        --drawing the planet
        love.graphics.circle("fill", x, y, r * 1.0);
    end

    love.graphics.setColor(1,1,1,1)

    --Draw the planet
    stencil()
    
    --Set the stencil
    love.graphics.stencil(stencil)
    
    --Set the stenciltest
    love.graphics.setStencilTest("greater", 0)

    --Draw the inside

    love.graphics.setColor(0,0,0);
    stencil();
    love.graphics.setColor(1,1,1);

    local scale = math.max((r * 2 + 10) / img:getWidth(), (r * 2 + 10) / img:getHeight());

    love.graphics.draw(img, x - r - 5, y - r - 5, 0, scale);

    --End stencil test
    love.graphics.setStencilTest()

    --love.graphics.setColor(1, 0.0, 0.0, 0.5);
    --stencil();

end


-- Draw

local function drawDashedLine(x1,y1,x2,y2)
    love.graphics.setPointSize(2);
  
    local x, y = x2 - x1, y2 - y1;
    local len = math.sqrt(x^2 + y^2) / 10;
    local stepx, stepy = x / len, y / len;
    x = x1;
    y = y1;
  
    for i = 1, len + 1 do
      love.graphics.points(x, y);
      x = x + stepx;
      y = y + stepy;
    end
  end

function GameClient:draw()


    do -- arena
        local tx, ty, tw, th = self:getTableDimensions();

        love.graphics.translate(tx, ty);
        love.graphics.setColor(1,1,1,1);
        love.graphics.rectangle("fill", 0, 0, tw, th);

        local innerCircleRadius = 50;

        love.graphics.setColor(0.2, 0.2, 1.0, 1.0);
        love.graphics.circle("line", tw * 0.5, th * 0.5, innerCircleRadius);
        love.graphics.line(tw * 0.5, 0, tw * 0.5, th * 0.5 - innerCircleRadius);
        love.graphics.line(tw * 0.5, th * 0.5 + innerCircleRadius, tw * 0.5, th);

        local function drawCornerCircle(x, y)
            love.graphics.setColor(1.0, 0.2, 0.2, 1.0);
            love.graphics.circle("line", x, y, 30);
            love.graphics.circle("fill", x, y, 5);
        end

        drawCornerCircle(tw * 0.25, th * 0.25);
        drawCornerCircle(tw * 0.75, th * 0.25);
        drawCornerCircle(tw * 0.75, th * 0.75);
        drawCornerCircle(tw * 0.25, th * 0.75);

        love.graphics.setColor(0.2, 0.2, 1.0, 1.0);
        drawDashedLine(30, (th / 10) + (th/4), 30, (th - th/10) - (th/4));
        drawDashedLine(tw - 30, (th / 10) + (th/4), tw - 30, (th - th/10) - (th/4));


        love.graphics.setColor(1,1,1,1);
        love.graphics.translate(-tx, -ty);

    end

    do -- Physics bodies
        local worldId, world = self.physics:getWorld()
        if world then
            for _, body in ipairs(world:getBodies()) do
                local bodyId = self.physics:idForObject(body)
                local ownerId = self.physics:getOwner(bodyId)
                if ownerId then
                    local c = ownerId + 1
                    love.graphics.setColor(c % 2, math.floor(c / 2) % 2, math.floor(c / 4) % 2)
                else
                    love.graphics.setColor(1, 1, 1)
                end

                love.graphics.setColor(0,0,0,1.0);

                -- Draw shapes
                for _, fixture in ipairs(body:getFixtures()) do
                    local shape = fixture:getShape()
                    local ty = shape:getType()
                    if ty == 'circle' then
                        love.graphics.circle('fill', body:getX(), body:getY(), shape:getRadius())
                        love.graphics.setColor(1,0,0,1);
                        love.graphics.circle('fill', body:getX(), body:getY(), shape:getRadius() * 0.75)
                        love.graphics.setColor(0,0,0,1);
                    elseif ty == 'polygon' then
                        love.graphics.polygon('fill', body:getWorldPoints(shape:getPoints()))
                    elseif ty == 'edge' then
                        love.graphics.polygon('fill', body:getWorldPoints(shape:getPoints()))
                    elseif ty == 'chain' then
                        love.graphics.polygon('fill', body:getWorldPoints(shape:getPoints()))
                    end
                end
            end
        end
    end

do -- Player avatars
        love.graphics.setColor(1, 1, 1)
        for clientId, player in pairs(self.players) do
            local photoImage = self.photoImages[clientId]
            if photoImage then
                local body = self.physics:objectForId(player.bodyId)

                if (body) then
                
                    local scale = math.min(40 / photoImage:getWidth(), 40 / photoImage:getHeight())
                    --love.graphics.draw(photoImage, body:getX() - 20, body:getY() - 20, 0, scale)

                    --love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
                    --love.graphics.circle("fill", body:getX(), body:getY(), 20);

                    drawImageCircle(photoImage, body:getX(), body:getY(), 20);
                end
            end
        end
    end

    do -- Text overlay
        local networkText = ''
        if self.connected then
            local timeSinceConnect = love.timer.getTime() - self.connectTime
            networkText = networkText .. '    ping: ' .. self.client.getPing() .. 'ms'
            networkText = networkText .. '    down: ' .. math.floor(0.001 * (self.client.getENetHost():total_received_data() / timeSinceConnect)) .. 'kbps'
            networkText = networkText .. '    up: ' .. math.floor(0.001 * (self.client.getENetHost():total_sent_data() / timeSinceConnect)) .. 'kbps'
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.print('fps: ' .. love.timer.getFPS() .. networkText, 22, 2)
    end

    do -- Scores
        local tx, ty, tw, th = self:getTableDimensions();

        love.graphics.setColor(1,0.9,0.9,1);

        local aScore = (self.scoreA or 0);
        local bScore = (self.scoreB or 0);

        love.graphics.print(""..(aScore), tx + tw * 0.5 - 50, th + ty - 30);
        love.graphics.print(":", tx + tw * 0.5, th - 30);
        love.graphics.print(""..(bScore), tx + tw * 0.5 + 50, th + ty - 30);


    end
end
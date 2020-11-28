-------------------------------
--Copyright (c) 2018 DasEtwas--
-------------------------------

Airfoil = class()
Airfoil.airDensity = 2.75       -- air density in kg/m³
Airfoil.sleepTime = 5           -- how many updates it takes for a wing to fall asleep
Airfoil.maxJerk = (72.0) / 40.0 -- lift change clamp in (N/tick/sec or 40N/s²) per (m/s) = 40*N/(m*s)
Airfoil.maxVel = 600            -- velocity at which wings are turned off
Airfoil.maxVelTimeout = 400     -- how long in ticks wings are shut off if they exceed max velocity

function Airfoil:server_onCreate()
    self.area = self.data.area
    -- angle gives rotation about the local z axis (getUp)
    self.angle = math.rad(self.data.angle)
    self.sleepTimer = 0
end

function Airfoil:server_onFixedUpdate(deltaTime)
    local globalVel = sm.shape.getVelocity(self.shape)
    local globalVelLength = globalVel:length()

    if globalVelLength > 0.08 then
        self.sleepTimer = self.sleepTimer + 1
    else
        self.sleepTimer = math.max(-self.sleepTime, math.min(self.sleepTimer - 1, 0))
    end

    -- spazzing out protection
    if globalVelLength > self.maxVel and self.sleepTimer > -self.sleepTime then
        self.sleepTimer = -self.maxVelTimeout
        print("[Wings] Disabled wing for " .. (self.maxVelTimeout * deltaTime) .. " seconds due to high velocity (>" .. self.maxVel .. "m/s)")
    end

    if self.sleepTimer > 0 then
        local aSin = math.sin(self.angle)
        local aCos = math.cos(self.angle)

        local globalUp = sm.shape.getRight(self.shape) * aSin + sm.shape.getAt(self.shape) * aCos

        local normalVel = -globalVel:dot(globalUp)
        local lastLift = self.liftMagnitude or 0
        -- lift magnitude along wing normal vector
        self.liftMagnitude = self.airDensity * math.abs(normalVel) * normalVel * 0.5 * self.area

        if math.abs(self.liftMagnitude) - math.abs(lastLift) > 0 then
            -- lift magnitude has increased
            self.liftMagnitude = lastLift + math.max(-self.maxJerk * globalVelLength, math.min(self.maxJerk * globalVelLength, self.liftMagnitude - lastLift))
        end

        local lift = sm.vec3.new(self.liftMagnitude * deltaTime * 40 * aSin, self.liftMagnitude * deltaTime * 40 * aCos, 0)
        sm.physics.applyImpulse(self.shape, lift)
    end
end

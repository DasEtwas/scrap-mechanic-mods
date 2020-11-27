-------------------------------
--Copyright (c) 2018 DasEtwas--
-------------------------------

Airfoil = class()
Airfoil.airDensity = 2.3
Airfoil.sleepTime = 5           -- how long it takes for a wing to fall asleep
Airfoil.maxForce = 80000        -- max force excerted by a wing in N
Airfoil.maxJerk = 1.8           -- is multiplied with velocity
Airfoil.maxVel = 600
Airfoil.maxVelTimeout = 400

local function sign(num)
    if num < 0 then
        return -1
    elseif num > 0 then
        return 1
    else
        return 0
    end
end

function Airfoil:server_onCreate()
    self.area = self.data.area
    self.sleep = self.data.sleep
    self.angle = self.data.angle
    self.width = self.data.width
    self.chord = self.data.chord
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
        print("[Wings] Disabled wing for " .. (self.maxVelTimeout / 40) .. " seconds due to high velocity (>" .. self.maxVel .. "m/s)")
    end

    if self.sleepTimer > 0 then
        local pos = sm.shape.getWorldPosition(self.shape)

        local aSin = -math.sin(math.rad(self.angle))
        local aCos = math.cos(math.rad(self.angle))
        local globalUp = sm.shape.getAt(self.shape) * -aCos + sm.shape.getRight(self.shape) * aSin

        self.normalVel = globalVel:dot(globalUp)
        local lastLift = self.lift or 0
        self.lift = self.airDensity * self.normalVel * self.normalVel * 0.5 * self.area * sign(self.normalVel) 

        if math.abs(self.lift) - math.abs(lastLift) > 0 then
            self.lift = lastLift + math.max(-self.maxJerk * globalVelLength, math.min(self.maxJerk * globalVelLength, self.lift - lastLift))
        end

        local lift = sm.vec3.new(-self.lift * deltaTime * 40 * aSin, self.lift * deltaTime * 40 * aCos, 0)
        self.lastLift = sm.shape.getRight(self.shape) * lift.x + sm.shape.getAt(self.shape) * lift.y + sm.shape.getUp(self.shape) * lift.z
        sm.physics.applyImpulse(self.shape, lift)
    end
end

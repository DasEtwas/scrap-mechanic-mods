-------------------------------
--Copyright (c) 2018 DasEtwas--
-------------------------------

airDensity         = 2.75
sleepTime          = 5          -- how long it takes for a wing to fall asleep
maxForce           = 80000      -- max force excerted by a wing in N
maxJerk            = 1.4 + 0.4  -- is multiplied with velocity
maxVel             = 600
maxVelTimeout      = 10 * 40
groundEffectHeight = 20
groundEffectFactor = -1 + (2.5) -- math.pow(dist/height, gEF)
groundEffectCurve  = 1.4
groundEffectChance = 0.15
gefv = sm.vec3.new(0, 0, -groundEffectHeight)

function sign(num)
	if num < 0 then
		return -1
	elseif num > 0 then
		return 1
	else
		return 0
	end
end

function equals(vec1, vec2)
	return sm.vec3.getX(vec1) == sm.vec3.getX(vec2) and sm.vec3.getY(vec1) == sm.vec3.getY(vec2) and sm.vec3.getZ(vec1) == sm.vec3.getZ(vec2)
end

function airfoil(self, dt)
	if self.sleepTimer == nil then self.sleepTimer = 0 end
	
	local globalVel = sm.shape.getVelocity(self.shape)
	local globalVelL = globalVel:length()
	if globalVel.x ~= globalVel.x then -- nan
		return
	end
	
	if globalVelL > 0.08 then
		self.sleepTimer = self.sleepTimer + 1
	else
		self.sleepTimer = math.max(-sleepTime, math.min(self.sleepTimer - 1, 0))
	end
	
	-- spazzing out protection
	if globalVelL > maxVel and self.sleepTimer > -sleepTime then
		self.sleepTimer = -maxVelTimeout
		print("[Wings] Disabled wing for " .. (maxVelTimeout / 40) .. " seconds due to high velocity (>" .. maxVel .. "m/s)")
	end
	
	
	if self.sleepTimer > 0 then
		local pos = sm.shape.getWorldPosition(self.shape)
		if math.random() <= groundEffectChance then
			local hit, rcr = sm.physics.raycast(pos, pos + gefv, self.shape:getBody())
			
			if hit and (rcr.type == "terrainSurface" or rcr.type == "terrainAsset") then
				self.lastGroundHeight = rcr.pointWorld.z
			end
		end
		
		local groundDist = pos.z - self.lastGroundHeight;
		if groundDist < groundEffectHeight then
			local temp = math.pow(1 - math.min(1, math.max(0, groundDist / groundEffectHeight)), groundEffectCurve) * groundEffectFactor
			local temp2 = temp * 0.2 + 1
			sm.vec3.setX(self.factor, temp2)
			sm.vec3.setY(self.factor, temp2)
			sm.vec3.setZ(self.factor, temp + 1)
		else
			sm.vec3.setX(self.factor, 1)
			sm.vec3.setY(self.factor, 1)
			sm.vec3.setZ(self.factor, 1)
		end
		
		local aSin = -math.sin(math.rad(self.angle))
		local aCos = math.cos(math.rad(self.angle))
		local globalUp = sm.shape.getAt(self.shape) * -aCos + sm.shape.getRight(self.shape) * aSin
		
		self.normalVel = globalVel:dot(globalUp)
		local lastLift = self.lift or 0
		self.lift = airDensity * self.normalVel * self.normalVel * 0.5 * self.area * sign(self.normalVel) 
		
		--self.lift = math.max(-maxForce, math.min(maxForce, self.lift))
		
		--if math.abs(self.lift - lastLift) > maxJerk then
			--self.sleepTimer = -sleepTime - 2
			---return
		--end
		
		if math.abs(self.lift) - math.abs(lastLift) > 0 then
			self.lift = lastLift + math.max(-maxJerk * globalVelL, math.min(maxJerk * globalVelL, self.lift - lastLift))
		end
			
		--print(self.lift - lastLift)
		--print(globalVelL)
		
		local lift = sm.vec3.new(-self.lift * dt * 40 * aSin, self.lift * dt * 40 * aCos, 0) * self.factor
		self.lastLift = sm.shape.getRight(self.shape) * lift.x + sm.shape.getAt(self.shape) * lift.y + sm.shape.getUp(self.shape) * lift.z
		sm.physics.applyImpulse(self.shape, lift)
	end
end

DefaultBig = class(nil)
DefaultBig.area = 1
DefaultBig.sleep = movementSleep
DefaultBig.angle = 0
DefaultBig.width = 0.5
DefaultBig.chord = 0.5
DefaultBig.factor = sm.vec3.new(1, 1, 1)
DefaultBig.lastGroundHeight = -100

function DefaultBig.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

DefaultSmall = class(nil)
DefaultSmall.area = 0.25
DefaultSmall.sleep = movementSleep
DefaultSmall.angle = 0
DefaultSmall.width = 0.5
DefaultSmall.chord = 0.125
DefaultSmall.factor = sm.vec3.new(1, 1, 1)
DefaultSmall.lastGroundHeight = -100

function DefaultSmall.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

SmallAngled00 = class(nil)
SmallAngled00.area = 0.0625
SmallAngled00.sleep = movementSleep
SmallAngled00.angle = 0
SmallAngled00.width = 0.125
SmallAngled00.chord = 0.125
SmallAngled00.factor = sm.vec3.new(1, 1, 1)
SmallAngled00.lastGroundHeight = -100

function SmallAngled00.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

SmallAngled15 = class(nil)
SmallAngled15.area = 0.0625
SmallAngled15.sleep = movementSleep
SmallAngled15.angle = 15
SmallAngled15.width = 0.125
SmallAngled15.chord = 0.125
SmallAngled15.factor = sm.vec3.new(1, 1, 1)
SmallAngled15.lastGroundHeight = -100

function SmallAngled15.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

SmallAngled30 = class(nil)
SmallAngled30.area = 0.0625
SmallAngled30.sleep = movementSleep
SmallAngled30.angle = 30
SmallAngled30.width = 0.125
SmallAngled30.chord = 0.125
SmallAngled30.factor = sm.vec3.new(1, 1, 1)
SmallAngled30.lastGroundHeight = -100

function SmallAngled30.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

SmallAngled45 = class(nil)
SmallAngled45.area = 0.0625
SmallAngled45.sleep = movementSleep
SmallAngled45.angle = 45
SmallAngled45.width = 0.125
SmallAngled45.chord = 0.125
SmallAngled45.factor = sm.vec3.new(1, 1, 1)
SmallAngled45.lastGroundHeight = -100

function SmallAngled45.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

DefaultBigConnector = class(nil)
DefaultBigConnector.area = 0.65
DefaultBigConnector.sleep = movementSleep
DefaultBigConnector.angle = 0
DefaultBigConnector.width = 0.375
DefaultBigConnector.chord = 0.5
DefaultBigConnector.factor = sm.vec3.new(1, 1, 1)
DefaultBigConnector.lastGroundHeight = -100

function DefaultBigConnector.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

ModularSize0125 = class(nil)
ModularSize0125.area = 0.125
ModularSize0125.sleep = movementSleep
ModularSize0125.angle = 0
ModularSize0125.width = 0.3535
ModularSize0125.chord = 0.3535
ModularSize0125.factor = sm.vec3.new(1, 1, 1)
ModularSize0125.lastGroundHeight = -100

function ModularSize0125.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

ModularSize01875 = class(nil)
ModularSize01875.area = 0.1875
ModularSize01875.sleep = movementSleep
ModularSize01875.angle = 0
ModularSize01875.width = 0.433
ModularSize01875.chord = 0.433
ModularSize01875.factor = sm.vec3.new(1, 1, 1)
ModularSize01875.lastGroundHeight = -100

function ModularSize01875.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

ModularSize05625 = class(nil)
ModularSize05625.area = 0.5625
ModularSize05625.sleep = movementSleep
ModularSize05625.angle = 0
ModularSize05625.width = 0.75
ModularSize05625.chord = 0.75
ModularSize05625.factor = sm.vec3.new(1, 1, 1)
ModularSize05625.lastGroundHeight = -100

function ModularSize05625.server_onFixedUpdate(self, timeStep)
	airfoil(self, timeStep)
end

-- end of file --
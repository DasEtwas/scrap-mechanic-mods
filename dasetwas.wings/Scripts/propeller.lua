--[[
Made by DasEtwas
All rights reserved
]]--

airDensity = 2.8
torqueFac = 0.98
sleepTime = 5 -- how long it takes for a prop to fall asleep
maxForce = 800 -- max force excerted by a prop in N
maxJerk = 4
maxVel = 1000
maxVelTimeout = 10 * 40

function sign(num)
	if num < 0 then
		return -1
	elseif num > 0 then
		return 1
	else
		return 0
	end
end

function propeller(self, dt)
	if self.sleepTimer == nil then self.sleepTimer = 0 end
	
	local globalVel = sm.shape.getVelocity(self.shape)
	local globalVelL = globalVel:length()
	
	if globalVelL ~= 0 then
		self.sleepTimer = self.sleepTimer + 1
	else
		self.sleepTimer = math.max(self.sleepTimer - 1, 0)
	end
	
	-- spazzing out protection
	if globalVelL > maxVel and self.sleepTimer > -sleepTime then
		self.sleepTimer = -maxVelTimeout
		print("[Wings] Disabled propeller for " .. (maxVelTimeout / 40) .. " seconds due to high velocity (>" .. maxVel .. "m/s)")
	end
	
	if self.sleepTimer > -sleepTime then
		local globalForward = sm.shape.getAt(self.shape)
		
		self.normalVel = globalVel:dot(globalForward)
		local lastThrust = self.thrust or 0
		local angvel = self.shape:getBody().angularVelocity:dot(globalForward)
		local effwind = self.normalVel * self.windFac - angvel * self.mult
		local absangvel = math.abs(angvel)
		local effwind2 = effwind * math.abs(effwind)
		self.thrust = dt * airDensity * 0.5 * (self.radius * self.radius * absangvel / 2) * effwind2 * self.chord * self.numBlades * -1
		self.torque = dt * self.radius / 2 * airDensity * 0.5 * (self.radius * self.radius * absangvel / 2) * effwind2 * self.chord * self.numBlades * sign(self.mult)
		--self.thrust = math.max(-maxForce, math.min(maxForce, self.thrust))
		
		--print(self.angle, self.thrust, self.torque, effwind)
		
		if math.abs(self.thrust) - math.abs(lastThrust) > 0 then
			self.thrust = lastThrust + math.max(-maxJerk * absangvel, math.min(maxJerk * absangvel, self.thrust - lastThrust))
		end
		
		sm.physics.applyImpulse(self.shape, sm.vec3.new(0, self.thrust, 0))
		sm.physics.applyTorque(self.shape:getBody(), sm.shape.getAt(self.shape) * self.torque * torqueFac, true)
	end
end

Prop1 = class(nil)
Prop1.numBlades = 2
Prop1.radius = 1.125
Prop1.chord = 0.25
Prop1.sleep = movementSleep
Prop1.mult = math.sin(math.rad(((32))) * 2.0) / 2.0 -- insert angle into triple parantheses
Prop1.windFac = 1

function Prop1.server_onFixedUpdate( self, timeStep )
	propeller(self, timeStep)
end

Prop1_2 = class(nil)
Prop1_2.numBlades = 2
Prop1_2.radius = 1.125
Prop1_2.chord = 0.25
Prop1_2.sleep = movementSleep
Prop1_2.mult = math.sin(math.rad(((-32))) * 2.0) / 2.0 -- insert angle into triple parantheses
Prop1_2.windFac = 1

function Prop1_2.server_onFixedUpdate( self, timeStep )
	propeller(self, timeStep)
end

Prop2 = class(nil)
Prop2.numBlades = 6
Prop2.radius = 1.125
Prop2.chord = 0.25
Prop2.sleep = movementSleep
Prop2.mult = math.sin(math.rad(((40))) * 2.0) / 2.0 -- insert angle into triple parantheses
Prop2.windFac = 1

function Prop2.server_onFixedUpdate( self, timeStep )
	propeller(self, timeStep)
end

Prop2_2 = class(nil)
Prop2_2.numBlades = 6
Prop2_2.radius = 1.125
Prop2_2.chord = 0.25
Prop2_2.sleep = movementSleep
Prop2_2.mult = math.sin(math.rad(((-40))) * 2.0) / 2.0 -- insert angle into triple parantheses
Prop2_2.windFac = 1

function Prop2_2.server_onFixedUpdate( self, timeStep )
	propeller(self, timeStep)
end

-- end of file --
--[[
Made by DasEtwas
All rights reserved
]]--

dofile("airfoil.lua")

chuteAirDensity = 0.073
chuteMaxAcceleration = 70 -- m/(s^2) max acceleration
--[[
movementSleep = 15 -- how many ticks it takes for previously completely still wings to activate when velocity:length() > sleepVel
sleepVel = 0.3 -- m/s
sleepTime = 5 -- how long it takes for a wing to fall asleep
]]--

function sign(num)
	if num < 0 then
		return -1
	elseif num > 0 then
		return 1
	else
		return 0
	end
end

-- gets local pos from relative global-space pos
function getLocal(shape, vec)
	return sm.vec3.new(sm.shape.getRight(shape):dot(vec), sm.shape.getAt(shape):dot(vec), sm.shape.getUp(shape):dot(vec))
end

function getGlobal(shape, vec)
	return vec.x * sm.shape.getRight(shape) + vec.y * sm.shape.getAt(shape) + vec.z * sm.shape.getUp(shape)
end

-- applies /impulse/ at arbitary /impulsePos/ to /shapes/
-- /impulse/ and /impulsePos/ are global
-- table, vec3, vec3, number
function applyGlobalImpulse(shapes, impulsePos, impulse, creationMass)
	local torqueVec, imp, pos
	for k, shape in pairs(shapes) do
		pos = impulsePos - sm.shape.getWorldPosition(shape)
		
		if pos:length2() ~= 0 then
			torqueVec = pos:cross(impulse) * -1
			imp = (torqueVec:cross(pos) / pos:length2() + impulse) * shape:getMass() / creationMass
			sm.physics.applyImpulse(shape, getLocal(shape, imp))
		end
	end
end

Chute2 = class(nil)
Chute2.active = false
Chute2.maxChildCount = 0
Chute2.maxParentCount = 1 --in
Chute2.connectionInput = sm.interactable.connectionType.logic
Chute2.connectionOutput = sm.interactable.connectionType.none
Chute2.colorNormal = sm.color.new( 0xCC0600ff )
Chute2.colorHighlight = sm.color.new( 0xEF3C39ff )
Chute2.poseWeightCount = 2
Chute2.area = 28 --28m²
Chute2.size = 7 -- extended radius
Chute2.driftCoef = 1.8
Chute2.dragCoef = 0.3
Chute2.deployTime = 1.25
Chute2.activeCounter = 0
Chute2.minDeploy = 0.15
Chute2.pos = Chute2.minDeploy * Chute2.size
Chute2.windCoef = 0.15
Chute2.chuteMaxAcceleration = 3.5 -- 3.5G of force
Chute2.sleep = movementSleep
Chute2.closeAnimPos = nil
Chute2.poseWeight1 = 0
Chute2.poseWeight2 = 0

function Chute2.server_onFixedUpdate(self, dt)
	if self.interactable:getSingleParent() then
		if self.interactable:getSingleParent():isActive() and (not self.active) then
			self.active = true
			self.activeCounter = 0
		end
	end
	
	self.pos = math.max(self.size * self.minDeploy, math.min(self.size, self.pos))
	
	if self.active then 
		if self.activeCounter < self.deployTime then
			self.activeCounter = self.activeCounter + dt
			
			if self.activeCounter > self.deployTime / 2 then				
				local deployPos = math.min((self.activeCounter - self.deployTime / 2) / self.deployTime * 2, 1) * self.minDeploy
				self.poseWeight1 = (1 - deployPos)
				self.poseWeight2 = (deployPos)
			else
				self.poseWeight1 = math.min(self.activeCounter / self.deployTime * 2, 1)
				self.closeAnimPos = nil
			end
			
			self.network:sendToClients("client_syncAnim", {[0] = self.interactable:getPoseWeight(0), [1] = self.interactable:getPoseWeight(1)})
		end
	else
		if self.activeCounter > 0 then
			self.activeCounter = math.min(self.deployTime, self.activeCounter) - dt
			
			if self.activeCounter > self.deployTime / 2 then
				if not self.closeAnimPos then self.closeAnimPos = self.pos / self.size end
				
				local deployPos = math.min((self.activeCounter - self.deployTime / 2) / self.deployTime * 2, 1) * self.closeAnimPos
				self.poseWeight2 = deployPos
				self.poseWeight1 = 1 - deployPos
			else
				self.poseWeight2 = 0
				self.poseWeight1 = math.min(self.activeCounter / self.deployTime * 2, 1)
				self.closeAnimPos = nil
			end
			
			self.pos = 0
			
			self.network:sendToClients("client_syncAnim", {[0] = self.interactable:getPoseWeight(0), [1] = self.interactable:getPoseWeight(1)})
		end
	end
	
	if self.sleepTimer == nil then self.sleepTimer = 0 end
	
	local prevPos = self.pos
	
	if self.lastPosition and self.active and self.activeCounter >= self.deployTime then
		local currentPos = sm.shape.getWorldPosition(self.shape) + sm.shape.getUp(self.shape):normalize() * self.pos

		local globalVel = (currentPos - self.lastPosition) / dt
		local globalVelL = globalVel:length()
		
		if globalVelL < sleepVel then
			if self.sleepTimer < sleepTime then
				self.sleepTimer = self.sleepTimer + 1
			end
		else
			self.sleepTimer = 0
		end

		if self.parentBodyMass ~= sm.body.getMass(self.shape:getBody()) then
			self.sleepTimer = sleepTime
		end
		
		if self.sleepTimer >= sleepTime then -- fall asleep
			self.sleep = movementSleep
		elseif self.sleep > 0 then
			self.sleep = self.sleep - 1
		end
		
		if self.sleepTimer == 0 then
			self.acceleration = globalVelL
			
			if self.lastVelocity then
				self.acceleration = (globalVelL - self.lastVelocity) / dt
			end
			
			self.lastVelocity = globalVelL
		end
	
		if self.sleep == 0 then
			if math.abs(self.acceleration) < chuteMaxAcceleration then
				--globalVel = globalVel + getWindAt(currentPos, self.shape:getId())
				local up = sm.shape.getUp(self.shape)
				local at = sm.shape.getAt(self.shape)
				local right = sm.shape.getRight(self.shape)
				
				local extendMult = math.pow(self.pos / self.size, 3)
				
				local upVel2 =  math.pow(globalVel:dot(up) / dt, 2)
				local atVel2 = math.pow(globalVel:dot(at) / dt, 2)
				local rightVel2 = math.pow(globalVel:dot(right) / dt, 2)
				local chuteForce = sm.vec3.new(0, 0, 0)
				chuteForce = chuteForce - at * (extendMult * self.area * atVel2 * 0.5 * chuteAirDensity * self.driftCoef * sign(globalVel:dot(at)))
				chuteForce = chuteForce - right * (extendMult * self.area * rightVel2 * 0.5 * chuteAirDensity * self.driftCoef * sign(globalVel:dot(right)))
				chuteForce = chuteForce - up * math.min(0, extendMult * self.area * upVel2 * 0.5 * chuteAirDensity * self.dragCoef * sign(globalVel:dot(up)))
				
				self.pos = math.max(self.size * self.minDeploy, math.min(self.size, self.pos - globalVel:dot(sm.shape.getUp(self.shape)) * dt * self.windCoef - sm.shape.getUp(self.shape).z * 0.35 * dt))
				self.poseWeight2 = self.pos / self.size
				self.poseWeight1 = 1 - self.pos / self.size
				
				local localShapes = self.shape:getBody():getShapes()
				local localMass = 0
				
				for k, shape in pairs(localShapes) do
					localMass = localMass + shape:getMass()
				end
				
				chuteForce = chuteForce * dt
				
				local chuteForceL = chuteForce:length()
				
				if chuteForceL / localMass > self.chuteMaxAcceleration then
					chuteForce = chuteForce * (self.chuteMaxAcceleration * localMass) / chuteForceL
				end
				
				applyGlobalImpulse(localShapes, currentPos, chuteForce, localMass)
			end
		end
	end
	
	--self.network:sendToClients("client_syncAnim", {[0] = self.interactable:getPoseWeight(0), [1] = self.interactable:getPoseWeight(1)})
	self.client_anims = {[0] = self.poseWeight1, [1] = self.poseWeight2}
	self.network:sendToClients("client_syncAnim", self.client_anims)
	
	if not self.timer then self.timer = 0 end
	self.timer = self.timer + dt
	self.interactable:setPoseWeight(0, math.sin(self.timer) * 0.5 + 0.5)
	self.interactable:setPoseWeight(1, 0)
	print(self.interactable:getPoseWeight(0))
	
	self.lastPosition = sm.shape.getWorldPosition(self.shape) + sm.shape.getUp(self.shape):normalize() * prevPos
	self.parentBodyMass = sm.body.getMass(self.shape:getBody())
end

function Chute2.client_syncAnim(self, client_anims)
	self.client_anims = client_anims
end

function Chute2.client_onUpdate(self, dt)
	if self.client_anims then
		--print(self.client_anims[0] .. "    " .. self.client_anims[1])
		self.interactable:setPoseWeight(0, self.client_anims[0])
		self.interactable:setPoseWeight(1, self.client_anims[1])
	end
end

function Chute2.server_repack(self)
	self.active = false
end

function Chute2.client_onInteract(self)
	if self.interactable:getSingleParent() then
		if not self.interactable:getSingleParent():isActive() then
			self.network:sendToServer("server_repack")
		end
	else
		self.network:sendToServer("server_repack")
	end
end

-- end of file --
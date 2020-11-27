--[[
Made by DasEtwas
All rights reserved
]]--

dofile("airfoil.lua")

chuteAirDensity = 2.25
chuteMaxAcc = 12 --m/s
maxVel = 600 -- m/s
maxAngVel = 0.7 -- rad/s

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
	return sm.shape.getRight(shape) * vec.x + sm.shape.getAt(shape) * vec.y + sm.shape.getUp(shape) * vec.z
end

Chute1 = class(nil)
Chute1.active = false
Chute1.maxChildCount = 0
Chute1.maxParentCount = 1 --in
Chute1.connectionInput = sm.interactable.connectionType.logic
Chute1.connectionOutput = sm.interactable.connectionType.none
Chute1.colorNormal = sm.color.new( 0xCC0600ff )
Chute1.colorHighlight = sm.color.new( 0xEF3C39ff )
Chute1.poseWeightCount = 2
Chute1.area = 28 -- 28m²
Chute1.size = 7 -- extended radius
Chute1.driftCoef = 0.15
Chute1.dragCoef = 1.0
Chute1.deployTime = 1.25
Chute1.activeCounter = 0
Chute1.minDeploy = 0.3
Chute1.windCoef = 0.15
Chute1.pos = Chute1.minDeploy * Chute1.size
Chute1.sleep = movementSleep
Chute1.closeAnimPos = nil
Chute1.poseWeight1 = 0
Chute1.poseWeight2 = 0
Chute1.angVelFac = 0.7

function Chute1.server_onFixedUpdate(self, dt)
	if self.interactable:getSingleParent() then
		if self.interactable:getSingleParent():isActive() and (not self.active) then
			self.active = true
			self.activeCounter = 0
		end
	else
		self.active = false
	end
	
	local skipTick = false
	-- spazzing out protection
	if sm.shape.getVelocity(self.shape):length() > maxVel then
		print("[Wings] Disabled chute for this update frame due to high velocity (>" .. maxVel .. "m/s)")
		skipTick = true
	end
	
	self.pos = math.max(self.size * self.minDeploy, math.min(self.size, self.pos)) -- clamp
	
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
		end
	end
	
	if self.sleepTimer == nil then self.sleepTimer = 0 end
	
	if self.active and self.activeCounter >= self.deployTime and (not skipTick) then
		local currentPos = self.shape.worldPosition + sm.shape.getUp(self.shape):normalize() * self.pos
	
		local angvel = self.shape:getBody():getAngularVelocity()
		local len1 = angvel:length()
		if len1 ~= 0 then
			angvel = angvel / len1 * math.min(len1, maxAngVel)
		end
		sm.vec3.setZ(angvel, 0)
		
		local bodyMass = self.shape:getBody():getMass()
		local angVelFac = self.angVelFac * math.min(1, bodyMass / 250) 
		local globalVel = sm.shape.getVelocity(self.shape) + angvel:cross(sm.shape.getUp(self.shape):normalize() * self.pos) * angVelFac
		local globalVelL = globalVel:length()
		
		if globalVelL ~= 0 then
			self.sleepTimer = self.sleepTimer + 1
		else
			self.sleepTimer = math.min(self.sleepTimer - 1, 0)
		end
	
		if self.sleepTimer > -sleepTime then
			local up = sm.shape.getUp(self.shape)
			local at = sm.shape.getAt(self.shape)
			local right = sm.shape.getRight(self.shape)
			
			local extendMult = math.pow(self.pos / self.size, 1.5) / (self.size / (self.size - 0.1)) + 0.1
			
			local upVel2 =  math.pow(globalVel:dot(up), 2)
			local atVel2 = math.pow(globalVel:dot(at), 2)
			local rightVel2 = math.pow(globalVel:dot(right), 2)
			local chuteForce = sm.vec3.new(0, 0, 0)
			local fac1 = extendMult * self.area * chuteAirDensity * 0.5
			chuteForce = chuteForce + at * fac1 * atVel2 * self.driftCoef * sign(globalVel:dot(at))
			chuteForce = chuteForce + right * fac1 * rightVel2 * self.driftCoef * sign(globalVel:dot(right))
			chuteForce = chuteForce - up * math.min(0, fac1 * upVel2 * self.dragCoef * sign(globalVel:dot(up)))
			
			self.pos = math.max(self.size * self.minDeploy, math.min(self.size, self.pos - globalVel:dot(sm.shape.getUp(self.shape)) * dt * self.windCoef - sm.shape.getUp(self.shape).z * 0.35 * dt))
			self.poseWeight2 = self.pos / self.size
			self.poseWeight1 = 1 - self.pos / self.size
			
			chuteForce = chuteForce * dt
			
			local chuteForceL = chuteForce:length()
			
			if chuteForceL / bodyMass > chuteMaxAcc then
				chuteForce = chuteForce * ((chuteMaxAcc / bodyMass) / chuteForceL)
			end
			
			sm.physics.applyImpulse(self.shape, chuteForce, true, (self.shape.worldPosition - currentPos) * angVelFac * 0.9)
		end
	end
	
	self.client_anims = {[0] = self.poseWeight1, [1] = self.poseWeight2}
	self.network:sendToClients("client_syncAnim", self.client_anims)
end

function Chute1.client_syncAnim(self, client_anims)
	self.client_anims = client_anims
end

function Chute1.client_onUpdate(self, dt)
	if self.client_anims then
		self.interactable:setPoseWeight(0, self.client_anims[0])
		self.interactable:setPoseWeight(1, self.client_anims[1])
	end
end

function Chute1.server_repack(self)
	self.active = false
end

function Chute1.client_onInteract(self)
	if self.interactable:getSingleParent() then
		if not self.interactable:getSingleParent():isActive() then
			self.network:sendToServer("server_repack")
		end
	else
		self.network:sendToServer("server_repack")
	end
end

-- end of file --
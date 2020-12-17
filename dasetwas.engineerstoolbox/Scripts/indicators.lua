--[[
Made by DasEtwas
All rights reserved
]]--
 
CoMIndicator = class(nil)
CoMIndicator.displayInterval = 1 -- sec

function CoMIndicator.client_onCreate(self)
	self.timer = 0
	self.mode = 0
	self.lastCoM = sm.vec3.new(0, 0, 0)
end

function CoMIndicator.client_onUpdate(self, dt)
	local frame = math.floor(self.timer / self.displayInterval)
	self.timer = self.timer + dt
	
	if self.mode ~= 0 then
		if math.random() > 0.8 then
			sm.particle.createParticle("hammer_metal", self.lastCoM)
		end
		
		if frame ~= self.lastFrame then
			-- create particles
			local creationMass = 0
			local creationCoM = sm.vec3.new(0, 0, 0)
			
			for k, v in pairs(self.shape:getBody():getCreationShapes()) do
				creationMass = creationMass + v:getMass()
				creationCoM = creationCoM + (v:getWorldPosition() * v:getMass())
			end
			
			creationCoM = creationCoM / creationMass
			self.lastCoM = creationCoM

			sm.particle.createParticle("hammer_metal", creationCoM)
			
			local at = self.shape:getAt()
			local up = self.shape:getUp()
			local right = self.shape:getRight()
			local mult = self.mode - 1
			
			for i = 0.8 / mult, mult * 2, 0.4 do
				sm.particle.createParticle("construct_welding", creationCoM + at * i)
				sm.particle.createParticle("construct_welding", creationCoM - at * i)
				sm.particle.createParticle("construct_welding", creationCoM + up * i)
				sm.particle.createParticle("construct_welding", creationCoM - up * i)
				sm.particle.createParticle("construct_welding", creationCoM + right * i)
				sm.particle.createParticle("construct_welding", creationCoM - right * i)
			end
		end
	end
	
	self.lastFrame = frame
end

function CoMIndicator.client_onInteract(self)
	sm.particle.createParticle("construct_welding", self.shape:getWorldPosition())
	self.mode = (self.mode + 1) % 5
	self.timer = 0
end

LocalCoMIndicator = class(nil)
LocalCoMIndicator.displayInterval = 1 -- sec

function LocalCoMIndicator.client_onCreate(self)
	self.timer = 0
	self.mode = 0
	self.lastCoM = sm.vec3.new(0, 0, 0)
end

function LocalCoMIndicator.client_onUpdate(self, dt)
	local frame = math.floor(self.timer / self.displayInterval)
	self.timer = self.timer + dt
	
	if self.mode ~= 0 then
		if math.random() > 0.8 then
			sm.particle.createParticle("hammer_metal", self.lastCoM)
		end
		
		if frame ~= self.lastFrame then
			-- create particles
			local creationMass = 0
			local creationCoM = sm.vec3.new(0, 0, 0)
			
			for k, v in pairs(self.shape:getBody():getShapes()) do
				creationMass = creationMass + v:getMass()
				creationCoM = creationCoM + (v:getWorldPosition() * v:getMass())
			end
			
			creationCoM = creationCoM / creationMass
			self.lastCoM = creationCoM

			sm.particle.createParticle("hammer_metal", creationCoM)
			
			local at = self.shape:getAt()
			local up = self.shape:getUp()
			local right = self.shape:getRight()
			local mult = self.mode - 1
			
			for i = 0.8 / mult, mult * 2, 0.4 do
				sm.particle.createParticle("construct_welding", creationCoM + at * i)
				sm.particle.createParticle("construct_welding", creationCoM - at * i)
				sm.particle.createParticle("construct_welding", creationCoM + up * i)
				sm.particle.createParticle("construct_welding", creationCoM - up * i)
				sm.particle.createParticle("construct_welding", creationCoM + right * i)
				sm.particle.createParticle("construct_welding", creationCoM - right * i)
			end
		end
	end
	
	self.lastFrame = frame
end

function LocalCoMIndicator.client_onInteract(self)
	sm.particle.createParticle("construct_welding", self.shape:getWorldPosition())
	self.mode = (self.mode + 1) % 5
	self.timer = 0
end

thruster = { 2222.22, 3333.33, 5000, 7500, 11250, 16875, 25312.5 } -- newtons of force per setting

CoTIndicator = class(nil)
CoTIndicator.displayInterval = 0.6 -- sec

function CoTIndicator.client_onCreate(self)
	self.timer = 0
	self.mode = 0
	self.lastCoT = sm.vec3.new(0, 0, 0)
	self.lastDir = sm.vec3.new(0, 0, 0)
end

function CoTIndicator.client_onUpdate(self, dt)
	local frame = math.floor(self.timer / self.displayInterval)
	self.timer = self.timer + dt
	
	if self.mode ~= 0 then
		if math.random() > 0.8 then
			sm.particle.createParticle("construct_welding", self.lastCoT)
		end
		
		if math.random() > 0.7 then	
			if self.lastDir:length() ~= 0 then
				local i = self.mode * (self.timer % self.displayInterval) / self.displayInterval
				sm.particle.createParticle("hammer_plastic", self.lastCoT + self.lastDir * i)
			end
		end
		
		if frame ~= self.lastFrame then
			local creationThrust = 0
			local creationCoT = sm.vec3.new(0, 0, 0)
			local dir = sm.vec3.new(0, 0, 0)
			
			for k, v in pairs(self.shape:getBody():getCreationShapes()) do
				if v:getInteractable() and v:getInteractable():getType() == "Thruster" then
					local thrust = thruster[math.floor(v:getInteractable():getPoseWeight(1) * (#thruster - 1) + 1)]
					creationThrust = creationThrust + thrust
					dir = dir + v:getUp() * thrust -- local Z+, thrusters fire in Z+
					creationCoT = creationCoT + (v:getWorldPosition() * thrust)
				end
			end
			
			dir = dir / 40000 -- make it shorter for particles
				
			creationCoT = creationCoT / creationThrust
			self.lastCoT = creationCoT
			self.lastDir = dir
		end
	end
	
	self.lastFrame = frame
end

function CoTIndicator.client_onInteract(self)
	sm.particle.createParticle("construct_welding", self.shape:getWorldPosition())
	self.mode = (self.mode + 1) % 5
	self.timer = 0
end

Scale = class(nil)

function numFormat(num)
	return math.floor(num * 1000 + 0.5) / 1000
end

function Scale.client_onInteract(self)
	self.network:sendToServer("server_scale")
end

function Scale.server_scale(self)
	local creationMass = 0

	for k, v in pairs(self.shape:getBody():getCreationShapes()) do
		creationMass = creationMass + v:getMass()
	end
	
	local s = "[Scale Block] Mass: " .. numFormat(creationMass) .. "kg (" .. numFormat(creationMass * 2.20462) .. "lbs), Weight: " .. numFormat(creationMass * sm.physics.getGravity() * -1) .. "N"
	self.network:sendToClients("client_print", s)
end

function Scale.client_print(self, s)
	print(s)
end

ThrustScale = class(nil)

function ThrustScale.client_onInteract(self)
	self.network:sendToServer("server_thrustScale")
end

function ThrustScale.server_thrustScale(self)
	local dir = sm.vec3.new(0, 0, 0)
	for k, v in pairs(self.shape:getBody():getCreationShapes()) do
		if v:getInteractable() and v:getInteractable():getType() == "thruster" then
			local thrust = thruster[math.floor(v:getInteractable():getPoseWeight(1) * (#thruster - 1) + 1)]
			dir = dir + v:getUp() * thrust -- local Z+, thrusters fire in Z+
		end
	end
	
	local creationMass = 0

	for k, v in pairs(self.shape:getBody():getCreationShapes()) do
		creationMass = creationMass + v:getMass()
	end
	
	local s = "[Thrust Scale Block] Total average thrust: " .. numFormat(dir:length()) .. "N, can lift: " .. numFormat(dir:length() / sm.physics.getGravity() * -1) .. "kg, TWR: " .. math.floor((dir:length() /  sm.physics.getGravity() * -1) / creationMass * 1000 + 0.5) / 1000
	self.network:sendToClients("client_print", s)
end

function ThrustScale.client_print(self, s)
	print(s)
end
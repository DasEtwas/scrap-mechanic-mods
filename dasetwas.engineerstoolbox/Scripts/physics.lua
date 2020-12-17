-------------------------------
--Copyright (c) 2018 DasEtwas--
-------------------------------

-- ids of bodies that have a drag block
activeBodies = {}
activeCheckPeriod = 1 -- sec
dampingComp = 0.025 - 0.000125

function sign(num)
	if num < 0 then
		return -1
	elseif num > 0 then
		return 1
	else
		return 0
	end
end

function drag(self, dt)
	for _,body in pairs(self.shape:getBody():getCreationBodies()) do
		-- disable drag
		sm.physics.applyImpulse(body, body:getVelocity() * (1 / (1 - dampingComp) - 1) * body:getMass() * dt * 10, true)
	end
end

function checkActive(self)
	for _,body in ipairs(self.shape:getBody():getCreationBodies()) do
		if activeBodies[body:getId()] == nil then
			activeBodies[body:getId()] = self.shape:getId()
		end
		if activeBodies[body:getId()] <= self.shape:getId() then
			activeBodies[body:getId()] = self.shape:getId()
			self.active = true
		else
			self.active = false
		end
	end
end

Drag = class( nil )
Drag.myBodyId = 0
Drag.myShapeId = 0
Drag.time = 0
Drag.counter = 0
Drag.active = false
Drag.maxParentCount = 0
Drag.maxChildCount = 0
Drag.connectionInput = sm.interactable.connectionType.none
Drag.connectionOutput = sm.interactable.connectionType.none
Drag.colorNormal = sm.color.new( 0xE5FFFFff )
Drag.colorHighlight = sm.color.new( 0xE5FFFFff )

function Drag.server_onCreate(self) 
end

function Drag.server_onFixedUpdate(self, dt)
	if self.myBodyId ~= self.shape:getBody():getId() then
		self.active = false
		
		for k,v in pairs(activeBodies) do
			if v == self.shape:getId() then
				activeBodies[k] = nil
			end
		end
		self.myBodyId = self.shape:getBody():getId()
	end
	self.myShapeId = self.shape:getId()
	
	checkActive(self)
	if self.active then
		drag(self, dt)
	end
end

function Drag.server_onDestroy(self)
	for k,v in pairs(activeBodies) do
		if v == self.myShapeId then
			activeBodies[k] = nil
		end
	end
end

-- end of file --
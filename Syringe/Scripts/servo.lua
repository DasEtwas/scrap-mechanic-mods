--[[
Copyright (C) 2019 DasEtwas
]]--
 
dofile("Sm-Keyboard/Scripts/ServoWidget.lua")
 
Servo = class(nil)
Servo.maxParentCount = 1
Servo.maxChildCount = -1
Servo.connectionInput =  sm.interactable.connectionType.power
Servo.connectionOutput = sm.interactable.connectionType.bearing
Servo.colorNormal = sm.color.new(0x733396FF)
Servo.colorHighlight = sm.color.new(0x7A4E93FF)
Servo.deflection = 30 -- max deflection
Servo.offset = 0 -- offset (trim)
Servo.in_ = 0 -- input signal
Servo.out_ = 0 -- output angle

function Servo.client_onCreate(self)
	self:client_onRefresh()
end

function Servo.client_onRefresh(self)
	self.network:sendToServer("server_askValues") -- for new clients joining, they need to know the channel
end

function Servo.server_askValues(self)
	self.network:sendToClients("client_valueIs", {deflection = self.deflection, offset = self.offset})
end

function Servo.client_valueIs(self, tab)
	self.deflection = tab.deflection or 0
	self.offset = tab.offset or 0
end

function Servo.server_onFixedUpdate(self, dt)
	local parent = self.interactable:getSingleParent()
    if parent then
        self.in_ = parent:getPower()
    else
        self.in_ = 0
    end
	
	if self.in_ > 1 then self.in_ = 1 end
	if self.in_ < -1 then self.in_ = -1 end

	self.out_ = self.in_ * self.deflection + self.offset
	
	local outRad = math.rad(self.out_)
	
	for k, v in pairs(self.interactable:getBearings()) do
		sm.joint.setTargetAngle(v, outRad, 14, 15000)
    end
	
	self.lastout = self.out_
end

function Servo.server_onCreate(self) 
	local stored = self.storage:load()
	if stored then
		self.deflection = stored.deflection or stored.max_
		self.offset = stored.offset or stored.offs
	else
		self.storage:save({deflection = self.deflection, offset = self.offset})
	end
end

function Servo.server_onRefresh(self)
	self:server_onCreate()
end

function Servo.client_onInteract(self, character, lookingAt)
	if lookingAt then
		self.servoGui = ServoWidget.new(self,
			{
				deflection = math.min(18, math.max(0, math.floor(self.deflection / 5))), 
				offset = math.min(36, math.max(0, math.floor((self.offset + 45)/ 2.5))), 
			},
			{
				deflection = 18, 
				offset = 36, 
			},
			function (onChangeValue)
				-- sanitize

				local value = {
					deflection = onChangeValue.deflection * 5,
					offset = onChangeValue.offset * 2.5 - 45
				}
				
				self.servoGui:setInfo(value)
				
				self:client_setValue(value)
				self.network:sendToServer("server_setValue", value)
			end
		)
		
		self.servoGui:setInfo({deflection = self.deflection, offset = self.offset})
		
		self.servoGui:open(self.channel)
	end
end

function Servo.client_setValue(self, tab)
	sm.audio.play("GUI Inventory highlight", self.shape:getWorldPosition())
	self.deflection = tab.deflection or 0
	self.offset = tab.offset or 0
end

function Servo.server_setValue(self, value)
	self.storage:save({deflection = self.deflection, offset = self.offset})
    self.network:sendToClients("client_valueIs", {deflection = self.deflection, offset = self.offset})
end

-- end of file

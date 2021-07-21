--[[
Copyright (C) 2019 DasEtwas & Brent Batch
]]--
 
dofile("Sm-Keyboard/Scripts/PeerWidget.lua")

NO_OUTPUT_VALUE = -5.75469999999999994422213214208E29
NO_INPUT_VALUE = -3.14678168466178684178E29

Peer = class(nil)
Peer.maxParentCount = 2
Peer.maxChildCount = -1
Peer.connectionInput =  sm.interactable.connectionType.power + sm.interactable.connectionType.logic + sm.interactable.connectionType.seated
Peer.connectionOutput = sm.interactable.connectionType.power + sm.interactable.connectionType.logic
Peer.colorNormal = sm.color.new(0x7AADFFFF)
Peer.colorHighlight = sm.color.new(0xBFDAFFFF)
Peer.channel = 0
Peer.in_ = 0
Peer.out_ = 0
Peer.updateClientChannels = false
Peer.peerPoolIndex = nil

-- stores the addresses of all peers
local peerPool = peerPool or {}

local delimiter = {0.0, 0.0, 0.0, 191.0, 192.0, 176.0, 201.0, 118.0, 152.0, 171.0, 27.0, 199.0, 55.0, 77.0, 217.0, 101.0, 122.0, 155.0, 15.0, 180.0, 60.0, 239.0, 58.0, 248.0, 17.0, 204.0, 198.0, 38.0, 98.0, 125.0, 206.0, 61.0, 174.0, 137.0, 80.0, 43.0, 213.0, 59.0, 172.0, 236.0, 51.0, 18.0, 28.0, 11.0, 227.0, 104.0, 170.0, 105.0, 42.0, 86.0, 156.0, 66.0, 138.0, 207.0, 83.0, 159.0, 222.0, 121.0, 185.0, 94.0, 158.0, 32.0, 254.0, 13.0, 67.0, 203.0, 221.0, 79.0, 106.0, 120.0, 54.0, 150.0, 108.0, 16.0, 226.0, 48.0, 146.0, 173.0, 202.0, 57.0, 157.0, 242.0, 210.0, 110.0, 129.0, 21.0, 253.0, 114.0, 228.0, 241.0, 12.0, 39.0, 102.0, 142.0, 182.0, 149.0, 211.0, 97.0, 153.0, 116.0, 23.0, 112.0, 93.0, 103.0, 195.0, 82.0, 131.0, 140.0, 46.0, 243.0, 194.0, 205.0, 154.0, 147.0, 25.0, 196.0, 119.0, 63.0, 188.0, 244.0, 99.0, 71.0, 45.0, 164.0, 166.0, 111.0, 113.0, 89.0, 165.0, 41.0, 49.0, 31.0, 85.0, 132.0, 220.0, 200.0, 143.0, 249.0, 40.0, 130.0, 19.0, 219.0, 162.0, 30.0, 92.0, 247.0, 160.0, 90.0, 20.0, 214.0, 34.0, 134.0, 161.0, 26.0, 229.0, 81.0, 141.0, 9.0, 72.0, 212.0, 126.0, 115.0, 69.0, 56.0, 117.0, 123.0, 168.0, 208.0, 231.0, 33.0, 215.0, 78.0, 251.0, 230.0, 189.0, 235.0, 127.0, 223.0, 181.0, 136.0, 52.0, 35.0, 87.0, 187.0, 64.0, 88.0, 76.0, 234.0, 74.0, 178.0, 145.0, 70.0, 29.0, 75.0, 240.0, 37.0, 135.0, 68.0, 44.0, 224.0, 124.0, 24.0, 50.0, 175.0, 184.0, 133.0, 167.0, 73.0, 91.0, 197.0, 186.0, 218.0, 233.0, 209.0, 238.0, 245.0, 193.0, 151.0, 62.0, 36.0, 179.0, 252.0, 216.0, 232.0, 10.0, 250.0, 246.0, 95.0, 190.0, 128.0, 84.0, 255.0, 107.0, 100.0, 109.0, 169.0, 183.0, 177.0, 163.0, 148.0, 96.0, 225.0, 53.0, 144.0, 22.0, 65.0, 47.0}
local delimiterSize = #delimiter -- 247 doubles
local totalSize = delimiterSize + 10

function Peer.client_onCreate(self)
	self:client_onRefresh()
end

function Peer.client_onRefresh(self)
	self.data = {}
	-- delimiter | 1 channel | 2 in | 3 out | 4 R | 5 G | 6 B | 7 numOutputs | 8 numInputs | 9 shapeid | 10 peerPoolIndex
	
	self.peerPoolIndex = #peerPool + 1
	
	local myAddress = self:client_dataAddress()
	
	peerPool[self.peerPoolIndex] = myAddress;
	self.data[totalSize + 1] = #peerPool

	-- completes the delimiter
	for i = 3, delimiterSize do
		self.data[i] = delimiter[i] + 0
	end
	for i = delimiterSize + 1, totalSize do
		self.data[i] = 0.0
	end
	self.data[1] = 14.0
	self.data[2] = 237.0
	self.data[3] = 139.0
	
	--print("peer id: " .. self.shape:getId() .. ", channel: " .. self.channel .. ", data[1]: " .. self.data[1])
end

function Peer.client_dataAddress(self)
	local addressString = tostring(self.data):sub(10)

	local addressLo = tonumber(addressString:sub(-8, -1) or "0", 16)
	local addressHi = tonumber(addressString:sub(-16, -9) or "0", 16)
	return addressLo + addressHi * math.pow(2, 32)
end

function Peer.server_onCreate(self)
	self.updateClientChannels = true
end

function Peer.server_onRefresh(self)
	self.updateClientChannels = true
end

function Peer.client_onFixedUpdate(self, dt)
	local parents = self.interactable:getParents()

	local isLocalPlayerSeated = false
	self.controllingPlayer = nil
	
	-- prevent LuaJIT from deduplicating the data table of peers; because we want
	-- every peer to have its own data table, we corrupt the delimiter
	-- on every tick to discourage all peers sharing one table.
	-- sminject.exe allows for a certain number of wrong delimiter
	-- values (eg. 2) while scanning for peers.
	if self.randomIndex then
		self.data[self.randomIndex] = delimiter[self.randomIndex]
	end
	self.randomIndex = math.floor(4 + math.random() * (delimiterSize - 5));
	self.data[self.randomIndex] = math.random()
	local h = { h = self.data[self.randomIndex] }
	
	for _, interactable in pairs(parents) do
		local character = interactable:getSeatCharacter()
		if character then
			if character:getPlayer() then
				self.controllingPlayer = character:getPlayer()
				
				if character:getPlayer():getId() == sm.localPlayer.getId() then
					isLocalPlayerSeated = true
				end
			end
		else
			-- input signal
			if interactable:isActive() then
				-- logic input
				self.out_ = 1
			else
				-- 0 for logic input or else power
				self.out_ = interactable:getPower()
			end    
		end
	end

	if #parents <= 1 then
		-- this peer is not connected to at least a seat and input
		self.out_ = NO_OUTPUT_VALUE
	end

	local myAddress = self:client_dataAddress()
	
	peerPool[self.peerPoolIndex] = myAddress;
	self.data[totalSize + 1] = #peerPool
	
	for i = totalSize + 2, totalSize + 2 + #peerPool do
		self.data[i] = peerPool[i - totalSize - 1]
	end

	self.data[delimiterSize + 1] = self.channel + 5000.0
	if isLocalPlayerSeated then
		self.in_ = self.data[delimiterSize + 2]
		
		if self.in_ ~= self.lastin  then	
			-- The player in the seat is the one of the client running this very code, so we tell the server to
			-- update the value of the peer for the server (and implicitly every other client).
			self.network:sendToServer("server_setValue", self.in_)
			--print("sending to server: " .. self.in_)
		end
	else
		-- used for UI
		self.in_ = NO_INPUT_VALUE
	end

	self.data[delimiterSize + 3] = self.out_
	
	local color = sm.shape.getColor(self.shape)
	self.data[delimiterSize + 4] = color.r
	self.data[delimiterSize + 5] = color.g
	self.data[delimiterSize + 6] = color.b
	self.data[delimiterSize + 7] = #self.interactable:getChildren()
	self.data[delimiterSize + 8] = #self.interactable:getParents()
	self.data[delimiterSize + 9] = self.shape:getId()
	self.data[delimiterSize + 10] = self.peerPoolIndex
	
	self.lastin = self.in_
end

function playerexists(player)
	return (player.character.worldPosition ~= nil)
end

-- sets the peer's output value
function Peer.server_setValue(self, data)
	self.interactable:setPower(data)
	self.interactable:setActive(data >= 0.5)
end

function Peer.server_onCreate(self) 
	local stored = self.storage:load()
	
	if stored then
		self.channel = stored.channel or 0
	else
		self.storage:save({channel = self.channel})
	end
	
	self.updateClientChannels = true
end

function Peer.server_onRefresh(self)
	self:server_onCreate()
end

function Peer.server_onFixedUpdate(self)
	if self.updateClientChannels then 
		self.network:sendToClients("client_setChannel", self.channel)
		
		self.updateClientChannels = false
	end
end

function Peer.client_onUpdate(self, dt)
	if self.keypad then
		self.keypad:setInfo(
			"#D6D6D6output: " .. ((self.out_ == NO_OUTPUT_VALUE) and "#FF4830no inputs connected" or math.floor(self.out_ * 1000.0 + 0.5) / 1000.0) ..
			(self.controllingPlayer and 
				("\n#D6D6D6input: " .. (math.floor(((self.in_ == NO_INPUT_VALUE) and self.interactable:getPower() or self.in_) * 1000.0 + 0.5) / 1000.0) ..
				"\nControlled by: #FFFFFF" .. self.controllingPlayer:getName())
			 or
				"\n#D6D6D6input: #FF4830no player"
			)
		)
	end
end

function Peer.client_onInteract(self, character, lookingAt)
	if lookingAt then
		self.keypad = PeerWidget.new(self, "Set channel of Peer ##" .. self.shape:getId(),
			function (onConfirmValue)
				-- value confirmed
				
				-- sanitize
				onConfirmValue = math.max(0, math.min(math.pow(2, 32) - 1 - 5000, math.floor(onConfirmValue)))
				
				self:client_setMyChannel(onConfirmValue)
				self.network:sendToServer("server_setChannel", onConfirmValue)
			end,
			function ()
				self.keypad = nil
			end
		)
		
		self.keypad:open(self.channel)
	end
end

function Peer.server_setChannel(self, chID)
	self.channel = chID
	
	self.storage:save({ channel = self.channel })
	self.network:sendToClients("client_setChannel", self.channel)
end

function Peer.client_setMyChannel(self, channel)
	sm.audio.play("GUI Inventory highlight", self.shape:getWorldPosition())
	self.channel = channel or 0
end

function Peer.client_setChannel(self, channel)
	self.channel = channel or 0
end

function Peer.server_onDestroy(self)
	peerPool[self.peerPoolIndex] = -1;

	-- invalidates the delimiter
	for i = 1, delimiterSize do
		self.data[i] = 500.0
	end
	
	self.data = nil
end

-- end of file

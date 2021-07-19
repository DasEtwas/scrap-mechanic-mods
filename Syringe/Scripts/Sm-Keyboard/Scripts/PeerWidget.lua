PeerWidget = class()
PeerWidget.layout = nil
PeerWidget.gui = nil
PeerWidget.scriptedShape = nil
PeerWidget.buffer = nil

local function generateCallbacks(scriptedShape, instance)
    scriptedShape.gui_keypadButtonCallback = function (shape, buttonName)
        instance:onButtonClick(buttonName)
    end

    scriptedShape.gui_keypadConfirm = function (shape, buttonName)
        instance:confirm()
    end

    scriptedShape.gui_keypadCancel = function (shape, buttonName)
        instance:cancel()
    end

    scriptedShape.gui_keypadClear = function (shape, buttonName)
        instance:clear()
    end

    scriptedShape.gui_keypadBackspace = function (shape, buttonName)
        instance:backspace()
    end

    scriptedShape.gui_keypadCloseCallback = function (shape)
        instance:close()
    end
end

local function setCallbacks(instance)
    for i = 0, 9, 1 do
        instance.gui:setButtonCallback(tostring(i), "gui_keypadButtonCallback")
    end

    instance.gui:setButtonCallback("Confirm", "gui_keypadConfirm")
    instance.gui:setButtonCallback("Cancel", "gui_keypadCancel")
    instance.gui:setButtonCallback("Clear", "gui_keypadClear")
    instance.gui:setButtonCallback("Backspace", "gui_keypadBackspace")
    instance.gui:setOnCloseCallback("gui_keypadCloseCallback")
end

function PeerWidget.new(scriptedShape, title, onConfirmCallback, onCloseCallback)
    assert(onConfirmCallback ~= nil and type(onConfirmCallback) == "function", "Invalid confirm callback passed.")
    assert(onCloseCallback ~= nil and type(onCloseCallback) == "function", "Invalid close callback passed.")

    local instance = PeerWidget()
    instance.scriptedShape = scriptedShape
    instance.buffer = ""
    instance.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Scripts/Sm-Keyboard/Gui/PeerWidget.layout")
    instance.gui:setText("Title", title)

    instance.confirm = function (shape, buttonName)
        onConfirmCallback(tonumber(instance.buffer) or 0)
        instance.gui:close()
    end

    instance.close = function (shape, buttonName)
        onCloseCallback()
        instance.buffer = ""
    end

    generateCallbacks(scriptedShape, instance)
    setCallbacks(instance)

    return instance
end

function PeerWidget:setInfo(text)
	self.gui:setText("Info", text)
end

function PeerWidget:open(initialBuffer)
    if initialBuffer ~= nil and type(initialBuffer) == "number" then
        self.buffer = tostring(initialBuffer)
    else
        self.buffer = "0"
    end

    self.gui:setText("Textbox", self.buffer)
    self.gui:open()
end

function PeerWidget:onButtonClick(buttonName)
    if self.buffer == "0" then
        self.buffer = buttonName
    elseif self.buffer == "-0" then
        self.buffer = "-" .. buttonName
    else
        self.buffer = self.buffer .. buttonName
    end

    self.gui:setText("Textbox", self.buffer)
end

function PeerWidget:cancel()
    self.gui:close()
end

function PeerWidget:clear()
    self.buffer = "0"
    self.gui:setText("Textbox", self.buffer)
end

function PeerWidget:backspace()
    local tempBuffer = self.buffer:sub(1, -2)

    self.buffer = #tempBuffer > 0 and tempBuffer or "0"
    self.gui:setText("Textbox", self.buffer)
end

function PeerWidget:negate()
    local number = tonumber(self.buffer) or 0
    number = number * -1
    self.buffer = tostring(number)
    self.gui:setText("Textbox", self.buffer)
end

function PeerWidget:decimalPoint()
    if not self.hasDecimalPoint then
        self.hasDecimalPoint = true
        self.buffer = self.buffer .. "."
    end

    self.gui:setText("Textbox", self.buffer)
end

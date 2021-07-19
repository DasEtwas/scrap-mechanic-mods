Keypad = class()
Keypad.layout = nil
Keypad.gui = nil
Keypad.scriptedShape = nil
Keypad.buffer = nil
Keypad.hasDecimalPoint = nil
Keypad.negative = nil

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

    scriptedShape.gui_keypadNegate = function (shape, buttonName)
        instance:negate()
    end

    scriptedShape.gui_keypadDecimalPoint = function (shape, buttonName)
        instance:decimalPoint()
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
    instance.gui:setButtonCallback("Negate", "gui_keypadNegate")
    instance.gui:setButtonCallback("DecimalPoint", "gui_keypadDecimalPoint")
    instance.gui:setOnCloseCallback("gui_keypadCloseCallback")
end

function Keypad.new(scriptedShape, title, onConfirmCallback, onCloseCallback)
    assert(onConfirmCallback ~= nil and type(onConfirmCallback) == "function", "Invalid confirm callback passed.")
    assert(onCloseCallback ~= nil and type(onCloseCallback) == "function", "Invalid close callback passed.")

    local instance = Keypad()
    instance.scriptedShape = scriptedShape
    instance.buffer = ""
    instance.hasDecimalPoint = false
    instance.negative = false
    instance.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Scripts/Sm-Keyboard/Gui/Keypad.layout")
    instance.gui:setText("Title", title)

    instance.confirm = function (shape, buttonName)
        onConfirmCallback(tonumber(instance.buffer) or 0)
        instance.gui:close()
    end

    instance.close = function (shape, buttonName)
        onCloseCallback()
        instance.buffer = ""
        instance.hasDecimalPoint = false
        instance.negative = false
    end

    generateCallbacks(scriptedShape, instance)
    setCallbacks(instance)

    return instance
end

function Keypad:open(initialBuffer)
    if initialBuffer ~= nil and type(initialBuffer) == "number" then
        self.buffer = tostring(initialBuffer)
        self.hasDecimalPoint = initialBuffer % 1 ~= 0
        self.negative = initialBuffer < 0
    else
        self.buffer = "0"
    end

    self.gui:setText("Textbox", self.buffer)
    self.gui:open()
end

function Keypad:onButtonClick(buttonName)
    if self.buffer == "0" then
        self.buffer = buttonName
    elseif self.buffer == "-0" then
        self.buffer = "-" .. buttonName
    else
        self.buffer = self.buffer .. buttonName
    end

    self.gui:setText("Textbox", self.buffer)
end

function Keypad:cancel()
    self.gui:close()
end

function Keypad:clear()
    self.buffer = "0"
    self.hasDecimalPoint = false
    self.gui:setText("Textbox", self.buffer)
end

function Keypad:backspace()
    local tempBuffer = self.buffer:sub(1, -2)

    if self.hasDecimalPoint and tempBuffer:find(".", 1, true) == nil then
        self.hasDecimalPoint = false
    end

    self.buffer = #tempBuffer > 0 and tempBuffer or "0"
    self.gui:setText("Textbox", self.buffer)
end

function Keypad:negate()
    local number = tonumber(self.buffer) or 0
    number = number * -1
    self.hasDecimalPoint = number % 1 ~= 0
    self.negative = number < 0
    self.buffer = tostring(number)
    self.gui:setText("Textbox", self.buffer)
end

function Keypad:decimalPoint()
    if not self.hasDecimalPoint then
        self.hasDecimalPoint = true
        self.buffer = self.buffer .. "."
    end

    self.gui:setText("Textbox", self.buffer)
end

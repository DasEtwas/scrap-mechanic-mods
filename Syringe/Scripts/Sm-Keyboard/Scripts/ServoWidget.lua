ServoWidget = class()
ServoWidget.layout = nil
ServoWidget.gui = nil
ServoWidget.scriptedShape = nil
ServoWidget.deflection = nil
ServoWidget.offset = nil

local function generateCallbacks(scriptedShape, instance)
    scriptedShape.gui_servoSliderDeflection = function (shape, sliderName, sliderPos)
        instance.deflection = sliderPos
		instance.onChangeCallback({ deflection = instance.deflection, offset = instance.offset })
    end

    scriptedShape.gui_servoSliderOffset = function (shape, sliderName, sliderPos)
        instance.offset = sliderPos
		instance.onChangeCallback({ deflection = instance.deflection, offset = instance.offset })
    end
	
	scriptedShape.gui_servoDeflectionIncrease = function (shape, button)
        instance.deflection = math.min(instance.steps.deflection, instance.deflection + 1)
		instance.onChangeCallback({ deflection = instance.deflection, offset = instance.offset })
    end
	
	scriptedShape.gui_servoDeflectionDecrease = function (shape, button)
        instance.deflection = math.max(0, instance.deflection - 1)
		instance.onChangeCallback({ deflection = instance.deflection, offset = instance.offset })
    end
	
	scriptedShape.gui_servoOffsetIncrease = function (shape, button)
        instance.offset = math.min(instance.steps.offset, instance.offset + 1)
		instance.onChangeCallback({ deflection = instance.deflection, offset = instance.offset })
    end
	
	scriptedShape.gui_servoOffsetDecrease = function (shape, button)
        instance.offset = math.max(0, instance.offset - 1)
		instance.onChangeCallback({ deflection = instance.deflection, offset = instance.offset })
    end

    scriptedShape.gui_servoCloseCallback = function (shape)
        instance.gui:close()
    end
end

local function setCallbacks(instance)
	instance.gui:setSliderCallback("Deflection", "gui_servoSliderDeflection")
	instance.gui:setSliderCallback("Offset", "gui_servoSliderOffset")
	
	instance.gui:setButtonCallback("DeflectionIncrease", "gui_servoDeflectionIncrease")
	instance.gui:setButtonCallback("DeflectionDecrease", "gui_servoDeflectionDecrease")

	instance.gui:setButtonCallback("OffsetIncrease", "gui_servoOffsetIncrease")
	instance.gui:setButtonCallback("OffsetDecrease", "gui_servoOffsetDecrease")
	
    instance.gui:setOnCloseCallback("gui_servoCloseCallback")
end

function ServoWidget.new(scriptedShape, initial, steps, onChangeCallback)
    assert(onChangeCallback ~= nil and type(onChangeCallback) == "function", "Invalid confirm callback passed.")
    assert(initial.deflection ~= nil and initial.offset ~= nil, "Invalid initial state passed.")
	assert(steps.deflection ~= nil and steps.offset ~= nil, "Invalid step count table passed.")

    local instance = ServoWidget()
	instance.offset = initial.offset
	instance.deflection = initial.deflection
    instance.scriptedShape = scriptedShape
    instance.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Scripts/Sm-Keyboard/Gui/ServoWidget.layout")

	-- TODO: reenable sliders when they work
	instance.gui:setVisible("Deflection", false)
	--instance.gui:setSliderData("Deflection", steps.deflection, initial.deflection)
	instance.gui:setVisible("Offset", false)
	--instance.gui:setSliderData("Offset", steps.offset, initial.offset)
	
	instance.steps = steps

	instance.onChangeCallback = onChangeCallback

    generateCallbacks(scriptedShape, instance)
    setCallbacks(instance)

    return instance
end

function ServoWidget:setInfo(values)
	self.gui:setText("DeflectionInfo", values.deflection .. "°")
	self.gui:setText("OffsetInfo", values.offset .. "°")
end

function ServoWidget:open()
    self.gui:open()
end

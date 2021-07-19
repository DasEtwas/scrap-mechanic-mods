ServoWidget = class()
ServoWidget.layout = nil
ServoWidget.gui = nil
ServoWidget.scriptedShape = nil
ServoWidget.deflection = nil
ServoWidget.offset = nil

local function generateCallbacks(scriptedShape, instance)
    scriptedShape.gui_servoSliderDeflection = function (shape, sliderName, sliderPos)
        instance.deflection = sliderPos
		instance.onConfirmCallback({ deflection = instance.deflection, offset = instance.offset })
    end

    scriptedShape.gui_servoSliderOffset = function (shape, sliderName, sliderPos)
        instance.offset = sliderPos
		instance.onConfirmCallback({ deflection = instance.deflection, offset = instance.offset })
    end

    scriptedShape.gui_servoCloseCallback = function (shape)
        instance.gui:close()
    end
end

local function setCallbacks(instance)
	instance.gui:setSliderCallback("Deflection", "gui_servoSliderDeflection")
	--instance.gui:setSliderCallback("Offset", "gui_servoSliderOffset")
    instance.gui:setOnCloseCallback("gui_servoCloseCallback")
end

function ServoWidget.new(scriptedShape, initial, steps, onChangeCallback)
    assert(onChangeCallback ~= nil and type(onChangeCallback) == "function", "Invalid confirm callback passed.")
    assert(initial.deflection ~= nil and initial.offset ~= nil, "Invalid initial state passed.")
	assert(steps.deflection ~= nil and steps.offset ~= nil, "Invalid step count table passed.")

    local instance = ServoWidget()
    instance.scriptedShape = scriptedShape
    instance.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Scripts/Sm-Keyboard/Gui/ServoWidget.layout")


	
	instance.gui:setSliderData("Deflection", steps.deflection,  initial.deflection)
	instance.gui:setSliderRangeLimit("Deflection", steps.deflection)
	--instance.gui:setSliderData("Offset", steps.offset,  math.min(steps.offset, math.max(0, math.floor(initial.offset))))
	
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

-- Settings panel (Game Menu > Options > AddOns > SwingBar, or /swingbar).
local _, ns = ...

local O = { syncs = {} }
ns.Options = O

local function Changed()
    ns.Bars:Refresh()
end

local function Check(parent, text, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(text)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Changed()
    end)
    O.syncs[#O.syncs + 1] = function() cb:SetChecked(get()) end
    return cb
end

local function Slider(parent, text, key, lo, hi, step, fmt)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(200, 16)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(6)
    local label = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
    local function Show(v) label:SetText(text .. ": " .. fmt:format(v)) end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        if ns.db[key] ~= v then
            ns.db[key] = v
            Changed()
        end
        Show(v)
    end)
    O.syncs[#O.syncs + 1] = function()
        s:SetValue(ns.db[key])
        Show(ns.db[key])
    end
    return s
end

local function Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function PickColor(color)
    local r, g, b = color[1], color[2], color[3]
    local function Apply()
        color[1], color[2], color[3] = ColorPickerFrame:GetColorRGB()
        Changed()
        O:Sync()
    end
    local function Cancel()
        color[1], color[2], color[3] = r, g, b
        Changed()
        O:Sync()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
                                                   swatchFunc = Apply, cancelFunc = Cancel })
    else
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc, ColorPickerFrame.hasOpacity = Apply, Cancel, false
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end
end

local function Swatch(parent, key)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(1, 1, 1, 0.8)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetScript("OnClick", function() PickColor(ns.db.bars[key].color) end)
    O.syncs[#O.syncs + 1] = function() tex:SetColorTexture(unpack(ns.db.bars[key].color)) end
    return b
end

function O:Sync()
    for _, fn in ipairs(self.syncs) do fn() end
end

function O:Open()
    if Settings and Settings.OpenToCategory and self.category then
        Settings.OpenToCategory(self.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end

function O:Init()
    local db = ns.db
    local panel = CreateFrame("Frame")
    panel.name = "SwingBar"
    self.panel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SwingBar")
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Subtle swing timers for main hand, off hand and ranged weapons.")

    -- Left column: look
    local x, y = 20, -70
    local function Place(widget, dy)
        widget:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        y = y - dy
        return widget
    end

    local styleBtn
    styleBtn = Place(Button(panel, "", 200, function()
        db.style = (db.style == "classic") and "clean" or "classic"
        Changed()
        O:Sync()
    end), 44)
    self.syncs[#self.syncs + 1] = function()
        styleBtn:SetText("Bar look: " .. (ns.db.style == "classic" and "Classic cast bar" or "Solid clean"))
    end

    Place(Slider(panel, "Opacity", "alpha", 0.1, 1, 0.05, "%.2f"), 40)
    Place(Slider(panel, "Background opacity", "bgAlpha", 0, 1, 0.05, "%.2f"), 40)
    Place(Slider(panel, "Scale", "scale", 0.5, 2.5, 0.05, "%.2f"), 40)
    Place(Slider(panel, "Width", "width", 60, 400, 5, "%d"), 40)
    Place(Slider(panel, "Height", "height", 4, 30, 1, "%d"), 40)
    Place(Slider(panel, "Gap between bars", "spacing", 0, 30, 1, "%d"), 40)

    -- Right column: behaviour and per-bar settings
    x, y = 290, -66
    Place(Check(panel, "Lock position", function() return ns.db.locked end, function(v) ns.db.locked = v end), 28)
    Place(Check(panel, "Hide bars when not swinging", function() return ns.db.hideIdle end, function(v) ns.db.hideIdle = v end), 28)
    Place(Check(panel, "Show spark", function() return ns.db.showSpark end, function(v) ns.db.showSpark = v end), 28)
    Place(Check(panel, "Show time left", function() return ns.db.showTime end, function(v) ns.db.showTime = v end), 28)
    Place(Check(panel, "Show weapon type", function() return ns.db.showLabel end, function(v) ns.db.showLabel = v end), 28)
    Place(Check(panel, "Drain instead of fill", function() return ns.db.fill == "drain" end,
                function(v) ns.db.fill = v and "drain" or "fill" end), 40)

    local names = { mh = "Main hand bar", oh = "Off hand bar", ranged = "Ranged / wand bar" }
    for _, key in ipairs(ns.Bars.order) do
        local cb = Place(Check(panel, names[key], function() return ns.db.bars[key].enabled end,
                               function(v) ns.db.bars[key].enabled = v end), 28)
        Swatch(panel, key):SetPoint("LEFT", cb, "RIGHT", 150, 0)
    end

    y = y - 12
    local test = Place(Button(panel, "Test bars", 100, function()
        ns.Bars.testing = not ns.Bars.testing
        Changed()
    end), 0)
    Button(panel, "Reset all", 100, function() ns:ResetSettings() end):SetPoint("LEFT", test, "RIGHT", 8, 0)

    panel:SetScript("OnShow", function() O:Sync() end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        self.category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(self.category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    self:Sync()
end

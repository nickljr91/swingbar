-- Bar frames: one small status bar each for main hand, off hand and ranged.
local _, ns = ...

local B = { bars = {}, order = { "mh", "oh", "ranged" }, testing = false }
ns.Bars = B

local TEX_CLASSIC = "Interface\\TargetingFrame\\UI-StatusBar"
local TEX_CLEAN   = "Interface\\Buttons\\WHITE8x8"
local TEX_BORDER  = "Interface\\CastingBar\\UI-CastingBar-Border"
local TEX_SPARK   = "Interface\\CastingBar\\UI-CastingBar-Spark"
local TEST_DURATION = { mh = 2.6, oh = 1.8, ranged = 2.1 }

local function CreateBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    bar.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -1) -- thin outline (clean look)
    bar.edge:SetPoint("TOPLEFT", -1, 1)
    bar.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.edge:SetColorTexture(0, 0, 0, 1)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()

    bar.overlay = CreateFrame("Frame", nil, bar) -- keeps art and text above the fill
    bar.overlay:SetAllPoints()

    bar.border = bar.overlay:CreateTexture(nil, "ARTWORK") -- cast bar frame (classic look)
    bar.border:SetTexture(TEX_BORDER)

    bar.spark = bar.overlay:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture(TEX_SPARK)
    bar.spark:SetBlendMode("ADD")

    bar.label = bar.overlay:CreateFontString(nil, "OVERLAY")
    bar.label:SetPoint("LEFT", 3, 0)
    bar.label:SetJustifyH("LEFT")
    bar.time = bar.overlay:CreateFontString(nil, "OVERLAY")
    bar.time:SetPoint("RIGHT", -3, 0)
    bar.time:SetJustifyH("RIGHT")
    return bar
end

function B:ApplyPosition()
    local p = ns.db.point
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- A bar takes a row when it is switched on and the character can use it.
function B:IsPresent(key)
    local db = ns.db
    if not db.bars[key].enabled then return false end
    return self.testing or not db.locked or ns.Engine:Has(key)
end

-- Re-applies every setting. Cheap enough to call on any change.
function B:Refresh()
    local db, anchor = ns.db, self.anchor
    if not anchor then return end
    local w, h = db.width, db.height
    local classic = (db.style == "classic")
    local font = math.max(8, math.min(14, h))

    anchor:SetScale(db.scale)
    anchor:SetAlpha(db.alpha)
    anchor:EnableMouse(not db.locked)
    anchor.hint:SetShown(not db.locked)

    local rows = 0
    for _, key in ipairs(self.order) do
        local bar = self.bars[key]
        bar.present = self:IsPresent(key)
        if bar.present then
            bar:SetSize(w, h)
            bar:ClearAllPoints()
            bar:SetPoint("TOP", anchor, "TOP", 0, -rows * (h + db.spacing))
            rows = rows + 1

            bar:SetStatusBarTexture(classic and TEX_CLASSIC or TEX_CLEAN)
            bar:SetStatusBarColor(unpack(db.bars[key].color))
            bar.bg:SetColorTexture(0, 0, 0, db.bgAlpha)
            bar.edge:SetShown(not classic)
            bar.edge:SetAlpha(math.min(1, db.bgAlpha + 0.3))

            -- The border art is drawn for a 195x13 bar; stretch it to this bar.
            bar.border:SetShown(classic)
            bar.border:SetSize(w * 256 / 195, h * 64 / 13)
            bar.border:ClearAllPoints()
            bar.border:SetPoint("TOP", bar, "TOP", 0, h * 28 / 13)

            bar.spark:SetSize(h * 32 / 13, h * 32 / 13)
            bar.label:SetFont(STANDARD_TEXT_FONT, font, "OUTLINE")
            bar.time:SetFont(STANDARD_TEXT_FONT, font, "OUTLINE")
            bar.label:SetShown(db.showLabel or not db.locked)
            bar.label:SetText(ns.Weapons:Label(key))
            bar.time:SetShown(db.showTime)
        else
            bar:Hide()
        end
    end
    anchor:SetSize(w, math.max(h, rows * h + math.max(0, rows - 1) * db.spacing))
end

local function Draw(bar, db, frac, remaining, alpha)
    local value = (db.fill == "drain") and (1 - frac) or frac
    bar:SetValue(value)
    bar:SetAlpha(alpha)
    if db.showSpark and frac > 0 and frac < 1 then
        bar.spark:SetPoint("CENTER", bar, "LEFT", value * db.width, 0)
        bar.spark:Show()
    else
        bar.spark:Hide()
    end
    if db.showTime then
        if remaining and remaining > 0 then
            bar.time:SetFormattedText("%.1f", remaining)
        else
            bar.time:SetText("")
        end
    end
    bar:Show()
end

function B:OnUpdate()
    local db, now = ns.db, GetTime()
    for _, key in ipairs(self.order) do
        local bar = self.bars[key]
        if bar.present then
            if self.testing then
                local d = TEST_DURATION[key]
                local frac = (now % d) / d
                Draw(bar, db, frac, d * (1 - frac), 1)
            elseif not db.locked then
                Draw(bar, db, 0.6, nil, 1)
            else
                local frac, remaining, over = ns.Engine:Progress(key, now)
                if frac then
                    Draw(bar, db, frac, remaining, 1 - over / ns.Engine.linger)
                elseif db.hideIdle then
                    bar:Hide()
                else
                    Draw(bar, db, 0, nil, 1)
                end
            end
        end
    end
end

function B:Init()
    local anchor = CreateFrame("Frame", "SwingBarAnchor", UIParent)
    self.anchor = anchor
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", anchor.StartMoving)
    anchor:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        ns.db.point = { point, relPoint, x, y }
    end)

    anchor.hint = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.hint:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    anchor.hint:SetText("SwingBar - drag to move")

    for _, key in ipairs(self.order) do
        self.bars[key] = CreateBar(anchor)
    end
    self:ApplyPosition()
    self:Refresh()
    anchor:SetScript("OnUpdate", function() B:OnUpdate() end)
end

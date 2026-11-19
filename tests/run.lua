-- Offline smoke test: loads the addon against a stubbed WoW API and checks the
-- timer logic. Run from the repo root:  lua5.1 tests/run.lua
local now = 100
local speeds = { 2.0, 1.5, 3.0 }
local handlers, frames = {}, {}

local function Widget()
    local w = { scripts = {} }
    return setmetatable(w, { __index = function(_, k)
        if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k:match("^Create") then return function() return Widget() end end
        if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
        if k == "GetChecked" then return function() return true end end
        if k == "GetID" then return function() return 1 end end
        return function() end
    end })
end

function CreateFrame() local f = Widget(); frames[#frames + 1] = f; return f end
UIParent = Widget()
ColorPickerFrame = Widget()
STANDARD_TEXT_FONT = "font"
SlashCmdList = {}
Settings = { RegisterCanvasLayoutCategory = function() return Widget() end,
             RegisterAddOnCategory = function() end, OpenToCategory = function() end }
function GetTime() return now end
function UnitAttackSpeed() return speeds[1], speeds[2], speeds[3] end
function GetInventoryItemID(_, slot) return ({ [16] = 1, [17] = 2, [18] = 3 })[slot] end
C_Item = { GetItemInfoInstant = function(id)
    return id, nil, nil, nil, nil, 2, ({ 7, 15, 19 })[id] end }
print = function() end

local ns = {}
for _, file in ipairs({ "Core", "Weapons", "Engine", "Bars", "Options" }) do
    assert(loadfile(file .. ".lua"))("SwingBar", ns)
end
frames[1].scripts.OnEvent(frames[1], "ADDON_LOADED", "SwingBar")

local E, pass = ns.Engine, 0
local function check(cond, what)
    if not cond then io.stderr:write("FAIL: " .. what .. "\n"); os.exit(1) end
    pass = pass + 1
end
local function near(a, b) return a and math.abs(a - b) < 1e-6 end
local function tick() ns.Bars:OnUpdate() end

-- Dual wield: main hand and off hand run independently.
E:HandleEvent("PLAYER_SWING", 2.0, 0)
now = 100.5
E:HandleEvent("PLAYER_SWING", 1.5, 1)
now = 101
local f, rem = E:Progress("mh", now)
check(near(f, 0.5) and near(rem, 1.0), "main hand half way")
f, rem = E:Progress("oh", now)
check(near(f, 1 / 3) and near(rem, 1.0), "off hand independent")
check(E:Progress("ranged", now) == nil, "ranged idle")
tick()

-- Ranged (wand / bow / gun) uses swing type 2.
E:HandleEvent("PLAYER_SWING", 3.0, 2)
now = 102.5
f = E:Progress("ranged", now)
check(near(f, 0.5), "ranged half way")

-- Haste mid-swing: 30% faster keeps the fraction, shortens the rest.
E:HandleEvent("PLAYER_SWING", 2.0, 0)   -- at 102.5
now = 103.5
speeds[1] = 1.0
E:HandleEvent("UNIT_ATTACK_SPEED", "player")
f, rem = E:Progress("mh", now)
check(near(f, 0.5) and near(rem, 0.5), "rescale on haste")

-- Finished timers linger for the fade and then stop.
now = 104.2
f, rem = E:Progress("mh", now)
check(f == 1 and rem == 0, "lingers at full")
now = 105
check(E:Progress("mh", now) == nil, "stops after linger")

-- Weapon swap restarts a running swing at the new speed.
speeds[1] = 2.0
E:HandleEvent("PLAYER_SWING", 2.0, 0)
now = 106
speeds[1] = 3.5
E:HandleEvent("PLAYER_EQUIPMENT_CHANGED", 16)
f, rem = E:Progress("mh", now)
check(near(f, 0) and near(rem, 3.5), "weapon swap restarts")

-- Bad payloads are ignored.
E:HandleEvent("PLAYER_SWING", nil, 0)
E:HandleEvent("PLAYER_SWING", 2.0, 9)
E:HandleEvent("PLAYER_SWING", 0, 1)

-- Presence and labels.
check(E:Has("oh") and E:Has("ranged"), "off hand and ranged detected")
speeds[2] = nil
E:HandleEvent("PLAYER_EQUIPMENT_CHANGED", 17)
check(not E:Has("oh"), "no off hand without a second weapon")
check(ns.Weapons:Label("mh") == "One-Handed Sword" and ns.Weapons:Label("ranged") == "Wand", "weapon labels")

-- Off hand keeps its bar when the sheet speed is unreadable (haste buff case).
speeds[2] = 1.5
ns.Bars:Refresh()
check(ns.Bars.bars.oh.present, "off hand bar present when dual wielding")
speeds[2] = nil
E:HandleEvent("UNIT_ATTACK_SPEED", "player")
check(not ns.Bars.bars.oh.present, "off hand row dropped before it has swung")
E:HandleEvent("PLAYER_SWING", 1.2, 1)
check(ns.Bars.bars.oh.present, "off hand swing brings the bar back")
E:HandleEvent("UNIT_ATTACK_SPEED", "player")
check(ns.Bars.bars.oh.present, "off hand bar survives an unreadable speed")
f, rem = E:Progress("oh", now)
check(near(rem, 1.2), "off hand uses the duration the game sent")
issecretvalue = function(v) return v == "secret" end
speeds[2] = "secret"
E:HandleEvent("UNIT_ATTACK_SPEED", "player")
check(ns.Bars.bars.oh.present and near(select(2, E:Progress("oh", now)), 1.2), "hidden speed is left alone")
SlashCmdList.SWINGBAR("debug")
E:HandleEvent("PLAYER_SWING", 1.2, 1)
SlashCmdList.SWINGBAR("debug")
issecretvalue, speeds[2] = nil, nil
E:HandleEvent("PLAYER_EQUIPMENT_CHANGED", 17)
check(not E:Has("oh"), "unequipping the off hand removes the bar")

-- Slash commands and every display mode run without errors.
for _, cmd in ipairs({ "unlock", "lock", "test", "test", "style clean", "style classic", "alpha 0.4",
                       "width 9999", "", "nonsense", "reset" }) do
    SlashCmdList.SWINGBAR(cmd)
    tick()
end
check(ns.db.width == 180 and ns.db.alpha == 0.7, "reset restores defaults")
SlashCmdList.SWINGBAR("width 9999")
check(ns.db.width == 400, "width clamped")
ns.db.fill, ns.db.hideIdle = "drain", false
tick()

io.write(("ok - %d checks passed\n"):format(pass))

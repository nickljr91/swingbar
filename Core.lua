-- SwingBar: subtle melee / ranged swing timers.
local ADDON, ns = ...

ns.defaults = {
    locked    = true,
    style     = "classic",   -- "classic" (cast bar look) or "clean" (flat)
    width     = 180,
    height    = 10,
    scale     = 1,
    alpha     = 0.7,         -- overall opacity
    bgAlpha   = 0.5,         -- bar background opacity
    spacing   = 8,
    fill      = "fill",      -- "fill" (grows) or "drain" (shrinks)
    showSpark = true,
    showTime  = true,
    showLabel = false,
    hideIdle  = true,        -- only show a bar while its timer runs
    point     = { "CENTER", "CENTER", 0, -180 },
    bars = {
        mh     = { enabled = true, color = { 1.0, 0.7, 0.0 } },
        oh     = { enabled = true, color = { 0.9, 0.45, 0.1 } },
        ranged = { enabled = true, color = { 0.45, 0.8, 0.35 } },
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.CopyDefaults = CopyDefaults

local function Print(msg)
    print("|cffffb400SwingBar|r: " .. msg)
end
ns.Print = Print

function ns:ResetSettings()
    for k in pairs(self.db) do self.db[k] = nil end
    CopyDefaults(self.defaults, self.db)
    self.Bars:ApplyPosition()
    self.Bars:Refresh()
    if self.Options then self.Options:Sync() end
end

-- Slash commands --------------------------------------------------------------
local numeric = {
    alpha  = { "alpha",   0.1, 1 },
    bg     = { "bgAlpha", 0,   1 },
    scale  = { "scale",   0.5, 2.5 },
    width  = { "width",   60,  400 },
    height = { "height",  4,   30 },
    gap    = { "spacing", 0,   30 },
}

local function Help()
    Print("commands (/swingbar or /swb):")
    print("  (no command) - open the settings panel")
    print("  unlock | lock - drag the bars / lock them in place")
    print("  test - toggle looping test bars")
    print("  style classic|clean - bar look")
    print("  alpha 0.1-1, bg 0-1, scale 0.5-2.5, width 60-400, height 4-30, gap 0-30")
    print("  reset - restore default settings")
    print("  debug - print swing events to chat (for bug reports)")
end

local function Slash(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local db, Bars = ns.db, ns.Bars
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Open()
        return
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        Print(db.locked and "locked." or "unlocked - drag the bars, then /swingbar lock.")
    elseif cmd == "debug" then
        ns.Engine.debug = not ns.Engine.debug
        Print(ns.Engine.debug and "debug on - swing and attack speed events print to chat." or "debug off.")
        return
    elseif cmd == "test" then
        Bars.testing = not Bars.testing
        Print(Bars.testing and "test mode on." or "test mode off.")
    elseif cmd == "style" and (arg == "classic" or arg == "clean") then
        db.style = arg
    elseif cmd == "reset" then
        ns:ResetSettings()
        Print("settings reset.")
        return
    elseif numeric[cmd] and tonumber(arg) then
        local key, lo, hi = unpack(numeric[cmd])
        db[key] = math.min(hi, math.max(lo, tonumber(arg)))
    else
        Help()
        return
    end
    Bars:Refresh()
    ns.Options:Sync()
end

-- Startup ---------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    SwingBarDB = CopyDefaults(ns.defaults, SwingBarDB or {})
    ns.db = SwingBarDB
    ns.Bars:Init()
    ns.Engine:Init()
    ns.Options:Init()
    SLASH_SWINGBAR1, SLASH_SWINGBAR2 = "/swingbar", "/swb"
    SlashCmdList.SWINGBAR = Slash
end)

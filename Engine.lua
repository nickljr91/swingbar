-- Swing detection for WoW Forever.
-- The client blocks combat-log reading for addons, and instead fires
-- PLAYER_SWING(swingDuration, swingType) every time an auto attack starts its
-- cooldown. swingType: 0 = main hand, 1 = off hand, 2 = ranged (bow, gun,
-- crossbow, thrown, wand).
local _, ns = ...

local E = { timers = { mh = {}, oh = {}, ranged = {} }, seen = {}, linger = 0.4 }
ns.Engine = E

local SwingType = (Enum and Enum.PlayerSwingType) or { MainHand = 0, OffHand = 1, Ranged = 2 }
local KEY_BY_TYPE = { [SwingType.MainHand] = "mh", [SwingType.OffHand] = "oh", [SwingType.Ranged] = "ranged" }
local SLOT_KEYS = { [16] = "mh", [17] = "oh", [18] = "ranged" }

-- Some stats can be hidden from addons ("secret values"); never do maths on those.
local function Usable(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

-- Current attack speed of a hand from the character sheet, or nil.
function E:Speed(key)
    local mh, oh, ranged = UnitAttackSpeed("player")
    local v = Usable((key == "mh" and mh) or (key == "oh" and oh) or (key == "ranged" and ranged) or nil)
    if v and v > 0 then return v end
    return nil
end

-- Whether the character can swing with this hand. The character sheet is not
-- always readable (the off-hand speed can come back hidden or missing while
-- buffs change), so a hand that has actually swung counts too.
function E:Has(key)
    return key == "mh" or self.seen[key] or self:Speed(key) ~= nil
end

local function Describe(v)
    if v == nil then return "nil" end
    if issecretvalue and issecretvalue(v) then return "hidden" end
    return type(v) == "number" and ("%.3f"):format(v) or tostring(v)
end

function E:Debug(event, a1, a2)
    if not self.debug then return end
    local mh, oh, ranged = UnitAttackSpeed("player")
    ns.Print(("%s(%s, %s) sheet mh=%s oh=%s ranged=%s"):format(
        event, Describe(a1), Describe(a2), Describe(mh), Describe(oh), Describe(ranged)))
end

-- Timers ----------------------------------------------------------------------
function E:Start(key, duration, now)
    if not duration or duration <= 0 then return end
    local t = self.timers[key]
    t.start, t.duration, t.active = now or GetTime(), duration, true
    t.speed = self:Speed(key) -- sheet speed at swing start, used by Rescale
end

function E:Stop(key)
    self.timers[key].active = false
end

-- Returns progress (0..1), seconds remaining and seconds past the end, or nil
-- when the timer is not running. A finished timer lingers briefly for the fade.
function E:Progress(key, now)
    local t = self.timers[key]
    if not t.active then return nil end
    local elapsed = now - t.start
    if elapsed >= t.duration then
        if elapsed - t.duration > self.linger then
            t.active = false
            return nil
        end
        return 1, 0, elapsed - t.duration
    end
    return elapsed / t.duration, t.duration - elapsed, 0
end

-- Attack speed changed mid-swing (haste gained or lost): scale the running
-- swing by the same ratio, keeping the fraction already done.
function E:Rescale(key)
    local t = self.timers[key]
    local speed = self:Speed(key)
    if not t.active or not speed or not t.speed or speed == t.speed then return end
    local now = GetTime()
    local frac = (now - t.start) / t.duration
    if frac >= 1 then return end
    t.duration = t.duration * speed / t.speed
    t.speed = speed
    t.start = now - frac * t.duration
end

-- A weapon was swapped: a running swing starts over at the new weapon's speed.
function E:WeaponChanged(key)
    local t = self.timers[key]
    if t.active then
        local speed = self:Speed(key)
        if speed then self:Start(key, speed) else self:Stop(key) end
    end
end

-- Events ----------------------------------------------------------------------
function E:HandleEvent(event, a1, a2)
    if event == "PLAYER_SWING" then
        local duration, key = Usable(a1), KEY_BY_TYPE[Usable(a2) or -1]
        self:Debug(event, a1, a2)
        if duration and key then
            local isNew = not self:Has(key)
            self.seen[key] = true
            self:Start(key, duration)
            if isNew then ns.Bars:Refresh() end
        end
    elseif event == "UNIT_ATTACK_SPEED" or event == "UNIT_RANGEDDAMAGE" then
        self:Debug(event)
        self:Rescale("mh")
        self:Rescale("oh")
        self:Rescale("ranged")
        ns.Bars:Refresh()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local key = SLOT_KEYS[a1]
        if key then
            self.seen[key] = nil -- the new item may not be a weapon
            self:WeaponChanged(key)
            ns.Bars:Refresh()
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_INVENTORY_CHANGED" then
        ns.Bars:Refresh()
    end
end

function E:Init()
    local f = CreateFrame("Frame")
    self.frame = f
    f:RegisterEvent("PLAYER_SWING")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")
    f:RegisterUnitEvent("UNIT_RANGEDDAMAGE", "player")
    f:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    f:SetScript("OnEvent", function(_, event, ...) E:HandleEvent(event, ...) end)
end

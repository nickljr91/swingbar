-- Weapon types (item class 2 = Weapon; index = item subclass ID).
local _, ns = ...

local W = {}
ns.Weapons = W

W.SLOT_MAINHAND, W.SLOT_OFFHAND, W.SLOT_RANGED = 16, 17, 18
W.CLASS_WEAPON = 2

-- kind: "melee" or "ranged". hands: 1 or 2 (two-handers can never dual wield).
W.types = {
    [0]  = { name = "One-Handed Axe",   kind = "melee",  hands = 1 },
    [1]  = { name = "Two-Handed Axe",   kind = "melee",  hands = 2 },
    [2]  = { name = "Bow",              kind = "ranged", hands = 2 },
    [3]  = { name = "Gun",              kind = "ranged", hands = 2 },
    [4]  = { name = "One-Handed Mace",  kind = "melee",  hands = 1 },
    [5]  = { name = "Two-Handed Mace",  kind = "melee",  hands = 2 },
    [6]  = { name = "Polearm",          kind = "melee",  hands = 2 },
    [7]  = { name = "One-Handed Sword", kind = "melee",  hands = 1 },
    [8]  = { name = "Two-Handed Sword", kind = "melee",  hands = 2 },
    [10] = { name = "Staff",            kind = "melee",  hands = 2 },
    [13] = { name = "Fist Weapon",      kind = "melee",  hands = 1 },
    [14] = { name = "Miscellaneous",    kind = "melee",  hands = 1 },
    [15] = { name = "Dagger",           kind = "melee",  hands = 1 },
    [16] = { name = "Thrown",           kind = "ranged", hands = 1 },
    [18] = { name = "Crossbow",         kind = "ranged", hands = 2 },
    [19] = { name = "Wand",             kind = "ranged", hands = 1 },
    [20] = { name = "Fishing Pole",     kind = "melee",  hands = 2 },
}

-- Returns the weapon type entry for an inventory slot, or nil if the slot does
-- not hold a weapon (empty, shield, held-in-off-hand item ...).
function W:InSlot(slot)
    local item = GetInventoryItemID("player", slot)
    if not item then return nil end
    local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, _, _, classID, subclassID = getInfo(item)
    if classID ~= self.CLASS_WEAPON then return nil end
    return self.types[subclassID] or { name = "Weapon", kind = "melee", hands = 1 }
end

-- Short text for a bar: weapon type if known, otherwise a generic name.
function W:Label(key)
    local slot = (key == "mh" and self.SLOT_MAINHAND) or (key == "oh" and self.SLOT_OFFHAND) or self.SLOT_RANGED
    local t = self:InSlot(slot)
    if t then return t.name end
    return (key == "mh" and "Main Hand") or (key == "oh" and "Off Hand") or "Ranged"
end

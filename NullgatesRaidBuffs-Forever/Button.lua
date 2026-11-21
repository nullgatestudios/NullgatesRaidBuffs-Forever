-- Nullgate's Raid Buffs: your buff button. A secure spell button aimed at the next player who needs
-- your class's buff (or the group version when enough of a group needs it). Right-click chooses which
-- of your buffs it casts. Its spell and target can only change out of combat.
local _, ns = ...

local L = ns.L
local Button = {}
ns.Button = Button

local SIZE = 40
local button, menu

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return GetSpellTexture and GetSpellTexture(spellID) or nil
end

function Button.Family()
    local _, class = UnitClass("player")
    local mine = ns.Buffs.Mine(class)
    for _, family in ipairs(mine) do
        if family.key == ns.db.family then return family, mine end
    end
    return mine[1], mine
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local family = Button.Family()
    GameTooltip:AddLine(family and ns.Scan.FamilyNames(family)[1] or L["Buff"], 1, 0.82, 0)
    if self.plan then
        local text = self.plan.group and string.format(L["Next: %s's group (%d need it)."], UnitName(self.plan.unit) or "?", self.plan.count)
            or string.format(L["Next: %s."], UnitName(self.plan.unit) or "?")
        GameTooltip:AddLine(text, 1, 1, 1, true)
    else
        GameTooltip:AddLine(L["Everyone in range has it."], 0.4, 1, 0.4, true)
    end
    local _, mine = Button.Family()
    if #mine > 1 then GameTooltip:AddLine(L["Right-click: choose the buff."], 0.6, 0.6, 0.6) end
    if self.stale then GameTooltip:AddLine(L["In combat: updates when combat ends."], 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

local function ShowMenu()
    local _, mine = Button.Family()
    if #mine < 2 then return end
    if not menu then
        menu = CreateFrame("Frame", "NullgatesRaidBuffsMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("DIALOG")
        menu:SetToplevel(true)
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        if menu.SetBackdrop then
            menu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
            menu:SetBackdropColor(0.05, 0.06, 0.08, 0.95)
        end
        menu.entries = {}
        if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesRaidBuffsMenu") end
    end
    for i, family in ipairs(mine) do
        local row = menu.entries[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetSize(200, 20)
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -8 - (i - 1) * 20)
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(row)
            hl:SetColorTexture(1, 1, 1, 0.15)
            row:SetScript("OnClick", function(self)
                ns.db.family = self.key
                menu:Hide()
                Button.Update()
            end)
            menu.entries[i] = row
        end
        row.key = family.key
        row.text:SetText((family.key == ns.db.family and "|cffffd100> |r" or "   ") .. tostring(ns.Scan.FamilyNames(family)[1]))
        row:Show()
    end
    for i = #mine + 1, #menu.entries do menu.entries[i]:Hide() end
    menu:SetSize(216, 16 + #mine * 20)
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 4)
    menu:Show()
end

function Button.Create()
    if button then return end
    button = CreateFrame("Button", "NullgatesRaidBuffsButton", UIParent, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self) if not ns.db.locked and not InCombatLockdown() then self:StartMoving() end end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.buttonPoint = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button.staleMark = button:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    button.staleMark:SetPoint("TOPLEFT", 2, -2)
    button.staleMark:SetText("*")
    button.staleMark:Hide()
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.15)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:HookScript("OnClick", function(_, mouse, down) if mouse == "RightButton" and not down then ShowMenu() end end)
    Button.Position()
    Button.Update()
end

function Button.Position()
    if not button then return end
    ns.WhenSafe("buttonPosition", function()
        button:ClearAllPoints()
        local p = ns.db.buttonPoint
        if p and p.point then button:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
        else button:SetPoint("CENTER", UIParent, "CENTER", 0, -260) end
        button:SetScale(ns.db.scale or 1)
        local family = Button.Family()
        button:SetShown(ns.db.showButton and family ~= nil)
    end)
end

-- The plan for your buff right now (members with their state for your family).
function Button.Plan(family)
    if not family then return nil end
    local now, members = GetTime(), {}
    for _, m in ipairs(ns.Scan.Members()) do
        local remaining, duration = ns.Scan.Find(ns.Scan.Auras(m.unit, now), ns.Scan.FamilyNames(family))
        members[#members + 1] = { unit = m.unit, group = m.group, level = m.level, reachable = m.reachable,
                                  state = ns.Buffs.Cell(remaining, duration) }
    end
    return ns.Buffs.Next(family, members, ns.Scan.ItemCount(family.reagent), ns.db.groupAt)
end

function Button.Update()
    if not button then return end
    local applied = ns.WhenSafe("buffButton", function()
        local family = Button.Family()
        local plan = Button.Plan(family)
        button.plan = plan
        button:SetAttribute("type1", plan and "spell" or nil)
        button:SetAttribute("spell1", plan and plan.spell or nil)
        button:SetAttribute("unit1", plan and plan.unit or nil)
        button.icon:SetTexture(plan and SpellIcon(plan.spell) or (family and SpellIcon(family.single[1][1])) or nil)
        button.icon:SetDesaturated(plan == nil)
        button.count:SetText(plan and plan.count > 1 and plan.count or "")
        button.stale = false
        button.staleMark:Hide()
    end)
    if not applied then
        button.stale = true
        button.staleMark:Show()
    end
end

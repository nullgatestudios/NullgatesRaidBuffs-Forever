-- Nullgate's Raid Buffs: the buff grid. Players by group are rows, buffs are columns; each cell is
-- green (up), yellow (running low), red (missing) or grey (out of range, so it can't be checked).
local _, ns = ...

local L = ns.L
local Grid = {}
ns.Grid = Grid

local ROW, CELL, NAME_W, HEADER = 14, 18, 110, 44
local COLORS = { ok = { 0.2, 0.8, 0.2 }, low = { 0.95, 0.8, 0.1 }, missing = { 0.85, 0.15, 0.15 }, far = { 0.35, 0.35, 0.35 } }
local frame
local rows, headers = {}, {}

-- The grid's contents: { columns = { { key, label, icon } }, rows = { { member, cells = { [key] = state } } } }.
function Grid.Compute(missingOnly)
    local now = GetTime()
    local members = ns.Scan.Members()
    local classes = {}
    for _, m in ipairs(members) do if m.class then classes[m.class] = true end end
    local columns = {}
    for _, family in ipairs(ns.Buffs.Columns(classes)) do
        columns[#columns + 1] = { key = family.key, family = family, label = ns.Scan.FamilyNames(family)[1],
                                  icon = family.single[1][1] }
    end
    if classes.PALADIN then columns[#columns + 1] = { key = "blessing", label = L["Blessing"], icon = ns.BLESSING_SPELLS[1] } end
    if ns.db.consumables then
        columns[#columns + 1] = { key = "flask", label = L["Flask"], icon = ns.FLASK_SPELLS[1] }
        columns[#columns + 1] = { key = "food", label = L["Well Fed"], icon = ns.WELL_FED_SPELL }
    end
    local out = {}
    for _, m in ipairs(members) do
        local auras = ns.Scan.Auras(m.unit, now)
        local cells, anyMissing = {}, false
        for _, col in ipairs(columns) do
            local remaining, duration
            if col.family then remaining, duration = ns.Scan.Find(auras, ns.Scan.FamilyNames(col.family))
            elseif col.key == "blessing" then remaining, duration = ns.Scan.HasBlessing(auras)
            elseif col.key == "flask" then remaining, duration = ns.Scan.HasFlask(auras)
            else remaining, duration = ns.Scan.HasWellFed(auras) end
            local state = ns.Buffs.Cell(remaining, duration)
            if state ~= "ok" and not m.reachable then state = "far" end
            cells[col.key] = state
            if state == "missing" or state == "low" then anyMissing = true end
        end
        if not missingOnly or anyMissing then out[#out + 1] = { member = m, cells = cells } end
    end
    return { columns = columns, rows = out, members = members }
end

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return GetSpellTexture and GetSpellTexture(spellID) or nil
end

local function Build()
    frame = CreateFrame("Frame", "NullgatesRaidBuffsGrid", UIParent, "BasicFrameTemplateWithInset")
    frame:SetFrameStrata("DIALOG") -- above unit frames, nameplates and bags
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.gridPoint = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    local p = ns.db.gridPoint
    if p and p.point then frame:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
    else frame:SetPoint("CENTER", UIParent, "CENTER", 260, 60) end
    if type(frame.SetTitle) == "function" then frame:SetTitle(L["Raid Buffs"])
    elseif type(frame.TitleText) == "table" then frame.TitleText:SetText(L["Raid Buffs"]) end
    if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesRaidBuffsGrid") end
    frame.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.empty:SetPoint("TOP", frame, "TOP", 0, -HEADER - 4)
    local report = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    report:SetSize(90, 20)
    report:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
    report:SetText(L["Report"])
    report:SetScript("OnClick", function() ns.Report() end)
    frame.report = report
    frame:SetScript("OnHide", function() frame.missingOnly = false end)
end

local function Header(i)
    local h = headers[i]
    if not h then
        h = CreateFrame("Frame", nil, frame)
        h:SetSize(CELL, CELL)
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetAllPoints(h)
        h:EnableMouse(true)
        h:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.label or "")
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        headers[i] = h
    end
    return h
end

local function Row(i)
    local r = rows[i]
    if not r then
        r = CreateFrame("Frame", nil, frame)
        r:SetHeight(ROW)
        r.name = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.name:SetWidth(NAME_W - 4)
        r.name:SetJustifyH("LEFT")
        r.cells = {}
        rows[i] = r
    end
    return r
end

function Grid.Draw()
    if not (frame and frame:IsShown()) then return end
    local data = Grid.Compute(frame.missingOnly)
    for i, col in ipairs(data.columns) do
        local h = Header(i)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + NAME_W + (i - 1) * (CELL + 2), -28)
        h.icon:SetTexture(SpellIcon(col.icon))
        h.label = col.label
        h:Show()
    end
    for i = #data.columns + 1, #headers do headers[i]:Hide() end
    for i, row in ipairs(data.rows) do
        local r = Row(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER - (i - 1) * ROW)
        r:SetWidth(NAME_W + #data.columns * (CELL + 2))
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.member.class]
        r.name:SetText((IsInRaid() and (row.member.group .. " ") or "") .. (row.member.name or "?"))
        if color then r.name:SetTextColor(color.r, color.g, color.b) end
        for j, col in ipairs(data.columns) do
            local cell = r.cells[j]
            if not cell then
                cell = r:CreateTexture(nil, "ARTWORK")
                cell:SetSize(CELL - 4, ROW - 4)
                r.cells[j] = cell
            end
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", r, "LEFT", NAME_W + (j - 1) * (CELL + 2) + 2, 0)
            local c = COLORS[row.cells[col.key]]
            cell:SetColorTexture(c[1], c[2], c[3], 0.9)
            cell:Show()
        end
        for j = #data.columns + 1, #r.cells do r.cells[j]:Hide() end
        r:Show()
    end
    for i = #data.rows + 1, #rows do rows[i]:Hide() end
    frame.empty:SetText(#data.rows == 0 and (frame.missingOnly and L["Everyone has every buff."] or L["Not in a group."]) or "")
    local width = math.max(220, 24 + NAME_W + #data.columns * (CELL + 2))
    frame:SetSize(width, HEADER + math.max(1, #data.rows) * ROW + 36)
end

function Grid.Show(missingOnly)
    if not frame then Build() end
    frame.missingOnly = missingOnly and true or false
    frame:Show()
    Grid.Draw()
end

function Grid.Hide()
    if frame then frame:Hide() end
end

function Grid.Toggle()
    if frame and frame:IsShown() then frame:Hide() else Grid.Show(false) end
end

function Grid.IsShown()
    return frame ~= nil and frame:IsShown()
end

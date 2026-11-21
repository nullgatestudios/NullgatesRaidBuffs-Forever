-- Nullgate's Raid Buffs: saved data, events (throttled refresh), ready checks, the report, self-buff
-- reminders and slash commands.
local addonName, ns = ...

local L = ns.L

ns.DEFAULTS = {
    locked = false,
    scale = 1,
    showButton = true,
    family = nil,         -- which of your buffs the button casts (nil = the first one you know)
    groupAt = 3,          -- use the group spell when this many in one group need it
    readyCheck = true,    -- show the grid (missing only) on a ready check
    consumables = false,  -- flask and Well Fed columns
    selfReminder = true,
    language = "auto",
}

local function Merge(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            Merge(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.Print(text)
    print("|cff00c0ffRaid Buffs:|r " .. tostring(text))
end

local pending = {}
function ns.WhenSafe(key, fn)
    if InCombatLockdown() then
        pending[key] = fn
        return false
    end
    pending[key] = nil
    fn()
    return true
end

-- --- Report ----------------------------------------------------------------------------
local lastReport = -math.huge
ns.REPORT_GAP = 30

-- The report lines: "Missing <buff>: name, name" for each column someone is missing.
function ns.ReportLines(data)
    local lines = {}
    for _, col in ipairs(data.columns) do
        local names = {}
        for _, row in ipairs(data.rows) do
            local state = row.cells[col.key]
            if state == "missing" or state == "far" then names[#names + 1] = row.member.name end
        end
        if #names > 0 then lines[#lines + 1] = string.format(L["Missing %s: %s"], col.label or col.key, table.concat(names, ", ")) end
    end
    return lines
end

function ns.Report()
    if GetTime() - lastReport < ns.REPORT_GAP then
        ns.Print(L["Wait a few seconds before reporting again."])
        return
    end
    local channel = IsInRaid() and "RAID" or (GetNumSubgroupMembers() > 0 and "PARTY") or nil
    local lines = ns.ReportLines(ns.Grid.Compute(false))
    if #lines == 0 then
        ns.Print(L["Everyone has every buff."])
        return
    end
    lastReport = GetTime()
    for _, line in ipairs(lines) do
        if channel then SendChatMessage(line, channel) else ns.Print(line) end
    end
end

-- --- Self buffs --------------------------------------------------------------------------
local selfWarned = false
function ns.CheckSelf()
    local _, class = UnitClass("player")
    local ids = ns.SELF_BUFFS[class]
    if not ns.db.selfReminder or not ids or InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
    local names, known = {}, false
    for _, id in ipairs(ids) do
        names[#names + 1] = ns.Scan.SpellName(id)
        if ns.Buffs.IsKnown(id) then known = true end
    end
    if not known then return end
    local has = ns.Scan.Find(ns.Scan.Auras("player", GetTime()), names) ~= nil
    if not has and not selfWarned then ns.Print(string.format(L["You don't have %s up."], table.concat(names, " / "))) end
    selfWarned = not has
end

-- --- Events (refresh at most every half second) ------------------------------------------
local queued = false
function ns.Refresh()
    if queued then return end
    queued = true
    C_Timer.After(0.5, function()
        queued = false
        ns.Grid.Draw()
        ns.Button.Update()
        ns.CheckSelf()
    end)
end

BINDING_HEADER_NULLGATESRAIDBUFFS = "Nullgate's Raid Buffs"

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            if type(NullgatesRaidBuffsDB) ~= "table" then NullgatesRaidBuffsDB = {} end
            Merge(NullgatesRaidBuffsDB, ns.DEFAULTS)
            ns.db = NullgatesRaidBuffsDB
            ns.SetLanguage(ns.db.language)
            _G["BINDING_NAME_CLICK NullgatesRaidBuffsButton:LeftButton"] = L["Cast your buff on the next player who needs it"]
        end
        if arg1 == addonName or arg1 == "NullgatesAddonConfig-Forever" then ns.Options.RegisterHub() end
    elseif event == "PLAYER_LOGIN" then
        ns.Button.Create()
        ns.Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        for key, fn in pairs(pending) do
            pending[key] = nil
            fn()
        end
        ns.Refresh()
    elseif event == "READY_CHECK" then
        if ns.db.readyCheck then ns.Grid.Show(true) end
    elseif event == "READY_CHECK_FINISHED" then
        if ns.db.readyCheck then C_Timer.After(5, function() if ns.Grid.IsShown() then ns.Grid.Hide() end end) end
    elseif event == "UNIT_AURA" then
        if arg1 == "player" or (arg1 and (arg1:match("^party%d") or arg1:match("^raid%d"))) then ns.Refresh() end
    elseif event == "SPELLS_CHANGED" then
        ns.Button.Position()
        ns.Refresh()
    else -- roster changes
        ns.Refresh()
    end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "UNIT_AURA",
    "READY_CHECK", "READY_CHECK_FINISHED", "SPELLS_CHANGED", "UNIT_CONNECTION", "BAG_UPDATE_DELAYED" }) do
    events:RegisterEvent(event)
end

local function Help()
    ns.Print(L["commands:"])
    print("  /nbuffs - " .. L["show or hide the buff grid"])
    print("  /nbuffs report - " .. L["post missing buffs to group chat"])
    print("  /nbuffs config - " .. L["open the settings"])
    print("  /nbuffs check - " .. L["test what the addon needs in this client (results are saved)"])
end

SLASH_NULLGATESRAIDBUFFS1 = "/nbuffs"
SLASH_NULLGATESRAIDBUFFS2 = "/raidbuffs"
SlashCmdList["NULLGATESRAIDBUFFS"] = function(msg)
    local command = string.lower((msg or ""):match("^%s*(%S*)") or "")
    if command == "" then
        ns.Grid.Toggle()
    elseif command == "report" then
        ns.Report()
    elseif command == "config" or command == "options" then
        ns.Options.Open()
    elseif command == "check" then
        ns.Check.Run()
    elseif command == "lock" or command == "unlock" then
        ns.db.locked = command == "lock"
    elseif command == "reset" then
        ns.db.buttonPoint, ns.db.gridPoint = nil, nil
        ns.Button.Position()
    else
        Help()
    end
end

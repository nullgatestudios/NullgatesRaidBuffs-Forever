-- Nullgate's Raid Buffs: smoke test of the whole addon with stand-in game API.
-- Loads the files in .toc order, logs in as a level 60 priest in a party with a warrior and a mage,
-- and drives the grid, the buff button, combat, a ready check, the report, consumables, the self
-- buff reminder, settings and /nbuffs check.
-- Run from the repository root:  lua tests/smoke.lua

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/smoke.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local repo = scriptDir:match("^(.*)[/\\][^/\\]*$") or "."
local folder = "NullgatesRaidBuffs-Forever"
local root = repo .. "/" .. folder .. "/"

local checks, failures = 0, 0
local function OK(cond, name)
    checks = checks + 1
    if not cond then failures = failures + 1; io.write("FAIL " .. name .. "\n") end
end

-- --- Stand-in game API ----------------------------------------------------------
local frames, printed, said = {}, {}, {}
local function NewFrame(kind, name, _, template)
    local f = { kind = kind, name = name, template = template, scripts = {}, attributes = {}, events = {}, shown = false }
    setmetatable(f, { __index = function(_, key) if type(key) == "string" and key:match("^%u") then return function() return nil end end end })
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:HookScript(k, fn) local old = self.scripts[k]; self.scripts[k] = function(...) if old then old(...) end fn(...) end end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:SetColorTexture(r, g, b) self.color = { r, g, b } end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:CreateTexture() return NewFrame("Texture") end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = NewFrame
SlashCmdList = {}
UIParent = NewFrame("Frame", "UIParent")
GameTooltip = NewFrame("GameTooltip", "GameTooltip")
UISpecialFrames = {}
RAID_CLASS_COLORS = {}
print = function(text) printed[#printed + 1] = tostring(text) end
function SendChatMessage(text, channel) said[#said + 1] = channel .. ": " .. text end
local function Printed(fragment)
    for _, line in ipairs(printed) do if line:find(fragment, 1, true) then return true end end
    return false
end

local inCombat, now = false, 100
local units = {
    player = { name = "Me", class = "PRIEST", level = 60 },
    party1 = { name = "Tank", class = "WARRIOR", level = 60 },
    party2 = { name = "Mage", class = "MAGE", level = 60 },
}
function UnitExists(u) return units[u] ~= nil end
function UnitClass(u) return units[u].class, units[u].class end
function UnitName(u) return units[u] and units[u].name end
function UnitLevel(u) return units[u].level end
function UnitIsUnit(a, b) return a == b end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
local far = {}
function UnitInRange(u) return not far[u], true end
function IsInRaid() return false end
function GetNumSubgroupMembers() return 2 end
function GetNumGroupMembers() return 3 end
function InCombatLockdown() return inCombat end
function GetTime() return now end
function GetBuildInfo() return "1.60.1", "70532", "Nov 2026", 16001 end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

local data = {}
assert(loadfile(root .. "Data/Buffs.lua"))(folder, data)
local names = {}
for _, f in ipairs(data.BUFF_FAMILIES) do
    local single = ({ fortitude = "Power Word: Fortitude", intellect = "Arcane Intellect", wild = "Mark of the Wild",
        spirit = "Divine Spirit", shadow = "Shadow Protection", thorns = "Thorns" })[f.key]
    local group = ({ fortitude = "Prayer of Fortitude", intellect = "Arcane Brilliance", wild = "Gift of the Wild",
        spirit = "Prayer of Spirit", shadow = "Prayer of Shadow Protection" })[f.key]
    for _, r in ipairs(f.single) do names[r[1]] = single end
    for _, r in ipairs(f.group) do names[r[1]] = group end
end
for _, id in ipairs(data.BLESSING_SPELLS) do names[id] = "Blessing " .. id end
for _, id in ipairs(data.FLASK_SPELLS) do names[id] = "Flask " .. id end
names[data.WELL_FED_SPELL] = "Well Fed"
names[588] = "Inner Fire"
C_Spell = { GetSpellName = function(id) return names[id] end, GetSpellTexture = function(id) return "tex" .. tostring(id) end }
local known = { [588] = true }
for _, r in ipairs(data.BUFF_FAMILIES[1].single) do known[r[1]] = true end -- every Fortitude rank
C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
local candles = 0
C_Item = { GetItemCount = function(id) return id == 17028 and candles or 0 end }
local auras = { player = {}, party1 = {}, party2 = {} } -- [unit] = { { name, duration, expires } }
C_UnitAuras = { GetAuraDataByIndex = function(u, i)
    local a = auras[u] and auras[u][i]
    return a and { name = a[1], duration = a[2], expirationTime = a[3] } or nil
end }

-- --- Load the files in .toc order -----------------------------------------------
local ns = {}
local toc = assert(io.open(root .. folder .. ".toc", "r")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        assert(loadfile(root .. line:gsub("\\", "/")))(folder, ns)
    end
end
local core
for _, f in ipairs(frames) do if f.events.READY_CHECK then core = f end end
local function Fire(event, ...) core.scripts.OnEvent(core, event, ...) end
Fire("ADDON_LOADED", folder)
local db = NullgatesRaidBuffsDB
OK(db.groupAt == 3 and db.readyCheck and not db.consumables, "saved data gets its defaults")
OK(SLASH_NULLGATESRAIDBUFFS1 == "/nbuffs" and SLASH_NULLGATESRAIDBUFFS2 == "/raidbuffs", "slash commands /nbuffs and /raidbuffs")

-- --- Login: nobody has Fortitude --------------------------------------------------------
Fire("PLAYER_LOGIN")
Flush()
local button = NullgatesRaidBuffsButton
OK(button and button.template == "SecureActionButtonTemplate" and button.shown, "the buff button exists and is shown for a priest")
OK(button.attributes.type1 == "spell" and button.attributes.spell1 == 10938 and button.attributes.unit1 == "party2",
    "it casts Fortitude rank 6 on the first player who needs it (sorted by name: the mage)")
OK(Printed("You don't have Inner Fire up."), "self buff reminder: no Inner Fire")

-- --- The grid -----------------------------------------------------------------------------
SlashCmdList.NULLGATESRAIDBUFFS("")
local grid = ns.Grid.Compute(false)
local keys = {}
for _, c in ipairs(grid.columns) do keys[#keys + 1] = c.key end
OK(table.concat(keys, ",") == "fortitude,intellect,spirit,shadow", "columns for the priest's and the mage's buffs")
OK(#grid.rows == 3 and grid.rows[1].cells.fortitude == "missing", "three rows, Fortitude missing")
OK(NullgatesRaidBuffsGrid and NullgatesRaidBuffsGrid.shown, "/nbuffs shows the grid")

-- --- Buffs land ----------------------------------------------------------------------------
auras.player = { { "Power Word: Fortitude", 3600, now + 3500 }, { "Inner Fire", 600, now + 500 } }
auras.party1 = { { "Power Word: Fortitude", 3600, now + 200 } }
far.party2 = true
Fire("UNIT_AURA", "player")
Flush()
grid = ns.Grid.Compute(false)
local byName = {}
for _, r in ipairs(grid.rows) do byName[r.member.name] = r.cells end
OK(byName.Me.fortitude == "ok", "your Fortitude: green")
OK(byName.Tank.fortitude == "low", "under 5 minutes left of an hour: yellow")
OK(byName.Mage.fortitude == "far", "out of range: grey, not red")
OK(button.attributes.unit1 == "party1", "the button moves on to the tank (low), skipping the mage out of range")

-- --- Combat --------------------------------------------------------------------------------
inCombat = true
auras.party1 = { { "Power Word: Fortitude", 3600, now + 3500 } }
far.party2 = nil
Fire("UNIT_AURA", "party1")
Flush()
OK(button.attributes.unit1 == "party1" and button.stale, "in combat the target doesn't change and the button is marked")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Flush()
OK(button.attributes.unit1 == "party2" and not button.stale, "after combat it moves on to the mage")

-- --- Group spell ---------------------------------------------------------------------------
auras = { player = {}, party1 = {}, party2 = {} }
for _, r in ipairs(data.BUFF_FAMILIES[1].group) do known[r[1]] = true end
candles = 5
ns.Button.Update()
OK(button.attributes.spell1 == data.BUFF_FAMILIES[1].group[2][1] and button.count.text == 3, "three need it and you have candles: Prayer of Fortitude")

-- --- Ready check and report ------------------------------------------------------------------
ns.Grid.Hide()
Fire("READY_CHECK")
OK(NullgatesRaidBuffsGrid.shown and NullgatesRaidBuffsGrid.missingOnly, "a ready check shows the grid, missing only")
SlashCmdList.NULLGATESRAIDBUFFS("report")
OK(said[1] and said[1]:find("^PARTY: Missing Power Word: Fortitude: ") ~= nil, "the report posts to party chat")
local count = #said
SlashCmdList.NULLGATESRAIDBUFFS("report")
OK(#said == count and Printed("Wait a few seconds"), "a second report right away is held back")

-- --- Consumables ----------------------------------------------------------------------------
db.consumables = true
grid = ns.Grid.Compute(false)
keys = {}
for _, c in ipairs(grid.columns) do keys[#keys + 1] = c.key end
OK(table.concat(keys, ","):find("flask,food", 1, true) ~= nil, "consumable columns when turned on")

-- --- Settings and /nbuffs check --------------------------------------------------------------
SlashCmdList.NULLGATESRAIDBUFFS("config")
OK(NullgatesRaidBuffsOptions and NullgatesRaidBuffsOptions.shown, "/nbuffs config opens the settings")
SlashCmdList.NULLGATESRAIDBUFFS("check")
do -- the report window every Nullgate addon shares
    local w = NullgateReportWindow
    OK(w and w.shown and w.url == "https://nullgatestudios.com/report?addon=raid-buffs", "check opens the shared report window with this addon's link")
    OK(w and w.text and w.text:find("Addon: raid-buffs\nNullgate's Raid Buffs - Forever ", 1, true) == 1, "the report starts with the addon's slug and name")
    OK(w and w.box.text == w.text and w.link.text == w.url, "the report and the link are in the window, ready to copy")
end
local log = table.concat(db.check or {}, "\n")
OK(log:find("C_UnitAuras.GetAuraDataByIndex=yes", 1, true), "check reports which calls exist")
OK(log:find("fortitude: looks for Power Word: Fortitude / Prayer of Fortitude (3600s)", 1, true), "check names the buffs it looks for")
OK(log:find("your buff fortitude:", 1, true), "check reports your button's plan")

io.write(string.format("smoke: %d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end

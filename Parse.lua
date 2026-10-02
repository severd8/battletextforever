-- BattleText Forever: reads the game's combat log lines.
--
-- WoW: Forever doesn't let addons listen to the combat log itself. What an addon
-- does get is each finished line of the Combat Log window, as plain text:
--
--   Your Claw hit Bristleback Hunter Faust 50 Physical. (Critical)
--   Bristleback Hunter Pal's Melee hit You 12 Physical. (3 Blocked)
--   Your Melee missed Bristleback Hunter Totes. Dodge
--   You killed Bristleback Hunter Zapsu.
--
-- The other creature's name is scrambled by the game, so it's ignored here. The
-- words ("Your", "hit", "Critical", ...) come from the game's own text, so this
-- works in every language the game does.

local _, ns = ...
local Parser = {}
ns.Parser = Parser

-- The game's text, with English fallbacks (used by the offline tests, and if a
-- string is ever missing)
local FALLBACK = {
    UNIT_YOU_SOURCE = "You", UNIT_YOU_SOURCE_POSSESSIVE = "Your", UNIT_YOU_DEST = "You",
    TEXT_MODE_A_STRING_POSSESSIVE = "%s's",
    ACTION_SWING = "Melee",
    ACTION_SWING_DAMAGE = "hit", ACTION_SWING_MISSED = "missed",
    ACTION_RANGE_DAMAGE = "hit", ACTION_RANGE_MISSED = "missed",
    ACTION_SPELL_DAMAGE = "hit", ACTION_SPELL_MISSED = "missed",
    ACTION_SPELL_PERIODIC_DAMAGE = "damaged", ACTION_SPELL_PERIODIC_MISSED = "missed",
    ACTION_DAMAGE_SHIELD = "damaged", ACTION_DAMAGE_SHIELD_MISSED = "missed",
    ACTION_DAMAGE_SPLIT = "damaged", ACTION_ENVIRONMENTAL_DAMAGE = "damaged",
    ACTION_SPELL_HEAL = "healed", ACTION_SPELL_PERIODIC_HEAL = "healed",
    ACTION_SPELL_ENERGIZE = "energized", ACTION_SPELL_PERIODIC_ENERGIZE = "energized",
    ACTION_PARTY_KILL = "killed", ACTION_UNIT_DIED = "died", ACTION_UNIT_DESTROYED = "was destroyed",
    ACTION_SPELL_INTERRUPT = "interrupted", ACTION_SPELL_DISPEL = "dispelled", ACTION_SPELL_STOLEN = "stole",
    TEXT_MODE_A_STRING_RESULT_CRITICAL = "(Critical)", TEXT_MODE_A_STRING_RESULT_CRITICAL_SPELL = "(Critical)",
    TEXT_MODE_A_STRING_RESULT_GLANCING = "(Glancing)", TEXT_MODE_A_STRING_RESULT_CRUSHING = "(Crushing)",
    TEXT_MODE_A_STRING_RESULT_BLOCK = "(%s Blocked)", TEXT_MODE_A_STRING_RESULT_ABSORB = "(%s Absorbed)",
    TEXT_MODE_A_STRING_RESULT_RESIST = "(%s Resisted)", TEXT_MODE_A_STRING_RESULT_OVERKILLING = "(%s Overkill)",
    TEXT_MODE_A_STRING_RESULT_OVERHEALING = "(%s Overhealed)",
    ACTION_SWING_MISSED_MISS = "Miss", ACTION_SWING_MISSED_DODGE = "Dodge", ACTION_SWING_MISSED_PARRY = "Parry",
    ACTION_SWING_MISSED_BLOCK = "Block", ACTION_SWING_MISSED_RESIST = "Resist", ACTION_SWING_MISSED_ABSORB = "Absorb",
    ACTION_SWING_MISSED_IMMUNE = "Immune", ACTION_SWING_MISSED_EVADE = "Evade",
    ACTION_SWING_MISSED_DEFLECT = "Deflect", ACTION_SWING_MISSED_REFLECT = "Reflect",
}

-- Which kind of thing each combat log event is. Events that share a word in the
-- game's text ("hit" for a swing and for a spell) share a kind, so the word is
-- all that's needed.
local EVENTS = {
    { "SWING_DAMAGE", "damage" }, { "RANGE_DAMAGE", "damage" }, { "SPELL_DAMAGE", "damage" },
    { "SPELL_PERIODIC_DAMAGE", "damage", true }, { "DAMAGE_SHIELD", "damage" }, { "DAMAGE_SPLIT", "damage" },
    { "ENVIRONMENTAL_DAMAGE", "damage" },
    { "SWING_MISSED", "miss" }, { "RANGE_MISSED", "miss" }, { "SPELL_MISSED", "miss" },
    { "SPELL_PERIODIC_MISSED", "miss" }, { "DAMAGE_SHIELD_MISSED", "miss" },
    { "SPELL_HEAL", "heal" }, { "SPELL_PERIODIC_HEAL", "heal" },
    { "SPELL_ENERGIZE", "energize" }, { "SPELL_PERIODIC_ENERGIZE", "energize" },
    { "PARTY_KILL", "kill" }, { "UNIT_DIED", "died" }, { "UNIT_DESTROYED", "died" },
    { "SPELL_INTERRUPT", "interrupt" }, { "SPELL_DISPEL", "dispel" }, { "SPELL_STOLEN", "dispel" },
}
local MISS_TYPES = { "MISS", "DODGE", "PARRY", "BLOCK", "RESIST", "ABSORB", "IMMUNE", "EVADE", "DEFLECT", "REFLECT" }
local AMOUNT_RESULTS = { blocked = "BLOCK", absorbed = "ABSORB", resisted = "RESIST", overkill = "OVERKILLING",
    overheal = "OVERHEALING" }

local function Text(key)
    local v = _G[key]
    if type(v) == "string" and v ~= "" and not (issecretvalue and issecretvalue(v)) then return v end
    return FALLBACK[key]
end

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function Escape(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
local function NoParens(s) return Trim((s:gsub("^%s*%(", ""):gsub("%)%s*$", ""))) end
local function ToNumber(s) return tonumber((s:gsub("[^%d]", ""))) end

-- Reads the game's text once (after login, when it's all loaded)
function Parser:Init()
    self.your = Text("UNIT_YOU_SOURCE_POSSESSIVE")
    self.you = Text("UNIT_YOU_SOURCE")
    self.youDest = Text("UNIT_YOU_DEST")
    self.melee = Text("ACTION_SWING")
    -- "%s's" -> the text between an owner and what they own ("'s ")
    local poss = Text("TEXT_MODE_A_STRING_POSSESSIVE")
    self.possessive = poss:gsub("%%%d*%$?s", "") .. " "

    -- Action words, longest first so "was destroyed" wins over a shorter word
    self.words, self.byWord = {}, {}
    for _, e in ipairs(EVENTS) do
        local word = Text("ACTION_" .. e[1])
        if word then
            local w = self.byWord[word]
            if not w then
                w = { text = word, kind = e[2], periodic = e[3] or false }
                self.byWord[word] = w
                self.words[#self.words + 1] = w
            elseif not e[3] then
                w.periodic = false   -- the word is also used by something that isn't a tick
            end
        end
    end
    table.sort(self.words, function(a, b) return #a.text > #b.text end)

    self.crit = { [NoParens(Text("TEXT_MODE_A_STRING_RESULT_CRITICAL"))] = true,
        [NoParens(Text("TEXT_MODE_A_STRING_RESULT_CRITICAL_SPELL"))] = true }
    self.glancing = NoParens(Text("TEXT_MODE_A_STRING_RESULT_GLANCING"))
    self.crushing = NoParens(Text("TEXT_MODE_A_STRING_RESULT_CRUSHING"))
    -- "(%s Blocked)" -> a pattern that captures the number
    self.amountPatterns = {}
    for field, key in pairs(AMOUNT_RESULTS) do
        local fmt = NoParens(Text("TEXT_MODE_A_STRING_RESULT_" .. key))
        local pattern = Escape(fmt):gsub("%%%%%d*%%?%$?s", "([%%d%%.,%%s]-%%d)")
        self.amountPatterns[field] = "^" .. pattern .. "$"
    end
    self.missWords = {}
    for _, t in ipairs(MISS_TYPES) do
        local word = Text("ACTION_SWING_MISSED_" .. t)
        if word then self.missWords[word:lower()] = { type = t, text = word } end
    end
    self.ready = true
end

-- Colour codes, icons and links aren't part of the sentence
local function Clean(line)
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    line = line:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    line = line:gsub("|H.-|h(.-)|h", "%1")
    return Trim(line)
end

-- The action word in `text`: its position, and the word's entry.
-- atStart: the sentence has no spell, so the word comes first ("You killed ...").
function Parser:FindAction(text, atStart)
    local bestPos, bestWord
    for _, w in ipairs(self.words) do
        local pos
        if atStart then
            if text == w.text or text:sub(1, #w.text + 1) == w.text .. " " then pos = 1 end
        else
            local s = text:find(" " .. w.text .. " ", 1, true)
            if s then
                pos = s + 1
            elseif #text > #w.text and text:sub(-#w.text - 1) == " " .. w.text then
                pos = #text - #w.text + 1   -- the word ends the sentence ("... died")
            end
        end
        if pos and (not bestPos or pos < bestPos) then bestPos, bestWord = pos, w end
    end
    return bestPos, bestWord
end

-- Turns one combat log line into a table, or nil if it isn't something to show:
--   kind      "damage", "miss", "heal", "energize", "kill", "died", "interrupt", "dispel"
--   fromMe    you did it          toMe   it happened to you
--   spell     "Claw" (nil for a plain melee swing)      melee = true for a swing
--   amount    50                  unit   "Physical" (or "Rage" for energize)
--   crit, glancing, crushing, periodic
--   blocked, absorbed, resisted, overkill, overheal     (amounts)
--   missType  "DODGE"             missText "Dodge"
function Parser:Parse(line)
    if not self.ready then self:Init() end
    if type(line) ~= "string" or (issecretvalue and issecretvalue(line)) then return nil end
    line = Clean(line)
    if line == "" then return nil end

    -- Results at the end: "(Critical)", "(3 Blocked)"
    local results = {}
    while true do
        local head, group = line:match("^(.-)%s*(%b())%s*$")
        if not group then break end
        table.insert(results, 1, Trim(group:sub(2, -2)))
        line = head
    end
    -- "sentence. extra"
    local main, tail = line:match("^(.*)%.%s*(.-)%s*$")
    if not main then main, tail = line, "" end
    main = Trim(main)

    local info = {}
    local rest, noSpell = main, false
    if main:sub(1, #self.your + 1) == self.your .. " " then
        info.fromMe = true
        rest = main:sub(#self.your + 2)
    elseif main:sub(1, #self.you + 1) == self.you .. " " then
        info.fromMe, noSpell = true, true
        rest = main:sub(#self.you + 2)
    end

    local pos, word = self:FindAction(rest, noSpell)
    if not pos then return nil end
    info.kind, info.periodic = word.kind, word.periodic

    local before = Trim(rest:sub(1, pos - 1))
    local after = Trim(rest:sub(pos + #word.text))
    -- Who did it, and with what
    if not noSpell and before ~= "" then
        local spell = before
        if not info.fromMe then
            local s, e = before:find(self.possessive, 1, true)
            if s then spell = Trim(before:sub(e + 1)) else spell = nil end
        end
        if spell == self.melee then
            info.melee = true
        elseif spell and spell ~= "" then
            info.spell = spell
        end
    end
    -- Who it happened to, how much, and of what
    local dest, amount, unit = after:match("^(.-)%s*(%d[%d%.,]*)%s+(%D+)$")
    if not dest then dest, amount = after:match("^(.-)%s*(%d[%d%.,]*)$") end
    if not dest then dest = after end
    dest = Trim(dest)
    if amount then info.amount = ToNumber(amount) end
    if unit then info.unit = Trim(unit) end
    if dest == self.youDest then info.toMe = true end

    -- Results
    local extras = {}
    for _, r in ipairs(results) do extras[#extras + 1] = r end
    if tail ~= "" then extras[#extras + 1] = tail end
    for _, r in ipairs(extras) do
        local miss = self.missWords[r:lower()]
        if self.crit[r] then
            info.crit = true
        elseif r == self.glancing then
            info.glancing = true
        elseif r == self.crushing then
            info.crushing = true
        elseif miss and info.kind == "miss" then
            info.missType, info.missText = miss.type, miss.text
        else
            for field, pattern in pairs(self.amountPatterns) do
                local n = r:match(pattern)
                if n then info[field] = ToNumber(n) break end
            end
        end
    end
    return info
end

-- A second scenario for tests/run.lua, in a process of its own: logging in (or
-- /reload) in the middle of a fight. Nothing secure may be touched until the
-- fight ends.
local ADDON = "BattleTextForever"
local ns = {}
for _, file in ipairs({ "Theme.lua", "Parse.lua", "Core.lua", "Options.lua" }) do
    local f = assert(io.open(ADDON_DIR .. "/" .. file)) local src = f:read("*a") f:close()
    assert(loadstring(src, "@" .. file))(ADDON, ns)
end
local BT = ns.BT
local function fire(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end
local function assertEq(a, b, msg)
    if a ~= b then error(("ASSERT %s: got %s expected %s"):format(msg, tostring(a), tostring(b)), 2) end
end

print("STEP logging in during a fight, with the Combat Log tab showing")
-- The window is up from the moment you log in, but the game hasn't loaded its
-- filter (that takes a click), so no lines arrive yet
ClickTab(ChatFrame2Tab)
STATE.filterApplied = false
COMBAT = true
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
fire("UNIT_COMBAT", "player", "WOUND", "", 23, 1)
Advance(4)
assertEq(table.concat(BLOCKED, ", "), "", "protected frame touched in combat")
assertEq(BT.startButton, nil, "no Start button yet")
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
local start = BT.startButton
assert(start and start:IsShown(), "the Start button appears when the fight ends")
ClickButton(start)
assertEq(STATE.filterApplied, true, "and works")
assertEq(SELECTED_DOCK_FRAME, ChatFrame2, "leaving you on the tab you were on")
assertEq(start:IsShown(), false, "started")
assertEq(table.concat(VIOLATIONS, "; "), "", "rule broken")
print("RELOAD-IN-COMBAT PASSED")

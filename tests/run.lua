-- Runs the BattleText Forever test suite outside the game.
-- From the repo root:  lua5.1 tests/run.lua
-- Exits with code 1 (and prints the error) if any test fails.

ADDON_DIR = "."
local realPrint = print

dofile("tests/wowstub.lua")   -- fake WoW API (replaces print with a logger)

-- "reload-in-combat" runs the second scenario (a fresh login, mid-fight); the
-- normal run does the main one and then starts that in a process of its own
local scenario = arg and arg[1] == "reload-in-combat" and "tests/reload_in_combat.lua" or "tests/run_tests.lua"
local ok, err = xpcall(function() dofile(scenario) end, debug.traceback)

for _, line in ipairs(LOG) do
    if line:find("^STEP") or line:find("PASSED") then realPrint(line) end
end
if not ok then
    realPrint("FAILED: " .. tostring(err))
    os.exit(1)
end
if scenario == "tests/run_tests.lua" then
    io.stdout:flush()
    local lua = arg and arg[-1] or "lua5.1"
    local code = os.execute(lua .. " tests/run.lua reload-in-combat")
    if code ~= 0 and code ~= true then os.exit(1) end
end

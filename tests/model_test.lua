local N = {}; PASSED = 0
assert(loadfile(ROOT .. "/QuestBrief/Model.lua"))("QuestBrief", N)
assert(loadfile(ROOT .. "/QuestBrief/Data/Quests.lua"))("QuestBrief", N)
local M = N.Model
local function test(name, fn) fn(); PASSED = PASSED + 1; print("PASS " .. name) end
test("exact classification has 218 new IDs among 1194", function()
    local total, new = 0, 0
    for id, status in pairs(N.Data.statusById) do total = total + 1; if M.IsNew(id) then new = new + 1; assert(status == "verifiedNew") end end
    assert(total == 1194 and new == 218)
end)
test("mixed-title older IDs never inherit New", function()
    for _, id in ipairs({286, 356, 921, 928, 929, 933, 934, 935, 7383, 932, 422, 423, 99, 424}) do assert(not M.IsNew(id)) end
    for _, id in ipairs({98189, 99156, 98046, 98065, 98403, 98298}) do assert(M.IsNew(id)) end
end)
test("unknown and malformed IDs are unchanged", function()
    for _, id in ipairs({0, -1, 1.5, math.huge, "92124", {}, false, 10000000}) do assert(not M.IsNew(id)) end
    assert(not M.IsNew(nil)); assert(not M.IsNew(0 / 0))
end)
test("default profiles are independent", function()
    local a = M.Load(nil); local b = M.Load(nil); a.enabled = false; assert(b.enabled and M.defaults.enabled)
end)
test("valid user opt-out and preset survive loading", function()
    local p, ro = M.Load({version = 1, enabled = false, preset = "blue", strength = .75})
    assert(not p.enabled and p.preset == "blue" and p.strength == .75 and not ro)
end)
test("malformed saved values cannot reach rendering", function()
    local p = M.Load({enabled = "yes", preset = {}, strength = 0 / 0}); assert(p.enabled and p.preset == "blue" and p.strength == .55)
    assert(M.Load({strength = -5}).strength == .1); assert(M.Load({strength = 3}).strength == 1)
end)
test("future settings are read-only without mutation", function()
    local saved = {version = 4, custom = {"preserve"}}; local p, ro = M.Load(saved)
    assert(ro and p.version == 3 and saved.version == 4 and saved.custom[1] == "preserve")
end)
test("tint preserves native alpha and stays subtle", function()
    local p = M.Load(nil); local color = M.Tint(p, {.8, .7, .6, .4})
    assert(math.abs(color[1] - .7472) < .00001 and math.abs(color[2] - .68075) < .00001 and color[3] == .6 and color[4] == .4)
end)
test("secret quest IDs are rejected before arithmetic", function()
    issecretvalue = function(value) return value == 92124 end
    assert(not M.IsNew(92124)); issecretvalue = nil
end)
test("secret colors and metadata are rejected", function()
    local marker = {}; issecretvalue = function(value) return value == marker end
    assert(not M.Number(marker)); assert(not M.SameColor({marker,1,1,1}, {1,1,1,1})); assert(M.Load(marker).enabled)
    issecretvalue = nil
end)

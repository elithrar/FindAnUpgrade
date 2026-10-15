local N = {}; PASSED = 0
assert(loadfile(ROOT .. "/FindAnUpgrade/Model.lua"))("FindAnUpgrade", N)
assert(loadfile(ROOT .. "/FindAnUpgrade/Data/Quests.lua"))("FindAnUpgrade", N)
local M = N.Model
local function test(name, fn) fn(); PASSED = PASSED + 1; print("PASS " .. name) end
test("exact classification matches the generated snapshot", function()
    local total, new = 0, 0
    for id, status in pairs(N.Data.statusById) do total = total + 1; if M.IsNew(id) then new = new + 1; assert(status == "verifiedNew") end end
    assert(total == N.Data.questCount and new == N.Data.newCount)
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
    local saved = {version = 5, custom = {"preserve"}}; local p, ro = M.Load(saved)
    assert(ro and p.version == 4 and saved.version == 5 and saved.custom[1] == "preserve")
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
test("renamed profile priority and future data remain lossless",function()
    local old={version=99,enabled=false,unknown={"keep"}}
    assert(M.RenameSeed(nil,old)==old and M.RenameSeed(false,old)==false)
    local current={version=3,enabled=true};assert(M.RenameSeed(current,old)==current)
    local profile,readonly=M.Load(M.RenameSeed(nil,old));assert(readonly and not profile.enabled and old.unknown[1]=="keep")
end)
test("obsolete scoring styles are ignored while current profile fields survive",function()
    local saved={scoringStyles={["Player-1:1"]="HEALER",["Player-2:2"]="MELEE",bad="unknown",[3]="CASTER"}}
    local profile=M.Load(saved)
    assert(profile.scoringStyles==nil and M.defaults.scoringStyles==nil and M.scoringStyles==nil)
    assert(saved.scoringStyles["Player-1:1"]=="HEALER" and profile.strength==M.defaults.strength)
end)

test("schema-three migration preserves preferences and owns independent search defaults",function()
    local old={version=3,enabled=false,scale=1.15,modifier="ALT",rewards=false}
    local a,readonly=M.Load(old);local b=M.Load(old)
    assert(a.version==4 and not readonly and not a.enabled and a.scale==1.15 and a.modifier=="ALT" and not a.rewards)
    assert(a.font=="Game tooltip" and a.border=="default" and a.searchDefaults.hideUnusable and not a.searchDefaults.includeDungeons)
    a.searchDefaults.levelsBelow=17
    assert(b.searchDefaults.levelsBelow==5 and M.defaults.searchDefaults.levelsBelow==5 and old.searchDefaults==nil and old.version==3)
end)
test("search defaults preserve false and validate independent offsets",function()
    local p=M.Load({searchDefaults={hideUnusable=false,includeDungeons=true,levelsBelow=-8,levelsAbove=299.7}})
    assert(not p.searchDefaults.hideUnusable and p.searchDefaults.includeDungeons and p.searchDefaults.levelsBelow==0 and p.searchDefaults.levelsAbove==199)
    p=M.Load({searchDefaults={hideUnusable="false",includeDungeons=1,levelsBelow=0/0,levelsAbove=math.huge}})
    assert(p.searchDefaults.hideUnusable and not p.searchDefaults.includeDungeons and p.searchDefaults.levelsBelow==5 and p.searchDefaults.levelsAbove==3)
    assert(M.SearchDefaults({levelsBelow=8.9,levelsAbove=0}).levelsBelow==8 and M.SearchDefaults({levelsAbove=0}).levelsAbove==0)
end)
test("font names and border enums validate without requiring media at load",function()
    assert(M.Load({font="Missing media",border="none"}).font=="Missing media")
    for _,font in ipairs({"",string.rep("x",129),"bad|Tfont","bad\nfont",12,{}}) do assert(M.Load({font=font}).font=="Game tooltip") end
    for _,border in ipairs({"default","none","tooltip","dialog","thin"}) do assert(M.Load({border=border}).border==border) end
    assert(M.Load({border="arbitrary/path"}).border=="default")
end)

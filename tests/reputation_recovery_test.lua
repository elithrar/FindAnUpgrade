local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup(entries)
    local N=W.Init()
    N.Providers.Source=function() return {itemState="published-empty",items={},rewardValues={reputation=entries}} end
    return N
end
local function pending(native)
    return {state="pending",money={state="unavailable"},xp={state="unavailable"},reputation={state="unavailable",items=native or {}}}
end
test("duplicate same-faction observations do not imply an effective award",function()
    local N=setup({{name="Stormwind",amount=200},{name="Stormwind",amount=200},{name="Stormwind",amount=400}})
    assert(#N.Rewards.Recorded(9,pending()).reputation.items==0)
end)
test("ambiguous factions do not erase independent zero negative or positive facts",function()
    local N=setup({{name="Stormwind",amount=200},{name="Stormwind",amount=400},{name="Darnassus",amount=0},{name="Bloodsail Buccaneers",amount=-500},{name="Ironforge",amount=75}})
    local rows=N.Rewards.Recorded(9,pending()).reputation.items
    assert(#rows==3 and rows[1].amount==0 and rows[2].amount==-500 and rows[3].amount==75)
end)
test("native matching faction retains authority over an ambiguous published list",function()
    local N=setup({{name="Stormwind",amount=200},{name="Stormwind",amount=400}})
    C_Reputation={GetFactionDataByID=function(id) return id==72 and {name="Stormwind"} end}
    local rows=N.Rewards.Recorded(9,pending({{factionID=72,amount=225}})).reputation.items
    assert(#rows==1 and rows[1].amount==225 and not rows[1].published)
end)
test("known native reputation exposes its authoritative faction name",function()
    local N=setup(nil)
    C_QuestLog.GetQuestLogMajorFactionReputationRewards=function() return {{factionID=72,rewardAmount=225}} end
    C_Reputation={GetFactionDataByID=function(id) return id==72 and {name="Stormwind"} end}
    local rows=N.Rewards.Read(9).reputation.items
    assert(#rows==1 and rows[1].name=="Stormwind" and rows[1].amount==225)
end)

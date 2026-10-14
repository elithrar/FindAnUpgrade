local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn();PASSED=PASSED+1;print("PASS "..name) end
local function prepare(mini)
    local N=W.Init();N.Core.profile.minimap=true;W.shift=true
    local icon=W.Object(true);icon.width=28;icon.height=28;icon.x=690;icon.y=690;icon.data={Id=9};icon.miniMapIcon=mini
    icon.texture=W.Object(true)
    local tooltip=W.Object(true);tooltip._owner=icon;tooltip.questOrder={[9]={},[14]={}};tooltip.npcAndObjectOrder={npc={A={questId=98189},B={questId=9}}}
    N.Questie:Observe(tooltip);tooltip._Rebuild=function()end
    return N,icon,tooltip
end
local function shown(N,icon,t) t._Rebuild=function()end;N.Questie:Shown(icon,t) end
test("Questie exact rendered group IDs deduplicate variants without creating icons",function()
    local N,icon,tooltip=prepare(false);N.Questie:Shown(icon,tooltip)
    assert(N.Hover.open and #N.Stack.cards==3 and N.Stack.cards[1].questID==9 and N.Stack.cards[3].questID==98189)
    assert(W.nativeMutations==0)
end)
test("Questie minimap respects independent surface setting",function()
    local N,icon,t=prepare(true);N.Core.profile.minimap=false;N.Questie:Shown(icon,t);assert(not N.Hover.open)
    N.Core.profile.minimap=true;shown(N,icon,t);assert(N.Hover.open and N.Hover.source.surface=="minimap")
end)
test("missing disabled hidden and stale Questie markers fail safely",function()
    local N,icon,t=prepare();icon.hidden=true;N.Questie:Shown(icon,t);assert(not N.Hover.open)
    icon.hidden=false;icon._needsUnload=true;N.Questie:Shown(icon,t);assert(not N.Hover.open)
    icon._needsUnload=false;t._owner={};N.Questie:Shown(icon,t);assert(not N.Hover.open)
    t._owner=icon;icon.data=nil;N.Questie:Shown(icon,t);assert(not N.Hover.open)
end)
test("Questie manual names and restricted IDs cannot fabricate quests",function()
    local N,icon,t=prepare();t.questOrder={Name={}};t.npcAndObjectOrder={npc={A={questId=W.secret},B={questId="9"}}}
    N.Questie:Shown(icon,t);assert(not N.Hover.open)
end)
test("Questie alpha-zero early return and unchanged render token cannot reuse stale rows",function()
    local N,icon,t=prepare();N.Questie:Shown(icon,t);N.Hover:Dismiss();icon.data={Id=14}
    N.Questie:Shown(icon,t);assert(not N.Hover.open)
    icon.texture.color={1,1,1,0};t.questOrder={[14]={}};t.npcAndObjectOrder={};shown(N,icon,t);assert(not N.Hover.open)
    icon.texture.color={1,1,1,1};shown(N,icon,t);assert(N.Hover.open and N.Stack.cards[1].questID==14)
end)
test("pooled Questie frames invalidate active identity and permit fresh activation",function()
    local N,icon,t=prepare();N.Questie:Shown(icon,t);assert(N.Hover.open)
    icon.data={Id=14};N.Hover:Tick(1);assert(not N.Hover.open)
    t.questOrder={[14]={}};t.npcAndObjectOrder={};shown(N,icon,t);assert(N.Hover.open and N.Stack.cards[1].questID==14)
end)
test("in-place Questie data mutation invalidates the frozen source",function()
    local N,icon,t=prepare();N.Questie:Shown(icon,t);icon.data.Id=14;N.Hover:Tick(1);assert(not N.Hover.open)
end)
test("Questie callback hooks preserve returns and native function",function()
    local N,icon,t=prepare();local calls=0
    local module={ShowOnTooltip=function()calls=calls+1;t._Rebuild=function()end;return "native",42 end}
    QuestieLoader={ImportModule=function(_,name)assert(name=="MapIconTooltip");return module end}
    W.Event("ADDON_LOADED","Questie");local first,count=module.ShowOnTooltip(icon,t)
    assert(first=="native" and count==42 and calls==1 and N.Hover.open)
    local callback=module.ShowOnTooltip;W.Event("ADDON_LOADED","Questie");assert(module.ShowOnTooltip==callback)
end)
test("Questie integration defers hook installation in combat and recovers",function()
    local N,icon,t=prepare();local module={ShowOnTooltip=function()end};QuestieLoader={ImportModule=function()return module end}
    W.combat=true;W.Event("ADDON_LOADED","Questie");assert(not N.Questie.module)
    W.combat=false;W.Event("PLAYER_REGEN_ENABLED");assert(N.Questie.module==module)
end)

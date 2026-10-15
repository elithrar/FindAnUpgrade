local W=assert(loadfile(ROOT .. "/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function pin(id)
    local f=W.Object(true); f.x=690;f.y=690;f.width=30;f.height=30;f.questID=id
    f.GetQuestID=function(self) return self.questID end
    return f
end
local function open(id)
    local N=W.Init(); W.shift=true; local f=pin(id or 9)
    EventRegistry:TriggerEvent("MapCanvas.QuestPin.OnEnter",f,f.questID)
    assert(N.Hover.open and N.Stack.frame:GetWidth()>=232 and N.Stack.frame:GetWidth()<=280)
    return N,f
end
local function geometry(N)
    N.Stack.frame.x=730;N.Stack.frame.y=400;N.Stack.frame.width=320;N.Stack.frame.height=400
    N.Stack.scroll.x=736;N.Stack.scroll.y=690;N.Stack.scroll.width=292;N.Stack.scroll.height=362
end
test("native callback opens held Shift and avoids warm data requests",function()
    local N,f=open(9); assert(W.rewardRequests[9]==nil and W.metadataRequests[9]==nil)
    for i=1,50 do EventRegistry:TriggerEvent("MapCanvas.QuestPin.OnEnter",f,9) end
    assert(W.rewardRequests[9]==nil and #N.Stack.cards==1)
end)
test("press after hover works with both modifier event sides",function()
    local N=W.Init(); local f=pin(9); EventRegistry:TriggerEvent("MapCanvas.QuestPin.OnEnter",f,9);assert(not N.Hover.open)
    W.shift=true; W.Event("MODIFIER_STATE_CHANGED","LSHIFT",1);assert(N.Hover.open)
    N.Hover:Dismiss();W.shift=false;W.Event("MODIFIER_STATE_CHANGED","LSHIFT",0)
    W.shift=true;W.Event("MODIFIER_STATE_CHANGED","RSHIFT",1);assert(N.Hover.open)
end)
test("release preserves stack and slow pointer transit uses grace",function()
    local N=open(); geometry(N);W.shift=false;W.Event("MODIFIER_STATE_CHANGED","LSHIFT",0);assert(N.Hover.open)
    W.mouseX=725;W.mouseY=700;N.Hover:Tick(1);N.Hover:Tick(1.19);assert(N.Hover.open)
    W.mouseX=750;N.Hover:Tick(1.2);assert(N.Hover.open)
    W.mouseX=1400;N.Hover:Tick(2);N.Hover:Tick(2.21);assert(not N.Hover.open)
end)
test("Escape hides and suppresses immediate reopening while Shift remains held",function()
    local N,f=open();N.Stack.frame:Hide();assert(not N.Hover.open)
    EventRegistry:TriggerEvent("MapCanvas.QuestPin.OnEnter",f,9);N.Hover:Tick(1);assert(not N.Hover.open)
    W.shift=false;W.Event("MODIFIER_STATE_CHANGED","RSHIFT",0);W.shift=true;W.Event("MODIFIER_STATE_CHANGED","RSHIFT",1);assert(N.Hover.open)
end)
test("focus-loss modifier reconciliation observes actual released key",function()
    local N=open();N.Hover:Dismiss();W.shift=false;N.Hover:Tick(1);assert(not N.Hover.open)
    W.shift=true;N.Hover:Tick(2);assert(N.Hover.open)
end)
test("None activation re-arms only after departure or a changed source",function()
    local N=W.Init({saved={modifier="NONE"}});local f=pin(9);N.Sources:Pin(f,9);assert(N.Hover.open)
    N.Hover:Dismiss();N.Hover:Tick(1);assert(not N.Hover.open)
    W.mouseX=1100;N.Hover:Tick(2);W.mouseX=700;N.Sources:Pin(f,9);assert(N.Hover.open)
end)
test("Ctrl and Alt alternatives keep Shift available for native comparison",function()
    for _,key in ipairs({"CTRL","ALT"}) do
        local N=W.Init({saved={modifier=key}});W.shift=true;local f=pin(9);N.Sources:Pin(f,9);assert(not N.Hover.open)
        W[key:lower()]=true;W.Event("MODIFIER_STATE_CHANGED",key,1);assert(N.Hover.open)
    end
end)
test("source B teardown cannot dismiss frozen source A",function()
    local N,a=open();geometry(N);W.mouseX=700;local b=pin(14);N.Sources:Pin(b,14)
    assert(N.Hover.source.owner==a); b.shown=false;b:Fire("OnHide");assert(N.Hover.open and N.Hover.source.owner==a)
    a.shown=false;a:Fire("OnHide");assert(not N.Hover.open)
end)
test("map close and pin pool reuse invalidate their own stack",function()
    local N,f=open();f.questID=14;N.Hover:Tick(1);assert(not N.Hover.open)
    N,f=open();WorldMapFrame:Hide();assert(not N.Hover.open and not N.Sources.current)
end)
test("mixed quest statuses stay exact and cards scroll without map zoom",function()
    local N=W.Init();W.shift=true;local f=pin(9);local rows={};C_QuestLog.IsOnQuest=function()return true end
    for _,id in ipairs({2,9,98189,286,14,921,932,422,356,99156,98046,98065}) do rows[#rows+1]={id=id,evidence="Map quest"} end
    f.related={};for _,row in ipairs(rows) do f.related[row.id]={} end;f.GetRelatedQuests=function(self)return self.related end
    N.Sources:Pin(f,nil,rows)
    assert(#N.Stack.cards==12 and N.Stack.maximum>0)
    assert(N.Stack.cards[1].backdropColor[1]==.09 and N.Stack.cards[2].backdropColor[2]>.09 and N.Stack.cards[3].backdropColor[1]>.09)
    for _,card in ipairs(N.Stack.cards) do assert(card.nativeTooltipArt and card.border[1]==.6) end
    N.Stack.scroll:Fire("OnMouseWheel",-10000);assert(N.Stack.offset==N.Stack.maximum)
    N.Stack.scroll:Fire("OnMouseWheel",10000);assert(N.Stack.offset==0)
end)
test("hub keeps all related exact variants and invalidates after membership changes",function()
    local N=W.Init();W.shift=true;local f=pin(9);f.related={[9]={},[14]={}};f.GetRelatedQuests=function(self)return self.related end
    N.Sources:Pin(f,nil,{{id=9},{id=14}});assert(N.Hover.open);f.related[14]=nil;N.Hover:Tick(1);assert(not N.Hover.open)
end)
test("stack placement is frozen while sources and cursor change",function()
    local N,f=open();local anchor=N.Stack.frame.point;W.mouseX=900;W.mouseY=200;N.Sources:Pin(pin(14),14)
    assert(N.Stack.frame.point==anchor and N.Stack.source.owner==f)
end)
test("restricted geometry and unsupported client fail safely",function()
    local N=W.Init();W.shift=true;local f=pin(9);f.rectSecret=true;N.Sources:Pin(f,9);assert(not N.Hover.open)
    N=W.Init({interface=120001});W.shift=true;N.Sources:Pin(pin(9),9);assert(not N.Hover.open)
end)
test("combat start dismisses owned frames and setup is deferred",function()
    local N=open();W.combat=true;W.Event("PLAYER_REGEN_DISABLED");assert(not N.Hover.open and W.nativeMutations==0)
    N=W.Init({combat=true});assert(not N.Sources.callbacks);W.combat=false;W.Event("PLAYER_REGEN_ENABLED");assert(N.Sources.callbacks)
end)
test("missing reward data never becomes zero and does not imply no choices",function()
    local N=W.Init();W.rewardReady=false;local r=N.Rewards.Read(999001)
    assert(r.money.state=="unavailable" and r.money.value==nil and r.items.state=="unavailable" and r.state=="pending")
end)
test("missing choice count cannot borrow the guaranteed item count",function()
    local N=W.Init();W.items={{"Reward",100,2,2,true,123}};GetNumQuestLogChoices=function()end
    local r=N.Rewards.Read(9);assert(r.choices.state=="unavailable" and #r.choices.items==0)
end)
test("guaranteed and choice slots preserve exact index and native item identity",function()
    local N=W.Init();W.items={{"A",100,2,2,true,123},{"B",101,1,3,true,124}};W.choices={{"C",102,1,3,true,125}}
    local r=N.Rewards.Read(9);assert(#r.items.items==2 and #r.choices.items==1 and r.choices.items[1].index==1 and r.choices.items[1].kind=="choice")
    assert(r.money.value==12345 and r.xp.value==450 and r.reputation.state=="unavailable")
    W.items[1]={};r=N.Rewards.Read(9);assert(r.items.items[1].state=="pending" and r.items.items[2].index==2)
end)
test("reward values and currency classification reject restricted and malformed values",function()
    local N=W.Init();GetQuestLogRewardMoney=function()return W.secret end
    C_QuestLog.GetQuestRewardCurrencies=function()return {{name="Token",currencyID=1,totalRewardAmount=3},{name="Bad",currencyID=W.secret,totalRewardAmount=8}}end
    C_QuestLog.GetQuestRewardCurrencyInfo=function(_,_,choice)if choice then return {name="Choice",currencyID=2,totalRewardAmount=5}end end
    W.choices={{"C",102,1,3,true,125}}
    local r=N.Rewards.Read(9);assert(not r.money.value and #r.currencies.items==2 and not r.currencies.items[1].isChoice and r.currencies.items[2].isChoice)
end)
test("mixed currency choices preserve native loot and item-tooltip indices",function()
    local N=W.Init();W.choices={{"Currency",999,4,2,true,777},{"Item A",100,1,2,true,123},{"Item B",101,2,3,true,124}}
    C_QuestLog.GetQuestRewardCurrencyInfo=function(_,index,choice)if choice and index==1 then return {name="Token",currencyID=777,totalRewardAmount=4}end end
    C_TooltipInfo.GetQuestLogItem=function(kind,index,id)return {type=0,id=W.choices[index+1][6],lines={}}end
    GetNumQuestLogChoices=function(_,currencies)return currencies and 3 or 2 end
    local r=N.Rewards.Read(9)
    assert(#r.choices.items==2 and #r.choices.currencies==1)
    assert(r.choices.items[1].itemID==123 and r.choices.items[1].index==1 and r.choices.items[1].exposedIndex==2)
    assert(r.choices.items[2].itemID==124 and r.choices.items[2].index==2 and r.choices.items[2].exposedIndex==3)
end)
test("mixed choices cross-check item ordinals and preserve missing duplicate slots",function()
    local N=W.Init();W.choices={{"A",100,1,2,true,123},{},{"Currency",999,4,2,true,777},{"A variant",100,2,2,true,123},{"B",101,1,3,true,124}}
    C_QuestLog.GetQuestRewardCurrencyInfo=function(_,i)if i==3 then return {name="Token",currencyID=777,totalRewardAmount=4}end end
    C_TooltipInfo.GetQuestLogItem=function(_,i) local ids={123,125,123,124};return {type=0,id=ids[i],lines={}}end
    GetNumQuestLogChoices=function(_,currencies)return currencies and 5 or 4 end
    local r=N.Rewards.Read(9);assert(#r.choices.items==4 and r.choices.items[2].state~="ready")
    assert(r.choices.items[3].index==3 and r.choices.items[3].exposedIndex==4 and r.choices.items[3].state=="unavailable")
    assert(r.choices.items[4].index==4 and r.choices.items[4].itemID==124)
end)
test("item-only metadata fallback requires an exact native tooltip ID match",function()
    local N=W.Init();W.choices={{"A",100,1,2,true,123},{"B",101,2,3,true,124},{}}
    C_QuestLog.GetQuestRewardCurrencyInfo=function(_,i)if i==1 then return {name="Token",currencyID=777,totalRewardAmount=4}end end
    C_TooltipInfo.GetQuestLogItem=function(_,i)return {type=0,id=i==1 and 123 or 124,lines={}}end
    GetNumQuestLogChoices=function(_,currencies)return currencies and 3 or 2 end
    local r=N.Rewards.Read(9);assert(#r.choices.items==2 and r.choices.items[1].itemID==123 and r.choices.items[2].itemID==124)
    C_TooltipInfo.GetQuestLogItem=function()return {type=0,id=999,lines={}}end
    r=N.Rewards.Read(9);assert(r.choices.items[1].state=="unavailable" and r.choices.items[1].texture==nil)
end)
test("unresolved currency kind cannot shift later item ordinals",function()
    local N=W.Init();W.choices={{"Unknown",100,1,2,true,123},{"B",101,1,3,true,124}}
    C_QuestLog.GetQuestRewardCurrencyInfo=function(_,i)if i==1 then return W.secret end end
    local r=N.Rewards.Read(9);assert(r.choices.state=="unavailable" and #r.choices.items==0)
end)
test("duplicate IDs with conflicting metadata routes never invent quantities",function()
    for _,itemOnly in ipairs({false,true}) do
        local N=W.Init();W.choices={{"Currency",999,4,2,true,777},{"A",100,1,2,true,123},{"A",100,5,2,true,123}}
        C_QuestLog.GetQuestRewardCurrencyInfo=function(_,i)if i==1 then return {name="Token",currencyID=777,totalRewardAmount=4}end end
        C_TooltipInfo.GetQuestLogItem=function()return {type=0,id=123,lines={}}end
        GetNumQuestLogChoices=function(_,currencies)return currencies and 3 or 2 end
        if itemOnly then GetQuestLogChoiceInfo=function(i)if i<=2 then return "A",100,i==1 and 1 or 5,2,true,123 end end end
        local r=N.Rewards.Read(9)
        local uncertain=r.choices.items[itemOnly and 1 or 2]
        assert(uncertain.state=="unavailable" and uncertain.quantity==nil and uncertain.texture==nil)
    end
end)
test("missing first duplicate metadata cannot borrow a later item's count",function()
    local N=W.Init();W.choices={{},{"A",100,5,2,true,123},{}}
    GetNumQuestLogChoices=function(_,currencies)return currencies and 3 or 2 end
    C_QuestLog.GetQuestRewardCurrencyInfo=function(_,i)if i==1 then return {name="Token",currencyID=777,totalRewardAmount=4}end end
    C_TooltipInfo.GetQuestLogItem=function()return {type=0,id=123,lines={}}end
    local r=N.Rewards.Read(9);assert(r.choices.items[1].state=="unavailable" and r.choices.items[1].quantity==nil)
end)
test("fractional item quantities cannot become ready rewards",function()
    local N=W.Init();W.items={{"A",100,1.5,2,true,123}};W.choices={{"B",101,1.5,2,true,124}}
    local r=N.Rewards.Read(9);assert(r.items.items[1].state~="ready" and r.choices.items[1].state~="ready")
end)
test("native item tooltip uses exact-ID native renderer and isolated comparison manager",function()
    local N,f=open();geometry(N);W.items={{"Reward",100,2,2,true,123}};N.Stack:Refresh()
    local b=N.Stack.cards[1].icons[1];b.x=750;b.y=690;b.width=28;b.height=28;W.mouseX=760;W.mouseY=700
    b:Fire("OnEnter");assert(N.Stack.item and W.tooltipRoute[1]=="reward" and W.tooltipRoute[2]==1 and W.tooltipRoute[3]==9)
    assert(N.Stack.tooltip.template=="SharedTooltipTemplate" and N.Stack.comparison.calls==1 and TooltipComparisonManager.calls==nil)
    W.shift=false;W.Event("MODIFIER_STATE_CHANGED","LSHIFT",0);assert(N.Hover.open and N.Stack.item)
    N.Stack:ClearItem();assert(not N.Stack.item and TooltipComparisonManager.clears==nil)
end)
test("owned matching tooltip refresh preserves transit and unrelated updates leave it alone",function()
    local N=open();geometry(N);W.items={{"Reward",100,2,2,true,123}};N.Stack:Refresh();local b=N.Stack.cards[1].icons[1]
    b.x=750;b.y=690;b.width=28;b.height=28;W.mouseX=760;W.mouseY=700;b:Fire("OnEnter")
    local t=N.Stack.tooltip;t.x=1060;t.y=400;t.width=280;t.height=300;W.mouseX=1100
    W.Event("TOOLTIP_DATA_UPDATE",999);assert(N.Stack.item and N.Hover.open)
    W.Event("TOOLTIP_DATA_UPDATE",123);assert(N.Stack.item and N.Hover.open)
end)
test("missed Shift release reconciles native comparison in Ctrl inspection",function()
    local N=open();N.Core.profile.modifier="CTRL";W.ctrl=true;geometry(N);W.items={{"Reward",100,2,2,true,123}};N.Stack:Refresh();local b=N.Stack.cards[1].icons[1]
    b.x=750;b.y=690;b.width=28;b.height=28;W.mouseX=760;W.mouseY=700;b:Fire("OnEnter");assert(N.Stack.compareState)
    local calls=N.Stack.comparison.calls;N.Hover:Tick(.1);assert(N.Stack.comparison.calls==calls)
    W.shift=false;N.Hover:Tick(.2);assert(N.Stack.item and not N.Stack.compareState)
end)
test("hidden reward details cause no reward queries preload or polling",function()
    local N=W.Init({saved={rewards=false}});W.shift=true;W.rewardReady=false
    GetQuestLogRewardMoney=function()error("hidden rewards queried")end
    N.Sources:Pin(pin(9),9);assert(N.Hover.open and not N.Hover.pending and W.rewardRequests[9]==nil)
    local anchor=N.Stack.cards[1].point;N.Hover:Tick(1);assert(N.Stack.cards[1].point==anchor)
end)
test("cold requests deduplicate and polling stops after five seconds",function()
    local N=W.Init();W.shift=true;W.rewardReady=false;C_QuestLog.GetTitleForQuestID=function()end;local f=pin(9);N.Sources:Pin(f,9)
    assert(W.rewardRequests[9]==1 and W.metadataRequests[9]==1 and N.Hover.pending)
    for i=1,12 do W.time=i*.5;N.Hover:Tick(W.time) end
    assert(N.Hover.timedOut and not N.Hover.pending and W.rewardRequests[9]==1)
    local anchor=N.Stack.cards[1].point;N.Hover:Tick(7);assert(N.Stack.cards[1].point==anchor)
end)
test("rename seed preserves opt-out and never overwrites an existing new profile",function()
    local old={version=3,enabled=false,strength=.8,preset="blue"};local N=W.Init({previous=old});assert(not N.Core.profile.enabled and FindAnUpgradeDB.strength==.8 and QuestBriefDB==old)
    N=W.Init({previous=old,saved={version=3,enabled=true,strength=.4}});assert(N.Core.profile.enabled and FindAnUpgradeDB.strength==.4)
    local future={version=99,enabled=false,custom={"preserve"}}
    N=W.Init({previous=future});assert(not N.Core.profile.enabled and N.Core.readOnly and FindAnUpgradeDB==future and QuestBriefDB==future)
end)
test("major faction rows never replace ordinary reputation unavailable",function()
    local N=W.Init();C_QuestLog.GetQuestLogMajorFactionReputationRewards=function()return {{factionID=72,rewardAmount=75},{factionID=76,rewardAmount=-10},{factionID=99,rewardAmount=W.secret}}end
    local r=N.Rewards.Read(999001);assert(r.reputation.state=="unavailable" and #r.reputation.items==2 and r.reputation.items[2].amount==-10)
end)
test("item transit includes mouse-transparent tooltip geometry",function()
    local N=open();geometry(N);W.items={{"Reward",100,2,2,true,123}};N.Stack:Refresh();local b=N.Stack.cards[1].icons[1]
    b.x=750;b.y=690;b.width=28;b.height=28;W.mouseX=760;W.mouseY=700;b:Fire("OnEnter")
    local t=N.Stack.tooltip;t.x=1060;t.y=400;t.width=280;t.height=300
    W.mouseX=1040;N.Hover:Tick(1);N.Hover:Tick(1.19);assert(N.Stack.item)
    W.mouseX=1100;N.Hover:Tick(1.2);assert(N.Stack.item and N.Hover.open)
    W.mouseX=1500;N.Hover:Tick(2);N.Hover:Tick(2.21);assert(not N.Hover.open)
end)
test("clipped reward rectangles cannot extend interaction outside viewport",function()
    local N=open();geometry(N);W.items={{"Reward",100,2,2,true,123}};N.Stack:Refresh();local b=N.Stack.cards[1].icons[1]
    b.x=750;b.y=690;b.width=28;b.height=28;W.mouseX=760;W.mouseY=700;b:Fire("OnEnter");assert(N.Stack.item)
    b.y=380;W.mouseY=390;N.Stack.tooltip.shown=false;assert(not N.Stack:ItemContains())
    N.Stack:Inspect(b,b.row);assert(not N.Stack.item)
end)
test("overflow choices remain separately accessible and scrolling clears item state",function()
    local N=open();W.choices={};for i=1,12 do W.choices[i]={"Choice",100+i,1,2,true,1000+i} end;N.Stack:Refresh()
    local c=N.Stack.cards[1];assert(#c.icons==8 and c.groups.choices.more:IsShown())
    c.groups.choices.more:Fire("OnClick");assert(#c.icons==12 and c.icons[12].row.index==12 and c.icons[12].row.kind=="choice")
    N.Stack:Scroll(100);assert(not N.Stack.item)
end)
test("late quest data cannot recreate dismissed UI",function()
    local N=open();N.Hover:Dismiss();local generation=N.Hover.generation
    W.Event("QUEST_DATA_LOAD_RESULT",9,true);assert(not N.Hover.open and N.Hover.generation==generation and not N.Stack.frame:IsShown())
end)
test("repeated inspection sessions reuse cards and owned tooltips",function()
    local N,f=open();local count=#W.frames
    for i=1,200 do N.Hover:Dismiss();N.Hover.blocked=nil;N.Sources:Pin(f,9) end
    assert(#W.frames==count);N.Sources:Clear();N.Core.events:Fire("OnUpdate");assert(not N.Core.updating)
end)
test("changing settings dismisses and rebinds a sanitized profile",function()
    local N=open();N.Core:Change("modifier","ALT");assert(not N.Hover.open and FindAnUpgradeDB.modifier=="ALT")
    N.Core:Change("scale",50);assert(FindAnUpgradeDB.scale==1.2);N.Core:Change("npc",false);assert(not FindAnUpgradeDB.npc)
end)
test("ordinary NPC without reliable associations stays native",function()
    local N=W.Init();W.shift=true;W.guid="Creature-0-1-2-3-54-0001";W.Event("UPDATE_MOUSEOVER_UNIT");assert(not N.Hover.open)
end)
test("provider requires Forever contract and reciprocal exact starter IDs",function()
    local N=W.Init();local quests={[9]={startedBy={{54}},name="A"},[14]={startedBy={{55}},name="A"}}
    LibQuestieDB={flavor={name="Forever"},RequireContract=function(v)return v==3 end,Npc={Get=function()return {9,14,9,"bogus"}end},Quest={Get=function(id,key)return quests[id] and quests[id][key]end}}
    N.CatalogData={schemaVersion=1,quests={}}
    local rows=N.Providers.ForNPC(54);assert(#rows==1 and rows[1].id==9 and rows[1].availability.state=="unknown" and rows[1].evidence==nil)
    LibQuestieDB.flavor.name="Era";assert(#N.Providers.ForNPC(54)==0)
end)
test("gossip exact IDs require matching current NPC and are cleared on close",function()
    local N=W.Init();W.shift=true;W.guid="Creature-0-1-2-3-54-0001";W.npcGuid=W.guid
    C_GossipInfo={GetAvailableQuests=function()return {{questID=9,title="A"},{questID=14,title="A"}}end,GetActiveQuests=function()return {}end}
    W.Event("GOSSIP_SHOW");W.Event("UPDATE_MOUSEOVER_UNIT");assert(N.Hover.open and #N.Stack.cards==2)
    W.Event("GOSSIP_CLOSED");assert(not N.Hover.open and not N.Sources.gossip)
end)

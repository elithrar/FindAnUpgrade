local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function start()
    local N=W.Init();W.rewardReady=false;W.cached=true;W.loads={}
    LibQuestieDB=nil;QuestieLoader=nil
    N.CatalogData={schemaVersion=2,quests={
        {id=682,title="Stromgarde Badges",level=37,confirmation="published",itemState="published",items={
            {itemID=4741,name="Leggings",quantity=1,group="guaranteed"},
            {itemID=4741,name="Leggings",quantity=1,group="choice"},
            {itemID=270056,name="Pants",quantity=1,group="choice"},
            {itemID=270057,name="Operative Pants",quantity=2,group="choice"}},
            rewardValues={xp=3550,reputation={{name="Stormwind",factionID=72,amount=150}}}},
        {id=292,title="The Eye of Paleth",level=30,confirmation="published",itemState="published-empty",items={}},
        {id=999001,itemState="unknown",confirmation="unconfirmed",items={}}
    }}
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    C_Item={IsItemDataCachedByID=function()return W.cached end,
        GetItemInfo=function(id)return "Item "..id,"item:"..id,2,30,20,"Armor","Mail",1,"INVTYPE_LEGS",100 end,
        GetItemInfoInstant=function(id)return id,"Armor","Mail","INVTYPE_LEGS",100 end,
        RequestLoadItemDataByID=function(id)W.loads[id]=(W.loads[id] or 0)+1 end}
    assert(N.Catalog:Begin());N.Catalog:Step()
    return N
end

test("comprehensive identity retains published empty and unknown quests without Questie",function()
    local N=start();assert(#N.Catalog.order==3 and N.Catalog.records[292] and N.Catalog.records[999001])
    assert(N.Providers.Source(292).itemState=="published-empty" and N.Providers.Source(999001).itemState=="unknown")
    assert(N.Model.Status(999001)==nil and LibQuestieDB==nil)
end)

test("published quest difficulty survives cold native metadata without borrowing minimum level",function()
    local N=start();assert(N.Catalog.records[682].level==37)
    assert(N.Catalog.records[999001].level==nil)
    N.Catalog.records[999001].source.minimum=20;N.Catalog:Metadata(N.Catalog.records[999001]);assert(N.Catalog.records[999001].level==nil)
    C_QuestLog.GetQuestDifficultyLevel=function()return 38 end;N.Catalog:Invalidate(682);N.Catalog:Metadata(N.Catalog.records[682]);assert(N.Catalog.records[682].level==38)
end)

test("recorded choice groups preserve cross-group duplicate and exact quantities",function()
    local N=start();local rewards=N.Rewards.Read(682)
    assert(rewards.recordedGroups and rewards.state=="pending" and #rewards.items.items==1 and #rewards.choices.items==3)
    assert(rewards.items.items[1].itemID==4741 and rewards.choices.items[1].itemID==4741)
    assert(rewards.choices.items[3].quantity==2 and rewards.choices.items[3].kind=="catalog")
end)

test("item metadata cache never owns another quest quantity or reward group",function()
    local N=start()
    local a=N.SearchModel:Item({itemID=4741,quantity=1,group="guaranteed"})
    local b=N.SearchModel:Item({itemID=4741,quantity=3,group="choice"})
    assert(a~=b and a.quantity==1 and b.quantity==3 and a.group=="guaranteed" and b.group=="choice")
    assert(N.SearchModel.cache[4741].quantity==nil and N.SearchModel.cache[4741].group==nil)
end)

test("confirmed empty source item list remains distinct from unknown source rewards",function()
    local N=start();local empty,unknown=N.Rewards.Read(292),N.Rewards.Read(999001)
    assert(empty.recordedGroups and empty.items.state=="published" and #empty.items.items==0)
    assert(not unknown.recordedGroups and unknown.items.state=="unavailable")
    assert(empty.money.state=="unavailable" and empty.xp.state=="unavailable")
end)

test("native confirmed empty items replace published reward associations completely",function()
    local N=start();W.rewardReady=true;W.items={};W.choices={}
    local rewards=N.Rewards.Read(682);assert(not rewards.recordedGroups and rewards.items.state=="ready" and #rewards.items.items==0)
    N.SearchModel:Reward(N.Catalog.records[682]);assert(#N.SearchModel.currentItems[682]==0)
end)

test("ambiguous native choices never fall back to published class-unfiltered choices",function()
    local N=start();W.rewardReady=true;W.items={};GetNumQuestLogChoices=function()return nil end
    local rewards=N.Rewards.Read(682);assert(not rewards.recordedGroups and rewards.choices.state=="unavailable" and #rewards.choices.items==0)
    local reward,pending=N.SearchModel:Reward(N.Catalog.records[682])
    assert(#pending==0 and #N.SearchModel.currentItems[682]==0)
    local rows=N.SearchModel:Query({minimum=1,maximum=60,slot="ALL",query="",usable=false})
    assert(#rows==0)
end)

test("published amounts are labelled base and missing money is never zero",function()
    local N=start();local rewards=N.Rewards.Read(682)
    assert(rewards.xp.published and rewards.xp.value==3550 and rewards.money.state=="unavailable")
    assert(rewards.reputation.items[1].name=="Stormwind" and rewards.reputation.items[1].published)
    N.Stack:Create();local c=N.Stack:Card(1);N.Stack:Fill(c,N.Catalog.records[682],N.Core.profile)
    assert(c.summary.text:find("3550 XP %(base%)") and c.summary.text:find("Stormwind: %+150 %(base%)"))
end)

test("source item requests are deduplicated across groups and repeated owner requests",function()
    local N=start();W.cached=false;local requested={}
    N.Rewards.Request(682,requested,true);N.Rewards.Request(682,requested,true)
    assert(W.loads[4741]==1 and W.loads[270056]==1 and W.loads[270057]==1)
    local reward,pending=N.SearchModel:Reward(N.Catalog.records[682]);assert(reward.recordedGroups and #pending==0)
end)

test("partial native reputation preserves unrelated ordinary factions and owns matching factions",function()
    local N=start();W.rewardReady=true
    local values=N.Catalog.records[682].source.rewardValues
    values.reputation={{name="Stormwind",amount=150},{name="Ironforge",amount=75}}
    C_QuestLog.GetQuestLogMajorFactionReputationRewards=function()return {{factionID=999,rewardAmount=50},{factionID=72,rewardAmount=180}} end
    C_Reputation={GetFactionDataByID=function(id)return {name=id==72 and "Stormwind" or "Unrelated faction"} end}
    local rows=N.Rewards.Read(682).reputation.items
    assert(#rows==3 and rows[1].factionID==999 and rows[2].factionID==72 and rows[2].amount==180)
    assert(rows[3].name=="Ironforge" and rows[3].amount==75 and rows[3].published)
end)

test("compiled class restrictions survive public reward rows and native offer proof remains authoritative",function()
    local N=start();local row=N.Catalog.records[682]
    row.source.classTokens={"WARRIOR","HUNTER"}
    assert(N.Providers.Availability(row,{classToken="WARLOCK"}).state=="blocked")
    row.source.eligibilityConflict=true
    assert(N.Providers.Availability(row,{}).state=="blocked")
    row.availabilityProof="native-available"
    assert(N.Providers.Availability(row,{}).state=="available")
end)

test("unconfirmed and historical candidates cannot become finder offers from cached title or rewards",function()
    local N=start();local row=N.Catalog.records[682]
    for _,confirmation in ipairs({"unconfirmed","historical"}) do
        row.source.confirmation=confirmation
        assert(N.SearchModel:Eligibility(row,{level=60})==false)
        W.rewardReady=true;N.SearchModel:Reward(row)
        assert(N.SearchModel:Eligibility(row,{level=60})==false)
        row.availabilityProof="native-available"
        assert(N.SearchModel:Eligibility(row,{level=60})==true)
        row.availabilityProof=nil
    end
    row.source.confirmation="published";row.source.questKind="hidden-trigger"
    assert(N.SearchModel:Eligibility(row,{level=60})==false)
    row.availabilityProof="native-map-available"
    assert(N.SearchModel:Eligibility(row,{level=60})==true)
end)

test("faction-qualified NPC starts and locations follow the current player faction",function()
    local N=start();local source=N.Catalog.records[682].source
    source.locations={{npcID=11,faction="Alliance",name="Alliance giver"},{npcID=22,faction="Horde",name="Horde giver"}}
    for _,faction in ipairs({"Alliance","Horde","Unknown"}) do
        UnitFactionGroup=function()return faction end
        local locations=N.Catalog:Locations(682)
        assert(#locations==(faction=="Unknown" and 0 or 1))
        assert(#N.Providers.ForNPC(11)==(faction=="Alliance" and 1 or 0))
        assert(#N.Providers.ForNPC(22)==(faction=="Horde" and 1 or 0))
    end
end)

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

test("recovered unconfirmed cached metadata does not establish availability or empty rewards",function()
    local N=W.Init();local source=N.Providers.Source(1156)
    assert(source and source.title=="<NYI> <TXT> speak to alchemist pestlezugg" and source.level==58 and source.minimum==25)
    assert(source.confirmation=="unconfirmed" and source.itemState=="unknown" and #source.items==0)
    assert(N.Providers.RequiresNativeProof(source) and N.Model.Status(1156)==nil)
    C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    N.Character:PrimeQuests({}, {},true)
    local eligible=N.SearchModel:Eligibility({id=1156,source=source},N.Character:Get())
    assert(not eligible)
    local category=N.Catalog:Category(93161);assert(category and category.sourceZoneID==16593 and N.Model.Status(93161)==nil)
    assert(N.Providers.Availability({id=93161,source=N.Providers.Source(93161)}).state=="unknown")
end)

test("website corrections reach bundled reward fallback without claiming unknown lists empty",function()
    local N=W.Init();W.rewardReady=false
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    C_Item={IsItemDataCachedByID=function()return false end}
    assert(N.Catalog:Begin());while N.Catalog:Step() do end
    local rewards=N.Rewards.Read(93176)
    assert(rewards.recordedGroups and #rewards.items.items==1 and #rewards.choices.items==0)
    local item=rewards.items.items[1]
    assert(item.itemID==280456 and item.name=="Weevil K. Neevil" and item.quantity==1 and item.group=="guaranteed")
    for _,id in ipairs({95816,95819}) do
        local unknown=N.Rewards.Read(id)
        assert(not unknown.recordedGroups and unknown.items.state=="unavailable")
    end
    for _,id in ipairs({92841,92844,92846}) do
        assert(N.Providers.Source(id).minimum==35)
    end
    W.rewardReady=true;W.items={};W.choices={}
    local native=N.Rewards.Read(93176)
    assert(not native.recordedGroups and native.items.state=="ready" and #native.items.items==0)
end)

test("comprehensive identity retains published empty and unknown quests without Questie",function()
    local N=start();assert(#N.Catalog.order==3 and N.Catalog.records[292] and N.Catalog.records[999001])
    assert(N.Providers.Source(292).itemState=="published-empty" and N.Providers.Source(999001).itemState=="unknown")
    assert(N.Model.Status(999001)==nil and LibQuestieDB==nil)
end)

test("item-start identities do not borrow item names levels rewards or current availability",function()
    local N=W.Init();W.rewardReady=false;C_Item={IsItemDataCachedByID=function()return false end}
    C_QuestLog.GetTitleForQuestID=function()return nil end;C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    N.Character:PrimeQuests({}, {},true)
    assert(N.Catalog:Begin());while N.Catalog:Step() do end
    N.Stack:Create();local card=N.Stack:Card(1)
    for _,pair in ipairs({{97270,277556,"Razza's Heart"},{99233,277557,"Skarr's Broken Gauntlet"},{99234,277558,"Mushgog's Crown of Thorns"}}) do
        local id,item,name=pair[1],pair[2],pair[3];local source=N.Providers.Source(id);local row=N.Catalog.records[id]
        assert(source and source.confirmation=="unconfirmed" and source.itemState=="unknown" and #source.items==0)
        assert(not source.title and not source.level and not source.minimum and not source.faction and not source.rewardValues)
        assert(source.locations[1].itemID==item and source.locations[1].name==name and not source.locations[1].mapID)
        assert(N.Model.Status(id)==nil and N.Providers.RequiresNativeProof(source) and not N.Catalog:Category(id))
        assert(not N.SearchModel:Eligibility(row,N.Character:Get()))
        local rewards=N.Rewards.Read(id);assert(not rewards.recordedGroups and rewards.items.state=="unavailable" and #rewards.items.items==0)
        N.Stack:Fill(card,row,N.Core.profile);assert(card.title.text=="Quest "..id)
        local offered={id=id,source=source,availabilityCheck=function()return "native-available" end}
        assert(N.Providers.Resolve(offered,{level=60}) and offered.availability.state=="available")
    end
end)

test("cached-only identity and metadata require native proof without inventing reward completeness",function()
    local N=W.Init();W.rewardReady=false;C_Item={IsItemDataCachedByID=function()return false end}
    C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    N.Character:PrimeQuests({}, {},true)
    assert(N.Catalog:Begin());while N.Catalog:Step() do end
    for _,id in ipairs({7741,8152,95951}) do
        local source=N.Providers.Source(id)
        assert(source and source.confirmation=="unconfirmed" and source.itemState=="unknown" and #source.items==0)
        assert(N.Providers.RequiresNativeProof(source) and N.Model.Status(id)==nil)
        local rewards=N.Rewards.Read(id);assert(not rewards.recordedGroups and rewards.items.state=="unavailable")
        assert(not N.SearchModel:Eligibility({id=id,source=source},N.Character:Get()))
    end
    local cached=N.Providers.Source(95951);assert(cached.title=="Fetch 'n' Fletch" and cached.level==38 and cached.minimum==36)
    local reused=N.Providers.Source(7790);assert(reused.title=="River Ends" and reused.confirmation=="published" and reused.itemState=="published-empty")
    local a,b=N.Rewards.Read(7201),N.Rewards.Read(3911)
    assert(a.recordedGroups and a.items.state=="pending" and #a.choices.items==2 and a.choices.items[2].itemID==270119)
    assert(b.recordedGroups and #b.items.items==1 and b.items.items[1].itemID==12038 and #b.choices.items==0)
    local dark=N.Rewards.Read(7850);assert(dark.items.state=="pending" and #dark.choices.items==4)
    assert(N.Catalog:Category(2039).sourceZoneID==38 and N.Providers.Source(2039).locations[1].mapID==1455)
    local arrows=N.Rewards.Read(7341);assert(arrows.items.items[1].quantity==200)
end)

test("new guaranteed-only variants retain five potions unknown choices and native authority",function()
    local N=W.Init();W.rewardReady=false;C_Item={IsItemDataCachedByID=function()return false end}
    assert(N.Catalog:Begin());while N.Catalog:Step() do end
    for _,id in ipairs({89013,91608}) do
        local source=N.Providers.Source(id);local rewards=N.Rewards.Read(id)
        assert(source.title=="Gettin' Buzzed" and source.level==48 and source.minimum==45 and source.eligibilityUnknown)
        assert(N.Model.Status(id)==nil and N.Providers.Availability({id=id,source=source},{level=60}).state=="unknown")
        assert(rewards.recordedGroups and rewards.items.state=="published" and #rewards.items.items==3)
        assert(rewards.items.items[1].itemID==290333 and rewards.items.items[2].itemID==250999 and rewards.items.items[3].itemID==250955)
        assert(rewards.items.items[3].quantity==5 and rewards.choices.state=="pending" and #rewards.choices.items==0)
        assert(N.Catalog:Category(id).sourceZoneID==16 and not source.locations and not source.faction)
    end
    local tracker=N.Providers.Source(614);assert(tracker.questKind=="hidden-trigger" and N.Providers.RequiresNativeProof(tracker))
    local partial=N.Rewards.Read(614);assert(partial.items.state=="pending" and #partial.choices.items==2)
    W.rewardReady=true;W.items={};W.choices={}
    local native=N.Rewards.Read(89013)
    assert(not native.recordedGroups and native.items.state=="ready" and native.choices.state=="ready" and #native.items.items==0)
    GetNumQuestLogChoices=function()return nil end
    local ambiguous=N.Rewards.Read(91608);assert(not ambiguous.recordedGroups and ambiguous.choices.state=="unavailable")
end)

test("receipted partial choices leave guaranteed rewards pending and native groups authoritative",function()
    local N=W.Init();W.rewardReady=false
    C_Item={IsItemDataCachedByID=function()return false end}
    assert(N.Catalog:Begin());while N.Catalog:Step() do end
    for _,case in ipairs({{206,4125,270096,270097},{608,4138,270092,270093},{611,4120,270076,270077},
        {630,4118,270226},{762,4987,270088,270089},{1139,6723,270095},{1166,10702,270086,270087},
        {8551,11469,270100},{8554,4130,270109,270110},{97282,281274,287060},{98025,281289,287062},{98093,279391,287064}}) do
        local rewards=N.Rewards.Read(case[1])
        assert(rewards.recordedGroups and rewards.items.state=="pending" and #rewards.items.items==0)
        assert(rewards.choices.state=="published" and #rewards.choices.items==#case-1)
        for index,item in ipairs(rewards.choices.items) do assert(item.itemID==case[index+1] and item.quantity==1 and item.group=="choice") end
    end
    W.rewardReady=true;W.items={};W.choices={}
    local native=N.Rewards.Read(630)
    assert(not native.recordedGroups and native.items.state=="ready" and native.choices.state=="ready")
    GetNumQuestLogChoices=function()return nil end
    local ambiguous=N.Rewards.Read(630)
    assert(not ambiguous.recordedGroups and ambiguous.choices.state=="unavailable" and #ambiguous.choices.items==0)
    for _,id in ipairs({5668,5669,5670,5671}) do
        local source=N.Providers.Source(id)
        assert(source.confirmation=="unconfirmed" and source.itemState=="unknown" and N.Providers.RequiresNativeProof(source))
    end
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
        W.Event("PLAYER_ENTERING_WORLD")
        local locations=N.Catalog:Locations(682)
        assert(#locations==(faction=="Unknown" and 0 or 1))
        assert(#N.Providers.ForNPC(11)==(faction=="Alliance" and 1 or 0))
        assert(#N.Providers.ForNPC(22)==(faction=="Horde" and 1 or 0))
    end
end)

local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn();PASSED=PASSED+1;print("PASS "..name) end
local function setup()
    local N=W.Init()
    -- Focus this suite on the character owner's registered handler. Integrated
    -- finder/QuestState suites exercise delivery through the complete addon.
    for _,frame in ipairs(W.frames)do frame:UnregisterAllEvents()end
    local reads={identity=0,location=0,equipment=0,quest=0,dispatch=0}
    local native={level=20,faction="Alliance",map=10,gear={},cache={},active={},complete={},done={}}
    local slots={HeadSlot=1,NeckSlot=2,ShoulderSlot=3,ShirtSlot=4,ChestSlot=5,WaistSlot=6,LegsSlot=7,FeetSlot=8,WristSlot=9,HandsSlot=10,Finger0Slot=11,Finger1Slot=12,Trinket0Slot=13,Trinket1Slot=14,BackSlot=15,MainHandSlot=16,SecondaryHandSlot=17,RangedSlot=18,TabardSlot=19}
    UnitLevel=function()reads.identity=reads.identity+1;return native.level end
    UnitFactionGroup=function()return native.faction end
    GetInventorySlotInfo=nil
    C_PaperDollInfo={GetInventorySlotInfo=function(name)return slots[name] end}
    GetInventoryItemID=function(_,slot)reads.equipment=reads.equipment+1;return native.gear[slot] and native.gear[slot].id end
    GetInventoryItemLink=function(_,slot)return native.gear[slot] and native.gear[slot].link end
    ItemLocation={CreateFromEquipmentSlot=function(_,slot)return {slot=slot} end}
    C_Item={DoesItemExist=function(location)local item=native.gear[location.slot];if item and item.exists==nil then return true end;return item and item.exists or false end,
        IsItemDataCachedByID=function(id)return native.cache[id]==true end}
    C_Map={GetBestMapForUnit=function()reads.location=reads.location+1;return native.map end,
        GetMapInfo=function(id)return {name="Map "..id,mapType=3,parentMapID=id==10 and 9 or 0} end}
    GetInstanceInfo=function()return "Instance","party",1,"Normal",5,0,false,100 end
    C_SpecializationInfo={GetActiveSpecGroup=function()return native.group or 1 end,GetSpecialization=function()return 1 end,
        GetSpecializationInfo=function()return 1491 end,GetCombatConfigIDForSpecGroup=function(group)return group+1000 end}
    C_QuestLog.IsOnQuest=function(id)reads.quest=reads.quest+1;return native.active[id]==true end
    C_QuestLog.IsComplete=function(id)return native.complete[id]==true end
    C_QuestLog.IsQuestFlaggedCompleted=function(id)return native.done[id]==true end
    C_QuestLog.IsRepeatableQuest=function()return false end
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    N.Search={Visible=function()return native.visible==true end,CharacterChanged=function(_,change)reads.dispatch=reads.dispatch+1;reads.change=change end}
    N.Hover={open=false};N.QuestState={active={},offers={},stale=false}
    assert(loadfile(ROOT.."/FindAnUpgrade/Character.lua"))("FindAnUpgrade",N)
    local C=N.Character;C:Initialize()
    local function tick()local fn=C.events:GetScript("OnUpdate");if fn then fn(C.events,.016) end end
    local function reset()for key in pairs(reads)do reads[key]=nil end;reads.identity,reads.location,reads.equipment,reads.quest,reads.dispatch=0,0,0,0,0 end
    return N,C,native,reads,tick,reset
end

test("initialization is dormant and first consumer captures one typed character snapshot",function()
    local N,C,native,reads=setup();assert(reads.identity==0 and reads.location==0 and reads.equipment==0)
    local snapshot=C:Get()
    assert(snapshot.level==20 and snapshot.faction=="Alliance" and snapshot.classToken=="WARRIOR" and snapshot.classID==1)
    assert(snapshot.specID==1491 and snapshot.talentGroup==1 and snapshot.combatConfigID==1001)
    assert(snapshot.mapID==10 and snapshot.instanceType=="party" and snapshot.instanceID==100 and #snapshot.mapHierarchy==2)
    assert(snapshot.emptySlots[1] and snapshot.emptySlots[19] and not snapshot.filter and not snapshot.sort)
    assert(reads.identity==1 and reads.location==1 and reads.equipment==19)
    assert(C:Get()==snapshot and reads.identity==1)
end)

test("character owns no quest event scanner or permanent updater",function()
    local N,C=setup()
    for event in pairs(C.events.events)do assert(not event:find("QUEST_",1,true))end
    assert(not C.events:GetScript("OnUpdate"))
end)

test("equipment burst publishes one coherent replacement for slot filtering and ranking",function()
    local N,C,native,reads,tick,reset=setup();local old=C:Get();native.visible=true;reset()
    native.gear[1]={id=123,link="item:123:7:0:0:0:0:8"};native.cache[123]=true
    for _=1,100 do W.Event("PLAYER_EQUIPMENT_CHANGED",1,true)end
    assert(reads.equipment==0);tick();local current=C:Get()
    assert(reads.equipment==19 and reads.dispatch==1 and reads.change.equipment)
    assert(current~=old and current.equipmentRevision==old.equipmentRevision+1)
    assert(old.emptySlots[1] and old.equipment[1].state=="empty")
    assert(not current.emptySlots[1] and current.equipment[1].state=="ready" and current.equipment[1].link==native.gear[1].link)
    assert(not C.events:GetScript("OnUpdate"))
end)

test("equal equipment events preserve snapshot identity revisions and visible results",function()
    local N,C,native,reads,tick,reset=setup();local old=C:Get();native.visible=true;reset()
    for _=1,100 do W.Event("PLAYER_EQUIPMENT_CHANGED",1,false)end;tick()
    assert(C:Get()==old and reads.dispatch==0 and reads.equipment==19)
end)

test("nil links or occupied uncached items never become an empty slot",function()
    local N,C,native=setup();native.gear[1]={exists=true};native.gear[2]={id=123,exists=true}
    local snapshot=C:Get()
    assert(snapshot.equipment[1].state=="pending" and snapshot.equipment[2].state=="pending")
    assert(not snapshot.emptySlots[1] and not snapshot.emptySlots[2])
end)

test("hidden world zone equipment and item bursts defer every native capture until reopen",function()
    local N,C,native,reads,tick,reset=setup();C:Get();reset()
    for _=1,500 do W.Event("PLAYER_ENTERING_WORLD");W.Event("ZONE_CHANGED");W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);W.Event("ITEM_DATA_LOAD_RESULT",123,true)end
    tick();assert(reads.identity==0 and reads.location==0 and reads.equipment==0 and reads.dispatch==0 and not C.events:GetScript("OnUpdate"))
    native.level=30;native.map=20;native.gear[1]={id=123,link="item:123"};native.cache[123]=true
    local snapshot=C:Get();assert(snapshot.level==30 and snapshot.mapID==20 and snapshot.equipment[1].itemID==123)
    assert(reads.identity==1 and reads.location==1 and reads.equipment==19)
end)

test("level-up payload wins when UnitLevel has not updated yet",function()
    local N,C,native,reads,tick=setup();local old=C:Get();native.visible=true
    W.Event("PLAYER_LEVEL_UP",21);tick()
    assert(C:Get().level==21 and C:Get().identityRevision==old.identityRevision+1 and native.level==20)
end)

test("world burst captures each family once and advances the global revision once",function()
    local N,C,native,reads,tick,reset=setup();local old=C:Get();native.visible=true;reset()
    native.level=30;native.map=20;native.gear[1]={id=123,link="item:123"};native.cache[123]=true
    for _=1,100 do W.Event("PLAYER_ENTERING_WORLD")end;tick();local now=C:Get()
    assert(reads.dispatch==1 and reads.identity==1 and reads.location==1 and reads.equipment==19)
    assert(now.revision==old.revision+1 and reads.change.identity and reads.change.location and reads.change.equipment)
end)

test("zone hierarchy cycles are bounded and equal zone events do not publish",function()
    local N,C,native,reads,tick=setup()
    C_Map.GetMapInfo=function(id)return {name="Map "..id,mapType=3,parentMapID=id==10 and 9 or 10}end
    local old=C:Get();assert(#old.mapHierarchy==2);native.visible=true
    for _=1,100 do W.Event("ZONE_CHANGED_NEW_AREA")end;tick();assert(C:Get()==old and reads.dispatch==0)
end)

test("stale item responses cannot resurrect replaced equipped links",function()
    local N,C,native,reads,tick,reset=setup();native.gear[1]={id=123,link="item:123"};C:Get();native.visible=true
    native.gear[1]={id=124,link="item:124"};native.cache[124]=true;W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);tick();reset()
    local current=C:Get();native.cache[123]=true;for _=1,100 do W.Event("ITEM_DATA_LOAD_RESULT",123,true)end;tick()
    assert(C:Get()==current and reads.dispatch==0 and reads.equipment==0 and current.equipment[1].itemID==124)
end)

test("current item readiness advances shared equipment dependency once",function()
    local N,C,native,reads,tick,reset=setup();native.gear[1]={id=123,link="item:123"};local old=C:Get();native.visible=true;reset()
    native.cache[123]=true;for _=1,100 do W.Event("ITEM_DATA_LOAD_RESULT",123,true);W.Event("GET_ITEM_INFO_RECEIVED",123,true)end;tick()
    local current=C:Get();assert(current.equipmentRevision==old.equipmentRevision+1 and current.itemRevision==old.itemRevision+1 and reads.dispatch==1)
    reset();for _=1,100 do W.Event("ITEM_DATA_LOAD_RESULT",123,true)end;tick();assert(C:Get()==current and reads.dispatch==0)
end)

test("equipping an identical ID with another exact link changes equipment identity",function()
    local N,C,native,reads,tick=setup();native.gear[1]={id=123,link="item:123:1"};native.cache[123]=true;local old=C:Get();native.visible=true
    native.gear[1].link="item:123:2";W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);tick()
    assert(C:Get().equipmentRevision==old.equipmentRevision+1 and old.equipment[1].link=="item:123:1")
end)

test("native quest false facts remain false and repeated consumers share one observation",function()
    local N,C,native,reads=setup();local a=C:Quest(9);local b=C:Quest(9)
    assert(a==b and a.active==false and a.completed==false and a.repeatable==false and a.disabled==false and reads.quest==1)
    N.QuestState.active[9]=false;C:PrimeQuests(N.QuestState.active,N.QuestState.offers,true)
    local fact=C:Quest(9);assert(fact.active==true and fact.complete==false)
end)

test("targeted quest transition invalidates one fact and never mutates the previous snapshot",function()
    local N,C,native,reads=setup();C:Quest(9);local untouched=C:Quest(14);local old=C:Get()
    N.QuestState.active[9]=false;N.QuestState.offers[30]="native-map-available"
    C:QuestChanged({ids={[9]=true},reason="QUEST_ACCEPTED"});local current=C:Get()
    assert(not old.quests.active[9] and not old.quests.offers[30] and current.quests.active[9]==false)
    N.QuestState.active[14]=true;assert(current.quests.active[14]==nil)
    assert(C:Quest(14)==untouched and C:Quest(9).active==true and current.questRevision==old.questRevision+1)
end)

test("hidden quest reconciliation expires old completion cache without a second scanner",function()
    local N,C,native,reads=setup();assert(C:Quest(9).completed==false);native.done[9]=true
    N.QuestState.stale=true;N.QuestState.Prime=function(self)self.stale=false;C:PrimeQuests(self.active,self.offers,true)end
    assert(C:Get() and C:Quest(9).completed==true and reads.quest==2)
end)

test("quest cache stays bounded and unknown beyond capacity never becomes false",function()
    local N,C,native,reads=setup();C.questLimit=2;C:Quest(9);C:Quest(14)
    local result=C:Quest(30);assert(result.active==nil and result.completed==nil and reads.quest==2)
end)

test("equipped metadata stamps coalesce and duplicate or stale responses have no effect",function()
    local N,C,native,reads,tick,reset=setup();native.gear[1]={id=123,link="item:123"};native.cache[123]=true
    local old=C:Get();native.visible=true;reset()
    for _=1,100 do assert(C:EquipmentMetadata(123,"complete-stats-v1",old.equipmentRevision))end;tick()
    local now=C:Get();assert(reads.dispatch==1 and reads.equipment==0 and now.itemRevision==old.itemRevision+1 and now.equipmentRevision==old.equipmentRevision+1)
    reset();assert(not C:EquipmentMetadata(123,"complete-stats-v1",now.equipmentRevision))
    assert(not C:EquipmentMetadata(123,"stale-stats-v2",old.equipmentRevision))
    assert(not C:EquipmentMetadata(999,"unrelated",now.equipmentRevision));tick();assert(reads.dispatch==0 and C:Get()==now)
end)

test("a queued metadata response cannot outlive an intervening equipment replacement",function()
    local N,C,native,reads,tick=setup();native.gear[1]={id=123,link="item:123"};native.cache[123]=true
    local old=C:Get();native.visible=true;C:EquipmentMetadata(123,"old-response",old.equipmentRevision)
    native.gear[1]={id=124,link="item:124"};native.cache[124]=true;W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);tick()
    assert(C:Get().equipment[1].itemID==124 and C.equipmentStamps[123]==nil)
end)

test("quest tags cache explicit unknown and only targeted changed metadata advances facts",function()
    local N,C,native,reads=setup();local calls=0;local tag
    C_QuestLog.GetQuestTagInfo=function()calls=calls+1;return tag and {tagID=tag} end
    assert(C:QuestTag(9)==nil and C:QuestTag(9)==nil and calls==1)
    native.visible=true;local old=C:Get();tag=81
    assert(C:QuestMetadata(9)==true and C:QuestTag(9)==81 and calls==2 and C:Get().questRevision==old.questRevision+1)
    assert(C:QuestMetadata(9)==false and calls==3)
    assert(C:QuestMetadata(14)==false and calls==3)
end)

test("hidden targeted tag invalidation waits for a consumer without native calls",function()
    local N,C,native,reads=setup();local calls=0
    C_QuestLog.GetQuestTagInfo=function()calls=calls+1;return {tagID=81}end
    assert(C:QuestTag(9)==81 and calls==1);assert(C:QuestMetadata(9)==false and calls==1)
    assert(C:QuestTag(9)==81 and calls==2)
end)

test("capability signals coalesce independently without pretending to capture a spellbook",function()
    local N,C,native,reads,tick,reset=setup();local old=C:Get();native.visible=true;reset()
    for _=1,100 do W.Event("SPELLS_CHANGED");W.Event("SKILL_LINES_CHANGED")end;tick()
    local now=C:Get();assert(now.capabilityRevision==old.capabilityRevision+1 and reads.dispatch==1 and reads.change.capabilities)
    assert(reads.identity==0 and reads.location==0 and reads.equipment==0 and now.identityRevision==old.identityRevision)
    native.visible=false;reset();for _=1,100 do W.Event("SPELLS_CHANGED")end;tick()
    assert(reads.dispatch==0 and not C.events:GetScript("OnUpdate") and C.snapshot==now)
    assert(C:Get().capabilityRevision==now.capabilityRevision+1)
end)

test("a synchronous consumer cannot swallow the pending visible equipment notification",function()
    local N,C,native,reads,tick,reset=setup();C:Get();native.visible=true;reset()
    native.gear[1]={id=123,link="item:123"};native.cache[123]=true
    W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);local snapshot=C:Get()
    assert(snapshot.equipment[1].itemID==123 and reads.dispatch==1);tick();assert(reads.dispatch==1)
end)

test("warm cached quest reads take the clean snapshot path without Flush allocations",function()
    local N,C,native,reads=setup();C:Quest(900);local calls=0;local flush=C.Flush
    C.Flush=function(self,...)calls=calls+1;return flush(self,...)end
    for _=1,1000 do C:Quest(900)end
    assert(calls==0 and reads.quest==1)
end)

test("rotating equipped identities cannot retain an unbounded metadata stamp history",function()
    local N,C,native,reads,tick=setup();C:Get();native.visible=true
    for id=100,399 do
        native.gear[1]={id=id,link="item:"..id};native.cache[id]=true;W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);tick()
        assert(C:EquipmentMetadata(id,"stats:"..id,C:Get().equipmentRevision));tick()
    end
    local count=0;for _ in pairs(C.equipmentStamps)do count=count+1 end
    assert(count==1 and C.equipmentStamps[399]=="stats:399")
end)

test("a reentrant context getter cannot cancel a new level event during equipment capture",function()
    local N,C,native,reads,tick,reset=setup();C:Get();native.visible=true;reset()
    local original=GetInventoryItemID;local injected=false
    GetInventoryItemID=function(...)
        if not injected then injected=true;W.Event("PLAYER_LEVEL_UP",21);C:Get()end
        return original(...)
    end
    native.gear[1]={id=123,link="item:123"};W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);tick()
    assert(C.events:GetScript("OnUpdate") and C.dirty.identity);tick()
    assert(C:Get().level==21 and not C.events:GetScript("OnUpdate") and not next(C.dirty))
end)

test("a synchronous quest transition survives a concurrent non-quest capture publication",function()
    local N,C,native,reads,tick=setup();local old=C:Get();native.visible=true
    local original=GetInventoryItemID;local injected=false
    GetInventoryItemID=function(...)
        if not injected then
            injected=true;N.QuestState.active[9]=false;C:QuestChanged({ids={[9]=true},reason="QUEST_ACCEPTED"})
        end
        return original(...)
    end
    native.gear[1]={id=123,link="item:123"};W.Event("PLAYER_EQUIPMENT_CHANGED",1,true);tick()
    local now=C:Get();assert(now.quests.active[9]==false and now.questRevision==old.questRevision+1 and now.equipment[1].itemID==123)
end)

local function worldFinder()
    local N=W.Init();C_QuestLine=nil;Questie=nil
    local done,rows={},{}
    for i=1,40 do rows[i]={id=490000+i,title="World quest "..i,level=20,confirmation="published",itemState="published",
        items={{itemID=3000+i,name="Item "..i,quantity=1,group="guaranteed"}},locations={{npcID=50000+i,name="Giver "..i}}}end
    N.CatalogData={schemaVersion=2,quests=rows}
    Enum.UIMapType={Zone=3,Dungeon=4}
    C_Map={GetBestMapForUnit=function()return 10 end,GetMapInfo=function()return {name="Test zone",mapType=3}end,GetAreaInfo=function()return "Test zone"end}
    N.Data.categories={{name="Test zone",sourceZoneID=100}};N.Data.categoryById={}
    for _,row in ipairs(rows)do N.Data.categoryById[row.id]=1 end
    W.rewardReady=false
    C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.IsComplete=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function(id)return done[id]==true end
    C_QuestLog.IsQuestDisabledForSession=function()return false end;C_QuestLog.IsRepeatableQuest=function()return false end
    C_QuestLog.GetTitleForQuestID=function(id)return "World quest "..id end;C_QuestLog.GetQuestDifficultyLevel=function()return 20 end
    local scans=0;C_QuestLog.GetNumQuestLogEntries=function()scans=scans+1;return 0 end;C_QuestLog.GetInfo=function()error("empty log")end
    C_Item={IsItemDataCachedByID=function()return true end,
        GetItemInfo=function(id)return "Item "..id,"item:"..id,2,20,1,"Armor","Cloth",1,"INVTYPE_HEAD",100 end,
        GetItemInfoInstant=function(id)return id,"Armor","Cloth","INVTYPE_HEAD",100,4 end}
    N.Core:Slash("");local S=N.Search
    local function tick(count)
        for _=1,count do W.time=W.time+.1;N.Character.events:Fire("OnUpdate",.1);S:Tick()end
    end
    tick(100)
    local function contains(id)for _,row in ipairs(S.results)do if row.id==id then return true end end;return false end
    return N,S,done,tick,contains,function()return scans end
end

test("world entry refreshes completed evidence outside an empty active log with equal character families",function()
    local N,S,done,tick,contains,scans=worldFinder();assert(contains(490001) and N.Character:Quest(490001).completed==false)
    local before=N.Character:Get();local priorScans=scans();local queries=0;local query=N.SearchModel.Query
    N.SearchModel.Query=function(self,...)queries=queries+1;return query(self,...)end
    done[490001]=true
    for _=1,100 do W.Event("PLAYER_ENTERING_WORLD",false,false)end;tick(20)
    local now=N.Character:Get()
    assert(not contains(490001) and queries==1 and not N.QuestState.stale and scans()==priorScans+1)
    assert(now.identityRevision==before.identityRevision and now.locationRevision==before.locationRevision and now.equipmentRevision==before.equipmentRevision)
    assert(now.questRevision>before.questRevision and N.Character:Quest(490001).completed==true)
end)

test("hidden equal-context world entry keeps native work deferred and reopens with fresh completion",function()
    local N,S,done,tick,contains,scans=worldFinder();assert(contains(490001));S.frame:Hide()
    local beforeScans=scans();local queries=0;local query=N.SearchModel.Query
    N.SearchModel.Query=function(self,...)queries=queries+1;return query(self,...)end
    done[490001]=true
    for _=1,100 do W.Event("PLAYER_ENTERING_WORLD",false,false)end
    assert(scans()==beforeScans and queries==0 and not N.Character.events:GetScript("OnUpdate"))
    N.Core:Slash("");tick(20)
    assert(not contains(490001) and queries==1 and scans()==beforeScans+1 and not N.QuestState.stale)
end)

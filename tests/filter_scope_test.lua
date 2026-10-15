local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function resetFacts(N)
    N.Character.questFacts={};N.Character.questFactCount=0
    N.Character.questTags={};N.Character.questTagCount=0
end
local function setup()
    local N=W.Init();W.rewardReady=false
    local active,done,tags={},{},{}
    C_QuestLog.IsOnQuest=function(id)return active[id]==true end
    C_QuestLog.IsComplete=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function(id)return done[id]==true end
    C_QuestLog.IsRepeatableQuest=function()return false end
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    C_QuestLog.GetQuestTagInfo=function(id)return tags[id] and {tagID=tags[id]} end
    C_QuestLine=nil
    Enum.UIMapType={Zone=3,Dungeon=4,Micro=5}
    C_Map={GetBestMapForUnit=function()return 101 end,
        GetMapInfo=function(id)return {name=id==101 and "Alpha localized" or "Beta localized",mapType=3,parentMapID=0} end,
        GetAreaInfo=function(id)return id==11 and "Alpha localized" or id==22 and "Beta localized" end}
    N.Data.categories={{name="Alpha",sourceZoneID=11},{name="Beta",sourceZoneID=22}}
    N.Data.categoryById={[91001]=1,[91002]=2,[91004]=1,[91005]=2,[91006]=2}
    N.QuestTags={[91003]=81,[91004]=81,[91005]=1,[91006]=62}
    local rows={}
    for id=91001,91007 do rows[#rows+1]={id=id,title="Quest "..id,level=20,minimum=1,
        items={},confirmation="published",rewardValues={xp=100},locations={{npcID=id}}} end
    N.CatalogData={schemaVersion=2,quests=rows}
    N.Character.dirty.identity,N.Character.dirty.location,N.Character.dirty.equipment=true,true,true
    N.QuestState.stale=true;N.Character.questPrimed=false;resetFacts(N)
    N.Catalog:Begin();while N.Catalog:Step() do end
    return N,rows,{query="",minimum=15,maximum=23,slot="ALL",usable=false,sort="FIT"},active,done,tags
end
local function ids(rows)
    local set={};for _,row in ipairs(rows) do set[row.id]=true end;return set
end

test("Same zone is the default exact primary-category filter with known dungeons excluded",function()
    local N,_,filter=setup();local rows,status=N.SearchModel:Query(filter)
    assert(#rows==1 and rows[1].id==91001 and status==nil)
end)

test("level mode broadens membership while keeping the same selected level interval",function()
    local N,source,filter=setup();filter.scope="LEVEL_RANGE"
    source[2].level=40;N.Catalog.records[91002].metadataReady=nil
    local rows=N.SearchModel:Query(filter);local seen=ids(rows)
    assert(#rows==4 and seen[91001] and seen[91005] and seen[91006] and seen[91007])
    filter.maximum=40;rows=N.SearchModel:Query(filter);assert(ids(rows)[91002])
    filter.scope="SAME_ZONE";assert(#N.SearchModel:Query(filter)==1)
    assert(filter.minimum==15 and filter.maximum==40)
end)

test("Dungeon checkbox adds only tag81 including no-primary-category exact IDs",function()
    local N,_,filter=setup();filter.includeDungeons=true
    local rows=N.SearchModel:Query(filter);local seen=ids(rows)
    assert(#rows==3 and seen[91001] and seen[91003] and seen[91004])
    assert(not seen[91005] and not seen[91006] and not seen[91007])
end)

test("Dungeon additions never escape the inclusive level interval",function()
    local N,source,filter=setup();filter.includeDungeons=true
    source[3].level=24;N.Catalog.records[91003].metadataReady=nil
    assert(not ids(N.SearchModel:Query(filter))[91003])
    source[3].level=23;N.Catalog.records[91003].metadataReady=nil
    assert(ids(N.SearchModel:Query(filter))[91003])
    filter.minimum=23;assert(#N.SearchModel:Query(filter)==1)
end)

test("giver map and matching quest title cannot invent primary-category membership",function()
    local N,source,filter=setup()
    source[2].locations={{npcID=99,mapID=101,x=.5,y=.5}};source[2].title="Alpha localized"
    N.Catalog.records[91002].metadataReady=nil
    assert(not ids(N.SearchModel:Query(filter))[91002])
end)

test("missing and ambiguous current category return a recoverable status without world fallback",function()
    local N,_,filter=setup()
    C_Map.GetAreaInfo=function()return nil end;N.Catalog.categorySource=nil
    local rows,status=N.SearchModel:Query(filter)
    assert(#rows==0 and status and status:find("Level range",1,true))
    filter.includeDungeons=true;rows,status=N.SearchModel:Query(filter)
    assert(#rows==2 and status and ids(rows)[91003] and ids(rows)[91004])
    C_Map.GetAreaInfo=function()return "Alpha localized" end;N.Catalog.categorySource=nil
    rows,status=N.SearchModel:Query(filter);assert(#rows==2 and status)
end)

test("unknown native tag preserves explicit type while a different native tag wins",function()
    local N,_,filter,_,_,tags=setup();filter.includeDungeons=true
    assert(ids(N.SearchModel:Query(filter))[91003])
    tags[91003]=62;N.Character:QuestMetadata(91003)
    assert(not ids(N.SearchModel:Query(filter))[91003])
    tags[91003]=nil;N.Character:QuestMetadata(91003)
    assert(ids(N.SearchModel:Query(filter))[91003])
end)

test("unknown native type and text containing Dungeon never supply an addition",function()
    local N,source,filter=setup();filter.includeDungeons=true
    source[7].title="Dungeon quest from Alpha";source[7].locations={{npcID=1,mapID=101}}
    assert(not ids(N.SearchModel:Query(filter))[91007])
end)

test("Dungeon additions require typed eligible starters and resolved chain branches",function()
    local N,source,filter,_,done=setup();filter.includeDungeons=true
    source[3].locations={};assert(not ids(N.SearchModel:Query(filter))[91003])
    source[3].locations={{itemID=40}};source[3].prerequisites={50}
    assert(not ids(N.SearchModel:Query(filter))[91003])
    filter.scope="LEVEL_RANGE"
    assert(not ids(N.SearchModel:Query(filter))[91003])
    filter.scope="SAME_ZONE"
    done[50]=true;N.Character:QuestChanged({ids={[50]=true}})
    assert(ids(N.SearchModel:Query(filter))[91003])
    source[3].locations={{objectID=40,faction="Horde"}}
    assert(not ids(N.SearchModel:Query(filter))[91003])
end)

test("unreadable chain completion cannot become an obtainable dungeon addition",function()
    local N,source,filter=setup();filter.includeDungeons=true;source[3].prerequisites={50}
    C_QuestLog.IsQuestFlaggedCompleted=function()return nil end;resetFacts(N)
    assert(not ids(N.SearchModel:Query(filter))[91003])
    source[3].prerequisites={50,50}
    assert(not ids(N.SearchModel:Query(filter))[91003])
end)

test("native active quest remains an eligible dungeon addition with stale source gates",function()
    local N,source,filter,active=setup();filter.includeDungeons=true
    source[3].faction="Horde";source[3].locations={};source[3].prerequisites={50}
    active[91003]=true;N.Character:QuestChanged({ids={[91003]=true}})
    assert(ids(N.SearchModel:Query(filter))[91003])
end)

test("historical and hidden dungeon records still need current native authority",function()
    local N,source,filter,active=setup();filter.includeDungeons=true
    source[3].confirmation="historical";source[4].questKind="hidden-trigger"
    local rows=N.SearchModel:Query(filter);assert(not ids(rows)[91003] and not ids(rows)[91004])
    active[91003],active[91004]=true,true;N.Character:QuestChanged({ids={[91003]=true,[91004]=true}})
    rows=N.SearchModel:Query(filter);assert(ids(rows)[91003] and ids(rows)[91004])
end)

test("out-of-scope rows create no reward or missing metadata requests",function()
    local N,source,filter=setup()
    source[7].title,source[7].level=nil,nil
    N.Catalog.records[91007].metadataReady=nil
    N.SearchModel:Query(filter)
    assert(#N.SearchModel.questNeeded==0 and #N.SearchModel.needed==0)
    assert(next(W.rewardRequests)==nil)
end)

test("queries reuse the central location and equipment snapshot with no fresh context reads",function()
    local N,_,filter=setup();local reads=0
    N.SearchModel:Query(filter)
    UnitFactionGroup=function()reads=reads+1;error("context reread")end
    UnitLevel=function()reads=reads+1;error("context reread")end
    C_Map.GetBestMapForUnit=function()reads=reads+1;error("map reread")end
    GetInventorySlotInfo=function()reads=reads+1;error("equipment reread")end
    for _=1,50 do assert(#N.SearchModel:Query(filter)==1) end
    assert(reads==0)
end)

test("upgrade comparator uses precomputed tier and ready gain with stable fallback",function()
    local N,source,filter=setup();filter.scope="LEVEL_RANGE";filter.includeDungeons=true;filter.sort="UPGRADE"
    local ranks={[91001]={tier=1,gain=5,state="ready"},[91002]={tier=1,gain=10,state="ready"},
        [91003]={tier=2,state="unsupported"},[91004]={tier=3,gain=-2,state="ready"},
        [91005]={tier=3,gain=0,state="ready"},[91006]={tier=2,state="pending"},[91007]={tier=2,state="none"}}
    for _,row in ipairs(source) do row.items={{itemID=row.id}};N.Catalog.records[row.id].items=row.items end
    N.SearchModel.Item=function(_,item)return {itemID=item.itemID,state="ready",name="Gear",minimum=1,slot="INVTYPE_HEAD"} end
    local calls=0;N.Ranking={Style=function()return {} end,Quest=function(_,items)calls=calls+1;return ranks[items[1].itemID] end}
    local rows=N.SearchModel:Query(filter)
    assert(#rows==7 and calls==7 and rows[1].id==91002 and rows[2].id==91001)
    assert(rows[3].id==91003 and rows[4].id==91006 and rows[5].id==91007 and rows[6].id==91005 and rows[7].id==91004)
end)

local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup(rows)
    local N=W.Init();W.rewardReady=false
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    C_QuestLog.IsOnQuest=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLine=nil;C_GossipInfo=nil
    C_Item={IsItemDataCachedByID=function()return true end,
        GetItemInfo=function(id)return "Item "..id,"item:"..id,2,20,1,"Armor","Cloth",1,"INVTYPE_HEAD",100 end}
    for i,row in ipairs(rows) do
        row.id,row.title,row.level,row.confirmation,row.itemState,row.items=980000+i,"Quest "..i,row.level or 20,row.confirmation or "published",row.itemState or "published-empty",row.items or {}
    end
    N.CatalogData={schemaVersion=2,quests=rows}
    N.Catalog:Begin();while N.Catalog:Step() do end
    return N,rows,{query="",minimum=1,maximum=200,slot="ALL",usable=false,sort="FIT"}
end
local function npc()return {{npcID=54001,name="Known giver"}} end

test("all rewards includes known positive amounts with NPC object and nonfixed item starts",function()
    local N,_,filter=setup({
        {locations=npc(),rewardValues={xp=100}},
        {locations={{objectID=54002,name="Known object"}},rewardValues={money=50}},
        {locations={{itemID=54003,name="Known item"}},rewardValues={reputation={{name="Stormwind",amount=25}}}},
        {rewardValues={xp=100}},
        {locations=npc(),rewardValues={xp=0,money=0,reputation={{name="Stormwind",amount=-25}}},moneyCost=50},
        {locations=npc(),items={{itemID=123,name="Useful item",quantity=1,group="choice"}}},
    })
    local result=N.SearchModel:Query(filter);local seen={}
    for _,row in ipairs(result) do seen[row.id]=true end
    assert(#result==4 and seen[980001] and seen[980002] and seen[980003] and seen[980006])
    assert(not seen[980004] and not seen[980005])
    assert(#result[1].items==0)
end)

test("specific equipment filters exclude amount-only quests",function()
    local N,_,filter=setup({{locations=npc(),rewardValues={xp=100}},{locations=npc(),items={{itemID=123,name="Useful item"}}}})
    filter.slot="INVTYPE_HEAD"
    local result=N.SearchModel:Query(filter)
    assert(#result==1 and result[1].id==980002 and #result[1].items==1)
end)

test("ambiguous reputation duplicate names and costs alone cannot create a benefit",function()
    local N,_,filter=setup({
        {locations=npc(),rewardValues={reputation={{name="Stormwind",amount=200},{name="Stormwind",amount=200}}}},
        {locations=npc(),rewardValues={reputation={{name="Ironforge",amount=0}}}},
        {locations=npc(),rewardValues={money=-10,reputation={{name="Stormwind",amount=-50}}}},
    })
    assert(#N.SearchModel:Query(filter)==0)
end)

test("ready native zero and empty reward sets override a published benefit",function()
    local N,_,filter=setup({{locations=npc(),rewardValues={xp=100}}})
    assert(#N.SearchModel:Query(filter)==1)
    W.rewardReady=true;GetQuestLogRewardXP=function()return 0 end;GetQuestLogRewardMoney=function()return 0 end
    assert(#N.SearchModel:Query(filter)==0)
    C_QuestLog.GetQuestRewardCurrencies=function()return {{currencyID=7,name="Native token",totalRewardAmount=2}} end
    N.SearchModel.currentItems,N.SearchModel.currentStamp={},{}
    assert(#N.SearchModel:Query(filter)==1)
end)

test("current native log gossip and map offers supply a missing start path only while current",function()
    local N,rows,filter=setup({{rewardValues={xp=100}}});local id=rows[1].id
    assert(#N.SearchModel:Query(filter)==0)
    C_QuestLog.IsOnQuest=function(candidate)return candidate==id end
    assert(#N.SearchModel:Query(filter)==1)
    C_QuestLog.IsOnQuest=function()return false end
    C_Map={GetBestMapForUnit=function()return 100 end}
    C_QuestLine={GetAvailableQuestLines=function()return {{questID=id,inProgress=false}} end}
    assert(#N.SearchModel:Query(filter)==1)
    C_QuestLine.GetAvailableQuestLines=function()return {} end
    assert(#N.SearchModel:Query(filter)==0)
    N.Sources.gossip={guid="Current NPC"};UnitGUID=function(unit)return unit=="npc" and "Current NPC" end
    C_GossipInfo={GetAvailableQuests=function()return {{questID=id}} end}
    assert(#N.SearchModel:Query(filter)==1)
    C_GossipInfo.GetAvailableQuests=function()return {} end
    assert(#N.SearchModel:Query(filter)==0)
end)

test("native reputation-only rewards require a resolved faction name",function()
    local N,_,filter=setup({{locations=npc()}})
    W.rewardReady=true;GetQuestLogRewardXP=function()return 0 end;GetQuestLogRewardMoney=function()return 0 end
    C_QuestLog.GetQuestLogMajorFactionReputationRewards=function()return {{factionID=72,rewardAmount=50}} end
    C_Reputation=nil;GetFactionInfoByID=nil
    assert(#N.SearchModel:Query(filter)==0)
    C_Reputation={GetFactionDataByID=function()return {name="Stormwind"} end}
    N.SearchModel.currentItems,N.SearchModel.currentStamp={},{}
    assert(#N.SearchModel:Query(filter)==1)
end)

test("starter faction qualifiers do not become another faction's path",function()
    local N,_,filter=setup({{locations={{npcID=54001,name="Other faction giver",faction="Horde"}},rewardValues={xp=100}}})
    assert(#N.SearchModel:Query(filter)==0)
    UnitFactionGroup=function()return "Horde" end
    assert(#N.SearchModel:Query(filter)==1)
end)

local function zones(N,rows)
    N.Data.categories={{name="Alpha",sourceZoneID=11},{name="Beta",sourceZoneID=22}}
    N.Data.categoryById={[rows[1].id]=1,[rows[2].id]=2}
    Enum.UIMapType={Zone=3,Dungeon=4,Micro=5}
    C_Map={GetBestMapForUnit=function()return 101 end,
        GetMapInfo=function(id)return id==101 and {name="Interior",mapType=5,parentMapID=100} or {name="Localized Alpha",mapType=3} end,
        GetAreaInfo=function(id)return id==11 and "Localized Alpha" or "Localized Beta" end}
end

test("current zone sorting uses exact category membership and localized native parent maps",function()
    local N,rows,filter=setup({{level=30,locations=npc(),rewardValues={xp=100}},{level=20,locations=npc(),rewardValues={xp=100}}})
    zones(N,rows);filter.sort="ZONE"
    local result=N.SearchModel:Query(filter);local categories,name=N.Catalog:CurrentCategories()
    assert(#result==2 and result[1].id==rows[1].id and result[1].currentZone and not result[2].currentZone)
    assert(categories.Alpha and name=="Localized Alpha")
    filter.sort="FIT";result=N.SearchModel:Query(filter)
    assert(result[1].id==rows[2].id)
    filter.sort="LEVEL";result=N.SearchModel:Query(filter)
    assert(result[1].id==rows[2].id)
end)

test("unknown or ambiguous area mapping falls back to level fit without giver inference",function()
    local N,rows,filter=setup({{level=30,locations=npc(),rewardValues={xp=100}},{level=20,locations=npc(),rewardValues={xp=100}}})
    zones(N,rows);filter.sort="ZONE"
    rows[2].locations[1].mapID,rows[2].locations[1].x,rows[2].locations[1].y=100,.5,.5
    C_Map.GetAreaInfo=function()return nil end
    local result=N.SearchModel:Query(filter)
    assert(result[1].id==rows[2].id and not result[1].currentZone and not result[2].currentZone)
    C_Map.GetAreaInfo=function()return "Localized Alpha" end
    result=N.SearchModel:Query(filter)
    assert(result[1].id==rows[2].id and not result[1].currentZone and not result[2].currentZone)
    local _,name=N.Catalog:CurrentCategories();assert(name==nil)
end)

test("native map cycles and restricted names cannot create a zone match",function()
    local N,rows=setup({{locations=npc(),rewardValues={xp=100}},{locations=npc(),rewardValues={xp=100}}})
    zones(N,rows);local calls=0
    C_Map.GetMapInfo=function(id)calls=calls+1;return {name=W.secret,mapType=3,parentMapID=id} end
    local categories,name=N.Catalog:CurrentCategories()
    assert(next(categories)==nil and name==nil and calls==1)
end)

test("a finder query snapshots native offers once instead of rescanning per record",function()
    local rows={};for id=1,20 do rows[id]={locations=npc(),rewardValues={xp=100}} end
    local N,_,filter=setup(rows);local snapshots,proofs=0,0
    N.QuestState={NativeOffers=function()snapshots=snapshots+1;return {[980001]="native-available"} end,
        Proof=function()proofs=proofs+1;return "native-available" end}
    local result=N.SearchModel:Query(filter)
    assert(#result==20 and snapshots==1 and proofs==0)
end)

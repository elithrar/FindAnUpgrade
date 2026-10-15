local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function setup(items,benefits)
    local N=W.Init();W.rewardReady=false
    local allowed,reads={},{}
    C_PlayerInfo={CanUseItem=function(id)reads[id]=(reads[id] or 0)+1;return allowed[id]end}
    C_Item={}
    C_Item.IsItemDataCachedByID=function()return true end
    C_Item.GetItemInfo=function(id)return "Gear "..id,"item:"..id,2,20,1,"Armor","Plate",1,"INVTYPE_CHEST",100,0,4,4 end
    C_QuestLog.IsOnQuest=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLog.IsRepeatableQuest=function()return false end
    C_QuestLog.GetTitleForQuestID=function()end
    C_QuestLog.GetQuestDifficultyLevel=function()end
    C_QuestLog.GetNumQuestLogEntries=function()return 0,0 end
    N.CatalogData={schemaVersion=2,quests={{id=555,title="Plate reward",level=20,minimum=1,
        confirmation="published",itemState="published",items=items or {{itemID=123,quantity=1,group="guaranteed"}},
        rewardValues=benefits or {},locations={{npcID=54}}}}}
    N.QuestState.stale=true;N.Catalog:Begin();while N.Catalog:Step()do end
    return N,allowed,reads,{query="",scope="LEVEL_RANGE",minimum=15,maximum=23,slot="ALL",sort="FIT",usable=true}
end
test("explicit native unusability hides a published reward before quest reward hydration",function()
    local N,use,_,filter=setup();use[123]=false
    assert(#N.SearchModel:Query(filter)==0)
    filter.usable=false;assert(#N.SearchModel:Query(filter)==1)
end)
test("unknown capability stays visible and distinct from explicit false",function()
    local N,_,_,filter=setup();assert(#N.SearchModel:Query(filter)==1)
end)
test("native capability true preserves the reward",function()
    local N,use,_,filter=setup();use[123]=true;assert(#N.SearchModel:Query(filter)==1)
end)
test("mixed choices retain only usable items without losing the quest",function()
    local N,use,_,filter=setup({{itemID=123,group="choice"},{itemID=124,group="choice"}})
    use[123],use[124]=false,true
    local rows=N.SearchModel:Query(filter);assert(#rows==1 and #rows[1].items==1 and rows[1].items[1].itemID==124)
end)
test("known XP remains a useful reward when its equipment is unusable",function()
    local N,use,_,filter=setup(nil,{xp=100});use[123]=false
    local rows=N.SearchModel:Query(filter);assert(#rows==1 and #rows[1].items==0)
end)
test("duplicate group items and equal queries share one capability observation",function()
    local N,use,reads,filter=setup({{itemID=123,group="guaranteed"},{itemID=123,group="choice"}});use[123]=false
    for _=1,5 do assert(#N.SearchModel:Query(filter)==0)end
    assert(reads[123]==1)
end)
test("capability invalidation makes a changed native usability result visible",function()
    local N,use,_,filter=setup();use[123]=false;assert(#N.SearchModel:Query(filter)==0)
    use[123]=true;W.Event("SKILL_LINES_CHANGED")
    assert(#N.SearchModel:Query(filter)==1)
end)

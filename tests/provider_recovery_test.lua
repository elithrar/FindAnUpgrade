local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup()
    local N=W.Init()
    C_QuestLog.IsOnQuest=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLog.GetTitleForQuestID=function()return "Cached candidate title" end
    local rows={}
    for i,source in ipairs({
        {confirmation="historical"},
        {confirmation="unconfirmed"},
        {confirmation="published",questKind="hidden-trigger"},
        {confirmation="published"},
    }) do
        source.id,source.title,source.items,source.locations=990000+i,"Candidate "..i,{},{{npcID=54001,name="Recorded giver"}}
        rows[i]=source
    end
    N.CatalogData={schemaVersion=2,quests=rows}
    return N,rows
end

test("historical unconfirmed and hidden NPC records require current native proof",function()
    local N=setup(); W.rewardReady=true
    local rows=N.Providers.ForNPC(54001)
    assert(#rows==1 and rows[1].id==990004)
    for _,id in ipairs({990001,990002,990003}) do
        assert(#N.Providers.ResolveRows({{id=id}})==0)
        assert(#N.Providers.ResolveRows({{id=id,availabilityProof="questie-available"}})==0)
        assert(#N.Providers.ResolveRows({{id=id,availabilityProof="questie-ready"}})==0)
    end
end)

test("current native log gossip and map proof can expose exact candidate IDs",function()
    local N=setup()
    for _,id in ipairs({990001,990002,990003}) do
        for _,proof in ipairs({"native-active","native-ready","native-available","native-map-available"}) do
            local rows=N.Providers.ResolveRows({{id=id,availabilityProof=proof}})
            assert(#rows==1 and rows[1].id==id)
        end
        C_QuestLog.IsOnQuest=function(candidate)return candidate==id end
        assert(#N.Providers.ResolveRows({{id=id}})==1)
        C_QuestLog.IsOnQuest=function()return false end
    end
end)

test("expired native offer evidence cannot fall back to a candidate starter",function()
    local N=setup()
    local proof="native-available"
    local row={id=990001,availabilityProof="native-available",availabilityCheck=function()return proof end}
    assert(#N.Providers.ResolveRows({row})==1)
    proof=nil
    assert(#N.Providers.ResolveRows({row})==0)
    assert(#N.Providers.ForNPC(54001)==1)
end)

test("native session blocks and completed history still exclude candidate offers",function()
    local N=setup()
    C_QuestLog.IsQuestDisabledForSession=function()return true end
    assert(#N.Providers.ResolveRows({{id=990001,availabilityProof="native-available"}})==0)
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function()return true end
    assert(#N.Providers.ResolveRows({{id=990001}})==0)
end)

test("published starters remain inspectable without claiming native availability",function()
    local N=setup()
    local rows=N.Providers.ResolveRows({{id=990004}})
    assert(#rows==1 and rows[1].availability.state=="unknown" and rows[1].evidence==nil)
end)

test("published exact title and difficulty are ready without a cold native load",function()
    local N=setup()
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    local row={id=9,source={confirmation="published",title="Published title",level=20}}
    assert(N.Catalog:Metadata(row,20) and row.title=="Published title" and row.level==20)
    for _,level in ipairs({0,-1,20.5,201}) do
        row.source.level=level; row.metadataReady=nil
        assert(not N.Catalog:Metadata(row,20) and row.level==nil)
    end
    row.source.level=nil;row.source.minimum=20;row.metadataReady=nil
    assert(not N.Catalog:Metadata(row,20) and row.level==nil)
end)

test("native metadata arrival replaces the published fallback through its event",function()
    local N,rows=setup(); local source=rows[4]
    source.title,source.level="Published title",20
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    N.Search:Toggle();N.Catalog:Step()
    local row=N.Catalog.records[source.id]
    assert(N.Catalog:Metadata(row,20) and row.title=="Published title" and row.level==20)
    C_QuestLog.GetTitleForQuestID=function()return "Native localized title" end
    C_QuestLog.GetQuestDifficultyLevel=function()return 32 end
    W.Event("QUEST_DATA_LOAD_RESULT",source.id,true)
    assert(row.metadataReady and row.title=="Native localized title" and row.level==32)
    assert(N.Catalog:Metadata(row,20))
end)

test("candidate metadata hydration starts only after current native proof arrives",function()
    local N,rows=setup()
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    rows[4].title,rows[4].level="Published quest",20
    N.Catalog:Begin();while N.Catalog:Step() do end
    local filter={query="",minimum=1,maximum=200,slot="ALL",usable=false,sort="FIT"}
    N.SearchModel:Query(filter)
    assert(#N.SearchModel.questNeeded==0)
    C_QuestLog.IsOnQuest=function(id)return id==990001 or id==990002 or id==990003 end
    N.SearchModel:Query(filter)
    assert(#N.SearchModel.questNeeded==3)
    C_QuestLog.IsOnQuest=function()return false end
    N.SearchModel:Query(filter)
    assert(#N.SearchModel.questNeeded==0)
end)

test("the complete cold catalog does not enqueue its published metadata or unavailable candidates",function()
    local N=W.Init()
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    C_QuestLog.IsOnQuest=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    HaveQuestRewardData=function()return false end
    N.Catalog:Begin();while N.Catalog:Step() do end
    N.SearchModel:Query({query="",minimum=15,maximum=23,slot="ALL",usable=false,sort="FIT"})
    assert(#N.Catalog.order>5000 and #N.SearchModel.questNeeded<100)
    for _,id in ipairs(N.SearchModel.questNeeded) do
        local source=N.Catalog.records[id].source
        assert(not N.Providers.RequiresNativeProof(source))
        assert(not source.title or not source.level)
    end
end)

test("cold published rows settle without metadata requests or an idle update",function()
    local N=setup();local rows={}
    for id=1,5000 do rows[id]={id=id,title="Published quest "..id,level=20,items={},confirmation="published"} end
    N.CatalogData={schemaVersion=2,quests=rows}
    C_QuestLog.GetTitleForQuestID=function()return nil end
    C_QuestLog.GetQuestDifficultyLevel=function()return nil end
    W.metadataRequests={}
    N.Search:Toggle()
    for tick=1,150 do W.time=tick/60; N.Search.frame:Fire("OnUpdate",1/60) end
    assert(N.Catalog.done and #N.Catalog.order==5000)
    assert(next(W.metadataRequests)==nil and not N.Search:HasRequests())
    assert(N.Search.frame:GetScript("OnUpdate")==nil)
end)

test("quest state invalidation touches only the affected reward snapshot",function()
    local N=setup()
    N.SearchModel.currentItems={[9]={{itemID=123}},[10]={{itemID=124}}}
    N.SearchModel.currentStamp={[9]="old9",[10]="old10"}
    N.SearchModel.usability={[9]={[123]=false},[10]={[124]=true}}
    N.SearchModel.cache={[123]={state="ready"}}
    N.Catalog.records={[9]={metadataReady=true},[10]={metadataReady=true}}
    assert(N.SearchModel:InvalidateQuest(9))
    assert(not N.SearchModel.currentItems[9] and not N.SearchModel.currentStamp[9] and not N.SearchModel.usability[9])
    assert(N.SearchModel.currentItems[10][1].itemID==124 and N.SearchModel.currentStamp[10]=="old10" and N.SearchModel.usability[10][124])
    assert(N.SearchModel.cache[123].state=="ready" and N.Catalog.records[9].metadataReady and N.Catalog.records[10].metadataReady)
    assert(not N.SearchModel:InvalidateQuest(0))
end)

test("forced quest metadata comparison reports actual changes without global invalidation",function()
    local N=setup();local reads=0
    C_QuestLog.GetTitleForQuestID=function(id)assert(id==9);reads=reads+1;return "Native title" end
    C_QuestLog.GetQuestDifficultyLevel=function(id)assert(id==9);return 20 end
    local row={id=9,source={confirmation="published",title="Published title",level=19}}
    local ready,changed=N.Catalog:Metadata(row,20)
    assert(ready and changed and row.title=="Native title" and row.level==20 and reads==1)
    ready,changed=N.Catalog:Metadata(row,20)
    assert(ready and not changed and reads==1)
    ready,changed=N.Catalog:Metadata(row,20,true)
    assert(ready and not changed and reads==2)
    C_QuestLog.GetQuestDifficultyLevel=function(id)assert(id==9);return 21 end
    ready,changed=N.Catalog:Metadata(row,20,true)
    assert(ready and changed and row.level==21 and reads==3)
end)

test("an expired explicit host proof cannot borrow another native association",function()
    local N=setup();local calls=0
    N.QuestState={Proof=function()calls=calls+1;return "native-available" end}
    local row={id=990001,availabilityCheck=function()return nil end}
    assert(#N.Providers.ResolveRows({row})==0 and calls==0)
end)

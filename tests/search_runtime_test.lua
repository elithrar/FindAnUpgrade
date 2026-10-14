local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup(count,cold,unknown)
    local N=W.Init(); local quests={}; W.cached={}; W.itemLoads={}; W.questLoads={}; W.rewardReady=false
    for i=1,count do quests[i]={id=i,title="Recorded "..i,items={{itemID=1000+i,name="Recorded item "..i}}}; W.cached[1000+i]=not cold end
    N.CatalogData={schemaVersion=1,quests=quests}
    C_QuestLog.GetTitleForQuestID=function(id) if not unknown then return "Quest "..id end end
    C_QuestLog.GetQuestDifficultyLevel=function() if not unknown then return 20 end end
    C_QuestLog.IsQuestFlaggedCompleted=function() return false end
    C_QuestLog.IsRepeatableQuest=function() return false end
    C_QuestLog.IsOnQuest=function() return false end
    C_QuestLog.RequestLoadQuestByID=function(id) W.questLoads[id]=(W.questLoads[id] or 0)+1 end
    C_Item={
        IsItemDataCachedByID=function(id) return W.cached[id]==true end,
        GetItemInfo=function(id) assert(W.cached[id],"cold full info read"); return "Native item "..id,"item:"..id,2,20,1,"Armor","Cloth",1,"INVTYPE_HEAD",100 end,
        GetItemInfoInstant=function(id) return id,"Armor","Cloth","INVTYPE_HEAD",100,4 end,
        RequestLoadItemDataByID=function(id) W.itemLoads[id]=(W.itemLoads[id] or 0)+1 end,
    }
    Menu={GetManager=function() W.menuReads=(W.menuReads or 0)+1; return {IsAnyMenuOpen=function() return false end} end}
    N.Search:Toggle(); W.time=.3; N.Search:Tick()
    return N,quests
end
local function tick(N,seconds,fps)
    for _=1,math.floor(seconds*fps) do W.time=W.time+1/fps; N.Search.frame:Fire("OnUpdate",1/fps) end
end
local function total(rows) local n=0; for _,value in pairs(rows) do n=n+value end; return n end

test("failed item loads do not starve more than 128 recorded rewards",function()
    local N=setup(300,true); tick(N,22,60)
    assert(total(W.itemLoads)==300 and W.itemLoads[1300]==1)
    for _,count in pairs(W.itemLoads) do assert(count==1) end
    assert(not N.Search.frame:GetScript("OnUpdate"))
end)
test("item and quest request rates are bounded independently of frame rate",function()
    local counts={}
    for _,fps in ipairs({30,60,144,240}) do
        local N=setup(300,true); tick(N,2,fps); local items=total(W.itemLoads)
        N=setup(300,false,true); tick(N,2,fps); local quests=total(W.questLoads)
        counts[#counts+1]={items=items,quests=quests}
        assert(items<=44 and quests<=44)
        assert(items>=30 and quests>=30)
    end
    assert(math.abs(counts[1].items-counts[4].items)<=6 and math.abs(counts[1].quests-counts[4].quests)<=6)
end)
test("quest metadata loading continues after the item queue is empty",function()
    local N=setup(70,false,true); tick(N,6,60)
    assert(total(W.itemLoads)==0 and total(W.questLoads)==70)
end)
test("visible reward preloads get fair turns during cold catalogue hydration",function()
    local N=setup(300,false,true); local hydrated={}; local firstReward
    C_QuestLog.GetTitleForQuestID=function(id) return "Quest "..id end
    C_QuestLog.GetQuestDifficultyLevel=function(id) if hydrated[id] then return 20 end end
    C_QuestLog.RequestLoadQuestByID=function(id) W.questLoads[id]=(W.questLoads[id] or 0)+1; hydrated[id]=true; W.Event("QUEST_DATA_LOAD_RESULT",id,true) end
    C_TaskQuest.RequestPreloadRewardData=function(id) firstReward=firstReward or W.time; W.rewardRequests[id]=(W.rewardRequests[id] or 0)+1 end
    tick(N,3,60)
    assert(firstReward and firstReward<1.2 and total(W.rewardRequests)>0 and total(W.questLoads)>20)
    assert(total(W.questLoads)+total(W.rewardRequests)<=64)
end)
test("data callbacks refresh during a sustained burst instead of sliding forever",function()
    local N=setup(3,true); local count=0; local refresh=N.Search.Refresh
    N.Search.Refresh=function(self) count=count+1; return refresh(self) end
    W.cached[1001]=true
    for _=1,100 do W.time=W.time+.1; W.Event("ITEM_DATA_LOAD_RESULT",1001,true); N.Search:Tick() end
    W.time=W.time+.3; N.Search:Tick()
    assert(count>=20 and N.SearchModel.cache[1001].state=="ready")
end)
test("item completion while hidden clears pending metadata before reopening",function()
    local N=setup(3,true); assert(N.SearchModel.cache[1001].state=="pending")
    N.Search.frame:Hide(); W.cached[1001]=true; W.Event("ITEM_DATA_LOAD_RESULT",1001,true)
    assert(N.SearchModel.cache[1001]==nil and N.Search.frame:GetScript("OnUpdate")==nil)
    N.Search:Toggle(); W.time=W.time+.3; N.Search:Tick(); assert(N.SearchModel.cache[1001].state=="ready")
end)
test("ready native cache recovers even when an item event is missed",function()
    local N=setup(3,true); W.cached[1001]=true
    local item=N.SearchModel:Item({itemID=1001}); assert(item.state=="ready" and item.name=="Native item 1001")
end)
test("settled visible finder stops updating and resumes for a filter change",function()
    local N=setup(3,false); tick(N,6,60); assert(not N.Search.frame:GetScript("OnUpdate"))
    local reads=W.menuReads; for _=1,1000 do N.Search.frame:Fire("OnUpdate",.01) end
    assert(W.menuReads==reads)
    N.Search.filter.query="1001"; N.Search:Changed(true); assert(N.Search.frame:GetScript("OnUpdate"))
    W.time=W.time+.3; N.Search:Tick(); assert(#N.Search.results==1)
end)
test("logged quests take precedence over recorded restrictions",function()
    local N,quests=setup(3,false); quests[1].classTokens={"PALADIN"}; quests[1].faction="Horde"; quests[1].races={95}; quests[1].maximum=5
    C_QuestLog.IsOnQuest=function(id) return id==1 end
    local allowed,note=N.SearchModel:Eligibility(N.Catalog.records[1],N.SearchModel:Context())
    assert(allowed and note=="In quest log")
end)
test("breadcrumb and incompletely interpreted prerequisites remain uncertain",function()
    local N,quests=setup(3,false); quests[1].prerequisites={999}; quests[1].minimum=30
    local allowed,note=N.SearchModel:Eligibility(N.Catalog.records[1],N.SearchModel:Context())
    assert(allowed and note=="Recorded minimum level 30")
    quests[1].minimum=nil; allowed,note=N.SearchModel:Eligibility(N.Catalog.records[1],N.SearchModel:Context())
    assert(allowed and note=="Quest chain: Quest 999")
end)
test("ready native reward names participate before a broad search renders cards",function()
    local N=setup(3,false); W.cached[9999]=true
    HaveQuestRewardData=function(id) return id==2 end
    GetNumQuestLogRewards=function(id) return id==2 and 1 or 0 end
    GetQuestLogRewardInfo=function(index,id) if id==2 then return "Native item 9999",100,1,2,true,9999 end end
    GetNumQuestLogChoices=function() return 0 end
    N.SearchModel.currentItems,N.SearchModel.currentStamp={},{}
    local rows=N.SearchModel:Query({query="Native item 9999",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"})
    assert(#rows==1 and rows[1].id==2 and rows[1].items[1].itemID==9999)
    rows=N.SearchModel:Query({query="Recorded item 2",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"}); assert(#rows==0)
end)
test("ready quest metadata is cached until an event invalidates it",function()
    local N=setup(3,false); local calls=0
    C_QuestLog.GetTitleForQuestID=function(id) calls=calls+1; return "Changed "..id end
    local filter={query="",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"}
    for _=1,10 do N.SearchModel:Query(filter) end; assert(calls==0)
    W.Event("QUEST_DATA_LOAD_RESULT",1,true); N.SearchModel:Query(filter)
    assert(calls==1 and N.Catalog.records[1].title=="Changed 1")
end)
test("quest data invalidation discards stale per-quest usability too",function()
    local N=setup(3,false); N.SearchModel.usability[1]={[1001]=false}
    local filter={query="1001",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"}
    assert(#N.SearchModel:Query(filter)==0)
    W.Event("QUEST_DATA_LOAD_RESULT",1,false)
    assert(N.SearchModel.usability[1]==nil and #N.SearchModel:Query(filter)==1)
end)
test("synchronous request callbacks cannot continue requesting after dismissal",function()
    local N=setup(20,true); local before=total(W.itemLoads)
    C_Item.RequestLoadItemDataByID=function(id) W.itemLoads[id]=(W.itemLoads[id] or 0)+1; N.Search.frame:Hide() end
    W.time=W.time+.2; N.Search:Tick()
    assert(total(W.itemLoads)==before+1 and not N.Search:Visible() and not N.Search.frame:GetScript("OnUpdate"))
end)
test("finder honors quest colors tint strength scale and immediate defaults",function()
    local N=setup(3,false); N.Model.Status=function() return "verifiedNew" end
    N.Core:Change("accents",false); W.time=W.time+.3; N.Search:Tick()
    local c=N.Search.cards[1]; assert(c.backdropColor[1]==.06 and c.tag.text=="New")
    N.Core:Change("strength",.1); N.Core:Change("accents",true); W.time=W.time+.3; N.Search:Tick()
    local subtle=c.backdropColor[1]; assert(subtle>.06 and c.backdropColor[1]>c.backdropColor[3])
    N.Core:Change("strength",1); W.time=W.time+.3; N.Search:Tick(); assert(c.backdropColor[1]>subtle)
    N.Core:Change("scale",.8); assert(N.Search.frame.scale==.8)
    N.Core:Defaults(); W.time=W.time+.3; N.Search:Tick()
    assert(N.Search.frame.scale==1 and N.Core.profile.strength==N.Model.defaults.strength)
    assert(c.backdropColor[1]>subtle and c.backdropColor[1]<.20 and c.backdropColor[1]>c.backdropColor[2] and c.backdropColor[2]>c.backdropColor[3])
    UIParent.width=500; UIParent.height=350; N.Core:Change("scale",1.2)
    assert(N.Search.frame.scale*N.Search.frame:GetWidth()<=476 and N.Search.frame.scale*N.Search.frame:GetHeight()<=326)
end)

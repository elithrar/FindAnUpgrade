local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function setup()
    local N=W.Init();W.active,W.ready,W.done,W.log={},{},{},{}
    local reads={log=0,complete=0,query=0,render=0,metadata=0,clears={}}
    local quests={
        {id=9,title="First",level=20,items={{itemID=123,name="Helmet"}},locations={{npcID=54,name="Giver"}}},
        {id=14,title="Second",level=21,items={{itemID=124,name="Sword"}},locations={{npcID=55,name="Giver"}}},
        {id=30,title="Unlocked",level=20,items={{itemID=125,name="Boots"}},locations={{itemID=200,name="Scroll"}},prerequisites={900},prerequisitesVerified=true},
        {id=99,title="Far above",level=60,items={{itemID=126,name="Shield"}},locations={{objectID=300,name="Poster"}}},
    }
    N.CatalogData={schemaVersion=2,quests=quests}
    C_QuestLog.GetTitleForQuestID=function(id)for _,row in ipairs(quests)do if row.id==id then return row.title end end end
    C_QuestLog.GetQuestDifficultyLevel=function(id)for _,row in ipairs(quests)do if row.id==id then return row.level end end end
    C_QuestLog.GetNumQuestLogEntries=function()reads.log=reads.log+1;return #W.log end
    C_QuestLog.GetInfo=function(index)reads.log=reads.log+1;return W.log[index]end
    C_QuestLog.IsOnQuest=function(id)return W.active[id]==true end
    C_QuestLog.IsComplete=function(id)reads.complete=reads.complete+1;return W.ready[id]==true end
    C_QuestLog.IsQuestFlaggedCompleted=function(id)return W.done[id]==true end
    C_QuestLog.IsRepeatableQuest=function()return false end
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLog.GetQuestObjectives=function()error("objective counters are not visible finder state")end
    ExpandQuestHeader=function()error("header state mutated")end;CollapseQuestHeader=ExpandQuestHeader
    W.rewardReady=false
    C_Item={IsItemDataCachedByID=function()return true end,
        GetItemInfo=function(id)return "Item "..id,"item:"..id,2,20,1,"Armor","Cloth",1,"INVTYPE_HEAD",100 end,
        GetItemInfoInstant=function(id)return id,"Armor","Cloth","INVTYPE_HEAD",100,4 end}
    local query=N.SearchModel.Query;N.SearchModel.Query=function(self,filter)reads.query=reads.query+1;return query(self,filter)end
    local render=N.Search.Render;N.Search.Render=function(self)reads.render=reads.render+1;return render(self)end
    local metadata=N.Catalog.Metadata;N.Catalog.Metadata=function(self,...)reads.metadata=reads.metadata+1;return metadata(self,...)end
    local invalidate=N.SearchModel.InvalidateQuest;N.SearchModel.InvalidateQuest=function(self,id)reads.clears[id]=(reads.clears[id]or 0)+1;return invalidate(self,id)end
    local S=N.Search;S:Toggle();S.filter.scope="LEVEL_RANGE";S:Changed(true)
    for _=1,65 do W.time=W.time+.1;S:Tick()end
    local function reset()reads.log,reads.complete,reads.query,reads.render,reads.metadata=0,0,0,0,0;reads.clears={}end
    reset();return N,S,reads,reset
end
local function settle(S)
    for _=1,6 do
        W.time=W.time+.1
        local events=W.N.Character.events;if events and events:GetScript("OnUpdate") then events:Fire("OnUpdate") end
        S:Tick()
    end
end
local function evidence(S,id)
    for _,row in ipairs(S.results)do if row.id==id then return row.evidence or "recorded" end end
end

test("a thousand unchanged log and objective updates do not query rebuild or clear metadata",function()
    local N,S,reads=setup()
    local metadata=N.Catalog.records[9].metadataReady;local native=N.SearchModel.currentItems
    for _=1,1000 do W.Event("QUEST_LOG_UPDATE");W.time=W.time+.02;S:Tick()end
    assert(reads.query==0 and reads.render==0 and reads.metadata==0 and not next(reads.clears))
    assert(N.Catalog.records[9].metadataReady==metadata and N.SearchModel.currentItems==native)
end)
test("accepted payload uses its first exact quest ID and duplicate events coalesce",function()
    local N,S,reads=setup();W.active[9]=true;W.log={{questID=9,isHeader=false}}
    for _=1,1000 do W.Event("QUEST_ACCEPTED",9)end
    settle(S);assert(reads.query==1 and reads.clears[9]==1 and not reads.clears[14])
    assert(evidence(S,9)=="In quest log")
end)
test("completion changes update visible eligibility while ordinary objective progress is a no-op",function()
    local N,S,reads,reset=setup();W.active[9]=true;W.log={{questID=9,isHeader=false}};W.Event("QUEST_ACCEPTED",9);settle(S);reset()
    for _=1,100 do W.Event("QUEST_LOG_UPDATE")end;settle(S);assert(reads.query==0)
    W.ready[9]=true;for _=1,100 do W.Event("QUEST_LOG_UPDATE")end;settle(S)
    assert(reads.query==1 and reads.clears[9]==1 and evidence(S,9)=="Ready to turn in")
end)
test("removal abandonment and turn-in refresh once without invalidating unrelated cached facts",function()
    local N,S,reads,reset=setup();W.active[9]=true;W.log={{questID=9,isHeader=false}};W.Event("QUEST_ACCEPTED",9);settle(S);reset()
    local unrelated=N.Catalog.records[14].metadataReady;local items={marker=true};N.SearchModel.currentItems[14]=items
    W.active[9]=false;W.log={};for _=1,100 do W.Event("QUEST_REMOVED",9,false)end;settle(S)
    assert(reads.query==1 and reads.clears[9]==1 and evidence(S,9)=="recorded")
    assert(N.Catalog.records[14].metadataReady==unrelated and N.SearchModel.currentItems[14]==items)
    reset();W.done[9]=true;for _=1,100 do W.Event("QUEST_TURNED_IN",9,450,100)end;settle(S)
    assert(reads.query==1 and reads.clears[9]==1 and not evidence(S,9))
end)
test("a completed prerequisite outside the catalog can reveal its dependent quest",function()
    local N,S,reads=setup();assert(not evidence(S,30));W.done[900]=true
    W.Event("QUEST_TURNED_IN",900,0,0);settle(S)
    assert(reads.query==1 and reads.clears[900]==1 and evidence(S,30))
end)
test("a verified exclusive alternative reaches an in-range dependent through two reverse edges",function()
    local N,S,reads,reset=setup();local quests=N.CatalogData.quests
    quests[#quests+1]={id=900,title="Prerequisite",level=60,items={},exclusive={901},exclusiveVerified=true}
    quests[#quests+1]={id=901,title="Alternate",level=60,items={}}
    N.CatalogData={schemaVersion=2,quests=quests};S:Toggle();S:Toggle();settle(S);reset()
    assert(not evidence(S,30));W.done[901]=true;W.Event("QUEST_TURNED_IN",901,0,0);settle(S)
    assert(reads.query==1 and evidence(S,30))
end)
test("events for quests outside the level range do not query the active browser",function()
    local N,S,reads=setup();W.active[99]=true;W.log={{questID=99,isHeader=false}}
    W.Event("QUEST_ACCEPTED",99);settle(S);assert(reads.query==0 and reads.render==0)
end)
test("collapsed headers never manufacture a removal and a real missing removal is detected",function()
    local N,S,reads,reset=setup();W.active[9]=true;W.log={{questID=9,isHeader=false}};W.Event("QUEST_ACCEPTED",9);settle(S);reset()
    W.log={{isHeader=true,isCollapsed=true}}
    for _=1,100 do W.Event("QUEST_LOG_UPDATE")end;settle(S)
    assert(reads.query==0 and N.QuestState.active[9]==false)
    W.active[9]=false;W.Event("QUEST_LOG_UPDATE");settle(S)
    assert(reads.query==1 and N.QuestState.active[9]==nil and evidence(S,9)=="recorded")
end)
test("hidden event bursts perform no native log reads queries requests or rendering",function()
    local N,S,reads,reset=setup();S.frame:Hide();reset();local requests=0
    C_Item.RequestLoadItemDataByID=function()requests=requests+1 end
    C_QuestLog.RequestLoadQuestByID=function()requests=requests+1 end
    for _=1,1000 do W.Event("QUEST_LOG_UPDATE");W.Event("QUEST_ACCEPTED",9);W.Event("QUEST_REMOVED",9,false)end
    assert(reads.log==0 and reads.complete==0 and reads.query==0 and reads.render==0 and reads.metadata==0 and requests==0 and not next(reads.clears))
    assert(not S.frame:GetScript("OnUpdate"))
    W.active[9]=true;W.ready[9]=true;W.log={{questID=9,isHeader=false}};S:Toggle();settle(S)
    assert(evidence(S,9)=="Ready to turn in")
end)
test("current native map offers change eligibility once and expire without a static upgrade",function()
    local N,S,reads,reset=setup();local source={id=777,title="Native offer",level=20,confirmation="historical-only",itemState="published-empty",items={},rewardValues={xp=100}}
    N.CatalogData.quests[#N.CatalogData.quests+1]=source;N.Catalog:Begin();N.Catalog.ids=N.CatalogData.quests;N.Catalog.done=false;N.Catalog.cursor=1
    N.Providers.data=nil
    C_QuestLog.GetTitleForQuestID=function(id)return id==777 and "Native offer" or "Quest "..id end
    C_QuestLog.GetQuestDifficultyLevel=function()return 20 end
    local offers={};C_Map={GetBestMapForUnit=function()return 100 end};C_QuestLine={GetAvailableQuestLines=function()return offers end}
    W.Event("ZONE_CHANGED_NEW_AREA")
    S:Changed();settle(S);assert(not evidence(S,777));reset()
    offers={{questID=777,inProgress=false}};for _=1,100 do W.Event("QUEST_LOG_UPDATE")end;settle(S)
    assert(reads.query==1 and evidence(S,777)=="Available")
    reset();for _=1,1000 do W.Event("QUEST_LOG_UPDATE")end;settle(S);assert(reads.query==0)
    reset();offers={};W.Event("QUEST_LOG_UPDATE");settle(S);assert(reads.query==1 and not evidence(S,777))
end)
test("duplicate warm metadata outside the active range never queries and a changed native level can enter",function()
    local N,S,reads,reset=setup()
    for _=1,100 do W.Event("QUEST_DATA_LOAD_RESULT",99,true);settle(S)end
    assert(reads.query==0 and reads.render==0 and not next(reads.clears) and reads.metadata==100)
    local difficulty=C_QuestLog.GetQuestDifficultyLevel
    C_QuestLog.GetQuestDifficultyLevel=function(id)if id==99 then return 20 end;return difficulty(id)end
    W.Event("QUEST_DATA_LOAD_RESULT",99,true);settle(S)
    assert(reads.query==1 and evidence(S,99))
    reset();for _=1,100 do W.Event("QUEST_DATA_LOAD_RESULT",99,true);settle(S)end
    assert(reads.query==0 and reads.render==0 and not next(reads.clears))
end)
test("unchanged in-range metadata is a no-op and a real reward change coalesces once",function()
    local N,S,reads,reset=setup()
    for _=1,100 do W.Event("QUEST_DATA_LOAD_RESULT",9,true);settle(S)end
    assert(reads.query==0 and reads.render==0 and not next(reads.clears))
    W.rewardReady=true
    for _=1,100 do W.Event("QUEST_DATA_LOAD_RESULT",9,true)end;settle(S)
    assert(reads.query==1)
    reset();for _=1,100 do W.Event("QUEST_DATA_LOAD_RESULT",9,true);settle(S)end
    assert(reads.query==0 and reads.render==0 and not next(reads.clears))
    GetQuestLogRewardMoney=function(id)return id==9 and 2300 or 0 end
    for _=1,100 do W.Event("QUEST_DATA_LOAD_RESULT",9,true)end;settle(S)
    assert(reads.query==1)
end)
test("hidden metadata events invalidate only the affected record once and never read native metadata",function()
    local N,S,reads,reset=setup();S.frame:Hide();reset()
    local metadata=C_QuestLog.GetTitleForQuestID
    C_QuestLog.GetTitleForQuestID=function()error("hidden native metadata read")end
    for _=1,1000 do W.Event("QUEST_DATA_LOAD_RESULT",9,true)end
    assert(reads.query==0 and reads.render==0 and reads.metadata==0 and not next(reads.clears))
    assert(N.Catalog.records[9].metadataReady==nil and N.Catalog.records[14].metadataReady==true)
    C_QuestLog.GetTitleForQuestID=metadata
end)
test("an expired native marker checker never falls back to its old proof",function()
    local N,S=setup();local current=true
    N.Sources.current={surface="worldmap",rows={{id=9,availabilityProof="native-map-available",availabilityCheck=function()if current then return "native-map-available" end end}},valid=function()return true end}
    assert(N.QuestState:Proof(9)=="native-map-available" and N.QuestState:NativeOffers()[9]=="native-map-available")
    current=false
    assert(N.QuestState:Proof(9)==nil and N.QuestState:NativeOffers()[9]==nil)
end)
test("duplicate item callbacks keep the same cache object and a real metadata change queries once",function()
    local N,S,reads,reset=setup();local cached=N.SearchModel.cache[123]
    for _=1,100 do W.Event("ITEM_DATA_LOAD_RESULT",123,true);W.Event("GET_ITEM_INFO_RECEIVED",123,true);settle(S)end
    assert(reads.query==0 and reads.render==0 and N.SearchModel.cache[123]==cached)
    local info=C_Item.GetItemInfo
    C_Item.GetItemInfo=function(id)if id==123 then return "Changed helmet","item:123",3,21,1,"Armor","Cloth",1,"INVTYPE_HEAD",101 end;return info(id)end
    for _=1,100 do W.Event("ITEM_DATA_LOAD_RESULT",123,true)end;settle(S)
    assert(reads.query==1 and N.SearchModel.cache[123].name=="Changed helmet")
    reset();for _=1,100 do W.Event("ITEM_DATA_LOAD_RESULT",123,true);settle(S)end
    assert(reads.query==0 and reads.render==0)
end)
test("hidden item callbacks never request or read native item metadata",function()
    local N,S,reads,reset=setup();S.frame:Hide();reset()
    C_Item.GetItemInfo=function()error("hidden full item read")end
    C_Item.GetItemInfoInstant=function()error("hidden instant item read")end
    for _=1,1000 do W.Event("ITEM_DATA_LOAD_RESULT",123,true)end
    assert(N.SearchModel.cache[123]==nil and reads.query==0 and reads.render==0)
end)

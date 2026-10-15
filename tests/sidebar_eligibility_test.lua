local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup()
    local N=W.Init()
    C_QuestLog.IsOnQuest=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    C_QuestLog.IsRepeatableQuest=function()return false end
    C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLog.GetQuestDifficultyLevel=function()return 20 end
    HaveQuestRewardData=function()return false end
    C_QuestLine=nil
    local source={id=40001,title="Faction test quest",level=20,confirmation="published",items={},rewardValues={xp=50},locations={{npcID=54}}}
    N.CatalogData={schemaVersion=2,quests={source,{id=40002,title="Earlier quest",confirmation="published",items={},locations={}}}}
    return N,source,N.Providers.Context()
end
local function availability(N,source,proof,context,npc)
    return N.Providers.Availability({id=source.id,source=source,npcID=npc,availabilityProof=proof},context)
end

test("map and optional marker proof cannot bypass an explicit opposing quest faction",function()
    local N,source,context=setup();source.faction="Horde"
    for _,proof in ipairs({"native-map-available","questie-available","questie-ready"}) do
        local result=availability(N,source,proof,context)
        assert(result.state=="blocked" and result.reason=="Other faction")
    end
end)

test("optional map proof also respects class race and verified prerequisites",function()
    for _,proof in ipairs({"native-map-available","questie-available"}) do
        local N,source,context=setup();source.classes={2}
        assert(availability(N,source,proof,context).reason=="Other class")
        source.classes=nil;source.classTokens={"PALADIN"}
        assert(availability(N,source,proof,context).reason=="Other class")
        source.classTokens=nil;source.races={8}
        assert(availability(N,source,proof,context).reason=="Other race")
        source.races=nil;source.prerequisites={40002};source.prerequisitesVerified=true
        assert(availability(N,source,proof,context).authority=="verified-prerequisite")
    end
end)

test("a future minimum level cannot hide a verified chain failure",function()
    local N,source,context=setup();source.minimum=30;source.prerequisites={40002};source.prerequisitesVerified=true
    local eligible,_,result=N.SearchModel:Eligibility({id=source.id,source=source},context)
    assert(not eligible and result.authority=="verified-prerequisite")
    source.prerequisitesVerified=nil
    eligible,_,result=N.SearchModel:Eligibility({id=source.id,source=source},context)
    assert(eligible and result.authority=="recorded-level")
end)

test("only an opposing faction starter cannot be admitted by native map proof",function()
    local N,source,context=setup();source.locations={{npcID=54,faction="Horde"}}
    local result=availability(N,source,"native-map-available",context)
    assert(result.state=="blocked" and result.reason=="Other faction starter")
    assert(not N.SearchModel:StartPath({id=source.id,source=source},context,{state="available",authority="native-map"}))
end)

test("a different friendly starter does not authorize the hovered opposing NPC",function()
    local N,source,context=setup();source.locations={{npcID=54,faction="Horde"},{npcID=55,faction="Alliance"}}
    assert(availability(N,source,"questie-available",context,54).reason=="Other faction starter")
    assert(availability(N,source,"questie-available",context,55).state=="available")
    assert(availability(N,source,"questie-available",context).state=="available")
    assert(#N.Providers.ForNPC(54)==0 and #N.Providers.ForNPC(55)==1)
end)

test("an unqualified duplicate cannot erase the exact NPC faction constraint",function()
    local N,source,context=setup();source.locations={{npcID=54},{npcID=54,faction="Horde"}}
    assert(availability(N,source,nil,context).reason=="Other faction starter")
    assert(#N.Providers.ForNPC(54)==0)
    source.locations[3]={npcID=55}
    assert(availability(N,source,nil,context).state=="unknown")
end)

test("same NPC with explicit Alliance and Horde paths stays available to each faction",function()
    local N,source,context=setup();source.locations={{npcID=54,faction="Horde"},{npcID=54,faction="Alliance"}}
    assert(availability(N,source,nil,context).state=="unknown")
    context.faction="Horde";assert(availability(N,source,nil,context).state=="unknown")
    assert(#N.Providers.ForNPC(54)==1)
end)

test("unqualified starters and valid item object alternatives stay distinct",function()
    local N,source,context=setup()
    for _,location in ipairs({{npcID=54},{objectID=54},{itemID=54}}) do
        source.locations={{npcID=54,faction="Horde"},location}
        local allowed=N.Providers.StartPath({id=source.id,source=source},context)
        assert(allowed==(location.npcID==nil))
    end
    source.locations={{npcID=54}}
    assert(N.Providers.StartPath({id=source.id,source=source},context))
end)

test("fresh native log and gossip authority can override stale exact quest metadata",function()
    local N,source,context=setup();source.faction="Horde";source.locations={{npcID=54,faction="Horde"}};source.classes={2};source.prerequisites={40002};source.prerequisitesVerified=true
    for _,proof in ipairs({"native-active","native-ready","native-available"}) do
        local result=availability(N,source,proof,context)
        assert(result.state~="blocked" and N.SearchModel:StartPath({id=source.id,source=source},context,result))
    end
    C_QuestLog.IsOnQuest=function()return true end
    N.Character:QuestChanged({ids={[source.id]=true}})
    local result=availability(N,source,nil,context)
    assert(result.authority=="native-log" and N.SearchModel:StartPath({id=source.id,source=source},context,result))
end)

test("native map proof can establish a currently offered ID with missing starter data",function()
    local N,source,context=setup();source.locations={}
    local result=availability(N,source,"native-map-available",context)
    assert(result.state=="available" and N.SearchModel:StartPath({id=source.id,source=source},context,result))
    assert(not N.SearchModel:StartPath({id=source.id,source=source},context,{state="unknown"}))
end)

test("completed disabled and expired proof guards survive faction changes",function()
    local N,source,context=setup();C_QuestLog.IsQuestFlaggedCompleted=function()return true end
    assert(availability(N,source,"native-map-available",context).state=="completed")
    C_QuestLog.IsQuestDisabledForSession=function()return true end
    N.Character:QuestChanged({ids={[source.id]=true}})
    assert(availability(N,source,"native-available",context).authority=="native-session")
    C_QuestLog.IsQuestDisabledForSession=function()return false end;C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    N.Character:QuestChanged({ids={[source.id]=true}})
    source.faction="Horde"
    local row={id=source.id,source=source,availabilityProof="native-available",availabilityCheck=function()return nil end}
    assert(N.Providers.Availability(row,context).reason=="Other faction")
end)
test("unknown repeatability cannot make completion history a final rejection",function()
    local N,source,context=setup();C_QuestLog.IsQuestFlaggedCompleted=function()return true end
    C_QuestLog.IsRepeatableQuest=function()return nil end
    assert(availability(N,source,"native-map-available",context).state=="available")
end)

test("unknown or secret player identity does not invent a faction or starter",function()
    local N,source=setup();UnitFactionGroup=function()return W.secret end;N.Character:Mark("identity")
    local context=N.Providers.Context();assert(context.faction==nil)
    source.locations={{npcID=54,faction="Alliance"}}
    assert(not N.Providers.StartPath({id=source.id,source=source},context))
    source.locations={{npcID=54}}
    assert(N.Providers.StartPath({id=source.id,source=source},context))
    source.locations={{mapID=1453,x=.5,y=.5}}
    assert(not N.Providers.StartPath({id=source.id,source=source},context))
end)

test("finder actual query excludes wrong quest and NPC factions despite current map offers",function()
    local N,source=setup();source.faction="Horde"
    local second={id=40002,title="Wrong NPC only",level=20,confirmation="published",items={},rewardValues={xp=50},locations={{npcID=55,faction="Horde"}}}
    local third={id=40003,title="Valid mixed starters",level=20,confirmation="published",items={},rewardValues={xp=50},locations={{npcID=56,faction="Horde"},{objectID=56,faction="Alliance"}}}
    N.CatalogData.quests={source,second,third}
    C_Map={GetBestMapForUnit=function()return 1429 end}
    C_QuestLine={GetAvailableQuestLines=function()return {{questID=40001,inProgress=false},{questID=40002,inProgress=false},{questID=40003,inProgress=false}} end}
    N.Catalog:Begin();while N.Catalog:Step() do end
    local rows=N.SearchModel:Query({scope="LEVEL_RANGE",query="",minimum=1,maximum=60,slot="ALL",usable=false,sort="FIT"})
    assert(#rows==1 and rows[1].id==40003)
end)

test("catalog locations never suggest an opposing duplicate or conflate typed identities",function()
    local N,source=setup();source.locations={{npcID=54},{npcID=54,faction="Horde"},{objectID=54,faction="Alliance"},{itemID=54}}
    N.Catalog:Begin();while N.Catalog:Step() do end
    local locations=N.Catalog:Locations(source.id)
    assert(#locations==2 and locations[1].objectID==54 and locations[2].itemID==54)
    UnitFactionGroup=function()return "Horde" end
    N.Character:Mark("identity")
    locations=N.Catalog:Locations(source.id)
    assert(#locations==3 and locations[1].npcID==54 and locations[2].npcID==54 and locations[3].itemID==54)
end)

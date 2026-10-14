local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup()
    local N=W.Init(); Questie=nil; C_QuestLine=nil
    N.CatalogData={schemaVersion=1,quests={
        {id=40001,title="Known quest",items={{itemID=123}},locations={{npcID=54}}},
        {id=40002,title="Earlier quest",items={{itemID=124}},locations={{npcID=55}}},
        {id=40003,title="Other path",items={{itemID=125}},locations={{npcID=55}}}}}
    W.active,W.done,W.repeatable,W.ready,W.disabled={},{},{},{},{}
    C_QuestLog.IsOnQuest=function(id) return W.active[id]==true end
    C_QuestLog.IsComplete=function(id) return W.ready[id]==true end
    C_QuestLog.IsQuestFlaggedCompleted=function(id) return W.done[id]==true end
    C_QuestLog.IsRepeatableQuest=function(id) return W.repeatable[id]==true end
    C_QuestLog.IsQuestDisabledForSession=function(id) return W.disabled[id]==true end
    C_QuestLog.GetTitleForQuestID=function(id) return id==40002 and "Earlier quest" or id==40003 and "Other path" or "Known quest" end
    return N,N.CatalogData.quests[1]
end
local function npcTip(N)
    local tip=W.Object();tip.GetUnit=function() return "Giver","mouseover" end
    local line="|TInterface\\Addons\\Questie\\Icons\\tooltip_available.png:14|tKnown quest"
    tip.lines={line};GameTooltip=tip;GameTooltipTextLeft1=W.Object();GameTooltipTextLeft1:SetText(line)
    N.Questie.lib={GetColoredQuestName=function(_,id) return id==40001 and "Known quest" or "Earlier quest" end}
    return tip
end
test("exact static starter identity has no invented availability or possible-quest wording",function()
    local N=setup(); local rows=N.Providers.ForNPC(54)
    assert(#rows==1 and rows[1].id==40001 and rows[1].title=="Known quest")
    assert(rows[1].availability.state=="unknown" and rows[1].evidence==nil)
    assert(LibQuestieDB==nil and QuestieLoader==nil)
end)
test("static starter rows reject completed nonrepeatable and known session-disabled quests",function()
    local N=setup(); W.done[40001]=true; assert(#N.Providers.ForNPC(54)==0)
    W.done[40001]=nil; W.disabled[40001]=true; assert(#N.Providers.ForNPC(54)==0)
end)
test("repeatable completion history does not imply current availability",function()
    local N=setup(); W.done[40001],W.repeatable[40001]=true,true
    local rows=N.Providers.ForNPC(54); assert(#rows==1 and rows[1].availability.state=="unknown" and rows[1].evidence=="Repeatable")
end)
test("native active quest overrides stale recorded faction class race and level restrictions",function()
    local N,source=setup(); source.faction="Horde"; source.classTokens={"PALADIN"}; source.races={95}; source.maximum=2
    W.active[40001]=true; local rows=N.Providers.ForNPC(54)
    assert(#rows==1 and rows[1].availability.state=="active" and rows[1].evidence=="In quest log")
    W.ready[40001]=true; rows=N.Providers.ForNPC(54); assert(rows[1].availability.state=="ready" and rows[1].evidence=="Ready to turn in")
end)
test("known wrong faction class race and level constraints filter static NPC associations",function()
    local N,source=setup(); source.faction="Horde"; assert(#N.Providers.ForNPC(54)==0)
    source.faction=nil; source.classTokens={"PALADIN"}; assert(#N.Providers.ForNPC(54)==0)
    source.classTokens=nil; source.races={95}; assert(#N.Providers.ForNPC(54)==0)
    source.races=nil; source.minimum=30; assert(#N.Providers.ForNPC(54)==0)
    local eligible,note=N.SearchModel:Eligibility({id=40001,source=source},N.Providers.Context()); assert(eligible and note=="Recorded minimum level 30")
end)
test("unknown player class and race cannot fabricate rejection",function()
    local N,source=setup(); source.classTokens={"PALADIN"}; source.races={95}
    UnitClass=function() return W.secret,W.secret,W.secret end; UnitRace=function() return W.secret,W.secret,W.secret end
    local rows=N.Providers.ForNPC(54); assert(#rows==1 and rows[1].availability.state=="unknown")
end)
test("unfulfilled authored chain links name exact quests without becoming hard server gates",function()
    local N,source=setup(); source.prerequisites={40002}; source.eligibilityUnknown=true
    local rows=N.Providers.ForNPC(54); assert(#rows==1 and rows[1].availability.state=="unknown" and rows[1].evidence=="Quest chain: Earlier quest")
    assert(rows[1].availability.requirements[1].id==40002)
end)
test("completed chain links do not fabricate Available",function()
    local N,source=setup(); source.prerequisites={40002}; W.done[40002]=true
    local rows=N.Providers.ForNPC(54); assert(#rows==1 and rows[1].availability.state=="unknown" and rows[1].evidence==nil)
end)
test("single OR prerequisite wins over an unrelated recorded group",function()
    local N,source=setup(); source.prerequisiteAlternatives={40002,40003}; source.prerequisites={999}; W.done[40003]=true
    local value=N.Providers.Availability({id=40001,source=source}); assert(value.state=="unknown" and value.label==nil)
end)
test("group thresholds count alternatives once and never silently assume all-of",function()
    local N,source=setup(); source.prerequisites={40002,40003}; source.prerequisiteCount=1; W.done[40003]=true
    local value=N.Providers.Availability({id=40001,source=source}); assert(value.state=="unknown" and value.label==nil)
    source.prerequisiteCount=2; value=N.Providers.Availability({id=40001,source=source}); assert(value.label=="Quest chain: Earlier quest")
end)
test("verified hard prerequisites may exclude while unverified links may not",function()
    local N,source=setup(); source.prerequisites={40002}; source.prerequisitesVerified=true
    assert(#N.Providers.ForNPC(54)==0)
    source.prerequisitesVerified=nil; assert(#N.Providers.ForNPC(54)==1)
end)
test("breadcrumb and unavailable completion data cannot become definitive hard failures",function()
    local N,source=setup(); source.prerequisites={40002}; source.prerequisitesVerified=true; N.CatalogData.quests[2].isBreadcrumb=true
    assert(#N.Providers.ForNPC(54)==1)
    N.CatalogData.quests[2].isBreadcrumb=nil; C_QuestLog.IsQuestFlaggedCompleted=function() return W.secret end
    assert(#N.Providers.ForNPC(54)==1)
end)
test("verified exclusive prior paths satisfy a link without false availability",function()
    local N,source=setup(); source.prerequisites={40002}; source.prerequisitesVerified=true
    N.CatalogData.quests[2].exclusive={40003}; N.CatalogData.quests[2].exclusiveVerified=true; W.done[40003]=true
    assert(N.Providers.Availability({id=40001,source=source}).state=="unknown")
end)
test("native current gossip carries Available active and ready states for the matching GUID",function()
    local N=setup(); W.guid="Creature-0-1-2-3-54-0001"; W.npcGuid=W.guid
    C_GossipInfo={GetAvailableQuests=function() return {{questID=40001,title="Known quest"}} end,
        GetActiveQuests=function() return {{questID=40002,title="Earlier quest",isComplete=false},{questID=40003,title="Other path",isComplete=true}} end}
    W.Event("GOSSIP_SHOW"); local rows=N.Sources:NPC().rows
    assert(#rows==3 and rows[1].availability.state=="available" and rows[2].availability.state=="active" and rows[3].availability.state=="ready")
    W.guid="Creature-0-1-2-3-55-0002"; rows=N.Sources:NPC().rows
    assert(#rows==2 and rows[1].availability.state=="unknown")
    W.Event("GOSSIP_CLOSED"); assert(N.Sources.gossip==nil)
end)
test("current native offer overrides an outdated recorded chain and completion snapshot",function()
    local N,source=setup(); source.prerequisites={40002}; source.faction="Horde"; W.done[40001]=true
    local value=N.Providers.Availability({id=40001,source=source,availabilityProof="native-available"})
    assert(value.state=="available" and value.authority=="native-gossip")
end)
test("native map availability requires the exact current available-line ID",function()
    local N=setup(); C_QuestLine={GetAvailableQuestLines=function(map) assert(map==1429); return {{questID=40001,inProgress=false}} end}
    assert(N.Sources:MapAvailability(40001,1429)=="native-map-available")
    assert(N.Sources:MapAvailability(40002,1429)==nil)
    C_QuestLine.GetAvailableQuestLines=function() return {{questID=W.secret},{questID="40001"},{questID=40001,inProgress=true}} end
    assert(N.Sources:MapAvailability(40001,1429)==nil)
end)
local function marker(N,kind)
    local icon=W.Object(); icon.x,icon.y,icon.width,icon.height=690,690,28,28; icon.texture=W.Object(); icon.data={Id=40001,Type=kind}
    local tip=W.Object(); tip._owner=icon; tip.questOrder={}; tip.npcAndObjectOrder={NPC={A={questId=40001,type="(Class)"},B={questId=40002,type="(Available)"}}}
    N.Questie:Observe(tip); tip._Rebuild=function() end
    return icon,tip
end
test("Questie primary available type is current attributed evidence regardless of localized class tag",function()
    local N=setup(); local icon,tip=marker(N,"available"); N.Questie:Shown(icon,tip)
    local rows=N.Sources.current.rows
    assert(rows[1].availability.state=="available" and rows[1].availability.authority=="questie-rendered" and rows[1].evidence=="Available")
    assert(rows[2].availability.state=="unknown" and rows[2].evidence==nil)
end)
test("duplicate objective grouping cannot discard a current primary offer status",function()
    local N=setup(); local icon,tip=marker(N,"available"); tip.questOrder={[40001]={}}
    N.Questie:Shown(icon,tip); assert(N.Sources.current.rows[1].availability.state=="available")
end)
test("Questie localized text alone cannot assert availability",function()
    local N=setup(); local icon,tip=marker(N,nil); N.Questie:Shown(icon,tip)
    assert(N.Sources.current.rows[1].availability.state=="unknown")
end)
test("native completed and active state overrides contradictory Questie markers",function()
    local N=setup(); local icon,tip=marker(N,"available"); W.done[40001]=true
    N.Questie:Shown(icon,tip); assert(N.Sources.current==nil)
    W.active[40001]=true; tip._Rebuild=function() end; N.Questie:Shown(icon,tip)
    assert(N.Sources.current.rows[1].availability.state=="active")
end)
test("complete marker without a local active quest cannot invent local completion",function()
    local N=setup(); local icon,tip=marker(N,"complete"); N.Questie:Shown(icon,tip)
    assert(N.Sources.current.rows[1].availability.state=="unknown")
    W.active[40001]=true; W.ready[40001]=true; tip._Rebuild=function() end; N.Questie:Shown(icon,tip)
    assert(N.Sources.current.rows[1].availability.state=="ready")
end)
test("marker type mutation and pooled data invalidate a frozen availability source",function()
    local N=setup(); local icon,tip=marker(N,"available"); N.Questie:Shown(icon,tip)
    local current=N.Sources.current; assert(current.valid()); icon.data.Type="complete"; assert(not current.valid())
    icon.data={Id=40001,Type="available"}; assert(not current.valid())
end)
test("unchanged render token hidden markers and alpha-zero markers cannot reuse availability",function()
    local N=setup(); local icon,tip=marker(N,"available"); N.Questie:Shown(icon,tip); N.Sources.current=nil
    N.Questie:Shown(icon,tip); assert(N.Sources.current==nil)
    icon.hidden=true; tip._Rebuild=function() end; N.Questie:Shown(icon,tip); assert(N.Sources.current==nil)
    icon.hidden=false; icon.texture.color={1,1,1,0}; N.Questie:Shown(icon,tip); assert(N.Sources.current==nil)
end)
test("current Questie NPC tooltip proves registered exact starter only for the rendered GUID",function()
    local N=setup(); W.guid="Creature-0-1-2-3-54-0001"
    local tip=npcTip(N)
    local units={lastGametooltipUnit="Giver",lastGametooltipType="monster",lookupByKey={m_54={A={questId=40001,name="Giver",starterId=54,type="NPC"},B={questId=40002,name="Other",starterId=55,type="NPC"}}}}
    Questie={db={profile={enableTooltips=true,showQuestsInNpcTooltip=true}}}; N.Questie.units=units
    N.Questie:UnitShown(tip); local rows=N.Providers.ForNPC(54)
    assert(#rows==1 and rows[1].availability.state=="available" and rows[1].availability.authority=="questie-rendered")
    W.guid="Creature-0-1-2-3-55-0002"; assert(#N.Questie.ForNPC(54)==0)
end)
test("hidden and disabled optional NPC tooltip cannot create fresh evidence",function()
    local N=setup(); W.guid="Creature-0-1-2-3-54-0001"; local tip=npcTip(N)
    N.Questie.units={lastGametooltipUnit="Giver",lastGametooltipType="monster",lookupByKey={m_54={A={questId=40001,name="Giver",starterId=54,type="NPC"}}}}
    Questie={db={profile={enableTooltips=false,showQuestsInNpcTooltip=true}}}; N.Questie:UnitShown(tip); assert(N.Questie.npc==nil)
    Questie.db.profile.enableTooltips=true; tip.shown=false; N.Questie:UnitShown(tip); assert(N.Questie.npc==nil)
end)
test("current Questie available evidence wins over an older recorded restriction",function()
    local N,source=setup(); source.faction="Horde"; source.minimum=60; source.classTokens={"PALADIN"}
    local icon,tip=marker(N,"available"); N.Questie:Shown(icon,tip)
    assert(N.Sources.current.rows[1].availability.state=="available")
    W.disabled[40001]=true; assert(not N.Providers.Resolve(N.Sources.current.rows[1]))
end)
test("gossip offer proof expires after the native offer is removed",function()
    local N=setup(); W.guid="Creature-0-1-2-3-54-0001"; W.npcGuid=W.guid
    local list={{questID=40001,title="Known quest"}}
    C_GossipInfo={GetAvailableQuests=function() return list end,GetActiveQuests=function() return {} end}
    N.Sources:Gossip(); local row=N.Sources.gossip.rows[1]
    assert(row.availability.state=="available")
    list={}; assert(N.Providers.Resolve(row) and row.availability.state=="unknown" and row.evidence==nil)
    W.done[40001]=true; assert(not N.Providers.Resolve(row) and row.availability.state=="completed")
end)
test("removed map offers cannot remain Available after a quest-log refresh",function()
    local N=setup(); local offers={{questID=40001,inProgress=false}}
    C_QuestLine={GetAvailableQuestLines=function() return offers end}
    local frame=W.Object(); frame.questID=40001; frame.mapID=1429
    N.Sources:Pin(frame,40001); local row=N.Sources.current.rows[1]
    assert(row.availability.state=="available")
    offers={}; assert(N.Providers.Resolve(row) and row.availability.state=="unknown")
    W.done[40001]=true; assert(not N.Providers.Resolve(row))
end)
test("old Questie render proof expires when a new tooltip render replaces its token",function()
    local N=setup(); local icon,tip=marker(N,"available"); N.Questie:Shown(icon,tip)
    local row=N.Sources.current.rows[1]; assert(row.availability.state=="available")
    tip._Rebuild=function() end; assert(N.Providers.Resolve(row) and row.availability.state=="unknown")
end)
test("removed NPC starter registry evidence cannot survive a status refresh",function()
    local N=setup(); W.guid="Creature-0-1-2-3-54-0001"; local tip=npcTip(N)
    local registry={A={questId=40001,name="Giver",starterId=54,type="NPC"}}
    N.Questie.units={lastGametooltipUnit="Giver",lastGametooltipType="monster",lookupByKey={m_54=registry}}
    Questie={db={profile={enableTooltips=true,showQuestsInNpcTooltip=true}}}; N.Questie:UnitShown(tip)
    local row=N.Providers.ForNPC(54)[1]; assert(row.availability.state=="available")
    registry.A=nil; assert(N.Providers.Resolve(row) and row.availability.state=="unknown")
end)
test("fresh grouped Questie offers use exact localized tags and class names",function()
    local N=setup(); local translated={Available="Disponible",Complete="Termine"}
    N.Questie.translator=setmetatable({},{__call=function(_,value) return translated[value] or value end})
    N.Questie.database={GetQuestTagInfo=function() return 21,"Guerrier" end}
    local icon,tip=marker(N,"available"); tip.npcAndObjectOrder.NPC.B.type="(Guerrier)"
    N.Questie:Shown(icon,tip); assert(N.Sources.current.rows[2].availability.state=="available")
    assert(N.Questie:GroupProof(40002,"(Disponible)")=="questie-available")
    assert(N.Questie:GroupProof(40002,"(Termine)")=="questie-ready")
end)
test("grouped Questie categories fail safely without localization or exact known category proof",function()
    local N=setup(); assert(N.Questie:GroupProof(40002,"(Available)")==nil)
    N.Questie.translator=function(value) return value end
    assert(N.Questie:GroupProof(40002,"(Banana)")==nil)
    assert(N.Questie:GroupProof(40002,W.secret)==nil)
    N.Questie.database={GetQuestTagInfo=function() return 999,"Banana" end}
    assert(N.Questie:GroupProof(40002,"(Banana)")==nil)
    N.Questie.translator=function() return W.secret end
    assert(N.Questie:GroupProof(40002,"(Available)")==nil)
end)
test("grouped offer evidence expires after membership or localized tag mutation",function()
    local N=setup(); N.Questie.translator=function(value) return value end
    local icon,tip=marker(N,"available"); N.Questie:Shown(icon,tip)
    local row=N.Sources.current.rows[2]; assert(row.availability.state=="available")
    tip.npcAndObjectOrder.NPC.B.type="(Complete)"; assert(N.Providers.Resolve(row) and row.availability.state=="unknown")
    tip.npcAndObjectOrder.NPC.B.type="(Available)"; tip.npcAndObjectOrder.NPC.B=nil
    assert(N.Providers.Resolve(row) and row.availability.state=="unknown")
end)
test("native repeated gossip offer overrides historical completion only while still offered",function()
    local N=setup(); W.guid="Creature-0-1-2-3-54-0001"; W.npcGuid=W.guid; W.done[40001]=true
    local offered={{questID=40001,title="Known quest",repeatable=true}}
    C_GossipInfo={GetAvailableQuests=function() return offered end,GetActiveQuests=function() return {} end}
    N.Sources:Gossip(); local row=N.Sources.gossip.rows[1]; assert(row.availability.state=="available")
    offered={}; assert(not N.Providers.Resolve(row))
end)
test("a registered NPC starter omitted from the actual tooltip never becomes Available",function()
    local N=setup();W.guid="Creature-0-1-2-3-54-0001";local tip=npcTip(N);tip.lines={};GameTooltipTextLeft1=nil
    N.Questie.units={lastGametooltipUnit="Giver",lastGametooltipType="monster",lookupByKey={m_54={A={questId=40001,name="Giver",starterId=54,type="NPC"}}}}
    Questie={db={profile={enableTooltips=true,showQuestsInNpcTooltip=true}}};N.Questie:UnitShown(tip)
    assert(N.Providers.ForNPC(54)[1].availability.state=="unknown")
end)
test("whole NPC registry replacement entry-ID mutation and profile replacement expire old proof",function()
    for _,mutation in ipairs({"registry","id","profile","guid"}) do
        local N=setup();W.guid="Creature-0-1-2-3-54-0001";local tip=npcTip(N)
        local registry={A={questId=40001,name="Giver",starterId=54,type="NPC"}}
        N.Questie.units={lastGametooltipUnit="Giver",lastGametooltipType="monster",lookupByKey={m_54=registry}}
        Questie={db={profile={enableTooltips=true,showQuestsInNpcTooltip=true}}};N.Questie:UnitShown(tip)
        local row=N.Providers.ForNPC(54)[1];assert(row.availability.state=="available")
        if mutation=="registry" then N.Questie.units.lookupByKey={}
        elseif mutation=="id" then registry.A.questId=40002
        elseif mutation=="profile" then Questie.db.profile={enableTooltips=false,showQuestsInNpcTooltip=false}
        else W.guid="Creature-0-1-2-3-55-0002" end
        assert(N.Providers.Resolve(row) and row.availability.state=="unknown",mutation)
    end
end)
test("sticky NPC inspection retains a proved snapshot when the native tooltip hides",function()
    local N=setup();W.guid="Creature-0-1-2-3-54-0001";local tip=npcTip(N)
    N.Questie.units={lastGametooltipUnit="Giver",lastGametooltipType="monster",lookupByKey={m_54={A={questId=40001,name="Giver",starterId=54,type="NPC"}}}}
    Questie={db={profile={enableTooltips=true,showQuestsInNpcTooltip=true}}};N.Questie:UnitShown(tip)
    local row=N.Providers.ForNPC(54)[1];tip.shown=false
    assert(N.Providers.Resolve(row) and row.availability.state=="available")
    W.done[40001]=true;assert(not N.Providers.Resolve(row))
end)
test("restricted native tooltip text and a stale unrelated line cannot prove an NPC offer",function()
    local N=setup();W.guid="Creature-0-1-2-3-54-0001";local tip=npcTip(N)
    N.Questie.units={lastGametooltipUnit="Giver",lastGametooltipType="monster",lookupByKey={m_54={A={questId=40001,name="Giver",starterId=54,type="NPC"}}}}
    Questie={db={profile={enableTooltips=true,showQuestsInNpcTooltip=true}}};N.Questie:UnitShown(tip)
    GameTooltipTextLeft1.GetText=function()return W.secret end;assert(N.Providers.ForNPC(54)[1].availability.state=="unknown")
    GameTooltipTextLeft1.GetText=function()return "Known quest" end;assert(N.Providers.ForNPC(54)[1].availability.state=="unknown")
end)
test("cold native metadata retains an exact Questie title without adopting a formatted display label",function()
    local N=setup();N.Questie.database={QueryQuestSingle=function(id,key) assert(key=="name");return id==40001 and "Exact localized title" or "Earlier localized title" end}
    C_QuestLog.GetTitleForQuestID=function()return nil end
    local icon,tip=marker(N,"available");tip.npcAndObjectOrder.NPC.A.title="|cffff0000[20] Display text (40001)|r"
    N.Questie:Shown(icon,tip);assert(N.Sources.current.rows[1].title=="Exact localized title")
end)

local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function native(N,owner,lines)
    local tip=W.Object(); GameTooltip=tip; tip.owner=owner; tip.x=685; tip.y=620; tip.width=280; tip.height=100
    tip.SetOwner=function() error("native tooltip reowned") end
    tip.ClearAllPoints=function() error("native tooltip anchors changed") end
    tip.EnableMouse=function() error("native tooltip mouse changed") end
    local function add(self,value)
        self.lines=self.lines or {}; self.lines[#self.lines+1]=value
        local region=UIParent:CreateFontString(nil,"OVERLAY","GameTooltipText"); region:SetText(value)
        _G["GameTooltipTextLeft"..#self.lines]=region
    end
    tip.AddLine=add
    for _,value in ipairs(lines or {"Native NPC"}) do add(tip,value) end
    N.NativeTooltip:Attach(); return tip
end
local function open(config)
    local N=W.Init(config); W.shift=true
    C_QuestLog.IsOnQuest=function() return true end
    local f=W.Object(); f.x=690; f.y=690; f.width=30; f.height=30; f.questID=9; f.GetQuestID=function() return f.questID end
    local tip=native(N,f,{"Native NPC","Quest 9"})
    N.Sources:Pin(f,9); assert(N.Hover.open)
    return N,f,tip
end
local function currentLines(tip)
    local lines={}
    for i=1,tip:NumLines() do local value=_G["GameTooltipTextLeft"..i]:GetText(); if value~="" then lines[#lines+1]=value end end
    return table.concat(lines,"\n")
end
test("native preview appends to the same owner and preserves existing NPC and addon lines",function()
    local N,f,tip=open()
    assert(not N.Stack.frame and tip:GetOwner()==f)
    assert(GameTooltipTextLeft1:GetText()=="Native NPC" and GameTooltipTextLeft2:GetText()=="Quest 9")
    assert(currentLines(tip):find("450 XP",1,true) and currentLines(tip):find("Release Shift",1,true))
    local count=tip:NumLines(); for i=1,30 do N.Hover:Tick(i/100) end; assert(tip:NumLines()==count)
end)
test("release removes only owned native text and hands off to compact persistent item inspection",function()
    local N,f,tip=open(); W.items={{"Reward",100,2,2,true,123}}
    W.shift=false; W.Event("MODIFIER_STATE_CHANGED","LSHIFT",0)
    assert(N.Hover.open and N.Hover.mode=="inspector" and N.Stack.frame:IsShown())
    assert(currentLines(tip)=="Native NPC\nQuest 9" and tip:GetOwner()==f)
    assert(N.Stack.cards[1].icons[1]:GetWidth()==24 and N.Stack.cards[1].icons[1].border.color[2]==1)
    assert(N.Stack.frame:GetHeight()<=60 and N.Stack.placement.left>=N.Stack.anchorX+56)
end)
test("Escape dismisses native mode and a held key cannot immediately reopen it",function()
    local N,f=open(); N.NativeTooltip.escape:Hide()
    assert(not N.Hover.open); N.Sources:Pin(f,9); assert(not N.Hover.open)
    W.shift=false; N.Hover:Modifier(); W.shift=true; N.Hover:Modifier(); assert(N.Hover.open)
end)
test("a recycled source cannot hand off stale quest data on release",function()
    local N,f=open(); f.questID=14; W.shift=false; N.Hover:Modifier(); assert(not N.Hover.open)
end)
test("native text updates after the registered quest data event without duplicating rows",function()
    local N,f,tip=open(); local count=tip:NumLines()
    GetQuestLogRewardXP=function() return 1350 end
    W.Event("QUEST_DATA_LOAD_RESULT",9,true); N.Hover:Tick(.1)
    assert(tip:NumLines()==count and currentLines(tip):find("1350 XP",1,true) and not currentLines(tip):find("450 XP",1,true))
end)
test("another addon's changed line is never overwritten or blanked",function()
    local N,f,tip=open(); local region=GameTooltipTextLeft3; region:SetText("Another addon owns this now")
    W.Event("QUEST_DATA_LOAD_RESULT",9,true); N.Hover:Tick(.1)
    W.shift=false; N.Hover:Modifier(); assert(region:GetText()=="Another addon owns this now")
end)
test("clear and rebuild can reuse the same identity without accumulating supplements",function()
    local N,f,tip=open(); tip:ClearLines(); tip:AddLine("Rebuilt NPC"); tip:AddLine("Quest 9"); N.Hover:Tick(.1)
    assert(currentLines(tip):find("Rebuilt NPC",1,true) and currentLines(tip):find("450 XP",1,true))
    local count=tip:NumLines(); N.Hover:Tick(.2); assert(tip:NumLines()==count)
end)
test("unmatched, forbidden or protected native tooltips fall back without changing them",function()
    for _,kind in ipairs({"owner","forbidden","protected"}) do
        local N,f,tip=open(); N.Hover:Dismiss(); N.Hover.blocked=nil
        tip:ClearLines(); tip:AddLine("Other tooltip")
        if kind=="owner" then tip.owner=W.Object() elseif kind=="forbidden" then tip.forbidden=true else tip.IsProtected=function() return true end end
        N.Sources:Pin(f,9); N.Hover:Tick(.3)
        assert(N.Hover.mode=="inspector" and GameTooltipTextLeft1:GetText()=="Other tooltip" and tip:NumLines()==1)
    end
end)
test("secret native text fails closed instead of scanning or replacing it",function()
    local N,f,tip=open(); N.Hover:Dismiss(); N.Hover.blocked=nil
    tip:ClearLines(); tip:AddLine("Secret"); GameTooltipTextLeft1.GetText=function() return W.secret end
    N.Sources:Pin(f,9); N.Hover:Tick(.3); assert(N.Hover.mode=="inspector" and tip:NumLines()==1)
end)
test("NPC augmentation requires the exact current unit GUID",function()
    local N=W.Init(); W.shift=true; W.guid="Creature-0-0-0-0-54-ABC"
    C_QuestLog.IsOnQuest=function() return true end
    local tip=native(N,UIParent,{"NPC"}); tip.GetUnit=function() return "NPC","mouseover" end
    local source={key=W.guid,npcGUID=W.guid,surface="npc",rows={{id=9}},valid=function() return true end,over=function() return true end}
    N.Sources:Set(source); assert(N.Hover.mode=="native" and tip:NumLines()>1)
    N.Hover:Dismiss(); N.Hover.blocked=nil; tip:ClearLines(); tip:AddLine("Different NPC"); tip.GetUnit=function() return "Different NPC","target" end
    UnitGUID=function(unit) if unit=="mouseover" then return W.guid else return "Creature-0-0-0-0-55-ABC" end end
    N.Sources:Set(source); N.Hover:Tick(.3); assert(N.Hover.mode=="inspector" and tip:NumLines()==1)
end)
test("exact titles deduplicate but mentions and same-title variants retain identity",function()
    local N=W.Init(); N.Rewards.Read=function() return {items={items={}},choices={items={}},currencies={items={}},reputation={items={}},money={},xp={}} end
    C_QuestLog.GetTitleForQuestID=function() return "A Quest" end
    local profile=N.Model.Load(nil)
    local source={rows={{id=2}}}
    local lines=N.NativeTooltip:Lines(source,profile,{"A Quest"}); assert(#lines==1)
    lines=N.NativeTooltip:Lines(source,profile,{"Objective: finish A Quest"}); assert(lines[1]=="A Quest")
    source.rows={{id=2},{id=3}}; lines=N.NativeTooltip:Lines(source,profile,{"A Quest"})
    assert(lines[1]=="A Quest (#2)" and lines[2]:find("(#3)",1,true))
end)
test("known XP and reputation supplements do not repeat Questie values or lose exact classifications",function()
    local N=W.Init(); local reward=N.Rewards.Read(9)
    reward.reputation={items={{factionID=72,name="Stormwind",amount=75,published=true}}}
    N.Rewards.Read=function() return reward end
    local lines=N.NativeTooltip:Lines({rows={{id=9}}},N.Core.profile,{"Quest 9","(450xp)","+75 Stormwind"})
    local value=table.concat(lines,"\n")
    assert(not value:find("450 XP",1,true) and not value:find("Stormwind:",1,true) and value:find("FindAnUpgrade:",1,true))
end)
test("compact and None modes work immediately and settings survive malformed imports",function()
    for _,saved in ipairs({{previewLayout="inspector"},{modifier="NONE"}}) do
        local N,f=open({saved=saved}); assert(N.Hover.mode=="inspector" and N.Stack.frame:IsShown())
    end
    local M=W.Init().Model
    local p=M.Load({previewLayout={},inspectionPosition="nowhere",scale=0/0}); assert(p.previewLayout=="tooltip" and p.inspectionPosition=="right" and p.scale==1)
    p=M.Load({previewLayout="inspector",inspectionPosition="tooltip",enabled=false}); assert(p.previewLayout=="inspector" and p.inspectionPosition=="tooltip" and not p.enabled)
end)
test("bare slash opens search while explicit aliases keep settings separate",function()
    local N=W.Init(); local search,options=0,0
    N.Search.Toggle=function() search=search+1 end; N.Options.Toggle=function() options=options+1 end
    for _,command in ipairs({"","search","s"}) do SlashCmdList.FINDANUPGRADE(command) end
    for _,command in ipairs({"opts","options"}) do SlashCmdList.FINDANUPGRADE(command) end
    assert(search==3 and options==2)
end)
test("completion events remove stale native quest rows through provider eligibility",function()
    local N,f,tip=open()
    C_QuestLog.IsOnQuest=function() return false end
    C_QuestLog.IsQuestFlaggedCompleted=function() return true end
    C_QuestLog.IsRepeatableQuest=function() return false end
    W.Event("QUEST_LOG_UPDATE"); assert(not N.Hover.open and currentLines(tip)=="Native NPC\nQuest 9")
end)
test("in-place native data identity mutation fails closed",function()
    local N,f,tip=open(); N.Hover:Dismiss(); N.Hover.blocked=nil
    tip:ClearLines(); tip:AddLine("Native NPC"); local data={id=9,type=1}
    tip.GetPrimaryTooltipData=function() return data end; N.Sources:Pin(f,9)
    assert(N.NativeTooltip.token and N.Hover.mode=="native")
    data.guid="foreign"; N.Hover:Tick(.3); assert(N.Hover.mode=="inspector")
end)
test("reentrant teardown during composition cannot resurrect or append native state",function()
    local N,f,tip=open(); N.Hover:Dismiss(); N.Hover.blocked=nil
    tip:ClearLines(); tip:AddLine("Native NPC")
    local original=N.Rewards.Read
    N.Rewards.Read=function(id) N.Hover:Dismiss("test"); return original(id) end
    N.Sources:Pin(f,9); assert(not N.Hover.open and tip:NumLines()==1 and not N.NativeTooltip.token)
end)
test("reentrant teardown during native append stops the transaction",function()
    local N,f,tip=open(); N.Hover:Dismiss(); N.Hover.blocked=nil
    tip:ClearLines(); tip:AddLine("Native NPC")
    local add=tip.AddLine
    tip.AddLine=function(self,line) add(self,line); N.Hover:Dismiss("test") end
    N.Sources:Pin(f,9); assert(not N.Hover.open and currentLines(tip)=="Native NPC" and not N.NativeTooltip.token)
end)
test("multiple native quests and reward groups stay bounded and distinct",function()
    local N=W.Init(); W.items={{"Guaranteed",100,2,2,true,123}}; W.choices={{"Choice",101,1,3,true,124}}
    local rows={}; for i=1,40 do rows[#rows+1]={id=i} end
    local lines=N.NativeTooltip:Lines({rows=rows},N.Core.profile,{})
    local value=table.concat(lines,"\n")
    assert(#lines<=13 and value:find("Guaranteed:",1,true) and value:find("Choose one:",1,true))
end)
test("one quest's matching amount cannot erase another exact quest's rewards",function()
    local N=W.Init(); C_QuestLog.GetTitleForQuestID=function(id) return "Quest "..id end
    local lines=N.NativeTooltip:Lines({rows={{id=2},{id=3}}},N.Core.profile,{"Quest 2","Quest 3","|Tcoin:12|t12345  450 XP"})
    local count=0; for _,line in ipairs(lines) do if line:find("450 XP",1,true) then count=count+1 end end
    assert(count==2)
end)
test("native quick summary keeps guaranteed currencies distinct beside choice items",function()
    local N=W.Init(); W.choices={{"Choice",101,1,3,true,124}}
    C_QuestLog.GetQuestRewardCurrencies=function() return {{currencyID=10,name="Token",totalRewardAmount=3}} end
    local value=table.concat(N.NativeTooltip:Lines({rows={{id=9}}},N.Core.profile,{}),"\n")
    assert(value:find("Choose one:",1,true) and value:find("Guaranteed: Token 3",1,true))
end)
test("the complete native supplement occupies one multiline intrinsic row",function()
    local N,f,tip=open(); assert(tip:NumLines()==3 and N.NativeTooltip.token.lines[1].region==GameTooltipTextLeft3)
    assert(GameTooltipTextLeft3:GetText():find("\n",1,true))
    W.items={{"Reward",100,2,2,true,123}}; W.Event("QUEST_DATA_LOAD_RESULT",9,true); N.Hover:Tick(.1)
    assert(tip:NumLines()==3 and #N.NativeTooltip.token.lines==1)
end)
test("unchanged data events preserve an active item inspection and skip stack layout",function()
    local N=W.Init({saved={previewLayout="inspector"}}); W.shift=true; C_QuestLog.IsOnQuest=function() return true end
    local f=W.Object(); f.x=690; f.y=690; f.width=30; f.height=30; f.questID=9; f.GetQuestID=function() return 9 end
    N.Sources:Pin(f,9); local refresh=N.Stack.Refresh; local calls=0
    N.Stack.Refresh=function(self) calls=calls+1; return refresh(self) end
    local item={}; N.Stack.item=item
    for i=1,50 do W.Event("QUEST_DATA_LOAD_RESULT",9,true); N.Hover:QuestChanged({ids={[999]=true}}) end
    assert(N.Hover.open and N.Stack.item==item and calls==0)
    GetQuestLogRewardXP=function() return 1350 end; W.Event("QUEST_DATA_LOAD_RESULT",9,true)
    assert(not N.Hover.open)
end)
test("only current source and known prerequisite changes wake hover refresh",function()
    local N,f,tip=open(); local calls=0
    N.Providers.Source=function(id) if id==9 then return {prerequisites={8}} end end
    N.Hover.Refresh=function() calls=calls+1 end
    N.Hover:QuestChanged({ids={[777]=true}}); assert(calls==0)
    N.Hover:QuestChanged({ids={[8]=true}}); assert(calls==1)
    N.Hover:QuestChanged({ids={[9]=true}}); assert(calls==2)
end)
test("a newly unlocked NPC candidate appears while the pointer is in persistent inspection",function()
    local N=W.Init({saved={previewLayout="inspector"}}); W.shift=true
    N.CatalogData={schemaVersion=2,quests={
        {id=9,title="Unlocked",prerequisites={8},prerequisitesVerified=true,locations={{npcID=54}}},
        {id=14,title="Active",locations={{npcID=54}}}
    }}
    local done=false
    C_QuestLog.IsOnQuest=function(id) return id==14 end
    C_QuestLog.IsQuestFlaggedCompleted=function(id) return id==8 and done end
    W.guid="Creature-0-0-0-0-54-ABC"; local source=N.Sources:NPC(); N.Sources:Set(source)
    assert(N.Hover.open and #N.Hover.source.rows==1 and N.Hover.source.rows[1].id==14)
    W.guid=nil; done=true; N.Hover:QuestChanged({ids={[8]=true}})
    assert(N.Hover.open and #N.Hover.source.rows==2 and #N.Stack.cards==2)
end)
test("item cache events update only item IDs present in the visible native preview",function()
    local N,f,tip=open(); local reward=N.Rewards.Read(9)
    reward.items.items={{itemID=123,name="Recorded reward",quantity=2,state="pending",kind="catalog"}}
    N.Rewards.Read=function() return reward end
    W.Event("QUEST_DATA_LOAD_RESULT",9,true); N.Hover:Tick(.1)
    assert(currentLines(tip):find("Recorded reward",1,true))
    local calls=0; local refresh=N.Hover.Refresh; N.Hover.Refresh=function(self,...) calls=calls+1; return refresh(self,...) end
    for i=1,50 do W.Event("ITEM_DATA_LOAD_RESULT",999,true) end; assert(calls==0)
    reward.items.items[1].state="ready"; reward.items.items[1].texture=100; reward.items.items[1].quality=2
    W.Event("ITEM_DATA_LOAD_RESULT",123,true); N.Hover:Tick(.2)
    assert(calls==1 and currentLines(tip):find("|T100:24:24|t",1,true) and tip:NumLines()==3)
end)
test("secure AddLine post-hooks cannot transfer row ownership to foreign content",function()
    local N,f,tip=open(); N.Hover:Dismiss(); N.Hover.blocked=nil; tip:ClearLines(); tip:AddLine("Native NPC")
    local add=tip.AddLine
    tip.AddLine=function(self,line) add(self,line); add(self,"Another addon row") end
    N.Sources:Pin(f,9); assert(N.NativeTooltip.token.lines[1].index==2)
    W.shift=false; N.Hover:Modifier()
    assert(currentLines(tip)=="Native NPC\nAnother addon row")
end)
test("same owner hide and show reuses the owned native slot without growth",function()
    local N,f,tip=open(); local count=tip:NumLines()
    for i=1,20 do tip:Hide(); tip:Show(); N.Hover:Tick(i/100) end
    assert(tip:NumLines()==count and #N.NativeTooltip.token.lines==1)
end)
test("a hide inside AddLine's post-hook leaves no orphaned supplement",function()
    local N,f,tip=open(); N.Hover:Dismiss(); N.Hover.blocked=nil; tip:ClearLines(); tip:AddLine("Native NPC")
    local add=tip.AddLine
    tip.AddLine=function(self,line) add(self,line); self:Hide() end
    N.Sources:Pin(f,9); assert(currentLines(tip)=="Native NPC")
    tip.AddLine=add; tip:Show(); N.Hover:Tick(.1)
    assert(tip:NumLines()==2 and N.NativeTooltip.token)
end)
test("same pooled marker's rebuilt grouped IDs remove stale secondary quests",function()
    local N=W.Init(); W.shift=true; C_QuestLog.IsOnQuest=function() return true end
    local icon=W.Object(); icon.x=690; icon.y=690; icon.width=28; icon.height=28; icon.data={Id=9}; icon.texture=W.Object()
    local tip=W.Object(); tip._owner=icon; tip.questOrder={[9]={},[14]={}}; tip.npcAndObjectOrder={}
    N.Questie:Observe(tip); tip._Rebuild=function() end; N.Questie:Shown(icon,tip)
    assert(N.Hover.open and #N.Hover.source.rows==2)
    tip.questOrder={[9]={}}; tip._Rebuild=function() end; N.Questie:Shown(icon,tip)
    assert(N.Hover.open and #N.Hover.source.rows==1 and N.Hover.source.rows[1].id==9)
end)
test("a successful marker render with no exact current primary closes only that owner's stale stack",function()
    for _,groups in ipairs({{}, {[14]={}}}) do
        local N=W.Init(); W.shift=true; C_QuestLog.IsOnQuest=function() return true end
        local icon=W.Object(); icon.x=690; icon.y=690; icon.width=28; icon.height=28; icon.data={Id=9}; icon.texture=W.Object()
        local tip=W.Object(); tip._owner=icon; tip.questOrder={[9]={}}; tip.npcAndObjectOrder={}
        N.Questie:Observe(tip); tip._Rebuild=function() end; N.Questie:Shown(icon,tip); assert(N.Hover.open)
        tip.questOrder=groups; tip._Rebuild=function() end; N.Questie:Shown(icon,tip)
        assert(not N.Hover.open and not N.Sources.current)
    end
end)
test("disabled hover surfaces do not start idle updaters under a stationary pointer",function()
    for _,saved in ipairs({{enabled=false},{worldmap=false}}) do
        local N=W.Init({saved=saved}); W.shift=true
        local pin=W.Object(); pin.x=690; pin.y=690; pin.width=30; pin.height=30; pin.questID=9; pin.GetQuestID=function() return 9 end
        N.Sources:Pin(pin,9)
        assert(not N.Hover.open and not N.Core.events:GetScript("OnUpdate"))
        if saved.enabled==false then assert(not N.Sources.current) end
    end
end)
test("finder-visible sources retain native proof without a hover updater and reopen with modifier",function()
    local N=W.Init(); local visible=true; N.Search.Visible=function() return visible end
    local pin=W.Object(); pin.x=690; pin.y=690; pin.width=30; pin.height=30; pin.questID=9; pin.GetQuestID=function() return 9 end
    N.Sources:Pin(pin,9); assert(N.Sources.current and not N.Core.events:GetScript("OnUpdate"))
    visible=false; W.shift=true; N.Hover:Modifier()
    assert(N.Hover.open and N.Core.events:GetScript("OnUpdate"))
end)
test("native source clear leave and map hide immediately expire finder-only offer proof",function()
    for _,action in ipairs({"clear","leave","map","combat","world","settings"}) do
        local N=W.Reset(); W.rewardReady=false
        local id=800001
        N.CatalogData={schemaVersion=2,quests={{id=id,title="Native map offer",level=20,confirmation="published",itemState="published-empty",items={},rewardValues={xp=100}}}}
        C_QuestLog.IsOnQuest=function() return false end; C_QuestLog.IsQuestFlaggedCompleted=function() return false end
        C_QuestLog.GetNumQuestLogEntries=function() return 0,0 end; C_QuestLog.GetQuestDifficultyLevel=function() return 20 end
        W.Event("ADDON_LOADED","FindAnUpgrade"); N.Search:Create();N.Search.filter.scope="LEVEL_RANGE";N.Search:Toggle()
        local function tick() for i=1,30 do W.time=W.time+.02; N.Search.frame:Fire("OnUpdate",.02) end end
        tick(); assert(#N.Search.results==0)
        local owner=W.Object(); local valid=true
        local source={key={},owner=owner,surface="worldmap",rows={{id=id,availabilityCheck=function() return valid and "native-map-available" end}},valid=function() return valid end,over=function() return false end}
        N.Sources:Watch(owner); N.Sources:Set(source); tick(); assert(#N.Search.results==1)
        N.Sources:Clear(W.Object()); tick(); assert(#N.Search.results==1)
        if action=="clear" then valid=false; N.Sources:Clear(owner)
        elseif action=="leave" then owner:Fire("OnLeave")
        elseif action=="map" then WorldMapFrame:Hide()
        elseif action=="combat" then W.Event("PLAYER_REGEN_DISABLED")
        elseif action=="world" then W.Event("PLAYER_ENTERING_WORLD")
        else N.Core:Change("strength",.7) end
        tick(); assert(#N.Search.results==0 and not N.Sources.current and N.QuestState:Proof(id)==nil)
    end
end)
test("native map availability requires an explicit public false inProgress flag",function()
    local N=W.Init()
    C_QuestLine={GetAvailableQuestLines=function() return {{questID=9,inProgress=false}} end}
    assert(N.Sources:MapAvailability(9,37)=="native-map-available")
    for _,flag in ipairs({true,W.secret,0,"false"}) do
        C_QuestLine.GetAvailableQuestLines=function() return {{questID=9,inProgress=flag}} end
        assert(N.Sources:MapAvailability(9,37)==nil)
    end
    C_QuestLine.GetAvailableQuestLines=function() return {{questID=9}} end
    assert(N.Sources:MapAvailability(9,37)==nil)
end)

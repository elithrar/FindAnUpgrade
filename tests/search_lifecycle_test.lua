local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local base=ROOT.."/.work/current-api/Interface/AddOns/"
local function read(path)
    local file=io.open(path,"rb"); if not file then return end
    local source=file:read("*a"); file:close(); return source
end
local handler=read(base.."Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua")
local manager=read(base.."Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua")
local function setup(native,post)
    local N=W.Init()
    N.CatalogData={schemaVersion=1,quests={{id=9,title="Head quest",items={{itemID=123,name="Helmet"}},locations={{npcID=54001,name="Recorded giver"}}}}}
    W.rewardReady=false; W.openMenu=nil
    C_QuestLog.GetQuestDifficultyLevel=function()return 20 end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    C_QuestLog.IsRepeatableQuest=function()return false end
    C_Item={IsItemDataCachedByID=function()return true end,
        GetItemInfo=function(id)return "Helmet","item:"..id,2,22,15,"Armor","Plate",1,"INVTYPE_HEAD",100 end,
        GetItemInfoInstant=function(id)return id,"Armor","Plate","INVTYPE_HEAD",100,4,0 end,
        GetItemNameByID=function()end,GetItemQualityByID=function()end}
    C_TooltipInfo.GetHyperlink=function(link)
        return {id=tonumber(link:match("item:(%d+)")),type=0,hyperlink=link,dataInstanceID=123,lines={{leftText="Native item stat"}}}
    end
    Menu={GetManager=function()return {IsAnyMenuOpen=function()return W.openMenu~=nil end} end}
    if native then
        assert(handler and manager,"Pinned native tooltip fixtures required for this scenario")
        -- Execute the pinned renderer's actual procedure with mock callback and
        -- line services. Its post callbacks precede Show, the reentry boundary.
        for _,name in ipairs({"ProcessInfo","InternalProcessInfo","ClearHandlerInfo","HasDataInstanceID"}) do
            local method=handler:match("(function TooltipDataHandlerMixin:"..name.."%b()%s.-\nend)")
            assert(loadstring(assert(method,"Missing pinned method "..name)))()
        end
        TooltipDataHandlerMixin.ProcessLines=function(t)
            t.data=t.processingInfo.tooltipData
            for _,line in ipairs(t.data.lines) do t:AddLine(line.leftText) end
        end
        securecallfunction=function(fn,...)return fn(...)end
        ProcessTooltipPreCalls=function()return false end
        ProcessTooltipPostCalls=function(_,t,data)if post then post(N,t,data) end end
        RegisterEventCallback=function()end; assert(loadstring(manager))()
        Enum.TooltipComparisonMethod={Single=0,WithBagMainHandItem=1,WithBagOffHandItem=2,WithBothHands=3}
        GetScreenWidth=function()return 1920 end; EQUIPPED="Equipped"; IF_EQUIPPED_TOGETHER="Together"
        ITEM_DELTA_DESCRIPTION="Stat changes"
        ITEM_COMPARISON_SWAP_ITEM_MAINHAND_DESCRIPTION="Press %s to swap mainhand"
        ITEM_COMPARISON_SWAP_ITEM_OFFHAND_DESCRIPTION="Press %s to swap offhand"
        ITEM_COMPARISON_CYCLING_DISABLED_MSG_MAINHAND="Mainhand cycling unavailable"
        ITEM_COMPARISON_CYCLING_DISABLED_MSG_OFFHAND="Offhand cycling unavailable"
        GetBindingKeyForAction=function()return "TAB" end
        GetCVarBool=function(name)return name=="allowCompareWithToggle" end
        GameTooltip_AddBlankLineToTooltip=function(t)t:AddLine(" ")end
        GameTooltip_AddNormalLine=function(t,value)t:AddLine(value)end
        GameTooltip_AddHighlightLine=function(t,value)t:AddLine(value)end
        GameTooltip_AddDisabledLine=function(t,value)t:AddLine(value)end
        C_TooltipComparison={GetItemComparisonInfo=function()
            return {method=0,item={hyperlink="item:124"},additionalItems={{hyperlink="item:125"},{hyperlink="item:126"}}}
        end,GetItemComparisonDelta=function()return {"Crit +1"}end}
        GameTooltip=W.Object(true); ShoppingTooltip1=W.Object(true); ShoppingTooltip2=W.Object(true); BattlePetTooltip=W.Object(true)
        TooltipComparisonManager.tooltip=GameTooltip; TooltipComparisonManager.comparisonIndex=7
    end
    local S=N.Search;S:Create();S.filter.scope="LEVEL_RANGE";S.filter.sort="FIT"; S:Toggle(); W.time=.3; S.frame:Fire("OnUpdate",.3)
    S.frame.x=400; S.frame.y=200; S.frame.width=560; S.frame.height=600
    S.scroll.x=412; S.scroll.y=216; S.scroll.width=522; S.scroll.height=442
    local b=S.cards[1].icons[1]; b.x=430; b.y=500; b.width=28; b.height=28
    W.mouseX=440; W.mouseY=510
    assert(S.inspector:Tooltips())
    local t=S.inspector.tooltip; t.x=970; t.y=300; t.width=280; t.height=300
    for _,tip in ipairs(t.shoppingTooltips) do tip.x=1300; tip.y=300; tip.width=240; tip.height=200; tip.CompareHeader.Label.width=80 end
    return N,S,b
end
local function hidden(inspector)
    if inspector.item or inspector.tooltip:IsShown() then return false end
    for _,tip in ipairs(inspector.tooltip.shoppingTooltips) do if tip:IsShown() then return false end end
    return true
end
local function contains(t,value)
    for _,line in ipairs(t.lines or {}) do if line==value then return true end end
    return false
end

test("matching registered tooltip updates cannot restart pointer departure",function()
    local N,S,b=setup(); b:Fire("OnEnter"); assert(S.inspector.item)
    W.mouseX,W.mouseY=700,450; W.time=.4; S.frame:Fire("OnUpdate",.1); local outside=S.inspector.itemOutsideAt
    for _,now in ipairs({.45,.5,.55}) do
        W.time=now; W.Event("TOOLTIP_DATA_UPDATE",123); S.frame:Fire("OnUpdate",.05)
        assert(S.inspector.item and S.inspector.itemOutsideAt==outside)
    end
    W.time=.61; W.Event("TOOLTIP_DATA_UPDATE",123); S.frame:Fire("OnUpdate",.06)
    assert(hidden(S.inspector) and S:Visible())
end)

test("matching refresh keeps tooltip transit and comparison geometry alive",function()
    local N,S,b=setup(); b:Fire("OnEnter"); W.mouseX=1100; W.mouseY=400
    W.time=.5; W.Event("TOOLTIP_DATA_UPDATE",123); S.frame:Fire("OnUpdate",.2)
    assert(S.inspector.item and S.inspector.itemOutsideAt==nil)
    W.shift=true; W.mouseX=1400; W.Event("TOOLTIP_DATA_UPDATE",123)
    S.inspector.tooltip.shoppingTooltips[1]:Show(); W.time=.8; S.frame:Fire("OnUpdate",.3)
    assert(S.inspector.item and S.inspector.itemOutsideAt==nil)
end)

test("registered update rejects stale generation and reassigned pooled rows",function()
    for _,change in ipairs({function(i,b)i.generation=i.generation+1 end,function(i,b)b.row={itemID=b.row.itemID,state="ready"}end}) do
        local N,S,b=setup(); b:Fire("OnEnter"); change(S.inspector,b)
        W.Event("TOOLTIP_DATA_UPDATE",123); assert(hidden(S.inspector))
    end
end)

test("hover stack refresh rejects a stale session through its registered event",function()
    local N=W.Init(); W.shift=true; W.items={{"Helmet",100,1,2,true,123}}
    local pin=W.Object(); pin.x=690; pin.y=690; pin.width=30; pin.height=30; pin.questID=9
    W.mouseX=700; W.mouseY=700; EventRegistry:TriggerEvent("MapCanvas.QuestPin.OnEnter",pin,9)
    N.Stack.scroll.x=736; N.Stack.scroll.y=408; N.Stack.scroll.width=292; N.Stack.scroll.height=362
    local b=N.Stack.cards[1].icons[1]; b.x=750; b.y=690; W.mouseX=760; W.mouseY=700
    b:Fire("OnEnter"); assert(N.Stack.item); N.Hover.generation=N.Hover.generation+1
    W.Event("TOOLTIP_DATA_UPDATE",123); assert(hidden(N.Stack))
end)

test("pointer tick rejects a reassigned pooled row without a data event",function()
    local N,S,b=setup(); b:Fire("OnEnter"); assert(S.inspector.item)
    b.row={itemID=123,state="ready"}; W.time=.4; S.frame:Fire("OnUpdate",.1)
    assert(hidden(S.inspector) and S:Visible())
end)

if not handler or not manager then print("SKIP native lifecycle regressions: current pinned fixtures absent"); return end

test("pinned primary renderer cannot resurrect inspection after owner teardown",function()
    for _,teardown in ipairs({
        function(N)N.Search.frame:Hide()end,
        function(N)N.Core:Change("enabled",false)end,
        function(N)N.Search.scroll:Fire("OnMouseWheel",-1)end,
        function(N)N.Search.inspector.generation=N.Search.inspector.generation+1 end,
        function(N)N.Search.inspector.item.button.row={itemID=123,state="ready"}end,
        function()W.openMenu={}end,
    }) do
        local N,S,b=setup(true,function(N)teardown(N)end)
        b:Fire("OnEnter"); assert(hidden(S.inspector))
        assert(TooltipComparisonManager.tooltip==GameTooltip and GameTooltip:IsShown() and BattlePetTooltip:IsShown())
    end
end)

test("pinned comparison renderer cannot resurrect primary or secondary tips",function()
    for _,name in ipairs({"FindAnUpgradeSearchComparison1","FindAnUpgradeSearchComparison2"}) do
        local N,S,b=setup(true,function(N,t)if t.name==name then N.Search.frame:Hide() end end)
        W.shift=true; b:Fire("OnEnter"); assert(hidden(S.inspector) and not S:Visible())
        assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7 and GameTooltip:IsShown())
    end
end)

test("pinned comparison retains item and delta stats without unsupported cycling hints",function()
    for _,method in ipairs({0,2}) do for _,binding in ipairs({"TAB",""}) do
        local N,S,b=setup(true)
        GetBindingKeyForAction=function()return binding end
        C_TooltipComparison.GetItemComparisonInfo=function()
            return {method=method,item={hyperlink="item:124"},additionalItems={{hyperlink="item:125"},{hyperlink="item:126"}}}
        end
        W.shift=true; b:Fire("OnEnter"); local i=S.inspector; assert(i.item and i.tooltip:IsShown())
        for _,tip in ipairs(i.tooltip.shoppingTooltips) do
            assert(tip:IsShown() and contains(tip,"Native item stat"))
            assert(not contains(tip,"Press TAB to swap mainhand") and not contains(tip,"Press TAB to swap offhand"))
            assert(not contains(tip,ITEM_COMPARISON_CYCLING_DISABLED_MSG_MAINHAND) and not contains(tip,ITEM_COMPARISON_CYCLING_DISABLED_MSG_OFFHAND))
        end
        assert(contains(i.tooltip.shoppingTooltips[1],"Crit +1") and contains(i.tooltip.shoppingTooltips[1],"Stat changes"))
        assert(i.cycleHints==nil and TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7)
        W.shift=false; S.frame:Fire("OnUpdate",.1); assert(i.item and not i.tooltip.shoppingTooltips[1]:IsShown())
        assert(GameTooltip:IsShown() and ShoppingTooltip1:IsShown() and ShoppingTooltip2:IsShown() and BattlePetTooltip:IsShown())
    end end
end)

test("cycling text filtering is confined to owned native comparison rendering",function()
    local N,S,b=setup(true); W.shift=true; b:Fire("OnEnter"); local i=S.inspector
    i.tooltip.shoppingTooltips[1]:AddLine("Custom item stat")
    i.tooltip:AddLine("Press TAB to swap mainhand")
    assert(contains(i.tooltip.shoppingTooltips[1],"Custom item stat") and contains(i.tooltip,"Press TAB to swap mainhand"))
    assert(i.cycleHints==nil and GetCVarBool("allowCompareWithToggle") and GetBindingKeyForAction()=="TAB")
end)

test("hint-like native item data is preserved while duplicate cycling instruction is omitted",function()
    local N,S,b=setup(true)
    C_TooltipInfo.GetHyperlink=function(link)
        return {id=tonumber(link:match("item:(%d+)")),type=0,hyperlink=link,dataInstanceID=123,
            lines={{leftText="Native item stat"},{leftText="Press TAB to swap mainhand"}}}
    end
    W.shift=true; b:Fire("OnEnter"); local i=S.inspector; assert(i.item)
    for _,tip in ipairs(i.tooltip.shoppingTooltips) do
        local matches=0; for _,line in ipairs(tip.lines) do if line=="Press TAB to swap mainhand" then matches=matches+1 end end
        assert(matches==1 and contains(tip,"Native item stat") and not tip.questBriefItemData)
    end
end)

test("comparison-only native updates refresh the whole owned inspection without rearming transit",function()
    local N,S,b=setup(true); local fresh=false
    C_TooltipInfo.GetHyperlink=function(link)
        local id=tonumber(link:match("item:(%d+)"))
        return {id=id,type=0,hyperlink=link,dataInstanceID=id+1000,lines={{leftText="Item "..id..(fresh and " fresh" or " old")}}}
    end
    W.shift=true; b:Fire("OnEnter"); local i=S.inspector
    assert(i.item and contains(i.tooltip.shoppingTooltips[1],"Item 124 old") and i:HasTooltipData(1124))
    W.mouseX,W.mouseY=700,450; W.time=.4; S.frame:Fire("OnUpdate",.1); local outside=i.itemOutsideAt
    fresh=true; W.time=.45; W.Event("TOOLTIP_DATA_UPDATE",1124)
    assert(i.item and i.itemOutsideAt==outside and contains(i.tooltip,"Item 123 fresh"))
    assert(contains(i.tooltip.shoppingTooltips[1],"Item 124 fresh") and contains(i.tooltip.shoppingTooltips[2],"Item 125 fresh"))
    local current=i.item; W.Event("TOOLTIP_DATA_UPDATE",9999); assert(i.item==current)
    assert(not i:HasTooltipData(W.secret) and not i:HasTooltipData("1124"))
    W.time=.61; S.frame:Fire("OnUpdate",.16); assert(hidden(i))
    assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7 and GameTooltip:IsShown())
end)

test("cold native comparison item recovers while Shift remains held without load spam",function()
    local N,S,b=setup(true); local cold=true; local calls,loads=0,0
    local get=C_TooltipInfo.GetHyperlink
    C_TooltipInfo.GetHyperlink=function(link)
        if link=="item:124" then calls=calls+1; if cold then return end end
        return get(link)
    end
    C_Item.RequestLoadItemDataByID=function()loads=loads+1 end
    W.shift=true; b:Fire("OnEnter"); local i=S.inspector
    assert(i.item and not i.tooltip.shoppingTooltips[1]:IsShown() and calls==1)
    cold=false; W.Event("ITEM_DATA_LOAD_RESULT",124,true); W.Event("GET_ITEM_INFO_RECEIVED",124,true)
    for frame=1,120 do W.time=.3+frame/60; S.frame:Fire("OnUpdate",1/60) end
    assert(i.item and i.tooltip.shoppingTooltips[1]:IsShown() and contains(i.tooltip.shoppingTooltips[1],"Native item stat"))
    assert(contains(i.tooltip.shoppingTooltips[1],"Crit +1") and calls==2 and loads==0 and not i.item.compareRetryAt)
    assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7 and GameTooltip:IsShown())
end)

test("cold native comparison metadata is refetched despite the clone identity cache",function()
    local N,S,b=setup(true); local cold=true; local calls=0
    local get=C_TooltipComparison.GetItemComparisonInfo
    C_TooltipComparison.GetItemComparisonInfo=function(item)calls=calls+1; if not cold then return get(item) end end
    W.shift=true; b:Fire("OnEnter"); local i=S.inspector
    assert(i.item and i.comparison.compareInfo==nil and calls==1)
    cold=false; W.time=.51; S.frame:Fire("OnUpdate",.21)
    assert(i.tooltip.shoppingTooltips[1]:IsShown() and calls==2 and not i.item.compareRetryAt)
    assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7)
end)

test("permanently cold comparisons keep a fixed bounded retry window through update floods",function()
    for _,metadata in ipairs({false,true}) do
        local N,S,b=setup(true); local calls,loads=0,0
        if metadata then C_TooltipComparison.GetItemComparisonInfo=function()calls=calls+1 end
        else
            local get=C_TooltipInfo.GetHyperlink
            C_TooltipInfo.GetHyperlink=function(link)if link=="item:124" then calls=calls+1; return end; return get(link)end
        end
        C_Item.RequestLoadItemDataByID=function()loads=loads+1 end
        W.shift=true; b:Fire("OnEnter"); local i=S.inspector; local deadline=i.item.compareDeadline
        for frame=1,800 do
            W.time=.3+frame/100; W.Event("TOOLTIP_DATA_UPDATE",123); S.frame:Fire("OnUpdate",.01)
            assert(i.item and i.item.compareDeadline==deadline)
        end
        assert(calls>=2 and calls<=26 and loads==0 and i.item.compareTimedOut and not i.item.compareRetryAt)
        local stopped=calls
        for frame=1,600 do W.time=8.3+frame/60; S.frame:Fire("OnUpdate",1/60) end
        assert(calls==stopped and i.item and contains(i.tooltip,"Native item stat"))
        assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7 and GameTooltip:IsShown())
    end
end)

test("a missing equipped comparison entry is not treated as pending item data",function()
    local N,S,b=setup(true); local calls=0
    C_TooltipComparison.GetItemComparisonInfo=function()calls=calls+1; return {method=0,additionalItems={}}end
    W.shift=true; b:Fire("OnEnter"); local i=S.inspector
    for frame=1,120 do W.time=.3+frame/60; S.frame:Fire("OnUpdate",1/60) end
    assert(i.item and not i.item.compareRetryAt and calls==1)
end)

test("cold comparison retries stop on modifier release or inspection invalidation",function()
    for _,stop in ipairs({
        function(N,S,b)W.shift=false end,
        function(N,S,b)W.mouseX=700; W.mouseY=450 end,
        function(N,S,b)S.frame:Hide()end,
        function(N,S,b)S.inspector.generation=S.inspector.generation+1 end,
        function(N,S,b)b.row={itemID=123,state="ready"}end,
    }) do
        local N,S,b=setup(true); local calls=0; local get=C_TooltipInfo.GetHyperlink
        C_TooltipInfo.GetHyperlink=function(link)if link=="item:124" then calls=calls+1; return end; return get(link)end
        W.shift=true; b:Fire("OnEnter"); local i=S.inspector; stop(N,S,b)
        W.time=.4; S.frame:Fire("OnUpdate",.1); W.time=.61; S.frame:Fire("OnUpdate",.21)
        local stopped=calls
        for frame=1,600 do W.time=.61+frame/60; S.frame:Fire("OnUpdate",1/60) end
        assert(calls==stopped and (not i.item or not i.item.compareRetryAt))
        assert(TooltipComparisonManager.tooltip==GameTooltip and GameTooltip:IsShown())
    end
end)

test("comparison recovery preserves departure grace and handles reentrant teardown",function()
    for _,teardown in ipairs({false,true}) do
        local N,S,b=setup(true,function(N,t)if teardown and t.name=="FindAnUpgradeSearchComparison1" then N.Search.frame:Hide() end end)
        local cold=true; local get=C_TooltipInfo.GetHyperlink
        C_TooltipInfo.GetHyperlink=function(link)if cold and link=="item:124" then return end; return get(link)end
        W.shift=true; b:Fire("OnEnter"); local i=S.inspector
        W.mouseX,W.mouseY=700,450; W.time=.4; S.frame:Fire("OnUpdate",.1); local outside=i.itemOutsideAt
        cold=false; W.time=.51; S.frame:Fire("OnUpdate",.11)
        if teardown then assert(hidden(i) and not S:Visible())
        else
            assert(i.item and i.itemOutsideAt==outside and i.tooltip.shoppingTooltips[1]:IsShown() and not i.item.compareRetryAt)
            W.time=.61; S.frame:Fire("OnUpdate",.1); assert(hidden(i))
        end
        assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7 and GameTooltip:IsShown())
    end
end)

test("nil primary tooltip data recovers under a stationary pointer after cache events",function()
    local N,S,b=setup(true); local cold=true; local calls,comparisons=0,0
    local get=C_TooltipInfo.GetHyperlink; local compare=C_TooltipComparison.GetItemComparisonInfo
    C_TooltipInfo.GetHyperlink=function(link)if link=="item:123" then calls=calls+1; if cold then return end end; return get(link)end
    C_TooltipComparison.GetItemComparisonInfo=function(item)comparisons=comparisons+1; return compare(item)end
    W.shift=true; b:Fire("OnEnter"); local i=S.inspector
    assert(i.item and i.item.pending and i.item.data==nil and not i.tooltip:IsShown() and comparisons==0 and calls==1)
    cold=false; W.Event("ITEM_DATA_LOAD_RESULT",123,true); W.Event("GET_ITEM_INFO_RECEIVED",123,true)
    for frame=1,120 do W.time=.3+frame/60; S.frame:Fire("OnUpdate",1/60) end
    assert(i.item and not i.item.pending and i.item.data.id==123 and i.tooltip:IsShown() and calls==2 and comparisons==1)
    assert(contains(i.tooltip,"Native item stat") and contains(i.tooltip.shoppingTooltips[1],"Crit +1") and not i.item.primaryRetryAt)
    assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7 and GameTooltip:IsShown())
end)

test("permanently nil primary data uses a fixed bounded deadline and leaves no inspection",function()
    for _,fps in ipairs({30,240}) do
        local N,S,b=setup(true); local calls=0
        C_TooltipInfo.GetHyperlink=function()calls=calls+1 end
        b:Fire("OnEnter"); local i=S.inspector; local deadline=i.item.primaryDeadline
        for frame=1,fps*8 do
            W.time=.3+frame/fps; W.Event("ITEM_DATA_LOAD_RESULT",123,true); W.Event("TOOLTIP_DATA_UPDATE",123); S.frame:Fire("OnUpdate",1/fps)
            if i.item then assert(i.item.primaryDeadline==deadline and i.item.pending and not i.tooltip:IsShown()) end
        end
        assert(calls>=2 and calls<=26 and hidden(i) and deadline==5.3)
        local stopped=calls
        for frame=1,fps*5 do W.time=8.3+frame/fps; S.frame:Fire("OnUpdate",1/fps) end
        assert(calls==stopped and hidden(i) and TooltipComparisonManager.tooltip==GameTooltip and GameTooltip:IsShown())
    end
end)

test("pending primary data cannot show after departure or getter and frame teardown",function()
    for _,duringGetter in ipairs({false,true}) do for _,stop in ipairs({
        function(N,S,b)W.mouseX=700; W.mouseY=450 end,
        function(N,S,b)S.frame:Hide()end,
        function(N,S,b)S.inspector.generation=S.inspector.generation+1 end,
        function(N,S,b)b.row={itemID=123,state="ready"}end,
    }) do
        local N,S,b=setup(true); local cold=true; local calls=0; local get=C_TooltipInfo.GetHyperlink
        C_TooltipInfo.GetHyperlink=function(link)
            calls=calls+1; if duringGetter then stop(N,S,b) end
            if not cold then return get(link) end
        end
        b:Fire("OnEnter"); if not duringGetter then stop(N,S,b) end
        cold=false; W.time=.4; S.frame:Fire("OnUpdate",.1); W.time=.61; S.frame:Fire("OnUpdate",.21)
        local stopped=calls
        for frame=1,120 do W.time=.61+frame/60; S.frame:Fire("OnUpdate",1/60) end
        assert(hidden(S.inspector) and calls==stopped and stopped==1)
        assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==7 and GameTooltip:IsShown())
    end end
end)

test("only nil primary data is pending while restricted malformed failed and absent APIs close",function()
    for _,invalid in ipairs({
        function()return W.secret end,
        function()return false end,
        function()return "bad" end,
        function()return {} end,
        function()return {id=999,type=0,lines={}}end,
        function()return {id=123,type=9,lines={}}end,
        function()error("unavailable getter")end,
    }) do
        local N,S,b=setup(true); C_TooltipInfo.GetHyperlink=invalid; b:Fire("OnEnter")
        assert(hidden(S.inspector))
    end
    local N,S,b=setup(true); canaccessallvalues=function()return false end; b:Fire("OnEnter"); assert(hidden(S.inspector))
    N,S,b=setup(true); C_TooltipInfo.GetHyperlink=nil
    C_TooltipInfo.GetQuestLogItem=function()error("wrong getter fallback")end
    b:Fire("OnEnter"); assert(hidden(S.inspector))
end)


test("native item hover adds no explanatory usability note",function()
    local N,S,b=setup();b.row.usable=nil;b:Fire("OnEnter")
    assert(S.inspector.item and S.inspector.tooltip:IsShown())
    assert(not contains(S.inspector.tooltip,"Class usability unconfirmed"))
end)

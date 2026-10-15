local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local native=ROOT.."/.work/current-api/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua"
local file=io.open(native,"rb");if not file then print("SKIP equipped source integration: pinned fixture absent");return end;file:close()
local function setup(method)
    local N=W.Init();W.shift=true;RegisterEventCallback=function()end;assert(loadfile(native))()
    Enum.TooltipComparisonMethod={Single=0,WithBagMainHandItem=1,WithBagOffHandItem=2,WithBothHands=3}
    EQUIPPED="Equipped";IF_EQUIPPED_TOGETHER="If equipped together";ITEM_DELTA_DESCRIPTION="Native changes"
    ITEM_DELTA_MULTIPLE_COMPARISON_DESCRIPTION="Native combined changes"
    ITEM_DELTA_DUAL_WIELD_COMPARISON_MAINHAND_DESCRIPTION="%s%s";ITEM_DELTA_DUAL_WIELD_COMPARISON_OFFHAND_DESCRIPTION="%s%s"
    GameTooltip_AddBlankLineToTooltip=function(t)t:AddLine(" ")end
    GameTooltip_AddNormalLine=function(t,line)t:AddLine(line)end
    GameTooltip_AddHighlightLine=GameTooltip_AddNormalLine;GameTooltip_AddDisabledLine=GameTooltip_AddNormalLine
    GetScreenWidth=function()return 1920 end
    local state={calls=0,deltas={},primary=124,secondary=125,method=method or 0}
    N.Character.snapshot.equipment={{itemID=124},{itemID=125}}
    C_Item={GetItemNameByID=function()end,GetItemQualityByID=function()end}
    C_TooltipComparison={GetItemComparisonInfo=function()
        state.calls=state.calls+1;if state.cold then return end
        return {method=state.method,item=state.primary and {hyperlink="item:"..state.primary},
            additionalItems=state.secondary and {{hyperlink="item:"..state.secondary}} or {}}
    end,GetItemComparisonDelta=function(candidate,equipped,additional,paired)
        state.deltas[#state.deltas+1]={candidate,equipped,additional,paired};return {"Native engine delta -7"}
    end}
    C_TooltipInfo.GetHyperlink=function(link)
        local id=tonumber(link:match("item:(%d+)"));if state.coldItem==id then return end
        return {type=0,id=id,hyperlink=link,lines={},dataInstanceID=id}
    end
    TooltipDataHandlerMixin.ProcessInfo=function(t,info)
        if not info.append then t:ClearLines()end;t.data=info.tooltipData;t:AddLine("Native item "..t.data.id);t:Show();return true
    end
    GameTooltip=W.Object(true);TooltipComparisonManager.tooltip=GameTooltip;TooltipComparisonManager.comparisonIndex=17
    local frame,scroll,button=W.Object(),W.Object(),W.Object()
    frame.x=400;frame.y=200;frame.width=476;frame.height=680
    scroll.x=416;scroll.y=216;scroll.width=444;scroll.height=480
    button.x=450;button.y=500;button.width=28;button.height=28
    button.row={state="ready",itemID=123,kind="catalog",link="item:123"}
    local active=true;local inspector=N.Stack.NewInspector(frame,scroll,function()return active end)
    inspector:Tooltips();local tip=inspector.tooltip;tip.x=890;tip.y=300;tip.width=250;tip.height=300
    for i,t in ipairs(tip.shoppingTooltips)do t.x=1140+(i-1)*240;t.y=400;t.width=240;t.height=200;t.CompareHeader.Label.width=80 end
    W.mouseX=460;W.mouseY=510
    return inspector,button,state,function()active=false end
end
local function contains(t,value)for _,line in ipairs(t.lines or {})do if line==value then return true end end;return false end
local function isolated()assert(TooltipComparisonManager.tooltip==GameTooltip and TooltipComparisonManager.comparisonIndex==17 and GameTooltip:IsShown())end
test("rings and trinkets use both exact native equipped items and native deltas",function()
    for _=1,2 do
        local i,b,s=setup();i:Inspect(b,b.row)
        local first,second=i.tooltip.shoppingTooltips[1],i.tooltip.shoppingTooltips[2]
        assert(first:IsShown() and second:IsShown() and contains(first,"Native item 124") and contains(second,"Native item 125"))
        assert(contains(first,"Native engine delta -7") and contains(second,"Native engine delta -7") and #s.deltas==2)
        assert(s.deltas[1][1].hyperlink=="item:123" and s.deltas[1][2].hyperlink=="item:124" and s.deltas[1][3]==nil)
        assert(first.CompareHeader.Label:GetText()==EQUIPPED and second.CompareHeader.Label:GetText()==EQUIPPED);isolated()
    end
end)
test("native two-hand and paired-hand methods own legality and combined delta inputs",function()
    for _,method in ipairs({1,2,3})do
        local i,b,s=setup(method);i:Inspect(b,b.row)
        assert(#s.deltas==1 and s.deltas[1][3].hyperlink=="item:125" and s.deltas[1][4]==(method~=3))
        local first,second=i.tooltip.shoppingTooltips[1],i.tooltip.shoppingTooltips[2]
        assert(first:IsShown() and second:IsShown() and not contains(second,"Native engine delta -7"))
        assert(second.CompareHeader.Label:GetText()==(method==3 and EQUIPPED or IF_EQUIPPED_TOGETHER))
        assert(contains(first,method==3 and ITEM_DELTA_MULTIPLE_COMPARISON_DESCRIPTION or ITEM_DELTA_DESCRIPTION));isolated()
    end
end)
test("empty native equipped slots stay absent without invented zero tooltips or retries",function()
    local i,b,s=setup();s.primary=nil;s.secondary=nil;i:Inspect(b,b.row)
    assert(i.item and not i.tooltip.shoppingTooltips[1]:IsShown() and not i.tooltip.shoppingTooltips[2]:IsShown())
    for n=1,120 do W.time=n/60;i:Compare()end
    assert(s.calls==1 and not i.item.compareRetryAt and #s.deltas==0);isolated()
end)
test("equipment changes invalidate native identity cache and refresh candidate without losing transit",function()
    local i,b,s=setup();i:Inspect(b,b.row);i.item.bridgeAt=.1;i.itemOutsideAt=.2
    s.primary=126;s.secondary=nil;i:EquipmentChanged()
    assert(s.calls==2 and contains(i.tooltip.shoppingTooltips[1],"Native item 126") and not i.tooltip.shoppingTooltips[2]:IsShown())
    assert(i.item.bridgeAt==.1 and i.itemOutsideAt==.2 and i.tooltip.data.id==123);isolated()
end)
test("modifier and CVar transitions honor native remapping without global comparison mutation",function()
    local i,b,s=setup();W.compareClick=false;i:Inspect(b,b.row);assert(s.calls==0)
    W.compareClick=true;i:Compare();assert(s.calls==1)
    W.compareClick=false;i:Compare();assert(not i.compareState and not i.tooltip.shoppingTooltips[1]:IsShown())
    W.alwaysCompare=true;i:ComparisonChanged();assert(i.compareState and s.calls==2)
    W.alwaysCompare=false;i:ComparisonChanged();assert(not i.compareState and not i.tooltip.shoppingTooltips[1]:IsShown());isolated()
end)
test("cold native comparison metadata is bounded and a later equipped load revives it",function()
    for _,coldInfo in ipairs({false,true})do
        local i,b,s=setup();if coldInfo then s.cold=true else s.coldItem=124 end;i:Inspect(b,b.row)
        local deadline=i.item.compareDeadline
        for n=1,800 do W.time=n/100;i:Compare()end
        assert(i.item.compareTimedOut and i.item.compareDeadline==deadline and s.calls<=26)
        local calls=s.calls;for n=1,100 do W.time=8+n/60;i:Compare()end;assert(s.calls==calls)
        s.cold=false;s.coldItem=nil;i:ComparisonItemData(124)
        assert(i.tooltip.shoppingTooltips[1]:IsShown() and not i.item.compareTimedOut and s.calls==calls+1);isolated()
    end
end)
test("late metadata and equipment invalidation cannot resurrect a stale inspector",function()
    for _,invalidate in ipairs({function(i,close)close()end,function(i)i.generation=i.generation+1 end,function(i,_,b)b.row={}end})do
        local i,b,s,close=setup();s.cold=true;i:Inspect(b,b.row);local calls=s.calls;invalidate(i,close,b)
        s.cold=false;i:ComparisonItemData(124);i:EquipmentChanged();i:ComparisonChanged()
        assert(not i.item and not i.tooltip:IsShown() and s.calls==calls);isolated()
    end
end)
test("missing button or row state is rejected during late comparison events",function()
    for _,malformed in ipairs({{row={},compareTimedOut=true}, {button={},compareTimedOut=true}})do
        local i=setup();i.item=malformed
        assert(not i:InspectionCurrent(malformed));i:ComparisonItemData(123)
        assert(i.item==nil and not i.tooltip:IsShown())
    end
end)
test("unrelated duplicate and cold item-load floods cannot rearm or bypass bounded retries",function()
    local i,b,s=setup();s.cold=true;i:Inspect(b,b.row);local deadline=i.item.compareDeadline
    for n=1,1600 do
        W.time=n/100;i:ComparisonItemData(n%2==0 and 124 or 999);i:Compare()
    end
    assert(i.item.compareTimedOut and s.calls<=52 and i.item.comparisonLoads[124] and i.item.compareDeadline>deadline)
    local calls=s.calls
    for n=1,800 do W.time=16+n/100;i:ComparisonItemData(124);i:ComparisonItemData(999);i:Compare()end
    assert(s.calls==calls and i.item.compareTimedOut)
end)
test("pointer bridge crosses the outside-viewport gap with a bounded lifetime",function()
    local i,b=setup();i:Inspect(b,b.row);W.mouseX=875;W.mouseY=514
    assert(i:ItemContains(1) and i:ItemContains(2.24) and not i:ItemContains(2.26))
    W.mouseX=900;assert(i:ItemContains(2.3));W.mouseX=875;assert(i:ItemContains(3))
    b.y=150;assert(not i:ItemContains(3.1))
end)
test("native comparison and header geometry retain owned pointer transit",function()
    local i,b=setup();i:Inspect(b,b.row)
    W.mouseX=1200;W.mouseY=500;assert(i:ItemContains(1))
    local second=i.tooltip.shoppingTooltips[2];second.CompareHeader.x=1380;second.CompareHeader.y=605;second.CompareHeader.width=120;second.CompareHeader.height=22
    W.mouseX=1400;W.mouseY=615;assert(i:ItemContains(1.1))
    W.shift=false;i:Compare();assert(not i:ItemContains(1.2));isolated()
end)

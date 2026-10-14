local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function start()
    local N=W.Init();N.Stack:Create();W.items={{"Reward",100,2,2,true,123}};W.shift=true
    local f=W.Object();f.x=690;f.y=690;f.width=30;f.height=30;f.questID=9;f.GetQuestID=function()return 9 end
    N.Sources:Pin(f,9);N.Stack.frame.x=730;N.Stack.frame.y=660;N.Stack.scroll.x=730;N.Stack.scroll.y=660
    local b=N.Stack.cards[1].icons[1];b.x=738;b.y=680;W.mouseX,W.mouseY=750,694
    return N,b
end
test("default verified orange and green fill hues are not dominated by native blue",function()
    local N=W.Init();local p=N.Core.profile
    local r,g,b=N.Model.AccentFill(p,"verifiedNew",.09,.09,.19);assert(r>g and g>b)
    r,g,b=N.Model.AccentFill(p,"verifiedUpdated",.09,.09,.19);assert(g>r and g>b)
    p.strength=1;r,g,b=N.Model.AccentFill(p,"verifiedNew",.09,.09,.19);assert(r>g and g>b)
    r,g,b=N.Model.AccentFill(p,"verifiedUpdated",.09,.09,.19);assert(g>r and g>b)
    p.accents=false;r,g,b=N.Model.AccentFill(p,"verifiedNew",.09,.09,.19);assert(r==.09 and g==.09 and b==.19)
    p.accents=true;r,g,b=N.Model.AccentFill(p,nil,.09,.09,.19);assert(r==.09 and g==.09 and b==.19)
end)
test("both reward views inherit native small numeric count fonts without shared writes",function()
    local N,b=start();N.Search:Create();local card=N.Search:Card(1);local other=N.Search:Icon(card,1)
    assert(b.count.fontObject==NumberFontNormalSmall and other.count.fontObject==NumberFontNormalSmall)
    assert(not N.UI.fontSizes[b.count] and not N.UI.fontSizes[other.count] and not NumberFontNormalSmall.fontWrites)
end)
test("always compare preference survives private automatic-manager suppression",function()
    local N,b=start();W.shift=false;W.alwaysCompare=true;b:Fire("OnEnter")
    local file=io.open(ROOT.."/.work/current-api/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua","rb")
    if file then
        local source=file:read("*a");file:close()
        local helper=source:match("(function TooltipUtil.ShouldDoItemComparison%b()%s.-\nend)")
        assert(loadstring(assert(helper)))()
        assert(TooltipUtil.ShouldDoItemComparison(N.Stack.tooltip)==false)
        assert(TooltipUtil.ShouldDoItemComparison({suppressAutomaticCompareItem=false})==true)
    end
    assert(N.Stack.item and N.Stack.tooltip.suppressAutomaticCompareItem and N.Stack.comparison.calls==1)
    assert(TooltipComparisonManager.calls==nil and N.Stack.compareState)
    W.alwaysCompare=false;N.Stack:Compare();assert(not N.Stack.compareState and TooltipComparisonManager.clears==nil)
end)
test("native comparison modified action is honored independently of physical Shift",function()
    local N,b=start();W.shift=false;W.compareClick=true;b:Fire("OnEnter");assert(N.Stack.compareState)
    W.compareClick=false;W.shift=true;N.Stack:Compare();assert(not N.Stack.compareState)
end)
test("repeated early options failures reuse permanent content and text objects",function()
    local N=W.Init();local build=N.Options.Build
    N.Options.Build=function(self,owner,frame,parent)self:Label(parent,"Heading",20,-15,560,16);error("persistent early failure")end
    local frames,texts
    for i=1,30 do
        assert(not pcall(SlashCmdList.QUESTBRIEF,"opts"));assert(not N.Options.shell:IsShown() and not N.Options.frame)
        frames,texts=frames or #W.frames,texts or #W.fontStrings;assert(#W.frames==frames and #W.fontStrings==texts)
    end
    N.Options.Build=build;SlashCmdList.QUESTBRIEF("opts");assert(N.Options.frame:IsShown() and N.Options.content:IsShown())
    local total=#W.frames;for i=1,30 do SlashCmdList.QUESTBRIEF("opts")end;assert(#W.frames==total)
end)
test("repeated late options failures reuse controls and retain atomic retry",function()
    local N=W.Init();local original=CreateFrame
    CreateFrame=function(kind,name,parent,template)
        local f=original(kind,name,parent,template)
        if name=="QuestBriefOptions"then local register=f.RegisterEvent;f.RegisterEvent=function(self,event)if event=="DISPLAY_SIZE_CHANGED" and not W.allowRecovery then error("persistent late failure")end;return register(self,event)end end
        return f
    end
    local frames,texts
    for i=1,30 do
        assert(not pcall(SlashCmdList.QUESTBRIEF,"opts"));frames,texts=frames or #W.frames,texts or #W.fontStrings
        assert(#W.frames==frames and #W.fontStrings==texts and not next(N.Options.shell.events))
        assert(not next(N.UI.fontSizes) and #UISpecialFrames==0)
    end
    W.allowRecovery=true;SlashCmdList.QUESTBRIEF("opts");assert(N.Options.frame:IsShown() and #UISpecialFrames==1)
end)
test("finder copy and options reuse the same working dialog chrome",function()
    local N=W.Init();SlashCmdList.QUESTBRIEF("opts");N.Search:Toggle();N.Search:Copy("123")
    for _,f in ipairs({N.Options.frame,N.Search.frame,N.Search.copyFrame})do
        assert(f.backdrop.edgeFile=="Interface\\DialogFrame\\UI-DialogBox-Border" and f.backdrop.edgeSize==16 and f.backdropColor[4]==.94 and f.border[4]==1)
    end
end)
test("native comparison label plate belongs to visible item inspection bounds",function()
    local N,b=start();b:Fire("OnEnter");N.Stack.tooltip.x,N.Stack.tooltip.y,N.Stack.tooltip.width,N.Stack.tooltip.height=1056,640,280,80
    local tip=N.Stack.tooltip.shoppingTooltips[1];tip:Show()
    tip.x,tip.y,tip.width,tip.height=1350,640,280,80
    local header=tip.CompareHeader;header:Show();header.x,header.y=1350,719
    W.mouseX,W.mouseY=1360,730;assert(N.Stack:ItemContains())
    tip:Hide();assert(header:IsShown() and not N.Stack:ItemContains())
end)

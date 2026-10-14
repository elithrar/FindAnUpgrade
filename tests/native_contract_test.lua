local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function exists(path)local f=io.open(path,"rb");if f then f:close();return true end end
local base=ROOT.."/.work/current-api/Interface/AddOns/"
local manager=base.."Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua"
local hubs=base.."Blizzard_SharedMapDataProviders/QuestOfferDataProvider.lua"
if not exists(manager) or not exists(hubs) then print("SKIP current native-source contracts: fixtures absent");return end
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
test("actual current native comparison methods use owned tooltips and tooltip edge",function()
    local N=W.Init();RegisterEventCallback=function()end
    assert(loadfile(manager))()
    Enum.TooltipComparisonMethod={Single=0,WithBagMainHandItem=1,WithBagOffHandItem=2,WithBothHands=3}
    GetScreenWidth=function()return 1920 end;EQUIPPED="Equipped"
    GetCVarBool=function()return false end
    C_TooltipComparison={GetItemComparisonInfo=function()return {method=0,item={hyperlink="item:124"},additionalItems={}}end,GetItemComparisonDelta=function()return {}end}
    C_TooltipInfo.GetHyperlink=function(link)return {type=0,id=124,hyperlink=link,lines={}}end
    N.Stack:Tooltips();local t=N.Stack.tooltip;t:SetOwner(UIParent,"ANCHOR_NONE");t.x=730;t.y=400;t.width=280;t.height=300
    for _,tip in ipairs(t.shoppingTooltips) do tip.width=240;tip.height=200;tip.CompareHeader.Label.width=80 end
    local comparison=N.Stack.comparison
    comparison:CompareItem({hyperlink="item:123"},t,t)
    assert(comparison.tooltip==t and TooltipComparisonManager.tooltip==nil)
    assert(t.shoppingTooltips[1]:IsShown() and t.shoppingTooltips[1].point[2]==t)
    assert(not t.shoppingTooltips[2]:IsShown())
    comparison:Clear(t);assert(not t.shoppingTooltips[1]:IsShown() and TooltipComparisonManager.tooltip==nil)
end)
test("actual current hub tooltip construction reaches exact multi-quest stack",function()
    local N=W.Init();W.shift=true
    Enum.QuestClassification={Campaign=1,Important=2,Legendary=3,Calling=4,Meta=5,Recurring=6,Questline=7,Normal=8,BonusObjective=9}
    CVarMapCanvasDataProviderMixin={Init=function()end}
    CreateFromMixins=function(...)
        local t={};for i=1,select('#',...)do local m=select(i,...);if type(m)=="table"then for k,v in pairs(m)do t[k]=v end end end;return t
    end
    assert(loadfile(hubs))()
    local f=W.Object();f.x=690;f.y=690;f.width=30;f.height=30;f.relatedQuests={[9]={},[14]={},[98189]={}}
    Mixin(f,QuestHubPinMixin)
    f.ResetSuppressedPinTooltipPool=function()end;f.GetSuppressedPinsSorted=function()return {},{},{},{}end
    f.AddSuppressedPinsToTooltip=function()end;f.GetLinkedUIMapID=function()end
    N.Sources:Attach();QuestHubPinMixin.AddCustomTooltipData(f,{})
    assert(N.Sources.hubHook and N.Hover.open and #N.Stack.cards==3)
    f.relatedQuests[14]=nil;N.Hover:Tick(1);assert(not N.Hover.open)
end)

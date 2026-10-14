local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function setup()
    local N=W.Init();N.Options:Toggle(N.Core);W.shift=true
    local f=W.Object();f.x=690;f.y=690;f.width=30;f.height=30;f.questID=9;f.GetQuestID=function()return 9 end
    W.items={{"Reward",100,2,2,true,123}};N.Sources:Pin(f,9)
    return N
end
local function media()
    local callbacks={};local lib={IsValid=function()return true end,Fetch=function()return "Expressway.ttf"end}
    lib.RegisterCallback=function(owner,event,fn)callbacks[event]=function()fn(nil,"font")end end
    LibStub=function()return lib end
    return callbacks,lib
end
test("optional media never replaces the current native tooltip default",function()
    local N=setup();local callbacks=media();W.Event("ADDON_LOADED","SharedMedia")
    for object in pairs(N.UI.fontSizes) do assert(object:GetFont()==GameTooltipText:GetFont()) end
    assert(N.Hover.open and callbacks.LibSharedMedia_Registered and callbacks.LibSharedMedia_SetGlobal)
    local registered=callbacks.LibSharedMedia_Registered;W.Event("ADDON_LOADED","SharedMedia");assert(callbacks.LibSharedMedia_Registered==registered)
end)
test("late native-family control rejection replays every owned object to one fallback",function()
    local N=setup();local bad=N.Options.texts[#N.Options.texts].object;local original=bad.SetFont
    GameTooltipText.font={"locale-tooltip.ttf",12,""}
    bad.SetFont=function(self,path,...)if path=="locale-tooltip.ttf"then return false end;return original(self,path,...)end
    media();W.Event("ADDON_LOADED","SharedMedia")
    for object in pairs(N.UI.fontSizes) do assert(object:GetFont()==STANDARD_TEXT_FONT) end
end)
test("native family recovers after an explicit font registration signal",function()
    local N=setup();local callbacks=media();GameTooltipText.font={"locale-tooltip.ttf",12,""};W.missingFont="locale-tooltip.ttf";W.Event("ADDON_LOADED","SharedMedia")
    assert(N.Options.texts[1].object:GetFont()==STANDARD_TEXT_FONT)
    W.missingFont=nil;callbacks.LibSharedMedia_Registered()
    for object in pairs(N.UI.fontSizes) do assert(object:GetFont()=="locale-tooltip.ttf") end
end)
test("hover uses native fonts and remeasures wrapped title on refresh",function()
    local N=setup();local title=N.Stack.cards[1].title
    assert(title.fontObject==GameTooltipHeaderText and not N.UI.fontSizes[title])
    title.GetStringHeight=function()return 74 end
    media();W.Event("ADDON_LOADED","SharedMedia")
    N.Hover.blocked=nil;local f=W.Object();f.x=690;f.y=690;f.width=30;f.height=30;f.questID=9;f.GetQuestID=function()return 9 end
    N.Sources:Pin(f,9);N.Stack:Refresh();local measured=N.Stack.cards[1]:GetHeight();N.Stack:Refresh()
    assert(title.fontObject==GameTooltipHeaderText and N.Stack.cards[1]:GetHeight()==measured and measured>=90)
end)
test("fractional reported font height is accepted without idle font mutation",function()
    local N=setup();local total=0
    for object in pairs(N.UI.fontSizes) do total=total+(object.fontWrites or 0) end
    for i=1,200 do N.Hover:Tick(i/100) end
    local after=0;for object in pairs(N.UI.fontSizes) do after=after+(object.fontWrites or 0) end
    assert(total==after)
end)
test("small screen high requested scale fits actual panel footprint",function()
    local N=W.Init({saved={scale=1.2}});UIParent.width=360;UIParent.height=240;W.shift=true;local f=W.Object();f.x=690;f.y=690;f.width=30;f.height=30;f.questID=9;f.GetQuestID=function()return 9 end
    N.Sources:Pin(f,9);assert(N.Hover.open and N.Stack.frame:GetWidth()*N.Stack.frame.scale<=UIParent.width-16)
    assert(N.Stack.bar.thumb:GetWidth()==12 and N.Stack.bar.thumb:GetHeight()==22)
end)

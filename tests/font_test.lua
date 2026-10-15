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
test("owned hover text uses the selected family and remeasures wrapped title on refresh",function()
    local N=setup();local title=N.Stack.cards[1].title
    assert(title.fontObject==GameTooltipHeaderText and N.UI.fontSizes[title]==14)
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

test("selected font changes ordinary owned text while native tooltip and numeric roles stay native",function()
    local N=setup();local native=GameTooltipText:GetFont();N.Core:Change("font","Arial")
    for object in pairs(N.UI.fontSizes) do assert(object:GetFont()=="Fonts\\ARIALN.TTF") end
    assert(GameTooltipText:GetFont()==native and GameTooltipHeaderText:GetFont()==STANDARD_TEXT_FONT)
end)
test("missing selected media remains saved and recovers on its registration signal",function()
    local N=setup();local valid=false;local callbacks={};local fonts={}
    local lib={IsValid=function(_,kind,name)return valid and name=="Later face"end,Fetch=function()return "later.ttf"end,HashTable=function()return fonts end}
    lib.RegisterCallback=function(owner,event,fn)callbacks[event]=fn end;LibStub=function()return lib end
    N.Core:Change("font","Later face");W.Event("ADDON_LOADED","Media")
    assert(N.Core.profile.font=="Later face" and N.Options.font.Text:GetText()=="Later face (unavailable)")
    for object in pairs(N.UI.fontSizes) do assert(object:GetFont()==GameTooltipText:GetFont()) end
    valid=true;fonts["Later face"]="later.ttf";callbacks.LibSharedMedia_Registered(nil,"font")
    assert(N.Options.font.Text:GetText()=="Later face" and N.Core.profile.font=="Later face")
    for object in pairs(N.UI.fontSizes) do assert(object:GetFont()=="later.ttf") end
end)
test("owned border none preserves geometry and background and restores native inspector art",function()
    local N=setup();local card=N.Stack.cards[1];local width,height=card:GetWidth(),card:GetHeight()
    N.Core:Change("border","none")
    assert(card.NineSlice:IsShown() and card.border[4]==0 and not card.qBorderFrame)
    assert(card.backdropColor[4]==.96 and card:GetWidth()==width and card:GetHeight()==height)
    local frames=#W.frames;N.Core:Change("border","dialog")
    assert(card.qBorderFrame.backdrop.edgeFile=="Interface\\DialogFrame\\UI-DialogBox-Border" and not card.qBorderFrame.backdrop.bgFile and #W.frames==frames+1)
    N.Core:Change("border","default")
    assert(card.NineSlice:IsShown() and card.border[4]==1 and not card.qBorderFrame:IsShown() and N.Options.frame.backdrop.edgeFile=="Interface\\DialogFrame\\UI-DialogBox-Border")
end)

test("border restyling preserves all four native color channels and rejects incomplete reads",function()
    local N=W.Init();local frame=W.Object();frame.width=320;frame.height=80
    frame.GetBackdropColor=function()return .11,.22,.33,.44 end
    frame.GetBackdropBorderColor=function()return .55,.66,.77,.88 end
    frame.SetBackdropColor=function(self,...)assert(select("#",...)==4);self.backdropColor={...}end
    frame.SetBackdropBorderColor=function(self,...)assert(select("#",...)==4);self.border={...}end
    N.Core:Change("border","none");N.UI:Border(frame,"tooltip")
    for index,value in ipairs({.11,.22,.33,.44}) do assert(frame.backdropColor[index]==value) end
    for index,value in ipairs({.55,.66,.77,.88}) do assert(frame.border[index]==value) end
    assert(not frame.backdrop.edgeFile and frame.width==320 and frame.height==80)
    frame.GetBackdropColor=function()return .11 end
    frame.GetBackdropBorderColor=function()return .55,.66,0/0,.88 end
    N.Core:Change("border","tooltip");N.UI:Border(frame,"tooltip")
    assert(frame.backdropColor[4]==.94 and frame.border[4]==1)
end)

test("warm font refresh and deferred open menus do not rescan media or wake search",function()
    local N=W.Init();local calls={stub=0,valid=0,fetch=0,hash=0,search=0,scripts=0};local callbacks={};local names={Selected="selected.ttf"}
    for i=1,180 do names["Font "..i]="font.ttf" end
    local lib={IsValid=function(_,_,name)calls.valid=calls.valid+1;return names[name]~=nil end,
        Fetch=function(_,_,name)calls.fetch=calls.fetch+1;return names[name]end,
        HashTable=function()calls.hash=calls.hash+1;return names end}
    lib.RegisterCallback=function(_,event,fn)callbacks[event]=fn end
    LibStub=function()calls.stub=calls.stub+1;return lib end
    W.Event("ADDON_LOADED","Media");N.Options:Toggle(N.Core);N.Core:Change("font","Selected");N.UI:RefreshFonts()
    local O=N.Options
    for key in pairs(calls) do calls[key]=0 end
    for i=1,20 do N.UI:RefreshFonts();O:Refresh() end
    assert(calls.stub==0 and calls.valid==0 and calls.fetch==0 and calls.hash==0)
    N.Search.Visible=function()return true end;N.Search.AppearanceChanged=function()calls.search=calls.search+1 end
    O.font.menuOpen=true;names.Additional="additional.ttf";callbacks.LibSharedMedia_Registered(nil,"font")
    assert(calls.search==0 and O.menuWaiting and calls.hash==1)
    local setScript=O.frame.SetScript
    O.frame.SetScript=function(self,...)calls.scripts=calls.scripts+1;return setScript(self,...)end
    for key in pairs(calls) do calls[key]=0 end
    for i=1,600 do O.frame:Fire("OnUpdate",.016) end
    assert(calls.stub==0 and calls.valid==0 and calls.fetch==0 and calls.hash==0 and calls.search==0 and calls.scripts==0)
    O.font.menuOpen=false;O.frame:Fire("OnUpdate",.016)
    assert(not O.menuWaiting and not O.frame:GetScript("OnUpdate") and calls.scripts==1)
end)

test("late addon native font changes relayout visible finder without another query",function()
    local N=W.Init();N.CatalogData={schemaVersion=1,quests={}};N.Search:Toggle()
    W.time=.3;N.Search:Tick();N.UI:RefreshFonts()
    local S=N.Search;local previousTop=S.scrollTop
    S.filter.query="keep this query"
    S.count.GetStringHeight=function(self)return self:GetFont()=="later-native.ttf" and 52 or 12 end
    local queries=0;local query=N.SearchModel.Query
    N.SearchModel.Query=function(self,...)queries=queries+1;return query(self,...)end
    GameTooltipText.font={"later-native.ttf",12,""};W.Event("ADDON_LOADED","NativeFontSkin")
    assert(S.appearanceDirty and S.count:GetFont()=="later-native.ttf")
    for i=1,5 do W.time=W.time+.2;S:Tick() end
    assert(queries==0 and S.count:GetHeight()==52 and S.scrollTop>previousTop and S.filter.query=="keep this query")
end)

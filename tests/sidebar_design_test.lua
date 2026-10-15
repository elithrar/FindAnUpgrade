local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function open(width,height,scale)
    local N=W.Init();N.CatalogData={schemaVersion=1,quests={}}
    W.guid="Player-1";C_SpecializationInfo={GetActiveSpecGroup=function()return 1 end};N.Character:Mark("identity")
    if width then UIParent.width,UIParent.height=width,height end
    N.Core.profile.scale=scale or 1
    N.Search:Toggle();W.time=.3;N.Search:Tick();return N,N.Search
end
local function rect(frame)local x,y,w,h=W.Bounds(frame);return {x=x,y=y,w=w,h=h,right=x+w,top=y+h}end
local function separated(a,b)return a.right<=b.x+.01 or b.right<=a.x+.01 or a.top<=b.y+.01 or b.top<=a.y+.01 end
local function reward(items,choices)
    return {state="ready",items={items=items or {}},choices={items=choices or {}},money={state="ready",value=125,published=true},xp={state="ready",value=800,published=true},currencies={items={}},reputation={items={{name="Stormwind",amount=75,published=true}}}}
end
local function fill(N,S,items,choices)
    local row={id=9,title="A useful quest",level=20,items={},evidence="Recorded minimum level 18"}
    for _,group in ipairs({items or {},choices or {}})do for _,item in ipairs(group)do row.items[#row.items+1]=item end end
    N.Catalog.records[9]={id=9,source={}}
    N.Catalog.locations[9]={{npcID=54,name="A long but useful quest giver",nameKnown=true,zone="Redridge Mountains",mapID=100,x=.226,y=.474}}
    N.SearchModel.Reward=function()return reward(items,choices),{},false end
    local card=S:Card(1);S:Fill(card,row);return card,row
end
test("sidebar default is fifteen percent narrower and input art follows thirty pixel hit area",function()
    local _,S=open();assert(S.frame:GetWidth()==476 and S.frame:GetHeight()==680)
    assert(S.frame.point[1]=="RIGHT" and S.search:GetHeight()==30)
    for _,key in ipairs({"Left","Right","Middle"})do assert(S.search[key]:GetHeight()==30)end
    local search,slot=rect(S.search),rect(S.slot)
    assert(search.h==slot.h and search.y==slot.y and slot.x-search.right>=9)
    assert(S.search:GetWidth()<S.frame:GetWidth()*.7)
    assert(S.usable.Text:GetNumPoints()==1 and S.usable.Text.point[2]==S.usable and S.usable.Text.point[4]==2)
    assert(S.usable.Text.justifyV=="MIDDLE" and S.slot.Text.justifyV=="MIDDLE")
    assert(S.filter.scope=="SAME_ZONE" and S.filter.sort=="UPGRADE" and S.filter.includeDungeons==false)
end)
test("header grid stays disjoint at narrow viewport and fractional scale without shrinking text",function()
    for _,size in ipairs({{1920,1080,1},{500,350,1.2},{400,350,1.2},{640,480,.85}})do
        local _,S=open(unpack(size));local scale=S.frame:GetScale()
        assert(S.frame:GetWidth()*scale<=size[1]-24+.01 and S.frame:GetHeight()*scale<=size[2]-24+.01)
        assert(scale==size[3] and S:ViewportHeight()>0)
        for index,pair in ipairs({{S.search,S.slot},{S.scope,S.levelLabel},{S.usable.Text,S.dungeons},{S.usable.Text,S.dungeons.Text},{S.maximumInput,S.sort},{S.count,S.sort},{S.drag,S.options},{S.options,S.close}})do
            assert(separated(rect(pair[1]),rect(pair[2])),"overlapping header controls "..index.." width "..size[1])
        end
        local scroll=rect(S.scroll);assert(math.abs(scroll.h-S:ViewportHeight())<.01)
    end
end)
test("native sort icon owns only menu artwork and exposes explicit scoring style",function()
    local N,S=open();assert(S.sort.template==nil and S.sort.Text==nil and S.sort:GetWidth()==28 and S.sort:GetHeight()==26)
    assert(S.sort:GetNormalTexture().atlas=="bags-button-autosort-up" and S.sort:GetPushedTexture().atlas=="bags-button-autosort-down")
    local highlight=S.sort:GetHighlightTexture();assert(highlight.texture=="Interface\\Buttons\\ButtonHilight-Square" and highlight.blendMode=="ADD" and highlight:GetWidth()==24 and highlight:GetHeight()==23)
    local menu=S.sort:GenerateMenu();assert(menu.entries[1].label=="Biggest upgrade" and menu.entries[1].checked())
    assert(menu.titles[2]:find("weapons and effects not rated",1,true))
    local owner=W.Object();local source={key={},owner=owner,surface="worldmap",rows={{id=9,availabilityCheck=function()return "native-map-available"end}},valid=function()return true end,over=function()return false end}
    N.Sources:Set(source);local proof=N.Sources.current
    local style=menu.entries[5];assert(style and style.enabled and not style.checked());style.callback()
    assert(style.checked() and N.Core.profile.scoringStyles[N.Character.snapshot.guid..":1"]==style.value)
    assert(N.Sources.current==proof and proof==source)
    C_SpecializationInfo.GetActiveSpecGroup=function()return 2 end;N.Character:Mark("identity");N.Character.events:Fire("OnUpdate")
    style.callback();assert(N.Core.profile.scoringStyles[N.Character.snapshot.guid..":2"]==style.value)
end)
test("scope and dungeon controls bind the exact query inputs without changing level window",function()
    local _,S=open();local lo,hi=S.filter.minimum,S.filter.maximum
    local menu=S.scope:GenerateMenu();assert(menu.entries[1].checked() and menu.entries[2].label=="Level range")
    menu.entries[2].callback();assert(S.filter.scope=="LEVEL_RANGE" and S.filter.minimum==lo and S.filter.maximum==hi)
    assert(S.minimumInput:IsShown() and S.maximumInput:IsShown())
    S.dungeons:SetChecked(true);S.dungeons:Fire("OnClick");assert(S.filter.includeDungeons)
    S.dungeons:SetChecked(false);S.dungeons:Fire("OnClick");assert(not S.filter.includeDungeons)
end)
test("character callbacks are safe before finder construction and coalesce visible invalidation",function()
    local N=W.Init();N.Search.Visible=function()return true end;N.Search:CharacterChanged({identity=true});assert(N.Search.contextDirty and not N.Search.frame)
    local S;N,S=open();S.dirty=false;local old=S.filter.minimum
    S:CharacterChanged({capabilities=true});assert(S.dirty and S.filter.minimum==old)
    assert(not S.frame.events.PLAYER_LEVEL_UP and not S.frame.events.PLAYER_EQUIPMENT_CHANGED and not S.frame.events.ZONE_CHANGED and not S.frame.events.SPELLS_CHANGED)
end)
test("fitting restores requested size after a temporary small viewport",function()
    local _,S=open();local width,height=S.frame:GetWidth(),S.frame:GetHeight()
    UIParent.width,UIParent.height=400,350;S:Fit();assert(S.frame:GetWidth()<width and S.frame:GetHeight()<height)
    UIParent.width,UIParent.height=1920,1080;S:Fit();assert(S.frame:GetWidth()==width and S.frame:GetHeight()==height)
end)
test("long scope caption and wrapped status grow within the grid without clipping",function()
    local _,S=open(400,350,1.2);S.scope.Text:SetText("Plage de niveaux");S.count:SetText(string.rep("Long zone and rating status ",5));S:LayoutControls()
    assert(S.scope.Text:GetStringWidth()<=S.scope.Text:GetWidth())
    assert(separated(rect(S.scope),rect(S.levelLabel)))
    assert(S.count:GetHeight()>=S.count:GetStringHeight() and rect(S.scroll).top<=rect(S.count).y-4)
end)
test("cog is native reference artwork beside close and opens existing options",function()
    local N,S=open();assert(S.options.icon.texture=="Interface\\WorldMap\\GEAR_64GREY")
    assert(S.options.icon:GetWidth()==20 and S.options:GetWidth()==26)
    S.search:SetFocus();S.options:Fire("OnClick");assert(N.Options.frame:IsShown() and not S.search.focused)
    assert(S:Visible());S.close:Fire("OnClick");assert(not S:Visible() and N.Options.frame:IsShown())
end)
test("range focus changes apply valid values without closing an opening native menu",function()
    local _,S=open();local oldClose=S.CloseMenu;local closes=0
    S.CloseMenu=function(self)closes=closes+1;oldClose(self)end
    S.minimumInput:SetText("17");S.maximumInput:SetText("24");S.slot:Fire("OnMouseDown","LeftButton")
    assert(S.filter.minimum==17 and S.filter.maximum==24 and closes==0)
    S.minimumInput:SetText("99");S.maximumInput:SetText("2");S.minimumInput:Fire("OnEditFocusLost")
    assert(S.minimumInput:GetText()=="17" and S.maximumInput:GetText()=="24")
    S.minimumInput:SetText("18");S.minimumInput:Fire("OnEscapePressed");assert(S.filter.minimum==17 and S.minimumInput:GetText()=="17")
end)
test("enlarged reward icons show verified level separately from quantity and reset pooled state",function()
    local N,S=open();local item={itemID=123,name="Helmet",state="ready",texture=100,quality=2,quantity=3,itemLevel=27,minimum=18}
    local c,row=fill(N,S,{item});local icon=c.icons[1]
    assert(math.abs(icon:GetWidth()-112/3)<.001 and icon.level.text=="27" and icon.count.text=="3")
    assert(icon.level.fontObject==NumberFontNormalSmall and icon.level.point[1]=="BOTTOMLEFT" and icon.count.point[1]=="BOTTOMRIGHT")
    NumberFontNormalSmall.font={"Fonts\\ARIALN.TTF",12,"OUTLINE"};item.itemLevel=100;item.quantity=200;S:Fill(c,row)
    assert(icon.level.point[1]=="BOTTOMLEFT" and icon.count.point[1]=="TOPRIGHT")
    item.itemLevel=nil;item.quantity=nil;S:Fill(c,row);assert(icon.level.text=="" and icon.count.text=="")
    assert(icon.level.point[3]==2 and icon.count.point[1]=="BOTTOMRIGHT")
    row.items={};N.SearchModel.Reward=function()return reward(),{},false end;S:Fill(c,row)
    assert(not icon:IsShown() and icon.row==nil and icon.level.text=="")
end)
test("single item area is natural width while guaranteed and choices remain distinct",function()
    local N,S=open();local a={itemID=123,state="ready",texture=100,itemLevel=27};local b={itemID=124,state="ready",texture=100,itemLevel=28}
    local c=fill(N,S,{a});local singleWidth=c.location:GetWidth()
    assert(singleWidth>S.child:GetWidth()*.8)
    c=fill(N,S,{a},{b});assert(c.icons[1].group.text=="Guaranteed" and c.icons[2].group.text=="Choose one")
    assert(c.icons[1].group:IsShown() and c.icons[2].group:IsShown())
    assert(separated(rect(c.icons[1]),rect(c.icons[2])) and c:GetHeight()<105)
end)
test("classification option removes fill and badge while preserving gold quest titles",function()
    local N,S=open();N.Model.Status=function()return "verifiedNew"end
    local c,row=fill(N,S,{{itemID=123,state="ready",texture=100}})
    assert(c.tag.text=="New in Forever" and c.tag:IsShown() and c.title.textColor[1]==1 and c.title.textColor[2]==.82)
    N.Core.profile.accents=false;S:Fill(c,row);assert(c.tag.text=="" and not c.tag:IsShown() and c.backdropColor[1]==.06)
    assert(c.title.textColor[1]==1 and c.title.textColor[2]==.82)
end)
test("finder copy and row text use plain labels without explanatory hover",function()
    local N,S=open(400,350,1.2);local c=fill(N,S,{{itemID=123,state="ready",texture=100}})
    assert(c.evidence.text=="Requires level 18" and not c.footer[1].text:find("base",1,true))
    assert(not c.location.text:find("\195\130",1,true))
    c.titleHit:Fire("OnEnter");c.locationHit:Fire("OnEnter");c.footerHits[1]:Fire("OnEnter")
    assert(not S.textTooltip and not S.footerTooltip:IsShown())
    S:Copy("Useful text");assert(S.copyFrame:GetWidth()<=S.frame:GetWidth()-24 and S.copyEdit:GetWidth()<=S.copyFrame:GetWidth()-30)
end)
test("reopening reuses controls and hidden event bursts create no frame or active updater",function()
    local _,S=open();local count=#W.frames
    for _=1,20 do S.frame:Hide();S:Toggle();W.time=W.time+.3;S:Tick()end
    assert(#W.frames==count);S.frame:Hide()
    for _=1,1000 do W.Event("QUEST_LOG_UPDATE");W.Event("UI_SCALE_CHANGED");W.Event("GET_ITEM_INFO_RECEIVED",999)end
    assert(#W.frames==count and not S.frame:GetScript("OnUpdate"))
end)
test("registered item callbacks update usability under Level fit without visual metadata changes",function()
    local N,S=open();S.filter.scope="LEVEL_RANGE";S.filter.sort="FIT";S.filter.slot="INVTYPE_HEAD";W.rewardReady=false
    local allowed=false
    C_PlayerInfo={CanUseItem=function()return allowed end}
    C_QuestLog.GetQuestDifficultyLevel=function()return 20 end
    C_Item={IsItemDataCachedByID=function()return true end,
        GetItemInfo=function(id)return "Stable helmet","item:"..id,2,22,1,"Armor","Plate",1,"INVTYPE_HEAD",100 end,
        GetItemInfoInstant=function(id)return id,"Armor","Plate","INVTYPE_HEAD",100,4 end}
    N.CatalogData={schemaVersion=1,quests={{id=9,title="A reward",level=20,items={{itemID=123}},locations={{npcID=54,name="A giver"}}}}}
    N.Catalog:Begin();S:Changed(true);W.time=.6;S:Tick();assert(#S.results==0)
    allowed=true;W.Event("ITEM_DATA_LOAD_RESULT",123,true);W.time=.9;S:Tick();assert(#S.results==1)
    allowed=false;W.Event("GET_ITEM_INFO_RECEIVED",123,true);W.time=1.2;S:Tick();assert(#S.results==0)
    S.dirty=false
    for _=1,100 do W.Event("GET_ITEM_INFO_RECEIVED",123,true)end
    assert(not S.dirty)
end)

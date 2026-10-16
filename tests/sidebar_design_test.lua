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
test("native sort icon exposes a minimal item level estimate menu",function()
    local N,S=open();assert(S.sort.template==nil and S.sort.Text==nil and S.sort:GetWidth()==28 and S.sort:GetHeight()==26)
    assert(S.sort.arrows[1].atlas=="auctionhouse-ui-sortarrow" and S.sort.arrows[2].atlas=="auctionhouse-ui-sortarrow")
    assert(S.sort.arrows[1]:GetWidth()==9 and S.sort.arrows[1]:GetHeight()==12 and S.sort.arrows[2].rotation==math.pi)
    S.sort:Fire("OnEnter");assert(S.footerTooltip:IsShown() and S.footerTooltip.text=="Sort by");S.sort:Fire("OnLeave");assert(not S.footerTooltip:IsShown())
    local highlight=S.sort:GetHighlightTexture();assert(highlight.texture=="Interface\\Buttons\\ButtonHilight-Square" and highlight.blendMode=="ADD" and highlight:GetWidth()==24 and highlight:GetHeight()==23)
    local menu=S.sort:GenerateMenu();assert(menu.entries[1].label=="Biggest upgrade" and menu.entries[1].checked())
    assert(#menu.entries==4 and menu.titles[2]=="Item-level estimate" and menu.titles[3]=="Item level and usable slots; not a performance score")
    local owner=W.Object();local source={key={},owner=owner,surface="worldmap",rows={{id=9,availabilityCheck=function()return "native-map-available"end}},valid=function()return true end,over=function()return false end}
    N.Sources:Set(source);local proof=N.Sources.current
    menu.entries[2].callback();assert(S.filter.sort=="FIT" and menu.entries[2].checked())
    assert(N.Sources.current==proof and proof==source)
    for _,title in ipairs(menu.titles)do assert(not title:find("style",1,true))end
    assert(not S.count:GetText():find("style",1,true))
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
    assert(c.evidence.text=="Req. lvl 18" and not c.footer[1].text:find("base",1,true))
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

test("owned native input and dropdown art share the declared control bounds",function()
    local _,S=open()
    for _,dropdown in ipairs({S.slot,S.scope}) do
        local control,left,right=rect(dropdown),rect(dropdown.Left),rect(dropdown.Right)
        assert(not dropdown.Background:IsShown())
        assert(math.abs(control.x-left.x)<.01 and math.abs(control.right-right.right)<.01)
        assert(left.h==control.h and right.h==control.h)
        for _,key in ipairs({"Left","Right","Middle"})do assert(dropdown[key].atlas==S.search[key].atlas and dropdown[key]:GetHeight()==control.h)end
        assert(rect(dropdown.Arrow).right<=control.right and rect(dropdown.Arrow).x>=control.x)
    end
    for _,input in ipairs({S.search,S.minimumInput,S.maximumInput}) do
        local control,left,right=rect(input),rect(input.Left),rect(input.Right)
        assert(math.abs(left.x-control.x)<.01 and math.abs(right.right-control.right)<.01)
        assert(left.h==control.h and right.h==control.h)
    end
    local scope,minimum,maximum,label=rect(S.scope),rect(S.minimumInput),rect(S.maximumInput),rect(S.levelLabel)
    for _,other in ipairs({minimum,maximum,label})do assert(math.abs(scope.y+scope.h/2-other.y-other.h/2)<.01)end
    assert(math.abs(maximum.right-rect(S.slot).right)<.01)
end)

test("query clear is content-only exact UTF8 with a roomy inset click target and one invalidation",function()
    local _,S=open();local clear=S.clearSearch
    assert(clear.text:GetText()==string.char(195,151) and not clear:IsShown() and S.placeholder:IsShown())
    local updates=0;local changed=S.Changed
    S.Changed=function(self,...)updates=updates+1;changed(self,...)end
    S.search:SetText("gun");S.search:Fire("OnTextChanged",true)
    assert(S.filter.query=="gun" and clear:IsShown() and not S.placeholder:IsShown() and updates==1)
    local input,hit=rect(S.search),rect(clear)
    assert(hit.w>=22 and hit.h>=22 and hit.x>=input.x and hit.right<=input.right)
    assert(input.right-S.search.textInsets[2]<hit.x and separated(hit,rect(S.slot)))
    clear:Fire("OnClick")
    assert(S.filter.query=="" and S.search:GetText()=="" and S.search.focused and not clear:IsShown() and S.placeholder:IsShown() and updates==2)
    clear:Fire("OnClick");assert(updates==2)
    S.search:SetText("sword");S.search:Fire("OnTextChanged",false)
    assert(clear:IsShown() and updates==2)
    S.search:SetText("");S.search:Fire("OnTextChanged",false);assert(not clear:IsShown() and updates==2)
end)

test("choice captions and multiple locations cannot offset the first reward icon",function()
    local N,S=open();local a={itemID=123,state="ready",texture=100};local b={itemID=124,state="ready",texture=100}
    local c,row=fill(N,S,{a});local baseline=rect(c.icons[1]).top-rect(c).top
    c,row=fill(N,S,{}, {a});assert(math.abs(rect(c.icons[1]).top-rect(c).top-baseline)<.01)
    assert(rect(c.icons[1].group).top<rect(c.icons[1]).y and c.icons[1].group.text=="Choose one")
    c,row=fill(N,S,{a},{b})
    assert(math.abs(rect(c.icons[1]).top-rect(c.icons[2]).top)<.01 and math.abs(rect(c.icons[1]).top-rect(c).top-baseline)<.01)
    for _,icon in ipairs(c.icons)do assert(separated(rect(icon),rect(icon.group)))end
    N.Catalog.locations[9][2]={npcID=55,name="Another giver",nameKnown=true,zone="Redridge Mountains",mapID=100,x=.3,y=.4}
    S:Fill(c,row);assert(math.abs(rect(c.icons[1]).top-rect(c).top-baseline)<.01 and c.giver:IsShown())
    assert(rect(c.giver).top<rect(c.icons[1].group).y and rect(c.giver).top<rect(c.icons[2].group).y)
    assert(c:GetHeight()<120)
end)

test("expanded mixed reward groups keep captions between nonoverlapping icon rows",function()
    local N,S=open();local items,choices={},{}
    for i=1,4 do items[i]={itemID=120+i,state="ready",texture=100};choices[i]={itemID=130+i,state="ready",texture=100}end
    S.expanded[9]=true;local c=fill(N,S,items,choices)
    assert(#c.icons==8 and c.icons[1].group.text=="Guaranteed" and c.icons[5].group.text=="Choose one")
    assert(rect(c.icons[1].group).top<rect(c.icons[1]).y and rect(c.icons[5]).top<rect(c.icons[1].group).y)
    for i=1,8 do for j=i+1,8 do assert(separated(rect(c.icons[i]),rect(c.icons[j])))end end
    for _,icon in ipairs(c.icons)do assert(rect(icon).y>=rect(c).y)end
end)

test("reward controls clear the full star target and measured header at narrow scales",function()
    for _,size in ipairs({{1920,1080,1},{640,480,.85},{500,350,1.2},{400,350,1.2}}) do
        local N,S=open(unpack(size));N.Data.statusById[9]="verifiedUpdated"
        local a={itemID=123,state="ready",texture=100};local b={itemID=124,state="ready",texture=100}
        local c,row=fill(N,S,{a},{b});assert(S.frame:GetScale()==size[3])
        for _,title in ipairs({"Short",string.rep("A longer quest title ",6)}) do
            row.title=title;S:Fill(c,row)
            for _,icon in ipairs(c.icons) do
                assert(separated(rect(c.star),rect(icon)))
                assert(rect(c.star).y-rect(icon).top>=6-.01)
                assert(rect(c.title).y-rect(icon).top>=8-.01)
                assert(rect(c.tag).y-rect(icon).top>=6-.01)
            end
            assert(c.star.icon:GetWidth()==17 and c.star.icon:GetHeight()==15.3)
        end
    end
end)

test("measured reward captions keep space before following groups and location controls",function()
    local N,S=open();local items,choices={},{}
    for i=1,4 do items[i]={itemID=120+i,state="ready",texture=100};choices[i]={itemID=130+i,state="ready",texture=100} end
    S.expanded[9]=true;local c,row=fill(N,S,items,choices)
    -- A tall font's measured line box must expand the group allocation.
    c.groupMeasure.GetStringHeight=function()return 24 end
    for _,icon in ipairs(c.icons) do icon.group.GetStringHeight=function()return 24 end end
    N.Catalog.locations[9][2]={npcID=55,name="Other",nameKnown=true};S:Fill(c,row)
    local lastFirstRow=rect(c.icons[4]);local firstCaption=rect(c.icons[1].group)
    local nextGroup=rect(c.icons[5]);local finalCaption=rect(c.icons[5].group)
    assert(lastFirstRow.y-firstCaption.top>=5-.01)
    assert(firstCaption.y-nextGroup.top>=8-.01)
    assert(finalCaption.y-rect(c.giver).top>=8-.01)
    assert(rect(c.giver).y-rect(c).y>=5-.01)
    -- Horizontal groups also have room between their caption bounds.
    c,row=fill(N,S,{items[1]},{choices[1]})
    assert(rect(c.icons[2].group).x-rect(c.icons[1].group).right>=14-.01)
end)

test("location format uses exact UTF8 bullets without empty components or fake coordinates",function()
    local _,S=open();local bullet=" "..string.char(226,128,162).." "
    assert(S:LocationLabel({zone="Westfall",name="Gryan",mapID=100,x=.25,y=.5})=="Westfall"..bullet.."Gryan"..bullet.."25.0, 50.0")
    assert(S:LocationLabel({name="Gryan"})=="Gryan")
    assert(S:LocationLabel({zone="Westfall",name="Letter",itemID=123})=="Westfall"..bullet.."Starts from Letter")
    assert(S:LocationLabel({})=="Quest giver unavailable")
    assert(not S:LocationLabel({zone="Westfall",name="Gryan"}):find(string.char(7),1,true))
end)

test("saved search defaults apply at every opening while retaining query scope slot and sort",function()
    local N,S=open();S.search:SetText("sword");S.search:Fire("OnTextChanged",true)
    S.filter.slot,S.filter.scope,S.filter.sort="INVTYPE_WEAPON","LEVEL_RANGE","TITLE"
    S.filter.usable,S.filter.includeDungeons=false,true
    S.minimumInput:SetText("18");S.maximumInput:SetText("19");S:CommitRange();assert(S.manualRange)
    N.Core:ChangeSearchDefault("hideUnusable",true);N.Core:ChangeSearchDefault("includeDungeons",false)
    N.Core:ChangeSearchDefault("levelsBelow",7);N.Core:ChangeSearchDefault("levelsAbove",1)
    assert(S.filter.usable==false and S.filter.includeDungeons==true and S.filter.minimum==18 and S.filter.maximum==19)
    S.frame:Hide();S:Toggle()
    assert(S.filter.usable and not S.filter.includeDungeons and S.usable:GetChecked() and not S.dungeons:GetChecked())
    assert(S.filter.minimum==13 and S.filter.maximum==21 and not S.manualRange)
    assert(S.filter.query=="sword" and S.search:GetText()=="sword" and S.filter.slot=="INVTYPE_WEAPON" and S.filter.scope=="LEVEL_RANGE" and S.filter.sort=="TITLE")
    local snapshot=N.Core.profile.searchDefaults
    S.filter.usable=false;S.filter.includeDungeons=true;S.minimumInput:SetText("17");S.maximumInput:SetText("25");S:CommitRange()
    assert(snapshot.hideUnusable and not snapshot.includeDungeons and snapshot.levelsBelow==7 and snapshot.levelsAbove==1)
end)

test("appearance changes preserve transient filters and defer geometry until a native menu closes",function()
    local N,S=open();S.filter.query="wand";S.filter.scope="LEVEL_RANGE";S.filter.minimum=11;S.filter.maximum=29;S.manualRange=true
    local before=S.frame:GetScale();W.menuOpen=true
    Menu={GetManager=function()return{IsAnyMenuOpen=function()return W.menuOpen end}end}
    N.Core:Change("scale",.8);assert(S.frame:GetScale()==before and S.appearanceDirty)
    W.time=W.time+.3;S:Tick();assert(S.frame:GetScale()==before)
    W.menuOpen=false;W.time=W.time+.3;S:Tick();assert(S.frame:GetScale()==.8 and not S.appearanceDirty)
    assert(S.filter.query=="wand" and S.filter.scope=="LEVEL_RANGE" and S.filter.minimum==11 and S.filter.maximum==29 and S.manualRange)
end)

test("result count omits rating diagnostics while retaining useful quest state in rows",function()
    local N,S=open();local c,row=fill(N,S,{{itemID=123,state="ready",texture=100}})
    row.ranking={state="unknown",tier=2};row.evidence="In quest log"
    N.SearchModel.Query=function()return {row}end;S:Refresh()
    assert(S.count:GetText():find("1 quests",1,true) and not S.count:GetText():find("not rated",1,true))
    assert(c.evidence:GetText()=="In quest log")
end)

test("sort has a readable owned fallback if the verified native atlas cannot load",function()
    local N=W.Init();local methods=getmetatable(W.Object()).__index;local original=methods.SetAtlas
    methods.SetAtlas=function(self,atlas)if atlas=="auctionhouse-ui-sortarrow"then error("asset unavailable")end;return original(self,atlas)end
    N.Search:Create();local d=N.Search.sort;methods.SetAtlas=original
    assert(d.fallback:GetText()=="Sort" and not d.arrows[1]:IsShown() and not d.arrows[2]:IsShown())
    assert(d.menuGenerator and d.hooks.OnMouseDown and d.hooks.OnEnter)
end)

test("appearance bursts reflow retained results without queries even with native size callbacks",function()
    local N,S=open();local _,row=fill(N,S,{{itemID=123,state="ready",texture=100}})
    S.results={row};S:LayoutResults();S:Scroll(0);S.dirty=false
    local queries=0;N.SearchModel.Query=function()queries=queries+1;return {row}end
    local setSize=S.frame.SetSize
    S.frame.SetSize=function(frame,w,h)
        local changed=w~=frame:GetWidth() or h~=frame:GetHeight();setSize(frame,w,h)
        if changed then frame:Fire("OnSizeChanged",w,h)end
    end
    S.filter.query="gun";S.filter.scope="LEVEL_RANGE";S.filter.minimum,S.filter.maximum=12,24;S.manualRange=true
    UIParent.width,UIParent.height=500,350
    for _=1,10 do N.Core:Change("border","none");N.Core:Change("scale",1.2);N.Core:Change("font","Arial")end
    W.time=W.time+.3;S:Tick()
    assert(queries==0 and not S.dirty and S.frame:GetScale()==1.2 and S.frame:GetWidth()<=476/1.2)
    assert(S.filter.query=="gun" and S.filter.scope=="LEVEL_RANGE" and S.filter.minimum==12 and S.filter.maximum==24 and S.manualRange)
    W.Event("UI_SCALE_CHANGED");W.Event("DISPLAY_SIZE_CHANGED");S.frame:Fire("OnSizeChanged");S.resize:Fire("OnMouseUp")
    W.time=W.time+.3;S:Tick();assert(queries==0 and not S.dirty)
    -- An actual data invalidation arriving beside appearance still queries.
    S:AppearanceChanged();S:DataChanged();W.time=W.time+.3;S:Tick();assert(queries==1)
end)

local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function setup(ids,count)
    local N=W.Init({characterSaved={schemaVersion=1,ids=ids or {}}});local quests={}
    for id=1,count or 6 do quests[#quests+1]={id=id,title="Quest "..id,level=20,minimum=10,confirmation="published",items={{itemID=1000+id,name="Reward "..id,group="choice"}},locations={{npcID=54,name="Giver",nameKnown=true}}} end
    N.CatalogData={schemaVersion=2,quests=quests};W.rewardReady=false
    C_QuestLog.GetTitleForQuestID=function(id)return id<=#quests and "Quest "..id end
    C_QuestLog.GetQuestDifficultyLevel=function()return 20 end
    C_QuestLog.IsOnQuest=function()return false end;C_QuestLog.IsQuestFlaggedCompleted=function()return false end;C_QuestLog.IsRepeatableQuest=function()return false end
    C_Item={}
    C_Item.GetItemInfo=function(id)return "Reward "..(id-1000),"item:"..id,2,20,1,"Armor","Plate",1,"INVTYPE_HEAD",100,0,4,4 end
    C_Item.IsItemDataCachedByID=function()return true end
    N.Search:Toggle();N.Search.filter.scope="LEVEL_RANGE";N.Search.filter.sort="TITLE";N.Search.filter.usable=false
    for i=1,4 do W.time=W.time+.3;N.Search:Tick() end
    return N,N.Search,quests
end
local function tick(S)W.time=W.time+.3;S:Tick()end
local function rect(f)local x,y,w,h=W.Bounds(f);return {x=x,y=y,w=w,h=h,right=x+w,top=y+h}end
local function separated(a,b)return a.right<=b.x+.01 or b.right<=a.x+.01 or a.top<=b.y+.01 or b.top<=a.y+.01 end
test("finder retains native tabs while Options uses one window",function()
    local N,S=setup();N.Options:Toggle(N.Core)
    assert(S.tabs.quests.template=="BackdropTemplate" and S.tabs.quests:GetHeight()==22)
    assert(S.tabs.quests.backdrop.edgeFile=="Interface\\Tooltips\\UI-Tooltip-Border" and N.Options.tabs==nil)
    assert(S.tabs.quests.activeGlow:IsShown() and not S.tabs.shortlist.activeGlow:IsShown())
    S.tabs.quests:Fire("OnEnter");S.tabs.quests:Fire("OnLeave");assert(S.tabs.quests.activeGlow:IsShown())
    S:View("shortlist");assert(S.tabs.shortlist.activeGlow:IsShown() and not S.tabs.quests.activeGlow:IsShown())
    S:View("quests")
    assert(separated(rect(S.title),rect(S.tabs.quests)) and separated(rect(S.tabs.quests),rect(S.search)))
end)
test("tabs retain independent queries offsets and all quest filters",function()
    local _,S=setup({2,4});S.search:SetText("Quest 1");S.filter.query="Quest 1";S.offset=25
    S.filter.slot="INVTYPE_HEAD";S.filter.scope="LEVEL_RANGE";local lo=S.filter.minimum
    S:View("shortlist");assert(S.search:GetText()=="" and S.offset==0)
    assert(not S.slot:IsShown() and not S.scope:IsShown() and not S.usable:IsShown() and not S.sort:IsShown())
    assert(S.search:GetWidth()==S.frame:GetWidth()-32 and S.scrollTop==146)
    S.search:SetText("Reward 4");S.offset=12;S:View("quests")
    assert(S.search:GetText()=="Quest 1" and S.filter.query=="Quest 1" and S.offset==25)
    assert(S.filter.scope=="LEVEL_RANGE" and S.filter.slot=="INVTYPE_HEAD" and S.filter.minimum==lo)
    assert(S.slot:IsShown() and S.scope:IsShown() and S.scrollTop>=210)
    S:View("shortlist");assert(S.search:GetText()=="Reward 4" and S.offset==12)
end)
test("shortlist hides completed quests and keeps blocked and unknown exact IDs across quest filters",function()
    local N,S,quests=setup({1,2,999});C_QuestLog.IsQuestFlaggedCompleted=function(id)return id==1 end
    N.Character:PrimeQuests({}, {},true);quests[2].faction="Horde";S.filter.minimum=70;S.filter.maximum=80;S.filter.slot="INVTYPE_FEET";S.filter.usable=true
    S:View("shortlist");tick(S);assert(#S.results==2 and S.results[1].id==2 and S.results[2].id==999)
    assert(S.results[2].missing and #S.results[2].items==0 and N.Shortlist:Contains(1))
    assert(S.cards[2].location:GetText()=="Quest data unavailable" and not S.cards[2].chain:IsShown())
    N.Core:Change("hideCompleted",false);tick(S)
    assert(#S.results==3 and S.results[1].id==1 and S.results[1].evidence=="Completed")
end)
test("save removal refreshes after click and pooled cards cannot retain old state",function()
    local N,S=setup({1,2});N.Adapter.Over=function()return true end;S:View("shortlist");tick(S)
    local card=S.cards[1];assert(card.row.id==1 and card.star.icon.atlas=="auctionhouse-icon-favorite")
    card.star:Fire("OnClick");assert(card.row.id==1 and not N.Shortlist:Contains(1));tick(S)
    assert(#S.results==1 and card.row.id==2 and card.star.icon.atlas=="auctionhouse-icon-favorite")
    card.star:Fire("OnClick");tick(S);assert(#S.results==0 and not card:IsShown() and S.offset==0)
    assert(S.empty:GetText()=="Star a quest to save it for this character.")
end)

test("search and shortlist render bottom rewards and clear recycled or unavailable rows",function()
    local N,S=setup({1,2});N.Adapter.Over=function()return true end
    N.SearchModel.Reward=function(_,row)
        return {state="ready",items={items=row.items},choices={items={}},money={state="unavailable"},
            xp=row.id==1 and {state="ready",value=875}or {state="unavailable"},currencies={items={}},
            reputation={items=row.id==1 and {{name="Darnassus",amount=75}}or {}}},{},false
    end
    S:Changed(true);tick(S)
    local card=S.cards[1]
    local function bottom()
        assert(card.row.id==1 and card.footer[1]:IsShown())
        assert(math.abs(rect(card.footer[1]).y-rect(card).y-S.geometry.cardInset)<.01)
    end
    bottom();S:View("shortlist");tick(S);assert(S.cards[1]==card);bottom()
    card.star:Fire("OnClick");tick(S)
    assert(card.row.id==2 and not card.footer[1]:IsShown()and card.footer[1].text==""and card.footerHits[1].value==nil)
    S:Fill(card,{id=999,title="Unavailable saved quest",missing=true,items={}})
    assert(not card.footer[1]:IsShown()and card.footerHits[1].value==nil)
    S:View("quests");tick(S);assert(S.cards[1]==card);bottom()
    S:Fill(card,{id=999,title="Unavailable saved quest",missing=true,items={}})
    assert(not card.footer[1]:IsShown()and card.footer[1].text==""and card.footerHits[1].value==nil)
end)
test("one native star texture swaps states at fifteen percent smaller size",function()
    local N,S=setup();local card=S.cards[1]
    assert(card.star:GetWidth()==24 and card.star:GetHeight()==24)
    assert(card.star.icon.atlas=="auctionhouse-icon-favorite-off" and card.star.outline==nil and card.star.fill==nil)
    assert(card.star.icon:GetWidth()==17 and card.star.icon:GetHeight()==15.3)
    local icon=card.star.icon;N.Shortlist:Toggle(card.row.id);S:Fill(card,card.row)
    assert(card.star.icon==icon and icon.atlas=="auctionhouse-icon-favorite")
    N.Shortlist:Toggle(card.row.id);S:Fill(card,card.row)
    assert(card.star.icon==icon and icon.atlas=="auctionhouse-icon-favorite-off")
    assert(separated(rect(card.titleHit),rect(card.star)))
end)
test("slot command opens Quests without toggling closed or discarding scope query sort",function()
    local N,S=setup({2});S.filter.scope="LEVEL_RANGE";S.filter.sort="TITLE";S.filter.query="Quest";S.search:SetText("Quest");S:View("shortlist")
    N.Core:Slash("slot ring");assert(S:Visible() and S.view=="quests" and S.filter.slot=="INVTYPE_FINGER")
    assert(S.filter.scope=="LEVEL_RANGE" and S.filter.sort=="TITLE" and S.search:GetText()=="Quest")
    N.Core:Slash("slot offhand");assert(S:Visible() and S.filter.slot=="OFFHAND")
    assert(not S:OpenSlot("inventedslot") and S.filter.slot=="OFFHAND")
end)
test("quest chain expands inline and survives scrolling and view changes",function()
    local N,S,quests=setup({2});quests[2].chain={groups={{kind="all",ids={1},verified=false}},relations={}}
    N.Chains.data=nil;S:View("shortlist");tick(S);local card=S.cards[1];assert(card.chain:IsShown())
    assert(card.chain.icon.atlas=="common-icon-chatlink" and card.chain.disclosure.atlas=="common-button-list-plus")
    assert(card.chain.text:GetText()=="Quest chain")
    assert(separated(rect(card.chain.icon),rect(card.chain.text)) and separated(rect(card.chain.text),rect(card.chain.disclosure)))
    N.Adapter.Over=function()return true end
    local collapsed=card:GetHeight();card.chain:Fire("OnClick")
    assert(S.chainExpanded[2] and card:GetHeight()>collapsed and S.chainFrame==nil)
    assert(card.chain.disclosure.atlas=="common-button-list-minus" and card.chain.text:GetText()=="Quest chain · 2 quests")
    assert(card.chainRows[1].questID==1 and card.chainRows[2].questID==2 and card.chainRows[2].selected)
    assert(card.chainRows[1].title:GetText()=="[20] Quest 1")
    assert(card.chainRows[2].detail:GetText():find("Selected",1,true))
    S:Scroll(0);assert(card.chainRows[1]:IsShown())
    S:View("quests");tick(S);S:View("shortlist");tick(S);assert(card.chainRows[1]:IsShown())
    card.chain:Fire("OnClick");assert(not S.chainExpanded[2] and card:GetHeight()==collapsed)
    assert(card.chain.disclosure.atlas=="common-button-list-plus" and card.chain.text:GetText()=="Quest chain")
    for _,row in ipairs(card.chainRows) do assert(not row:IsShown()) end
end)
test("inline chain rows wrap within the card and clear recycled and missing rows",function()
    local N,S,quests=setup({2});quests[2].chain={groups={{kind="any",ids={1},verified=true}}}
    quests[1].title=string.rep("Long prerequisite name ",12)
    S:View("shortlist");tick(S);S:Chain(2)
    local card=S.cards[1];local child=card.chainRows[1]
    local box,nested=rect(card),rect(child)
    assert(nested.x>box.x and nested.right<box.right and nested.y>box.y and nested.top<box.top)
    assert(child.title:GetStringHeight()>22 and child:GetHeight()>child.title:GetStringHeight())
    local frames=#W.frames
    for i=1,10 do S:Chain(2);S:Chain(2) end
    assert(#W.frames==frames)
    S:Fill(card,{id=3,title="Other quest",items={}})
    for _,row in ipairs(card.chainRows) do assert(not row:IsShown()) end
    S:Fill(card,{id=999,title="Missing",items={},missing=true})
    for _,row in ipairs(card.chainRows) do assert(not row:IsShown()) end
end)
test("nested rows clear reward icons and the footer at narrow and wide sizes",function()
    local N,S,quests=setup({2});quests[2].chain={groups={{kind="all",ids={1},verified=true}}}
    N.Chains.data=nil
    N.SearchModel.Reward=function(_,row)
        return {state="ready",items={items=row.items},choices={items={}},money={state="unavailable"},
            xp={state="ready",value=875},currencies={items={}},reputation={items={{name="Darnassus",amount=75}}}},{},false
    end
    S:View("shortlist");tick(S)
    for _,width in ipairs({420,680}) do
        S.frame:SetSize(width,600);S:LayoutControls();S:Render();S:Chain(2)
        local card=S.cards[1];local footer=rect(card.footer[1]);local child=rect(card.chainRows[1])
        assert(child.top<footer.y and child.right<rect(card).right and card.footer[1].point[1]=="TOPLEFT")
        for _,icon in ipairs(card.icons) do if icon:IsShown() then assert(separated(rect(icon),child)) end end
        S:Chain(2)
        assert(card.footer[1].point[1]=="TOPLEFT" and rect(card.footer[1]).y>rect(card.chain).top)
    end
end)
test("expanded follow-ups refresh outside the selected quest filters",function()
    local N,S,quests=setup({1})
    quests[2].chain={groups={{kind="all",ids={1},verified=true}}}
    quests[3].chain={groups={{kind="all",ids={2},verified=true}}};quests[3].level=80
    N.Chains.data=nil;local done=false
    N.Character.Quest=function(_,id)return {completed=id==3 and done or false,active=false,repeatable=false} end
    S:View("shortlist");tick(S);S:Chain(1)
    local card=S.cards[1];assert(card.chainRows[3].questID==3)
    S.filter.minimum=10;S.filter.maximum=30;S.dirty=false;done=true
    S:QuestChanged({ids={[3]=true}});assert(S.dirty);tick(S)
    assert(card.chainRows[3].detail:GetText():find("Completed",1,true))
    S:Chain(1);assert(card.chainQuestIDs==nil)
end)
test("new dependency changes invalidate saved rows outside level filters",function()
    local N,S,quests=setup({2});quests[2].chain={groups={{kind="all",ids={1},verified=true}}};N.Chains.data=nil;S:View("shortlist");tick(S)
    S.filter.minimum=70;S.filter.maximum=80;S.dirty=false;S:QuestChanged({ids={[1]=true}});assert(S.dirty)
end)
test("shortlist refreshes cached quest metadata when player level changes",function()
    local N,S=setup({1});S:View("shortlist");tick(S)
    assert(S.results[1].level==20)
    C_QuestLog.GetQuestDifficultyLevel=function()return 21 end
    W.Event("PLAYER_LEVEL_UP",21);N.Character:Flush(true);tick(S)
    assert(S.results[1].level==21 and S.cards[1].title:GetText():find("[21]",1,true))
    assert(N.Catalog.records[1].metadataPlayerLevel==21)
    local reads=0
    C_QuestLog.GetQuestDifficultyLevel=function()reads=reads+1;return 21 end
    S:ShortlistQuery();S:ShortlistQuery();assert(reads==0,"unchanged context reuses metadata")
end)
test("reopening shortlist refreshes metadata invalidated while hidden",function()
    local N,S=setup({1});S:View("shortlist");tick(S);S:Toggle()
    C_QuestLog.GetTitleForQuestID=function()return "Updated title" end
    C_QuestLog.GetQuestDifficultyLevel=function()return 22 end
    S:QuestData(1);assert(not N.Catalog.records[1].metadataReady)
    S:Toggle();tick(S)
    assert(S.view=="shortlist" and S.results[1].title=="Updated title" and S.results[1].level==22)
    assert(N.Catalog.records[1].metadataReady)
end)
test("repeated view switches reuse cards tabs and popup frames without idle work",function()
    local _,S=setup({1,2,3});S:View("shortlist");tick(S);S:View("quests");tick(S);local count=#W.frames
    for i=1,40 do S:View(i%2==0 and "quests" or "shortlist");tick(S) end
    assert(#W.frames==count)
    W.time=20;for i=1,20 do tick(S)end;assert(S.frame:GetScript("OnUpdate")==nil)
end)
test("opening Options dismisses the old copy owner and native edit focus",function()
    local N,S=setup();S:Copy("123");assert(N.Copy.frame:IsShown() and S.copyEdit:HasFocus())
    S.options:Fire("OnClick");assert(N.Options.frame:IsShown() and not N.Copy.frame:IsShown() and not S.copyEdit:HasFocus())
    S:Copy("456");N.Core:Slash("opts");assert(not N.Copy.frame:IsShown() and not S.copyEdit:HasFocus())
end)

test("follow-up inspection ignores level and usability filters and owns its actions",function()
    local N,S,quests=setup({1})
    quests[2].chain={groups={{kind="all",ids={1},verified=true}}};quests[2].level=80
    N.Chains.data=nil;N.Adapter.Over=function()return true end
    S.filter.usable=true;S:View("shortlist");tick(S);S:Chain(1)
    local card=S.cards[1];local child=card.chainRows[2]
    assert(not child.detail:GetText():find("#",1,true))
    child:Fire("OnEnter");assert(S.footerTooltip.text:find("#2",1,true));child:Fire("OnLeave")
    child:Fire("OnClick","LeftButton")
    local inspection=card.chainInspection
    assert(inspection and inspection:IsShown() and inspection.row.id==2 and not inspection.chain:IsShown())
    assert(not inspection.title:IsShown() and not inspection.star:IsShown(),"the mini row already owns the quest heading and save action")
    assert(inspection.icons[1]:IsShown() and inspection.icons[1].row.itemID==1002)
    assert(S.heights[2]==nil,"an inspection must not overwrite result height estimates")
    assert(rect(inspection).right<=rect(card).right and rect(inspection).y>rect(card).y)
    local clicked;S.ContextMenu=function(_,row)clicked=row.id end
    child:Fire("OnClick","RightButton");assert(clicked==2)
    child.save:Fire("OnClick");assert(N.Shortlist:Contains(2))
    child:Fire("OnClick","LeftButton");assert(not inspection:IsShown() and inspection.row==nil)
    S:Chain(1);assert(card.chainQuestIDs==nil and not child:IsShown())
end)

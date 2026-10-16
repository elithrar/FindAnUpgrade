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
    assert(S.tabs.quests.activeLine:IsShown() and not S.tabs.shortlist.activeLine:IsShown())
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
test("shortlist keeps completed blocked and unknown exact IDs across quest filters",function()
    local N,S,quests=setup({1,2,999});C_QuestLog.IsQuestFlaggedCompleted=function(id)return id==1 end
    N.Character:PrimeQuests({}, {},true);quests[2].faction="Horde";S.filter.minimum=70;S.filter.maximum=80;S.filter.slot="INVTYPE_FEET";S.filter.usable=true
    S:View("shortlist");tick(S);assert(#S.results==3 and S.results[1].id==1 and S.results[2].id==2 and S.results[3].id==999)
    assert(S.results[1].evidence=="Completed" and S.results[3].missing and #S.results[3].items==0)
    assert(S.cards[3].location:GetText()=="Quest data unavailable" and not S.cards[3].chain:IsShown())
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
test("chain popup is bounded scrollable and closes on navigation and owner changes",function()
    local N,S,quests=setup({2});quests[2].chain={groups={{kind="all",ids={1},verified=false}},relations={}}
    S:View("shortlist");tick(S);local card=S.cards[1];assert(card.chain:IsShown())
    S:Chain(2,card.chain);assert(S.chainFrame:IsShown() and S.chainFrame:GetHeight()<=320)
    assert(S.chainFrame.title:GetText()=="Quest chain" and not S.chainFrame.text:GetText():find("Recorded",1,true))
    S:View("quests");assert(not S.chainFrame:IsShown())
    S:Chain(2,card.chain);S:Scroll(0);assert(not S.chainFrame:IsShown())
end)
test("new dependency changes invalidate saved rows outside level filters",function()
    local N,S,quests=setup({2});quests[2].chain={groups={{kind="all",ids={1},verified=true}}};S:View("shortlist");tick(S)
    S.filter.minimum=70;S.filter.maximum=80;S.dirty=false;S:QuestChanged({ids={[1]=true}});assert(S.dirty)
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

local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup(config)
    local N=W.Init(config); local quests={[9]={id=9,name="Head quest",questLevel=20,items={{itemID=123,name="Helmet"},{itemID=125,name="Boots"}},locations={{npcID=54,name="Giver A",mapID=100,x=.5,y=.6}}},[14]={id=14,name="Weapon quest",questLevel=21,items={{itemID=124,name="Dagger"}},locations={{npcID=55,name="Giver B",mapID=101,x=.25,y=.3}}}}
    local items={[123]={name="Helmet",class=4,questRewards={9}},[124]={name="Dagger",class=2,questRewards={14}},[125]={name="Boots",class=4,questRewards={9}}}
    local npcs={[54]={name="Giver A",questStarts={9},spawns={[12]={{50,60}}}},[55]={name="Giver B",questStarts={14},spawns={[13]={{25,30}}}}}
    N.CatalogData={schemaVersion=1,quests={quests[9],quests[14]}}; LibQuestieDB=nil;QuestieLoader=nil
    W.completed={};W.repeatable={};W.onQuest={};W.cached={[123]=true,[124]=true,[125]=true};W.itemLoads={};W.waypoint=nil;W.tracked=nil;W.waypointSuccess=nil;W.openMenu=nil;W.rewardReady=false
    C_QuestLog.IsQuestFlaggedCompleted=function(id)return W.completed[id]==true end
    C_QuestLog.IsRepeatableQuest=function(id)return W.repeatable[id]==true end
    C_QuestLog.IsOnQuest=function(id)return W.onQuest[id]==true end; C_QuestLog.IsQuestDisabledForSession=function()return false end
    C_QuestLog.GetTitleForQuestID=function(id)return quests[id] and quests[id].name end
    C_QuestLog.GetQuestDifficultyLevel=function(id)return quests[id] and quests[id].questLevel end
    local slots={[123]="INVTYPE_HEAD",[124]="INVTYPE_WEAPON",[125]="INVTYPE_FEET"}
    C_Item={IsItemDataCachedByID=function(id)return W.cached[id]==true end,GetItemInfo=function(id) assert(W.cached[id],"cold full info read");return items[id].name,"item:"..id,2,22,15,"Armor","Plate",1,slots[id],100 end,GetItemInfoInstant=function(id)return id,"Armor","Plate",slots[id],100,items[id].class,0 end,RequestLoadItemDataByID=function(id)W.itemLoads[id]=(W.itemLoads[id] or 0)+1 end}
    C_TooltipInfo.GetHyperlink=function(link)return {id=tonumber(link:match("item:(%d+)")),type=0,hyperlink=link,lines={}}end
    Enum.UIMapType={Zone=3,Dungeon=4}
    C_Map={GetMapInfo=function(id)return {name="Zone "..id,mapType=3}end,GetBestMapForUnit=function()return 100 end,CanSetUserWaypointOnMap=function()return true end,SetUserWaypoint=function(point)W.waypoint=point;return W.waypointSuccess~=false end}
    UiMapPoint={CreateFromCoordinates=function(map,x,y)return {uiMapID=map,x=x,y=y}end}; C_SuperTrack={SetSuperTrackedUserWaypoint=function()W.tracked=true end}
    local rootMethods={}
    function rootMethods:CreateButton(label,fn)local e=setmetatable({label=label,callback=fn}, {__index=rootMethods});self.entries=self.entries or {};self.entries[#self.entries+1]=e;return e end
    function rootMethods:CreateRadio(label,checked,fn,value)local e=self:CreateButton(label,function()fn(value)end);e.checked=checked;return e end
    function rootMethods:AddInitializer(fn) local f=W.Object(); f.SetFont=function()error("compositor font setter")end;fn({fontString=f});self.fontObject=f.fontObject end
    function rootMethods:SetEnabled(v)self.enabled=v end
    function rootMethods:SetTooltip(fn)self.tooltip=fn end
    function rootMethods:SetScrollMode()end
    function rootMethods:CreateTitle(label)self.titles=self.titles or {};self.titles[#self.titles+1]=label;return {}end
    function rootMethods:AddMenuReleasedCallback(fn)self.release=fn end
    W.menuManager={IsAnyMenuOpen=function()return W.openMenu~=nil end}
    Menu={GetManager=function()return W.menuManager end}
    MenuUtil={CreateContextMenu=function(owner,generator)
        local root=setmetatable({entries={}}, {__index=rootMethods});generator(owner,root);local menu={root=root,owner=owner}
        function menu:Close()W.openMenu=nil;if root.release then root.release(self)end end
        W.openMenu=menu;return menu
    end}
    W.quests,W.catalogItems,W.npcs=quests,items,npcs
    N.Search:Create();N.Search.filter.scope="LEVEL_RANGE";N.Search.filter.sort="FIT"
    return N
end
local function open(config)
    local N=setup(config); N.Core:Slash("search"); W.time=.3; N.Search.frame:Fire("OnUpdate",.3); return N
end
test("finder opens through canonical aliases with reviewed title and level defaults",function()
    local N=open();assert(N.Search:Visible() and N.Search.title.text=="FindAnUpgrade" and N.Search.filter.minimum==15 and N.Search.filter.maximum==23 and N.Search.filter.sort=="FIT" and N.Search.filter.scope=="LEVEL_RANGE")
    N.Core:Slash("s");assert(not N.Search:Visible())
end)

test("registered finder aliases open and reopen without taking edit focus",function()
    for _,command in ipairs({"","search","s"}) do
        local N=setup();local S=N.Search
        for attempt=1,2 do
            SlashCmdList.FINDANUPGRADE(command)
            assert(S:Visible() and not S.search:HasFocus(),"opening the finder took search focus")
            for _,e in ipairs({S.search,S.minimumInput,S.maximumInput}) do assert(e.autoFocus==false and not e:HasFocus()) end
            W.time=W.time+.3;S:Tick();assert(not S.search:HasFocus())
            SlashCmdList.FINDANUPGRADE(command);assert(not S:Visible())
        end
    end
end)

test("closing a deliberately focused search releases focus and reopening retains its query",function()
    for _,close in ipairs({
        function(S)SlashCmdList.FINDANUPGRADE("")end,
        function(S)S.close:Fire("OnClick")end,
        function(S)S.search:Fire("OnEscapePressed")end,
    }) do
        local N=open();local S=N.Search
        -- Model native click-to-type focus; addon code must leave it available.
        S.search:SetFocus();S.search:SetText("Helmet");S.search:Fire("OnTextChanged",true)
        W.time=W.time+.3;S:Tick();assert(S.search:HasFocus() and #S.results==1 and S.results[1].id==9)
        close(S);assert(not S:Visible() and not S.search:HasFocus())
        SlashCmdList.FINDANUPGRADE("");W.time=W.time+.3;S:Tick()
        assert(S:Visible() and not S.search:HasFocus() and S.search:GetText()=="Helmet" and #S.results==1)
    end
end)

test("enter releases deliberate search focus without dismissing or clearing results",function()
    local N=open();local S=N.Search
    S.search:SetFocus();S.search:SetText("Helmet");S.search:Fire("OnTextChanged",true)
    S.search:Fire("OnEnterPressed");W.time=W.time+.3;S:Tick()
    assert(S:Visible() and not S.search:HasFocus() and S.filter.query=="Helmet" and #S.results==1)
end)

test("opening clears stale search focus even if it was focused while hidden",function()
    local N=setup();local S=N.Search;S.search:SetFocus()
    SlashCmdList.FINDANUPGRADE("");assert(S:Visible() and not S.search:HasFocus())
end)

test("clear refreshes both views without taking focus or erasing the other query",function()
    for _,focused in ipairs({false,true}) do
        local N=open();local S=N.Search;N.Shortlist:Toggle(9);N.Shortlist:Toggle(14)
        local function query(value)
            S.search:SetFocus();S.search:SetText(value);S.search:Fire("OnTextChanged",true)
            W.time=W.time+.3;S:Tick()
        end
        query("Helmet");assert(#S.results==1 and S.clearSearch:IsShown())
        S:View("shortlist");assert(S.placeholder:IsShown() and not S.clearSearch:IsShown())
        query("Dagger");assert(#S.results==1 and S.results[1].id==14)
        if not focused then S.search:ClearFocus() end
        S.clearSearch:Fire("OnClick");W.time=W.time+.3;S:Tick()
        assert(not S.search:HasFocus() and S.search:GetText()=="" and #S.results==2 and S.offset==0)
        assert(S.placeholder:IsShown() and not S.clearSearch:IsShown())
        S:View("quests");W.time=W.time+.3;S:Tick()
        assert(S.search:GetText()=="Helmet" and S.clearSearch:IsShown() and #S.results==1)
        if focused then S.search:SetFocus() end
        S.clearSearch:Fire("OnClick");W.time=W.time+.3;S:Tick()
        assert(not S.search:HasFocus() and S.filter.query=="" and #S.results==2 and S.offset==0)
        S:View("shortlist");assert(S.search:GetText()=="" and S.placeholder:IsShown() and not S.clearSearch:IsShown())
        S:View("quests");assert(S.search:GetText()=="" and not S.clearSearch:IsShown())
    end
end)
test("bundled catalogue works with both Questie addons absent and preserves input",function()
    local N=setup();assert(N.Catalog:Begin());N.Catalog:Step()
    assert(#N.Catalog.order==2 and #N.Catalog.records[9].items==2 and N.CatalogData.quests[1].id==9 and LibQuestieDB==nil)
end)
test("catalogue work is bounded to sixty-four items and pauses while hidden",function()
    local N=setup();local ids={};for i=1,200 do ids[i]={id=i,items={{itemID=123}}} end;N.CatalogData.quests=ids
    N.Search:Toggle();W.time=.3;N.Search.frame:Fire("OnUpdate",.3);assert(N.Catalog.cursor==65 and not N.Catalog.done)
    N.Search.frame:Hide();assert(N.Search.frame.scripts.OnUpdate==nil and N.Catalog.cursor==65)
end)
test("missing or incompatible catalogue gives an explicit bounded empty state",function()
    local N=setup();N.CatalogData=nil;N.Search:Toggle();W.time=.3;N.Search:Tick();assert(N.Search.empty.text:find("Bundled") and #N.Search.results==0)
end)
test("completed exact quests are hidden while repeatable quests remain unconfirmed",function()
    local N=setup();W.completed[9]=true;N.Search:Toggle();W.time=.3;N.Search:Tick();assert(#N.Search.results==1 and N.Search.results[1].id==14)
    N=setup();W.completed[9]=true;W.repeatable[9]=true;N.Search:Toggle();W.time=.6;N.Search:Tick();assert(#N.Search.results==2)
end)
test("wrong class and high-bit Forever race are filtered without thirty-two-bit truncation",function()
    local N=setup();W.quests[9].classTokens={"PALADIN"};W.quests[14].races={95};N.Search:Toggle();W.time=.3;N.Search:Tick();assert(#N.Search.results==0)
    UnitRace=function()return "Skyborne","Skyborne",95 end;N.Character:Mark("identity");N.Character.events:Fire("OnUpdate");N.Search:Changed();W.time=.6;N.Search:Tick();assert(#N.Search.results==1 and N.Search.results[1].id==14)
end)
test("unknown levels never become zero or a fabricated fit",function()
    local N=setup();W.quests[9].questLevel=0;W.quests[14].questLevel=nil;N.Search:Toggle();W.time=.3;N.Search:Tick();assert(#N.Search.results==0)
end)
test("completed single prerequisite takes precedence over an unmet group",function()
    local N=setup();W.quests[9].prerequisiteAlternatives={3};W.quests[9].prerequisites={2};W.completed[3]=true;N.Catalog:Begin();N.Catalog:Step()
    local eligible,note=N.SearchModel:Eligibility(N.Catalog.records[9],N.SearchModel:Context());assert(eligible and note==nil)
end)
test("an excluded reward name cannot match a different equipment slot",function()
    local N=setup();W.quests[9].items[#W.quests[9].items+1]={itemID=124,name="Dagger"};N.Catalog:Begin();N.Catalog:Step()
    local rows=N.SearchModel:Query({scope="LEVEL_RANGE",query="dagger",usable=true,minimum=15,maximum=23,slot="INVTYPE_HEAD",sort="FIT"});assert(#rows==0)
end)
test("weapon and robe slot families keep valid equipment categories",function()
    local N=setup();assert(N.SearchModel.SlotMatch("INVTYPE_2HWEAPON","WEAPON") and N.SearchModel.SlotMatch("INVTYPE_ROBE","CHEST") and not N.SearchModel.SlotMatch("INVTYPE_HEAD","WEAPON"))
end)
test("empty equipment slots use native slot identity and explicit empty state",function()
    local N=setup();GetInventorySlotInfo=function(name)return name=="HeadSlot" and 1 or nil end;ItemLocation={CreateFromEquipmentSlot=function(self,id)assert(self==ItemLocation);return {slot=id}end};C_Item.DoesItemExist=function(location)return location.slot~=1 end
    assert(N.SearchModel.SlotMatch("INVTYPE_HEAD","MISSING") and not N.SearchModel.SlotMatch("INVTYPE_FEET","MISSING"))
end)
test("cold item metadata does not trigger full-info reads and requests are bounded",function()
    local N=setup();for id in pairs(W.cached)do W.cached[id]=false end;N.Search:Toggle();W.time=.3;N.Search:Tick();local total=0;for _,n in pairs(W.itemLoads)do total=total+n end;assert(total<=2)
    W.time=.6;N.Search:Tick();for _,n in pairs(W.itemLoads)do assert(n==1)end
end)
test("matching item data callbacks recover names and unrelated callbacks do nothing",function()
    local N=setup();W.cached[123]=false;N.Search:Toggle();W.time=.3;N.Search:Tick();assert(N.SearchModel.cache[123].state=="pending")
    W.cached[123]=true;W.Event("ITEM_DATA_LOAD_RESULT",123,true);W.time=.6;N.Search:Tick();assert(N.SearchModel.cache[123].state=="ready")
    N.Search.dirty=false;W.Event("ITEM_DATA_LOAD_RESULT",999,true);assert(not N.Search.dirty)
end)
test("native unusable false is retained separately from unavailable usability",function()
    local N=setup();W.rewardReady=true;W.items={{"Helmet",100,1,2,false,123}};local r=N.Rewards.Read(9);assert(r.items.items[1].usable==false)
    W.items[1][5]=W.secret;r=N.Rewards.Read(9);assert(r.items.items[1].usable==nil)
end)
test("native usability changes invalidate rather than permanently excluding an item",function()
    local N=open();N.SearchModel.usability[9]={[123]=false,[125]=false};N.Search:Changed();W.time=.6;N.Search:Tick();assert(#N.Search.results==1)
    W.Event("PLAYER_LEVEL_UP",21);N.Character.events:Fire("OnUpdate");assert(next(N.SearchModel.usability)==nil)
end)
test("recorded rewards never invent quantities or guaranteed versus choice membership",function()
    local N=open();local card=N.Search.cards[1];assert(card.icons[1].group.text=="Reward" and not card.icons[1].group:IsShown() and card.icons[1].count.text=="" and not card.icons[1].name:IsShown() and card.fullTitle:find("Head quest",1,true))
end)
test("unknown values reserve no footer cells and no repeated unavailable labels",function()
    local N=open();local c=N.Search.cards[1]
    for i,label in ipairs(c.footer) do assert(not label:IsShown() and not c.footerHits[i]:IsShown()) end
    assert(c:GetHeight()<90 and not c.icons[1].name:IsShown())
end)
test("registered copy menu clears comparisons and preserves native menu font ownership",function()
    local N=open();local c=N.Search.cards[1];N.Search.inspector.item={};N.Search:ContextMenu(c.row,c);assert(N.Search.inspector.item==nil and #W.openMenu.root.entries==5)
    local entry=W.openMenu.root.entries[3];assert(entry.fontObject==N.Search.menuFont);entry.callback();assert(N.Search.copyEdit.text=="9" and N.Search.copyFrame:IsShown() and W.openMenu==nil)
end)
test("waypoint requires mapped coordinates and actual successful native set",function()
    local N=open();assert(not N.SearchModel.Waypoint({mapID=12,x=2,y=.5}) and W.waypoint==nil)
    W.waypointSuccess=false;assert(not N.SearchModel.Waypoint({mapID=100,x=.5,y=.6}) and not W.tracked)
    W.waypointSuccess=true;assert(N.SearchModel.Waypoint({mapID=100,x=.5,y=.6}) and W.tracked and W.waypoint.uiMapID==100)
end)
test("NPC locations use exact bundled giver records with native map validation",function()
    local N=setup();N.Catalog:Begin();N.Catalog:Step();local loc=N.Catalog:Location(9);assert(loc.name=="Giver A" and loc.mapID==100 and loc.x==.5)
    N.Catalog.locations={};W.quests[9].locations={};assert(#N.Catalog:Locations(9)==0)
end)
test("unverified dungeon map coordinates are rejected",function()
    local N=setup();C_Map.GetMapInfo=function()return {mapType=4,name="Wrong floor"}end;N.Catalog:Begin();N.Catalog:Step();local loc=N.Catalog:Location(9);assert(loc.name=="Giver A" and loc.mapID==nil)
end)
test("unknown coordinates disable waypoint and copy without fabricating a pin",function()
    local N=open();N.Search.cards[1].row.location={name="Known NPC"};N.Search:ContextMenu(N.Search.cards[1].row,N.Search.cards[1]);assert(W.openMenu.root.entries[1].enabled==false and W.openMenu.root.entries[2].enabled==false and W.waypoint==nil)
end)
test("catalogue links use the Forever environment and unknown IDs are unavailable",function()
    local N=open();assert(N.SearchModel.Wowhead(9):find("forever/quest=9",1,true));assert(not N.SearchModel.Wowhead(999999))
end)
test("search disables hover activation and hides cleanly on addon disable",function()
    local N=open();W.shift=true;local pin=W.Object();pin.questID=9;N.Sources:Pin(pin,9);assert(not N.Hover.open)
    N.Core:Change("enabled",false);assert(not N.Search:Visible() and N.Search.frame.scripts.OnUpdate==nil)
end)
test("search objects are reused and a hidden finder performs no frame work",function()
    local N=open();local count=#W.frames;for _=1,20 do N.Search.frame:Hide();N.Search:Toggle();W.time=W.time+.3;N.Search:Tick()end;assert(#W.frames==count)
    N.Search.frame:Hide();W.Event("QUEST_LOG_UPDATE");assert(N.Search.frame.scripts.OnUpdate==nil)
end)
test("launcher toggles persist independently from Questie preview surface",function()
    local N=setup();Minimap=W.Object(true);Minimap.width=140;Minimap.height=140;N.Launcher:Refresh();assert(N.Launcher.button:IsShown())
    N.Core:Slash("mm");assert(not N.Launcher.button:IsShown() and not FindAnUpgradeDB.launcher and FindAnUpgradeDB.minimap)
    N.Core:Slash("minimap");assert(N.Launcher.button:IsShown())
end)
test("launcher click opens finder and aborted drag removes recurring work",function()
    local N=setup();Minimap=W.Object(true);Minimap.width=140;N.Launcher:Refresh();local b=N.Launcher.button;b:Fire("OnClick","LeftButton");assert(N.Search:Visible())
    b:Fire("OnDragStart");assert(b.scripts.OnUpdate);b:Hide();assert(not b.scripts.OnUpdate and not N.Launcher.dragging and W.nativeMutations==0)
end)
test("schema-two settings migrate and launcher values are sanitized",function()
    local N=setup({saved={version=2,enabled=false,minimap=false,launcher=false,launcherAngle=-20}});assert(FindAnUpgradeDB.version==4 and not FindAnUpgradeDB.enabled and not FindAnUpgradeDB.minimap and not FindAnUpgradeDB.launcher and FindAnUpgradeDB.launcherAngle==340)
end)

test("production low mid and high catalogue searches work with Questie absent",function()
    local N=W.Init();assert(LibQuestieDB==nil and QuestieLoader==nil and #N.CatalogData.quests==N.CatalogData.questCount)
    W.rewardReady=false
    local selected={};for _,q in ipairs(N.CatalogData.quests) do
        local band=q.minimum and (q.minimum<=10 and 1 or q.minimum>=25 and q.minimum<=35 and 2 or q.minimum>=50 and 3)
        if band and #q.items>0 and not q.eligibilityConflict and not selected[band] and not q.classTokens and not q.races then selected[band]=q end
    end
    local levels={[selected[1].id]=8,[selected[2].id]=33,[selected[3].id]=60}
    C_QuestLog.GetQuestDifficultyLevel=function(id)return levels[id] end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    C_Item={IsItemDataCachedByID=function()return false end,GetItemInfoInstant=function(id)return id,"Armor","Cloth","INVTYPE_HEAD",100,4 end}
    assert(N.Catalog:Begin());while not N.Catalog.done do N.Catalog:Step() end
    for band,q in ipairs(selected) do
        UnitLevel=function()return levels[q.id]end;UnitFactionGroup=function()return q.faction or "Alliance"end;N.Character:Mark("identity")
        local rows=N.SearchModel:Query({scope="LEVEL_RANGE",query=tostring(q.id),usable=true,minimum=math.max(1,levels[q.id]-5),maximum=levels[q.id]+3,slot="ALL",sort="FIT"})
        local found;for _,row in ipairs(rows) do if row.id==q.id then found=row;break end end
        assert(found and #found.items>0 and found.fit==0)
    end
end)

test("recorded prerequisite thresholds permit either completed alternative",function()
    local N=setup();W.quests[9].prerequisites={2,3};W.quests[9].prerequisiteCount=1;W.completed[3]=true;N.Catalog:Begin();N.Catalog:Step()
    local allowed,note=N.SearchModel:Eligibility(N.Catalog.records[9],N.SearchModel:Context());assert(allowed and note==nil)
end)

test("native rewards obey slot filters and partial reputation remains explicit",function()
    local N=setup();W.rewardReady=true;W.items={{"Helmet",100,1,2,true,123},{"Boots",100,1,2,true,125}}
    C_QuestLog.GetQuestLogMajorFactionReputationRewards=function()return {{factionID=54,rewardAmount=125}}end
    N.Search:Create();N.Search.filter.slot="INVTYPE_HEAD";N.Search:Toggle();W.time=.3;N.Search:Tick()
    local c=N.Search.cards[1];assert(c.icons[1].row.itemID==123 and not (c.icons[2] and c.icons[2]:IsShown()) and c.footer[1].text:find("125",1,true) and c.footerHits[1].value:find("125",1,true) and not c.footer[3]:IsShown())
end)

test("cold quest difficulty cannot be inferred from its recorded minimum",function()
    local N=setup();W.quests[9].questLevel=nil;W.quests[9].minimum=20;N.Search:Toggle();W.time=.3;N.Search:Tick()
    assert(#N.Search.results==1 and N.SearchModel.unknownLevels==1 and W.metadataRequests[9]==1)
    W.quests[9].questLevel=20;W.Event("QUEST_DATA_LOAD_RESULT",9,true);W.time=.6;N.Search:Tick();assert(#N.Search.results==2)
end)

test("default card geometry fits four complete results and collapse clamps scroll",function()
    local N=open();assert(N.Search.cards[1]:GetHeight()*4+15<=N.Search:ViewportHeight())
    N.Search.offset=1000;N.Search:LayoutResults();assert(N.Search.offset==N.Search.maximum)
end)

test("drag release without a cursor sample does not open finder",function()
    local N=setup();Minimap=W.Object(true);Minimap.width=140;N.Launcher:Refresh();local b=N.Launcher.button;b:Fire("OnDragStart");b:Fire("OnDragStop");b:Fire("OnClick","LeftButton");assert(not N.Search:Visible())
end)

test("authoritative native rewards suppress conflicting catalogue associations",function()
    local N=open();W.rewardReady=true;W.items={{"Helmet",100,1,2,true,123}}
    local reward,recorded,changed=N.SearchModel:Reward(N.Search.results[1]);assert(changed and #recorded==0 and #reward.items.items==1)
    local rows=N.SearchModel:Query({scope="LEVEL_RANGE",query="boots",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"});assert(#rows==0)
    W.rewardReady=false;N.SearchModel:Reward(N.Catalog.records[9]);rows=N.SearchModel:Query({scope="LEVEL_RANGE",query="boots",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"});assert(#rows==1)
end)

test("asynchronous unrelated data preserves active inspection and context menus",function()
    local N=open();N.Search.inspector.item={marker=true};N.Search.itemRequests[124]=true
    W.catalogItems[124].name="Changed dagger";W.Event("ITEM_DATA_LOAD_RESULT",124,true)
    assert(N.Search.inspector.item and N.Search.dirty)
    N.Search.inspector.item=nil;local c=N.Search.cards[1];N.Search:ContextMenu(c.row,c);local menu=W.openMenu;N.Search.questRequests[14]=true
    W.quests[14].name="Changed weapon quest";W.Event("QUEST_DATA_LOAD_RESULT",14,true);assert(W.openMenu==menu and N.Search.dirty)
end)

test("cached non equipment rewards retain native names links and tooltips",function()
    local N=setup();C_Item.GetItemInfo=function(id)return "Food","item:"..id,1,1,1,"Consumable","Food",20,"",100 end
    local item=N.SearchModel:Item({itemID=123,name="Recorded Food"});assert(item.state=="ready" and item.link=="item:123" and item.slot=="" and N.SearchModel.SlotMatch(item.slot,"ALL") and not N.SearchModel.SlotMatch(item.slot,"WEAPON"))
end)

test("new inspection sessions discard old point in time usability exclusions",function()
    local N=open();N.SearchModel.usability[9]={[123]=false,[125]=false};N.Search.frame:Hide();N.Search:Toggle();assert(next(N.SearchModel.usability)==nil)
    N.SearchModel.usability[9]={[123]=false};W.Event("SKILL_LINES_CHANGED");N.Character.events:Fire("OnUpdate");assert(next(N.SearchModel.usability)==nil)
end)

test("giver button and native submenu select the location used by copy and waypoint",function()
    local N=setup();W.quests[9].locations[2]={npcID=55,name="Other giver",mapID=101,x=.25,y=.3}
    N.Search:Toggle();W.time=.3;N.Search:Tick();local S=N.Search;local c=S.cards[1]
    assert(c.giver:IsShown() and c.giver.text.text=="2 locations")
    N.Adapter.Over=function(frame)return frame==S.scroll or frame==c.giver end;c.giver:Fire("OnClick")
    assert(#W.openMenu.root.entries==2 and W.openMenu.root.entries[2].fontObject==S.menuFont)
    W.openMenu.root.entries[2].callback();W.time=.6;S:Tick();c=S.cards[1]
    assert(c.row.location.name=="Other giver" and c.location.text:find("Zone 101",1,true) and S.locationChoice[9]==c.row.location)
    S:ContextMenu(c.row,c);local root=W.openMenu.root;assert(root.entries[6].label=="Choose location" and #root.entries[6].entries==2)
    root.entries[1].callback();assert(W.waypoint.uiMapID==101 and W.waypoint.x==.25 and W.waypoint.y==.3)
    root.entries[4].callback();assert(S.copyEdit.text=="Other giver")
end)

test("single giver cards do not add a chooser or shrink the location allocation",function()
    local N=open();local S=N.Search;local c=S.cards[1]
    assert(not c.giver:IsShown() and c.location:GetWidth()>200 and c.location:GetWidth()<S.child:GetWidth()-16)
    S:ContextMenu(c.row,c);assert(#W.openMenu.root.entries==5)
end)

test("long title and location wrap in place without explanatory hover",function()
    local N=open();local S=N.Search;local c=S.cards[1]
    c.row.title=string.rep("A long native quest title ",5);S:Fill(c,c.row)
    assert(c.title.text:find("A long native quest title",1,true) and c.title:GetStringHeight()>13)
    c.titleHit:Fire("OnEnter");c.locationHit:Fire("OnEnter")
    assert(not S.textTooltip and not S.footerTooltip:IsShown())
    S:ContextMenu(c.row,c);c.titleHit:Fire("OnEnter");assert(not S.textTooltip)
    S.frame:Hide();assert(not S.textTooltip)
end)

test("disabled location actions expose distinct reasons and never copy a fabricated NPC name",function()
    local N=open();local S=N.Search;local c=S.cards[1];local tip=W.Object()
    c.row.location={npcID=99,name="NPC 99",nameKnown=false};S:ContextMenu(c.row,c);local entries=W.openMenu.root.entries
    assert(entries[1].enabled==false and entries[2].enabled==false and entries[4].enabled==false)
    entries[1].tooltip(tip);assert(tip.text:lower():find("coordinates unavailable",1,true));entries[4].tooltip(tip);assert(tip.text:find("NPC name unavailable",1,true))
    c.row.location={npcID=99,name="Phased giver",nameKnown=true,mapID=100,x=.2,y=.3,phase=true};S:ContextMenu(c.row,c);entries=W.openMenu.root.entries
    assert(entries[1].enabled==false and entries[2].enabled and entries[4].enabled);entries[1].tooltip(tip);assert(tip.text:find("phase",1,true))
    c.row.location.phase=false;C_Map.CanSetUserWaypointOnMap=function()return false end;S:ContextMenu(c.row,c);entries=W.openMenu.root.entries
    assert(entries[1].enabled==false);entries[1].tooltip(tip);assert(tip.text:find("cannot accept",1,true))
end)

test("bottom scrolling survives unseen height growth after narrowing and filter resets",function()
    local N=open();local S=N.Search;local rows={}
    for id=1,12 do
        N.Catalog.records[id]={id=id,source={locations={}}}
        local items={};for i=1,8 do items[i]={itemID=122+i} end
        rows[id]={id=id,title="Fixture "..id,level=20,evidence="Availability unconfirmed",items=items}
    end
    N.SearchModel.Reward=function(_,row)
        local items={};for i=1,8 do items[i]={itemID=122+i,name="Reward "..i,state="ready",usable=true,texture=100,quality=2} end
        return {state="ready",items={items={}},choices={items=items},money={state="ready",value=0},xp={state="ready",value=0},currencies={items={}},reputation={items={}}},{},false
    end
    S.results=rows;S.expanded[1]=true;S.heights={};S:LayoutResults();S:Scroll(0)
    S.frame:SetSize(520,400);S:LayoutResults();S:Scroll(1e9)
    assert(S.bottomTarget and S.offset==S.maximum and S.scroll.scrollValue==S.maximum and S.bar.value==S.maximum)
    local last;for _,card in ipairs(S.cards)do if card:IsShown() and card.row.id==12 then last=card end end
    assert(last and S.positions[12]+last:GetHeight()<=S.offset+S:ViewportHeight())
    S.expanded[12]=true;S:Render();assert(S.offset==S.maximum)
    S.expanded[12]=false;S.frame:SetSize(560,600);S:LayoutResults();S:Render();assert(S.offset==S.maximum)
    S:Scroll(S.offset-40);assert(not S.bottomTarget);local offset=S.offset;S:LayoutResults();assert(S.offset==offset)
    S:Scroll(1e9);S:Changed(true);assert(S.offset==0 and not S.bottomTarget)
end)

test("mixed old row heights settle newly visible third pass rows and final geometry",function()
    local N=open();local S=N.Search;local rows={}
    for id=1,8 do
        N.Catalog.records[id]={id=id,source={locations={}}}
        local items={};for i=1,8 do items[i]={itemID=122+i} end
        rows[id]={id=id,title="Fixture "..id,level=20,evidence="Availability unconfirmed",items=items}
    end
    N.SearchModel.Reward=function(_,row)
        local count=row.id==1 and 1 or row.id==2 and 4 or 8;local items={}
        for i=1,count do items[i]={itemID=122+i,name="Reward "..i,state="ready",usable=true,texture=100,quality=2} end
        return {state="ready",items={items={}},choices={items=items},money={state="ready",value=0},xp={state="ready",value=0},currencies={items={}},reputation={items={}}},{},false
    end
    local filled={};local fill=S.Fill;S.Fill=function(self,card,row)filled[row.id]=true;return fill(self,card,row)end
    S.results=rows;S.expanded[3]=true;S.heights={[1]=250,[2]=350,[3]=190,[4]=149,[5]=105,[6]=193,[7]=105,[8]=149}
    S.frame:SetSize(560,440);S:LayoutResults();S:Scroll(0)
    assert(filled[3] and S.heights[1]<105 and S.heights[2]<105 and S.heights[3]>S.heights[2])
    local y=0;for i,row in ipairs(rows)do assert(S.positions[i]==y);y=y+S.heights[row.id]+5 end
    assert(S.contentHeight==y and S.child:GetHeight()==y and S.maximum==y-S:ViewportHeight())
    for _,card in ipairs(S.cards)do if card:IsShown()then assert(card.point[3]==-S.positions[card.resultIndex])end end
    -- A wider viewport needs more than four passes through stale tall estimates.
    S.frame:SetSize(560,900);for id=1,8 do S.heights[id]=1000 end;S.expanded={};filled={};S.dirty=false
    S:LayoutResults();S:Scroll(0);assert(S.dirty)
    y=0;for i,row in ipairs(rows)do assert(S.positions[i]==y);y=y+S.heights[row.id]+5 end
    assert(S.child:GetHeight()==y and S.contentHeight==y and S.maximum==y-S:ViewportHeight() and S.offset==0 and S.bar.value==0 and S.scroll.scrollValue==0)
    for _,card in ipairs(S.cards)do if card:IsShown()then assert(card.point[3]==-S.positions[card.resultIndex])end end
end)

test("pooled text and amount rows never create explanatory hover tips",function()
    local N=open();local S=N.Search;local c=S.cards[1];N.Adapter.Over=function()return true end
    c.titleHit:Fire("OnEnter");S:Render();assert(not S.textTooltip)
    N.SearchModel.Reward=function() return {state="ready",items={items={}},choices={items={}},money={state="ready",value=50},xp={state="unavailable"},currencies={items={}},reputation={items={}}},{},false end
    S:Fill(c,c.row);c.footerHits[1]:Fire("OnEnter");assert(not S.footerTooltip:IsShown())
    S:Render();assert(not S.footerTooltip:IsShown() and not S.textTooltip)
end)

local nativeDropdownFile=io.open(ROOT.."/.work/current-api/Interface/AddOns/Blizzard_Menu/DropdownButton.lua","rb")
if nativeDropdownFile then
nativeDropdownFile:close()
test("native filter menus survive quest refresh and input until selection or dismissal",function()
    local N=open();local S=N.Search
    local file=assert(io.open(ROOT.."/.work/current-api/Interface/AddOns/Blizzard_Menu/DropdownButton.lua","rb"))
    local source=file:read("*a");file:close()
    local body=assert(source:match("(function DropdownButtonMixin:OnMouseDown_Intrinsic%b()%s.-\nend)"))
    DropdownButtonMixin={};assert(loadstring(body))()
    local setScale=S.frame.SetScale
    S.frame.SetScale=function(frame,value)setScale(frame,value);frame:Fire("OnSizeChanged")end
    for _,dropdown in ipairs({S.slot,S.sort}) do
        dropdown.CloseMenu=function(d)
            if d.openNative then d.openNative:Close();d.openNative=nil end
        end
        dropdown.SetMenuOpen=function(d,show)
            if show then
                d.openNative=MenuUtil.CreateContextMenu(d,d.menuGenerator)
            else d:CloseMenu() end
        end
        dropdown.IsMenuOpen=function(d)return d.openNative~=nil end
        S.search:SetFocus();S.minimumInput:SetFocus()
        DropdownButtonMixin.OnMouseDown_Intrinsic(dropdown)
        dropdown:Fire("OnMouseDown","LeftButton")
        local menu=W.openMenu;assert(menu and dropdown:IsMenuOpen() and not S.search.focused and not S.minimumInput.focused)
        dropdown:Fire("OnMouseUp","LeftButton");assert(W.openMenu==menu)
        for _,event in ipairs({"QUEST_LOG_UPDATE","PLAYER_EQUIPMENT_CHANGED","SPELLS_CHANGED","SKILL_LINES_CHANGED","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do
            W.Event(event);W.time=W.time+.2;S:Tick()
            assert(W.openMenu==menu and dropdown:IsMenuOpen(),event.." dismissed native menu")
        end
        assert(not dropdown:GetScript("OnMouseUp"))
        menu.root.entries[2].callback();assert(W.openMenu==nil)
        if dropdown==S.slot then assert(S.filter.slot=="MISSING") else assert(S.filter.sort=="FIT") end
        dropdown:SetMenuOpen(true);assert(W.openMenu)
        -- Outside-click/Escape use the native close callback; hiding the owner
        -- also releases menus. No addon timer closes them after opening.
        dropdown:CloseMenu();assert(not W.openMenu)
        dropdown:SetMenuOpen(true);S.frame:Hide();assert(not W.openMenu)
        S:Toggle();W.time=W.time+.3;S:Tick()
    end
end)
else
    print("SKIP native filter menus survive quest refresh and input until selection or dismissal: pinned DropdownButton fixture absent")
end

test("compact rows separate reward choices without squeezed item names",function()
    local N=open();local S=N.Search;local c=S.cards[1]
    N.SearchModel.Reward=function()
        local one={itemID=123,name=string.rep("A long full item name ",6),state="ready",usable=true,texture=100,quality=2,quantity=3,kind="reward"}
        local two={itemID=125,name="Choice",state="ready",usable=true,texture=100,quality=3,quantity=1,kind="choice"}
        return {state="ready",items={items={one}},choices={items={two}},money={state="unavailable"},xp={state="ready",value=1250},currencies={items={{name="Tokens",amount=2,isChoice=false}}},reputation={items={}}},{},false
    end
    S:Fill(c,c.row)
    assert(c.icons[1].group.text=="Guaranteed" and c.icons[2].group.text=="Choose one")
    assert(c.icons[1].count.text=="3" and math.abs(c.icons[1]:GetWidth()-112/3)<.001)
    assert(not c.icons[1].name:IsShown() and c.icons[1].row.name:find("full item name",1,true))
    assert(c.footer[1].text:find("1250 XP",1,true) and c.footer[1].text:find("Guaranteed: Tokens 2",1,true))
    assert(not c.footer[1].text:find("unavailable",1,true))
    local iconX=c.icons[1].point[2];assert(iconX>c.location:GetWidth()+8)
    assert(c:GetHeight()<130)
end)

test("only known amounts and item starts render without fabricated giver or zero",function()
    local N=open();local S=N.Search;local c=S.cards[1]
    N.Catalog.locations[9]={{itemID=123,name="A Scroll",nameKnown=true}}
    c.row.items={};c.row.evidence=nil
    N.SearchModel.Reward=function()return {state="ready",items={items={}},choices={items={}},money={state="unavailable"},xp={state="ready",value=900},currencies={items={}},reputation={items={}}},{},false end
    S:Fill(c,c.row)
    assert(c.location.text=="Starts from A Scroll" and c.footer[1].text=="900 XP")
    assert(c:GetHeight()<70 and c.location:GetWidth()==S.child:GetWidth()-16)
    assert(not c.evidence:IsShown() and not c.footer[2]:IsShown())
end)


test("location actions preserve item and object starter identities",function()
    local N=open();local S=N.Search;local c=S.cards[1]
    for _,spec in ipairs({{itemID=100,name="Starting Scroll",nameKnown=true},{objectID=200,name="Wanted Poster",nameKnown=true}}) do
        c.row.location=spec;S:ContextMenu(c.row,c)
        local entry=W.openMenu.root.entries[4]
        assert(entry.enabled and entry.label==(spec.itemID and "Copy item name" or "Copy object name"))
        assert(not W.openMenu.root.entries[1].enabled)
        entry.callback();assert(S.copyEdit.text==spec.name)
    end
    c.row.location={name="Unproven label",nameKnown=true};S:ContextMenu(c.row,c)
    assert(not W.openMenu.root.entries[4].enabled)
end)

local function subtypeFixture(cold)
    local N=setup();local traits={classID=2,subclassID=3,kind="Weapon",subtype="Guns"}
    local calls={info=0,instant=0};W.catalogItems[124].name="A neutral reward";W.quests[14].name="A neutral quest"
    W.cached[124]=not cold
    C_Item.GetItemInfo=function(id)
        calls.info=calls.info+1;assert(W.cached[id],"cold full metadata read")
        local item=W.catalogItems[id];local weapon=id==124
        local kind,subtype,class,subclass="Armor","Plate",4,4
        if weapon then kind,subtype,class,subclass=traits.kind,traits.subtype,traits.classID,traits.subclassID end
        return item.name,"item:"..id,2,22,15,kind,subtype,1,
            id==123 and "INVTYPE_HEAD" or id==125 and "INVTYPE_FEET" or "INVTYPE_RANGEDRIGHT",100,0,class,subclass
    end
    C_Item.GetItemInfoInstant=function(id)
        calls.instant=calls.instant+1;local weapon=id==124
        local kind,subtype,class,subclass="Armor","Plate",4,4
        if weapon then kind,subtype,class,subclass=traits.kind,traits.subtype,traits.classID,traits.subclassID end
        return id,kind,subtype,id==123 and "INVTYPE_HEAD" or id==125 and "INVTYPE_FEET" or "INVTYPE_RANGEDRIGHT",100,class,subclass
    end
    N.Catalog:Begin();N.Catalog:Step()
    local filter={scope="LEVEL_RANGE",usable=false,minimum=15,maximum=23,slot="ALL",sort="FIT"}
    local function query(value)filter.query=value;return N.SearchModel:Query(filter)end
    return N,traits,calls,query,filter
end

test("gun sword wand and staff terms use verified weapon subclasses with neutral names",function()
    local N,t,_,query=subtypeFixture()
    for _,spec in ipairs({{3,"Guns","gun"},{7,"One-Handed Swords","sword"},{8,"Two-Handed Swords","sword"},{19,"Wands","wand"},{10,"Staves","staff"},{18,"Crossbows","crossbow"}}) do
        t.subclassID,t.subtype=spec[1],spec[2];N.SearchModel.cache[124]=nil
        local rows=query(spec[3]);assert(#rows==1 and rows[1].id==14)
        assert(rows[1].items[1].classID==2 and rows[1].items[1].subclassID==spec[1])
    end
end)

test("weapon subtype matches retain slot usability level and quest class restrictions",function()
    local N,_,_,query,filter=subtypeFixture();filter.slot="INVTYPE_HEAD";assert(#query("gun")==0)
    filter.slot="ALL";filter.usable=true;N.SearchModel.usability[14]={[124]=false};assert(#query("gun")==0)
    N.SearchModel.usability[14]=nil;N.SearchModel.cache[124].minimum=21;assert(#query("gun")==0)
    filter.usable=false;N.Catalog.records[14].source.classTokens={"MAGE"};assert(#query("gun")==0)
end)

test("cold instant subtype evidence matches without any cold full metadata read",function()
    local N,_,calls,query=subtypeFixture(true);local rows=query("gun")
    assert(#rows==1 and rows[1].id==14 and rows[1].items[1].state=="pending")
    assert(calls.info==2 and calls.instant==1 and N.SearchModel.cache[124].itemSubType=="Guns")
    assert(#N.SearchModel.needed==1 and N.SearchModel.needed[1]==124)
end)

test("warm subtype searches and shared associations perform no extra item metadata reads",function()
    local N,_,calls,query=subtypeFixture();N.Catalog.records[9].items[#N.Catalog.records[9].items+1]={itemID=124,name="A neutral reward"}
    assert(#query("gun")==2);local full,instant=calls.info,calls.instant
    for _=1,8 do assert(#query("gun")==2) end
    assert(calls.info==full and calls.instant==instant and full==3)
end)

test("localized native subclass and exact numeric weapon aliases both match",function()
    local N,t,_,query=subtypeFixture();t.subtype="Armes à feu"
    local rows=query("armes");assert(#rows==1 and rows[1].id==14)
    assert(#query("gun")==1)
    t.classID=4;t.subtype="Other";N.SearchModel.cache[124]=nil
    assert(#query("gun")==0)
end)

test("unknown or secret subtype metadata never invents a weapon match",function()
    local N,t,_,query=subtypeFixture();t.classID,t.subclassID,t.kind,t.subtype=nil,nil,W.secret,W.secret
    assert(#query("gun")==0 and #query("wand")==0)
    local item=N.SearchModel.cache[124];assert(item.classID==nil and item.subclassID==nil and item.itemType==nil and item.itemSubType==nil)
end)

test("subtype-only item callbacks recover query results and unchanged events stay idle",function()
    local N,t,_,query,filter=subtypeFixture();t.subtype,t.subclassID=nil,nil
    N.Search.filter=filter;N.Search.frame:Show();assert(#query("gun")==0)
    t.subtype,t.subclassID="Guns",3;N.Search.dirty=false;W.Event("ITEM_DATA_LOAD_RESULT",124,true)
    assert(N.Search.dirty and #query("gun")==1)
    N.Search.dirty=false;W.Event("GET_ITEM_INFO_RECEIVED",124,true);assert(not N.Search.dirty)
end)

test("hidden subtype callbacks invalidate without hydration and unrelated callbacks do nothing",function()
    local N,t,calls,query=subtypeFixture();assert(#query("gun")==1)
    N.Search.frame:Hide();t.subtype,t.subclassID="Wands",19;local full,instant=calls.info,calls.instant
    W.Event("ITEM_DATA_LOAD_RESULT",124,true);assert(N.SearchModel.cache[124]==nil and calls.info==full and calls.instant==instant)
    N.Search.dirty=false;W.Event("GET_ITEM_INFO_RECEIVED",999,true);assert(not N.Search.dirty and calls.info==full and calls.instant==instant)
    assert(#query("wand")==1)
end)

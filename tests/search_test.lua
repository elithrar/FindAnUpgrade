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
    function rootMethods:CreateButton(label,fn)local e=setmetatable({label=label,callback=fn}, {__index=rootMethods});self.entries[#self.entries+1]=e;return e end
    function rootMethods:CreateRadio(label,checked,fn,value)local e=self:CreateButton(label,function()fn(value)end);e.checked=checked;return e end
    function rootMethods:AddInitializer(fn) local f=W.Object(); f.SetFont=function()error("compositor font setter")end;fn({fontString=f});self.fontObject=f.fontObject end
    function rootMethods:SetEnabled(v)self.enabled=v end
    function rootMethods:SetTooltip(fn)self.tooltip=fn end
    function rootMethods:SetScrollMode()end
    function rootMethods:AddMenuReleasedCallback(fn)self.release=fn end
    W.menuManager={IsAnyMenuOpen=function()return W.openMenu~=nil end}
    Menu={GetManager=function()return W.menuManager end}
    MenuUtil={CreateContextMenu=function(owner,generator)
        local root=setmetatable({entries={}}, {__index=rootMethods});generator(owner,root);local menu={root=root,owner=owner}
        function menu:Close()W.openMenu=nil;if root.release then root.release(self)end end
        W.openMenu=menu;return menu
    end}
    W.quests,W.catalogItems,W.npcs=quests,items,npcs
    return N
end
local function open(config)
    local N=setup(config); N.Core:Slash("search"); W.time=.3; N.Search.frame:Fire("OnUpdate",.3); return N
end
test("finder opens through canonical aliases with reviewed title and level defaults",function()
    local N=open();assert(N.Search:Visible() and N.Search.title.text=="QuestBrief" and N.Search.filter.minimum==15 and N.Search.filter.maximum==23 and N.Search.sort.defaultText=="Level fit")
    N.Core:Slash("s");assert(not N.Search:Visible())
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
    W.repeatable[9]=true;N.Search:Changed();W.time=.6;N.Search:Tick();assert(#N.Search.results==2)
end)
test("wrong class and high-bit Forever race are filtered without thirty-two-bit truncation",function()
    local N=setup();W.quests[9].classTokens={"PALADIN"};W.quests[14].races={95};N.Search:Toggle();W.time=.3;N.Search:Tick();assert(#N.Search.results==0)
    UnitRace=function()return "Skyborne","Skyborne",95 end;N.Search:Changed();W.time=.6;N.Search:Tick();assert(#N.Search.results==1 and N.Search.results[1].id==14)
end)
test("unknown levels never become zero or a fabricated fit",function()
    local N=setup();W.quests[9].questLevel=0;W.quests[14].questLevel=nil;N.Search:Toggle();W.time=.3;N.Search:Tick();assert(#N.Search.results==0)
end)
test("completed single prerequisite takes precedence over an unmet group",function()
    local N=setup();W.quests[9].prerequisiteAlternatives={3};W.quests[9].prerequisites={2};W.completed[3]=true;N.Catalog:Begin();N.Catalog:Step()
    local eligible,note=N.SearchModel:Eligibility(N.Catalog.records[9],N.SearchModel:Context());assert(eligible and note=="Availability unconfirmed")
end)
test("an excluded reward name cannot match a different equipment slot",function()
    local N=setup();W.quests[9].items[#W.quests[9].items+1]={itemID=124,name="Dagger"};N.Catalog:Begin();N.Catalog:Step()
    local rows=N.SearchModel:Query({query="dagger",usable=true,minimum=15,maximum=23,slot="INVTYPE_HEAD",sort="FIT"});assert(#rows==0)
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
    W.Event("PLAYER_LEVEL_UP",21);assert(next(N.SearchModel.usability)==nil)
end)
test("recorded rewards never invent quantities or guaranteed versus choice membership",function()
    local N=open();local card=N.Search.cards[1];assert(card.icons[1].group.text=="Recorded reward" and card.icons[1].count.text=="" and card.evidence.text:find("unconfirmed"))
end)
test("result footer columns share the same baseline including unavailable values",function()
    local N=open();local c=N.Search.cards[1];assert(c.footer[1].point[3]==c.footer[2].point[3] and c.footer[2].point[3]==c.footer[3].point[3] and c.footer[3].text=="Rep unavailable")
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
    N.Core:Slash("mm");assert(not N.Launcher.button:IsShown() and not QuestBriefDB.launcher and QuestBriefDB.minimap)
    N.Core:Slash("minimap");assert(N.Launcher.button:IsShown())
end)
test("launcher click opens finder and aborted drag removes recurring work",function()
    local N=setup();Minimap=W.Object(true);Minimap.width=140;N.Launcher:Refresh();local b=N.Launcher.button;b:Fire("OnClick","LeftButton");assert(N.Search:Visible())
    b:Fire("OnDragStart");assert(b.scripts.OnUpdate);b:Hide();assert(not b.scripts.OnUpdate and not N.Launcher.dragging and W.nativeMutations==0)
end)
test("schema-two settings migrate and launcher values are sanitized",function()
    local N=setup({saved={version=2,enabled=false,minimap=false,launcher=false,launcherAngle=-20}});assert(QuestBriefDB.version==3 and not QuestBriefDB.enabled and not QuestBriefDB.minimap and not QuestBriefDB.launcher and QuestBriefDB.launcherAngle==340)
end)

test("production low mid and high catalogue searches work with Questie absent",function()
    local N=W.Init();assert(LibQuestieDB==nil and QuestieLoader==nil and #N.CatalogData.quests==N.CatalogData.questCount)
    local selected={};for _,q in ipairs(N.CatalogData.quests) do
        local band=q.minimum and (q.minimum<=10 and 1 or q.minimum>=25 and q.minimum<=35 and 2 or q.minimum>=50 and 3)
        if band and not selected[band] and not q.classTokens and not q.races then selected[band]=q end
    end
    local levels={[selected[1].id]=8,[selected[2].id]=33,[selected[3].id]=60}
    C_QuestLog.GetQuestDifficultyLevel=function(id)return levels[id] end
    C_QuestLog.IsQuestFlaggedCompleted=function()return false end
    C_Item={IsItemDataCachedByID=function()return false end,GetItemInfoInstant=function(id)return id,"Armor","Cloth","INVTYPE_HEAD",100,4 end}
    assert(N.Catalog:Begin());while not N.Catalog.done do N.Catalog:Step() end
    for band,q in ipairs(selected) do
        UnitLevel=function()return levels[q.id]end;UnitFactionGroup=function()return q.faction or "Alliance"end
        local rows=N.SearchModel:Query({query=tostring(q.id),usable=true,minimum=math.max(1,levels[q.id]-5),maximum=levels[q.id]+3,slot="ALL",sort="FIT"})
        assert(#rows==1 and rows[1].id==q.id and #rows[1].items>0 and rows[1].fit==0)
    end
end)

test("recorded prerequisite thresholds permit either completed alternative",function()
    local N=setup();W.quests[9].prerequisites={2,3};W.quests[9].prerequisiteCount=1;W.completed[3]=true;N.Catalog:Begin();N.Catalog:Step()
    local allowed,note=N.SearchModel:Eligibility(N.Catalog.records[9],N.SearchModel:Context());assert(allowed and note=="Availability unconfirmed")
end)

test("native rewards obey slot filters and partial reputation remains explicit",function()
    local N=setup();W.rewardReady=true;W.items={{"Helmet",100,1,2,true,123},{"Boots",100,1,2,true,125}}
    C_QuestLog.GetQuestLogMajorFactionReputationRewards=function()return {{factionID=54,rewardAmount=125}}end
    N.Search:Create();N.Search.filter.slot="INVTYPE_HEAD";N.Search:Toggle();W.time=.3;N.Search:Tick()
    local c=N.Search.cards[1];assert(c.icons[1].row.itemID==123 and not (c.icons[2] and c.icons[2]:IsShown()) and c.footer[3].text=="Rep (partial)" and c.footerHits[3].value:find("125"))
end)

test("cold quest difficulty cannot be inferred from its recorded minimum",function()
    local N=setup();W.quests[9].questLevel=nil;W.quests[9].minimum=20;N.Search:Toggle();W.time=.3;N.Search:Tick()
    assert(#N.Search.results==1 and N.SearchModel.unknownLevels==1 and W.metadataRequests[9]==1)
    W.quests[9].questLevel=20;W.Event("QUEST_DATA_LOAD_RESULT",9,true);W.time=.6;N.Search:Tick();assert(#N.Search.results==2)
end)

test("default card geometry fits four complete results and collapse clamps scroll",function()
    local N=open();assert(N.Search.cards[1]:GetHeight()*4+15<=N.Search.frame:GetHeight()-158)
    N.Search.offset=1000;N.Search:LayoutResults();assert(N.Search.offset==N.Search.maximum)
end)

test("drag release without a cursor sample does not open finder",function()
    local N=setup();Minimap=W.Object(true);Minimap.width=140;N.Launcher:Refresh();local b=N.Launcher.button;b:Fire("OnDragStart");b:Fire("OnDragStop");b:Fire("OnClick","LeftButton");assert(not N.Search:Visible())
end)

test("authoritative native rewards suppress conflicting catalogue associations",function()
    local N=open();W.rewardReady=true;W.items={{"Helmet",100,1,2,true,123}}
    local reward,recorded,changed=N.SearchModel:Reward(N.Search.results[1]);assert(changed and #recorded==0 and #reward.items.items==1)
    local rows=N.SearchModel:Query({query="boots",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"});assert(#rows==0)
    W.rewardReady=false;N.SearchModel:Reward(N.Catalog.records[9]);rows=N.SearchModel:Query({query="boots",usable=true,minimum=15,maximum=23,slot="ALL",sort="FIT"});assert(#rows==1)
end)

test("asynchronous unrelated data preserves active inspection and context menus",function()
    local N=open();N.Search.inspector.item={marker=true};N.Search.itemRequests[124]=true;W.Event("ITEM_DATA_LOAD_RESULT",124,true)
    assert(N.Search.inspector.item and N.Search.dirty)
    N.Search.inspector.item=nil;local c=N.Search.cards[1];N.Search:ContextMenu(c.row,c);local menu=W.openMenu;N.Search.questRequests[14]=true;W.Event("QUEST_DATA_LOAD_RESULT",14,true);assert(W.openMenu==menu and N.Search.dirty)
end)

test("cached non equipment rewards retain native names links and tooltips",function()
    local N=setup();C_Item.GetItemInfo=function(id)return "Food","item:"..id,1,1,1,"Consumable","Food",20,"",100 end
    local item=N.SearchModel:Item({itemID=123,name="Recorded Food"});assert(item.state=="ready" and item.link=="item:123" and item.slot=="" and N.SearchModel.SlotMatch(item.slot,"ALL") and not N.SearchModel.SlotMatch(item.slot,"WEAPON"))
end)

test("new inspection sessions discard old point in time usability exclusions",function()
    local N=open();N.SearchModel.usability[9]={[123]=false,[125]=false};N.Search.frame:Hide();N.Search:Toggle();assert(next(N.SearchModel.usability)==nil)
    N.SearchModel.usability[9]={[123]=false};W.Event("SKILL_LINES_CHANGED");assert(next(N.SearchModel.usability)==nil)
end)

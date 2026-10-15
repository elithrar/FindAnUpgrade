local passed=0
local function test(name,fn)local ok,why=pcall(fn);if not ok then error(name..": "..tostring(why)) end;passed=passed+1 end
local function setup()
    local N,rows,calls={},{},{cache=0,info=0,use=0,limits=0,requests=0}
    issecretvalue=function(v)return type(v)=="table" and v.secret==true end
    loadfile(ROOT.."/FindAnUpgrade/Model.lua")("FindAnUpgrade",N);loadfile(ROOT.."/FindAnUpgrade/Adapter.lua")("FindAnUpgrade",N)
    C_Item={IsItemDataCachedByID=function(id)calls.cache=calls.cache+1;return rows[id] and rows[id].cached~=false or false end,
        GetItemInfo=function(link)
            calls.info=calls.info+1;local id=tonumber(link:match("item:(%d+)"));local r=rows[id];if not r then return end
            local minimum=r.minimumMissing and nil or r.minimum or 0
            return "Item "..id,r.infoLink or link,2,r.level,minimum,"Armor","Cloth",1,r.slot,100,0,r.classID or 4,r.subclassID or 1,1,0,r.setID
        end,
        GetItemUniqueness=function(link)calls.limits=calls.limits+1;local r=rows[tonumber(link:match("item:(%d+)"))];if r.uniqueMissing then return end;return r.category or 0,r.maximum or 0 end,
        GetItemUniquenessByID=function(link)calls.limits=calls.limits+1;local r=rows[tonumber(link:match("item:(%d+)"))];if r.uniqueMissing then return end;return r.single or false,nil,r.category and r.maximum or nil,r.category end,
        GetItemStats=function()error("minimal heuristic must not read stats")end,
        RequestLoadItemDataByID=function()calls.requests=calls.requests+1;error("ranker requested data")end}
    C_PlayerInfo={CanUseItem=function(id)calls.use=calls.use+1;local r=rows[id];if not r or r.useMissing then return end;return r.usable~=false end}
    C_TooltipInfo={GetHyperlink=function()error("minimal heuristic must not scan tooltips")end}
    GameTooltip={SetHyperlink=function()error("ranker changed native hover")end}
    loadfile(ROOT.."/FindAnUpgrade/Ranking.lua")("FindAnUpgrade",N)
    local s={guid="Player-1-1",classID=8,classToken="MAGE",faction="Alliance",level=30,identityRevision=1,equipmentRevision=1,capabilityRevision=0,itemRevision=0,equipment={},emptySlots={}}
    for slot=1,19 do s.equipment[slot]={state="empty"};s.emptySlots[slot]=true end
    local function add(id,slot,level,extra)
        local row={slot=slot,level=level};for k,v in pairs(extra or {})do row[k]=v end;rows[id]=row
        return {itemID=id,link="item:"..id..":0:0:0:0:0:0",slot=slot,state="ready",quantity=1,group="choice"}
    end
    local function equip(slot,item)s.equipment[slot]={state="ready",itemID=item.itemID,link=item.link};s.emptySlots[slot]=nil;s.equipmentRevision=s.equipmentRevision+1 end
    return N.Ranking,s,add,equip,rows,calls,N
end
local function normal(id,slot,level,extra)
    local row={itemID=id,slot=slot,itemLevel=level,state="ready",usable=true,unique={category=0,maximum=0,single=false}}
    for k,v in pairs(extra or {})do row[k]=v end;return row
end
local function gear()local g={};for i=1,19 do g[i]={state="empty"}end;return g end
local function total(c)return c.cache+c.info+c.use+c.limits end

test("native entry returns transparent estimated item level gain",function()
    local R,s,add,equip=setup();equip(1,add(1,"INVTYPE_HEAD",20))
    local r=R:Quest({add(2,"INVTYPE_HEAD",25)},s,"ALL")
    assert(r.state=="ready" and r.tier==1 and r.gain==5 and r.metric=="item-level" and r.estimated and r.percent==nil and r.dps==nil)
end)
test("stat scales styles and tooltip scanning are absent",function()
    local R,s,add=setup();assert(R.Styles==nil and R.Style==nil and R.Normalize==nil)
    assert(R:Quest({add(1,"INVTYPE_TRINKET",20,{setID=99})},s).gain==20)
end)
test("negative and equal item levels retain deterministic nonpositive tier",function()
    local R,s,add,equip=setup();equip(1,add(1,"INVTYPE_HEAD",25))
    assert(R:Quest({add(2,"INVTYPE_HEAD",20)},s).gain==-5 and R:Quest({add(3,"INVTYPE_HEAD",25)},s).tier==3)
end)
test("unknown occupied gear is never zero and known empties have finite gain",function()
    local R,s,add=setup();local item=add(1,"INVTYPE_NECK",20);assert(R:Quest({item},s).gain==20)
    s.emptySlots[2]=nil;s.equipment[2]={state="pending"};s.equipmentRevision=2
    assert(R:Quest({item},s).gain==nil)
end)
test("uncached baseline recovers with item event",function()
    local R,s,add,equip,rows=setup();equip(1,add(1,"INVTYPE_HEAD",20,{cached=false}));local item=add(2,"INVTYPE_HEAD",25)
    assert(R:Quest({item},s).gain==nil);rows[1].cached=true;assert(R:InvalidateItem(1,s,true));assert(R:Quest({item},s).gain==5)
end)
test("missing zero malformed and restricted item levels remain unknown",function()
    local R,s,add=setup()
    for i,lv in ipairs({0,-1,0/0,math.huge,{secret=true}})do assert(R:Quest({add(i,"INVTYPE_HEAD",lv)},s).gain==nil)end
    assert(R:Quest({add(20,"INVTYPE_HEAD",nil)},s).gain==nil)
end)
test("usable false and unavailable usability are distinct",function()
    local R,s,add=setup();local no=add(1,"INVTYPE_HEAD",30,{usable=false});local unknown=add(2,"INVTYPE_HEAD",30,{useMissing=true})
    assert(R:Usable(no.itemID,s)==false and R:Usable(unknown.itemID,s)==nil)
    assert(R:Quest({no},s).state=="none" and R:Quest({unknown},s).gain==nil)
end)
test("above current requirement cannot produce an upgrade",function()
    local R,s,add=setup();assert(R:Quest({add(1,"INVTYPE_HEAD",50,{minimum=40})},s).gain==nil)
end)
test("rings and trinkets compare both legal replacements",function()
    local R,s,add,equip=setup();equip(11,add(1,"INVTYPE_FINGER",25));equip(12,add(2,"INVTYPE_FINGER",10))
    assert(R:Quest({add(3,"INVTYPE_FINGER",20)},s).gain==10)
    equip(13,add(4,"INVTYPE_TRINKET",30));equip(14,add(5,"INVTYPE_TRINKET",12))
    assert(R:Quest({add(6,"INVTYPE_TRINKET",20)},s).gain==8)
end)
test("unknown ring partner prevents a definitive best replacement",function()
    local R,s,add,equip=setup();equip(11,add(1,"INVTYPE_FINGER",25,{cached=false}));equip(12,add(2,"INVTYPE_FINGER",10))
    assert(R:Quest({add(3,"INVTYPE_FINGER",20)},s).gain==nil)
end)
test("unique category forces replacement of its stronger ring",function()
    local R,s,add,equip=setup();equip(11,add(1,"INVTYPE_FINGER",25,{category=7,maximum=1}));equip(12,add(2,"INVTYPE_FINGER",10))
    assert(R:Quest({add(3,"INVTYPE_FINGER",20,{category=7,maximum=1})},s).gain==-5)
end)
test("whole retained outfit enforces unique category",function()
    local R,s=setup();local g=gear();g[1]=normal(1,"INVTYPE_HEAD",20,{unique={category=7,maximum=1,single=false}})
    assert(R.Compare(normal(2,"INVTYPE_FINGER",25,{unique={category=7,maximum=1,single=false}}),g,s).gain==nil)
end)
test("unique item cannot remain in the other paired slot",function()
    local R,s=setup();local g=gear();g[11]=normal(2,"INVTYPE_FINGER",25);g[12]=normal(3,"INVTYPE_FINGER",10)
    assert(R.Compare(normal(2,"INVTYPE_FINGER",20,{unique={category=0,maximum=0,single=true}}),g,s).gain==-5)
end)
test("unknown limits never imply unrestricted candidate gear",function()
    local R,s,add=setup();assert(R:Quest({add(1,"INVTYPE_HEAD",30,{uniqueMissing=true})},s).gain==nil)
end)
test("two hand compares to average occupied main and off hands",function()
    local R,s,add,equip=setup();equip(16,add(1,"INVTYPE_WEAPONMAINHAND",30));equip(17,add(2,"INVTYPE_SHIELD",20))
    assert(R:Quest({add(3,"INVTYPE_2HWEAPON",35)},s).gain==10)
end)
test("empty offhand does not halve a one hand baseline",function()
    local R,s,add,equip=setup();equip(16,add(1,"INVTYPE_WEAPONMAINHAND",30))
    assert(R:Quest({add(2,"INVTYPE_2HWEAPON",35)},s).gain==5)
end)
test("equipped two hand counts once and never invents an offhand",function()
    local R,s,add,equip=setup();equip(16,add(1,"INVTYPE_2HWEAPON",30))
    assert(R:Quest({add(2,"INVTYPE_2HWEAPON",35)},s).gain==5)
    assert(R:Quest({add(3,"INVTYPE_WEAPONMAINHAND",40)},s).gain==nil)
    assert(R:Quest({add(4,"INVTYPE_HOLDABLE",40)},s).gain==nil)
end)
test("two hand unknown or contradictory pair remains unknown",function()
    local R,s,add,equip=setup();equip(16,add(1,"INVTYPE_2HWEAPON",30));equip(17,add(2,"INVTYPE_SHIELD",20))
    assert(R:Quest({add(3,"INVTYPE_2HWEAPON",40)},s).gain==nil)
end)
test("two hand empty hands has a finite known zero baseline",function()
    local R,s,add=setup();assert(R:Quest({add(1,"INVTYPE_2HWEAPON",25)},s).gain==25)
end)
test("flexible weapon requires known dual capability for the alternative slot",function()
    local R,s=setup();local g=gear();g[16]=normal(1,"INVTYPE_WEAPONMAINHAND",20);local item=normal(2,"INVTYPE_WEAPON",25)
    assert(R.Compare(item,g,s).gain==nil);s.capabilities={dualWield=false};assert(R.Compare(item,g,s).gain==5)
    s.capabilities.dualWield=true;assert(R.Compare(item,g,s).gain==25)
end)
test("actual dual wield outfit proves current pairing without class guesses",function()
    local R,s,add,equip=setup();equip(16,add(1,"INVTYPE_WEAPON",25));equip(17,add(2,"INVTYPE_WEAPONOFFHAND",10))
    assert(R:Quest({add(3,"INVTYPE_WEAPON",20)},s).gain==10)
end)
test("offhand weapon cannot invent a main hand partner",function()
    local R,s=setup();s.capabilities={dualWield=true}
    assert(R.Compare(normal(1,"INVTYPE_WEAPONOFFHAND",30),gear(),s).gain==nil)
end)
test("ranged and relic use Forever slot18",function()
    local R,s=setup();local g=gear();g[18]=normal(1,"INVTYPE_RANGED",20)
    assert(R.Compare(normal(2,"INVTYPE_RANGED",25),g,s).gain==5)
    assert(R.Compare(normal(3,"INVTYPE_RELIC",25),g,s).gain==5)
end)
test("generic suffix must not borrow the equipped exact variant",function()
    local R,s,add,equip=setup();local item=add(1,"INVTYPE_HEAD",30);item.link="item:1:0:0:0:0:0:77";equip(1,item)
    assert(R:Item(item,s,true).state=="ready" and R:Item(item,s).reason=="reward-variant-unconfirmed")
end)
test("generic returned suffix and mismatched identities are withheld",function()
    local R,s,add=setup();assert(R:Quest({add(1,"INVTYPE_HEAD",30,{infoLink="item:1:0:0:0:0:0:77"})},s).gain==nil)
    assert(R:Quest({add(2,"INVTYPE_HEAD",30,{infoLink="item:200:0:0:0:0:0:0"})},s).gain==nil)
    local bad=add(3,"INVTYPE_HEAD",30);bad.link="item:3evil:0";assert(R:Quest({bad},s).gain==nil)
end)
test("cosmetic shirts tabards and nongear do not create upgrade scores",function()
    local R,s,add=setup()
    for i,slot in ipairs({"INVTYPE_BODY","INVTYPE_TABARD",""})do assert(R:Quest({add(i,slot,30)},s).state=="none")end
end)
test("quantities and duplicate guaranteed choice entries are not summed",function()
    local R,s,add=setup();local item=add(1,"INVTYPE_HEAD",20);item.quantity=10;item.group="guaranteed"
    local copy={};for k,v in pairs(item)do copy[k]=v end;copy.group="choice"
    assert(R:Quest({item,copy,add(2,"INVTYPE_FEET",25)},s).gain==25)
end)
test("one unknown equipment option keeps quest best reward unknown",function()
    local R,s,add=setup();assert(R:Quest({add(1,"INVTYPE_HEAD",20),add(2,"INVTYPE_FEET",25,{cached=false})},s).gain==nil)
end)
test("best score observes selected equipment slot",function()
    local R,s,add=setup();assert(R:Quest({add(1,"INVTYPE_HEAD",20),add(2,"INVTYPE_FEET",40)},s,"INVTYPE_HEAD").gain==20)
end)
test("equal gains use exact item identity deterministically",function()
    local R,s,add=setup();local a,b=add(2,"INVTYPE_HEAD",20),add(1,"INVTYPE_FEET",20)
    assert(R:Quest({a,b},s).itemID==1 and R:Quest({b,a},s).itemID==1)
end)
test("capability and equipment revisions refresh shared usability",function()
    local R,s,add,_,rows,calls=setup();local item=add(1,"INVTYPE_HEAD",25,{usable=false})
    assert(R:Usable(1,s)==false);local before=calls.use;for _=1,1000 do assert(R:Usable(1,s)==false)end;assert(calls.use==before)
    rows[1].usable=true;s.capabilityRevision=1;assert(R:Quest({item},s).gain==25)
    rows[1].usable=false;s.equipmentRevision=2;assert(R:Usable(1,s)==false)
end)
test("usability only item events update once even before full ranking",function()
    local R,s,add,_,rows=setup();add(1,"INVTYPE_HEAD",25,{usable=false});assert(R:Usable(1,s)==false and R:Interested(1))
    assert(not R:InvalidateItem(1,s,true));rows[1].usable=true;assert(R:InvalidateItem(1,s,true) and R:Usable(1,s))
end)
test("same ID ready item level changes use central exact gear metadata bridge",function()
    local R,s,add,equip,rows,_,N=setup();equip(1,add(1,"INVTYPE_HEAD",20));local item=add(2,"INVTYPE_HEAD",25)
    assert(R:Quest({item},s).gain==5);local forwarded=0
    N.Character={EquipmentMetadata=function(_,id,value,rev)assert(id==1 and value:find("itemLevel=30",1,true) and #value<8192 and rev==s.equipmentRevision);forwarded=forwarded+1;return true end}
    rows[1].level=30;local changed,central=R:InvalidateItem(1,s,true);assert(changed and central and forwarded==1 and R:Quest({item},s).gain==-5)
    for _=1,100 do changed,central=R:InvalidateItem(1,s,true);assert(not changed and not central)end;assert(forwarded==1)
end)
test("stats only changes are irrelevant to item level heuristic",function()
    local R,s,add,equip,rows,_,N=setup();equip(1,add(1,"INVTYPE_HEAD",20));R:Quest({add(2,"INVTYPE_HEAD",25)},s)
    N.Character={EquipmentMetadata=function()error("irrelevant stats changed central revisions")end};rows[1].stats={intellect=100}
    assert(not R:InvalidateItem(1,s,true))
end)
test("ready candidate metadata changes without visual identity can recover",function()
    local R,s,add,_,rows=setup();local item=add(1,"INVTYPE_HEAD",nil);assert(R:Quest({item},s).gain==nil)
    rows[1].level=25;assert(R:InvalidateItem(1,s,true));assert(R:Quest({item},s).gain==25)
end)
test("old item response cannot restore replaced gear",function()
    local R,s,add,equip=setup();local item=add(3,"INVTYPE_HEAD",25);equip(1,add(1,"INVTYPE_HEAD",20));assert(R:Quest({item},s).gain==5)
    equip(1,add(2,"INVTYPE_HEAD",30));R:InvalidateItem(1,s,true);assert(R:Quest({item},s).gain==-5)
end)
test("evicted equipped row remains an invalidation dependency",function()
    local R,s,add,equip,rows=setup();R.limit=8;equip(1,add(1,"INVTYPE_HEAD",20));local item=add(2,"INVTYPE_HEAD",25);assert(R:Quest({item},s).gain==5)
    for id=10,50 do R:Item(add(id,"INVTYPE_HEAD",30),s)end;assert(R.byID[1]==nil and R:Interested(1))
    rows[1].level=35;assert(R:InvalidateItem(1,s,true));assert(R:Quest({item},s).gain==-10)
end)
test("hidden and unrelated callbacks perform zero native work",function()
    local R,s,add,_,rows,calls=setup();local item=add(1,"INVTYPE_HEAD",20);R:Quest({item},s);rows[1].level=25;local before=total(calls)
    for _=1,2000 do assert(not R:InvalidateItem(1,nil,false) and not R:InvalidateItem(500000,s,true))end
    assert(before==total(calls));assert(R:Quest({item},s).gain==25)
end)
test("six hundred reward working set is warm and previous context is discarded",function()
    local R,s,add,_,_,calls=setup();local items={}
    for id=1,600 do items[id]=add(id,"INVTYPE_HEAD",20);R:Quest({items[id]},s)end
    local before=total(calls);for _,item in ipairs(items)do R:Quest({item},s)end;assert(total(calls)==before and #R.order==600)
    s.level=31;s.identityRevision=2;R:Quest({items[1]},s);assert(#R.order==1 and #R.useOrder==1)
end)
test("cache bound covers current catalog plus current gear and evicts overflow",function()
    local R,s,add=setup();local N={};loadfile(ROOT.."/FindAnUpgrade/Data/Catalog.lua")("FindAnUpgrade",N)
    local ids={};for _,q in ipairs(N.CatalogData.quests)do for _,item in ipairs(q.items or {})do ids[item.itemID]=true end end
    local count=0;for _ in pairs(ids)do count=count+1 end;assert(count>0 and count+19<R.limit)
    R.limit=8;for id=1,50 do R:Item(add(id,"INVTYPE_HEAD",20),s)end
    count=0;for _ in pairs(R.cache)do count=count+1 end;assert(count==8 and #R.order==8 and not R:Interested(1))
end)
test("pure comparator and warm native query have no repeated reads or requests",function()
    local R,s,add,_,_,calls=setup();local item=add(1,"INVTYPE_HEAD",20);R:Quest({item},s);local before=total(calls)
    local g=gear();for _=1,1000 do assert(R:Quest({item},s).gain==20 and R.Compare(normal(1,"INVTYPE_HEAD",20),g,s).gain==20)end
    assert(before==total(calls) and calls.requests==0 and R.events==nil)
end)
test("malformed options and unavailable context fail safely",function()
    local R,s,add=setup();local item=add(1,"INVTYPE_HEAD",20)
    assert(R:Quest({item,{}},s).gain==nil and R:Quest({[2]=item},s).gain==nil and R:Item(item,nil).state=="unsupported")
end)
test("unresolved character class or faction cannot become a rated opportunity",function()
    local R,s,add=setup();local item=add(1,"INVTYPE_HEAD",25)
    s.faction=nil;s.identityRevision=2;assert(R:Quest({item},s).gain==nil)
    s.faction="Alliance";s.classID=nil;s.identityRevision=3;assert(R:Quest({item},s).gain==nil)
    s.classID=8;s.identityRevision=4;assert(R:Quest({item},s).gain==25)
end)
test("retained shirt and tabard still expose uniqueness for whole outfit checks",function()
    local R,s,add,equip=setup();equip(4,add(1,"INVTYPE_BODY",0));equip(19,add(2,"INVTYPE_TABARD",0))
    assert(R:Quest({add(3,"INVTYPE_FINGER",25,{category=7,maximum=1})},s).gain==25)
end)
test("contradictory main hand identity never becomes a weapon comparison",function()
    local R,s=setup();local g=gear();g[16]=normal(1,"INVTYPE_HEAD",20)
    assert(R.Compare(normal(2,"INVTYPE_WEAPONMAINHAND",25),g,s).gain==nil)
end)
test("one query shares partial equipped metadata and the next query retries",function()
    local R,s,add,equip,rows,calls=setup();equip(1,add(1,"INVTYPE_HEAD",nil));local item=add(2,"INVTYPE_HEAD",25);local query={}
    for _=1,250 do assert(R:Quest({item},s,"ALL",query).gain==nil) end
    assert(calls.info==2)
    rows[1].level=20;assert(R:Quest({item},s,"ALL",{}).gain==5 and calls.info==3)
    for _=1,250 do assert(R:Quest({item},s,"ALL",{}).gain==5) end;assert(calls.info==3)
end)

test("one query shares partial reward metadata without suppressing later recovery",function()
    local R,s,add,_,rows,calls=setup();local item=add(1,"INVTYPE_HEAD",nil);local query={}
    for _=1,250 do assert(R:Quest({item},s,"ALL",query).gain==nil) end
    assert(calls.info==1);rows[1].level=25
    assert(R:Quest({item},s,"ALL",{}).gain==25 and calls.info==2)
end)

test("unknown usability retries once per query and ready booleans stay warm",function()
    for _,cold in ipairs({true,false}) do
        local R,s,add,_,rows,calls=setup();add(1,"INVTYPE_HEAD",25,{cached=not cold,useMissing=not cold});local query={}
        for _=1,250 do assert(R:Usable(1,s,query)==nil) end
        assert(calls.cache==1 and calls.use==(cold and 0 or 1))
        rows[1].cached,rows[1].useMissing=true,false
        assert(R:Usable(1,s,query)==nil and R:Usable(1,s,{})==true)
        local before=total(calls);for _=1,250 do assert(R:Usable(1,s,{})==true) end;assert(total(calls)==before)
    end
end)

test("query reuse cannot override equipment item or dirty revisions",function()
    for _,revision in ipairs({"equipmentRevision","itemRevision"}) do
        local R,s,add,equip,rows,calls=setup();equip(1,add(1,"INVTYPE_HEAD",nil));local item=add(2,"INVTYPE_HEAD",25);local query={}
        assert(R:Quest({item},s,"ALL",query).gain==nil);rows[1].level=20;s[revision]=s[revision]+1
        assert(R:Quest({item},s,"ALL",query).gain==5 and calls.info==3)
    end
    local R,s,add,_,rows=setup();local item=add(1,"INVTYPE_HEAD",nil);local query={}
    assert(R:Quest({item},s,"ALL",query).gain==nil);rows[1].level=25
    assert(R:InvalidateItem(1,s,true) and R:Quest({item},s,"ALL",query).gain==25)
end)

test("temporarily unavailable equipment uniqueness retries on a later query",function()
    local R,s,add,equip,rows,calls=setup();equip(11,add(1,"INVTYPE_FINGER",20,{uniqueMissing=true}));local item=add(2,"INVTYPE_FINGER",25,{category=7,maximum=1});local query={}
    for _=1,250 do assert(R:Quest({item},s,"ALL",query).gain==nil) end
    assert(calls.info==2);rows[1].uniqueMissing=false
    assert(R:Quest({item},s,"ALL",{}).gain==25 and calls.info==3)
end)
PASSED=passed

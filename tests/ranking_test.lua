local PASSES=0
local function test(name,fn)local ok,why=pcall(fn);if not ok then error(name..": "..tostring(why)) end;PASSES=PASSES+1 end
local function setup(token)
    local N={};local records,calls={},{info=0,stats=0,tooltip=0,use=0,requests=0}
    issecretvalue=function(v)return type(v)=="table" and v.secret==true end
    loadfile(ROOT.."/FindAnUpgrade/Model.lua")("FindAnUpgrade",N)
    loadfile(ROOT.."/FindAnUpgrade/Adapter.lua")("FindAnUpgrade",N)
    Enum={TooltipDataLineType={None=0,Blank=1,ItemBinding=20,EquipSlot=21,ItemName=22,Separator=23,
        ItemLevel=31,ItemQuality=35,FlavorText=37,TradeTimeRemaining=36,UsageRequirement=43,SellPrice=11,
        ItemSpellTriggerOnUse=44,ItemSpellTriggerOnEquip=45,ItemSpellTriggerOnProc=46}}
    ITEM_RANDOM_ENCHANT="Random enchantment"
    C_Item={IsItemDataCachedByID=function(id)return records[id] and records[id].cached~=false or false end,
        GetItemInfo=function(link)
            calls.info=calls.info+1;local id=tonumber(link:match("item:(%d+)"));local row=records[id]
            if not row then return end
            return "Item "..id,link,2,row.itemLevel or 20,row.minimum or 0,"Armor","Cloth",1,row.slot,100,0,row.classID or 4,row.subclassID or 1,1,0,row.setID
        end,
        GetItemStats=function(link)calls.stats=calls.stats+1;local row=records[tonumber(link:match("item:(%d+)"))];return row and row.stats end,
        GetItemUniqueness=function(link)local row=records[tonumber(link:match("item:(%d+)"))];if row.uniqueMissing then return end;return row.category or 0,row.maximum or 0 end,
        GetItemUniquenessByID=function(link)local row=records[tonumber(link:match("item:(%d+)"))];if row.uniqueMissing then return end;return row.single or false,nil,row.category and row.maximum or nil,row.category end,
        RequestLoadItemDataByID=function()calls.requests=calls.requests+1;error("ranking requested item data") end}
    C_PlayerInfo={CanUseItem=function(id)calls.use=calls.use+1;return records[id] and records[id].usable~=false end}
    C_TooltipInfo={GetHyperlink=function(link)
        calls.tooltip=calls.tooltip+1;local row=records[tonumber(link:match("item:(%d+)"))]
        if row.tooltipMissing then return end
        return {lines=row.lines or {{type=22,leftText="Item"},{type=0,leftText="Stats"}}}
    end}
    GameTooltip={SetHyperlink=function()error("ranking changed native hover") end}
    loadfile(ROOT.."/FindAnUpgrade/Ranking.lua")("FindAnUpgrade",N)
    local snapshot={guid="Player-1-1",classToken=token or "MAGE",classID=8,level=20,talentGroup=1,
        equipmentRevision=1,identityRevision=1,itemRevision=0,equipment={},emptySlots={}}
    for slot=1,19 do snapshot.equipment[slot]={state="empty"};snapshot.emptySlots[slot]=true end
    local function add(id,slot,stats,extra)
        local row={slot=slot,stats=stats};for k,v in pairs(extra or {})do row[k]=v end;records[id]=row
        return {itemID=id,link="item:"..id..":0:0:0:0:0:0",slot=slot,state="ready",quantity=1,group="choice"}
    end
    local function equip(slot,item)
        snapshot.equipment[slot]={itemID=item.itemID,link=item.link,state="ready"};snapshot.emptySlots[slot]=nil
        snapshot.equipmentRevision=snapshot.equipmentRevision+1
    end
    return N.Ranking,snapshot,add,equip,records,calls,N
end
local function plain(id,slot,stats,extra)
    local row={itemID=id,slot=slot,state="ready",stats=stats,usable=true,unique={category=0,maximum=0,single=false}}
    for k,v in pairs(extra or {})do row[k]=v end;return row
end
local function gear()local g={};for i=1,19 do g[i]={state="empty"}end;return g end
local function style(R,s,id)local selected=R:Style(s,{[s.guid..":"..s.talentGroup]=id or "CASTER"});return selected end

test("actual entry compares stats rather than item level",function()
    local R,s,add,equip=setup();equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10},{itemLevel=80}))
    local item=add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=12},{itemLevel=10})
    local rank=R:Quest({item},s,style(R,s));assert(rank.state=="ready" and rank.tier==1 and rank.gain==2)
end)
test("higher item level with worse weighted stats is not an upgrade",function()
    local R,s,add,equip=setup();equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10}))
    local rank=R:Quest({add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=9},{itemLevel=90})},s,style(R,s))
    assert(rank.gain==-1 and rank.tier==3)
end)
test("automatic roles are limited and hybrid selection follows group",function()
    local R,s=setup("DRUID");assert(R:Style(s,{})==nil)
    local selected,key=R:Style(s,{[s.guid..":1"]="HEALER"});assert(selected.id=="HEALER" and key==s.guid..":1")
    s.talentGroup=2;assert(R:Style(s,{[s.guid..":1"]="HEALER"})==nil)
    s.classToken="MAGE";assert(R:Style(s,{}).id=="CASTER")
end)
test("cross class and invalid saved styles cannot select arbitrary scales",function()
    local R,s=setup();assert(#R:Styles(s)==1)
    assert(R:Style(s,{[s.guid..":1"]="TANK"})==nil)
    assert(R:Style(s,{[s.guid..":1"]="made-up"})==nil)
end)
test("stat presets make healing and spell intent explicit",function()
    local R,s,add,equip=setup("PRIEST");equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5}))
    local item=add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=1,ITEM_MOD_SPELL_HEALING_DONE_SHORT=10})
    local caster=R:Quest({item},s,style(R,s,"CASTER"));local healer=R:Quest({item},s,style(R,s,"HEALER"))
    assert(caster.gain==-4 and healer.gain>0)
end)
test("empty requires snapshot proof and never creates an infinite percentage",function()
    local R,s,add=setup();local item=add(2,"INVTYPE_NECK",{ITEM_MOD_INTELLECT_SHORT=1})
    local rank=R:Quest({item},s,style(R,s));assert(rank.gain==1 and rank.percent==nil)
    s.emptySlots[2]=nil;s.equipment[2]={state="pending"};s.equipmentRevision=2
    assert(R:Quest({item},s,style(R,s)).tier==2)
end)
test("native occupied uncached equipment never becomes zero",function()
    local R,s,add,equip,records=setup();equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=20},{cached=false}))
    local candidate=add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=1})
    assert(R:Quest({candidate},s,style(R,s)).gain==nil)
    records[1].cached=true;R:InvalidateItem(1)
    assert(R:Quest({candidate},s,style(R,s)).gain==-19)
end)
test("rings compare both slots and replace the weaker legal one",function()
    local R,s,add,equip=setup();equip(11,add(1,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=10}));equip(12,add(2,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=3}))
    assert(R:Quest({add(3,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=8})},s,style(R,s)).gain==5)
end)
test("unknown ring partner prevents a definitive best replacement",function()
    local R,s,add,equip=setup();equip(11,add(1,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=10},{cached=false}));equip(12,add(2,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=3}))
    assert(R:Quest({add(3,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=8})},s,style(R,s)).tier==2)
end)
test("native unique category forces replacement of the stronger same category ring",function()
    local R,s,add,equip=setup();equip(11,add(1,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=10},{category=7,maximum=1}));equip(12,add(2,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=3}))
    local rank=R:Quest({add(3,"INVTYPE_FINGER",{ITEM_MOD_INTELLECT_SHORT=8},{category=7,maximum=1})},s,style(R,s))
    assert(rank.gain==-2)
end)
test("uniqueness checks retained gear outside the paired slots",function()
    local R,s=setup();local g=gear();g[1]=plain(1,"INVTYPE_HEAD",{intellect=1},{unique={category=7,maximum=1,single=false}})
    local item=plain(2,"INVTYPE_FINGER",{intellect=8},{unique={category=7,maximum=1,single=false}})
    assert(R.Compare(item,g,style(R,s),s).gain==nil)
end)
test("same unique item cannot remain in the other ring slot",function()
    local R,s=setup();local g=gear();g[11]=plain(2,"INVTYPE_FINGER",{intellect=10});g[12]=plain(3,"INVTYPE_FINGER",{intellect=3})
    local item=plain(2,"INVTYPE_FINGER",{intellect=8},{unique={category=0,maximum=0,single=true}})
    assert(R.Compare(item,g,style(R,s),s).gain==-2)
end)
test("unknown uniqueness is never unrestricted equipment",function()
    local R,s,add=setup();assert(R:Quest({add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=1},{uniqueMissing=true})},s,style(R,s)).gain==nil)
end)
test("two hand gain removes both main and offhand",function()
    local R,s=setup("WARRIOR");local g=gear();g[16]=plain(1,"INVTYPE_WEAPONMAINHAND",{weaponDps=10},{damageKnown=true});g[17]=plain(2,"INVTYPE_SHIELD",{stamina=20})
    local candidate=plain(3,"INVTYPE_2HWEAPON",{weaponDps=11},{damageKnown=true})
    assert(R.Compare(candidate,g,style(R,s,"MELEE"),s).gain==-1)
end)
test("one hand from two hand cannot invent a companion item",function()
    local R,s=setup("WARRIOR");local g=gear();g[16]=plain(1,"INVTYPE_2HWEAPON",{weaponDps=20},{damageKnown=true})
    local candidate=plain(3,"INVTYPE_WEAPONMAINHAND",{weaponDps=10},{damageKnown=true})
    assert(R.Compare(candidate,g,style(R,s,"MELEE"),s).gain==-40)
end)
test("offhand cannot pair with equipped two hand",function()
    local R,s=setup();local g=gear();g[16]=plain(1,"INVTYPE_2HWEAPON",{intellect=20},{damageKnown=true})
    assert(R.Compare(plain(2,"INVTYPE_HOLDABLE",{intellect=5}),g,style(R,s),s).gain==nil)
end)
test("dual wield needs proof and uses offhand weight",function()
    local R,s=setup("ROGUE");local g=gear();g[16]=plain(1,"INVTYPE_WEAPONMAINHAND",{weaponDps=10},{damageKnown=true})
    local candidate=plain(2,"INVTYPE_WEAPON",{weaponDps=11},{damageKnown=true})
    assert(R.Compare(candidate,g,style(R,s,"MELEE"),s).gain==nil)
    s.capabilities={dualWield=true};assert(R.Compare(candidate,g,style(R,s,"MELEE"),s).gain==22)
end)
test("weapon attributes cannot hide missing weapon damage",function()
    local R,s,add=setup("WARRIOR");local item=add(2,"INVTYPE_2HWEAPON",{ITEM_MOD_STRENGTH_SHORT=30})
    local rank=R:Quest({item},s,style(R,s,"MELEE"));assert(rank.gain==nil and rank.reason=="weapon-damage-unknown")
end)
test("ranged comparison uses Forever ranged slot18",function()
    local R,s=setup("HUNTER");local g=gear();g[18]=plain(1,"INVTYPE_RANGED",{rangedDps=10},{damageKnown=true})
    assert(R.Compare(plain(2,"INVTYPE_RANGED",{rangedDps=11},{damageKnown=true}),g,style(R,s,"RANGED"),s).gain==4)
end)
test("shield style does not rate abandoning its shield",function()
    local R,s=setup("PALADIN");assert(R.Compare(plain(2,"INVTYPE_2HWEAPON",{weaponDps=50},{damageKnown=true}),gear(),style(R,s,"TANK"),s).gain==nil)
end)
test("unsupported effects sets and sockets cannot become plain stats",function()
    local R,s,add=setup()
    for i,extra in ipairs({{setID=99},{lines={{type=22},{type=44}}},{lines={{type=22},{type=45}}},{lines={{type=22},{type=46}}},{lines={{type=22},{type=3}}}})do
        assert(R:Quest({add(10+i,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=100},extra)},s,style(R,s)).gain==nil)
    end
end)
test("unsupported replaced effect invalidates apparent gain but unrelated proc does not",function()
    local R,s,add,equip=setup();equip(13,add(1,"INVTYPE_TRINKET",{ITEM_MOD_INTELLECT_SHORT=1},{lines={{type=22},{type=46}}}))
    local candidate=add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});assert(R:Quest({candidate},s,style(R,s)).gain==5)
    equip(1,add(3,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=1},{setID=99}));assert(R:Quest({candidate},s,style(R,s)).gain==nil)
end)
test("unknown nonzero stats and conflicting aliases fail safely",function()
    local R=setup();assert(R.Normalize({FUTURE_STAT=1})==nil);assert(R.Normalize({ITEM_MOD_INTELLECT_SHORT=0/0})==nil)
    assert(R.Normalize({ITEM_MOD_SPELL_POWER_SHORT=5,ITEM_MOD_SPELL_DAMAGE_DONE_SHORT=6})==nil)
    local stats=R.Normalize({ITEM_MOD_SPELL_POWER_SHORT=5,ITEM_MOD_SPELL_DAMAGE_DONE_SHORT=5});assert(stats.spellPower==5)
end)
test("restricted values missing stats and absent tooltip are unknown",function()
    local R,s,add=setup()
    local variants={{ITEM_MOD_INTELLECT_SHORT={secret=true}},{}}
    for i,v in ipairs(variants)do assert(R:Quest({add(i,"INVTYPE_HEAD",v)},s,style(R,s)).gain==nil)end
    assert(R:Quest({add(5,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10},{tooltipMissing=true})},s,style(R,s)).gain==nil)
end)
test("unknown reward variant cannot use the cached best random enchantment",function()
    local R,s,add=setup();local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=20},{lines={{type=22},{type=0,leftText="Random enchantment"}}})
    assert(R:Quest({item},s,style(R,s)).gain==nil)
end)
test("choice quantities and guaranteed duplicates are not summed",function()
    local R,s,add=setup();local first=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});first.quantity=10;first.group="guaranteed"
    local copy={};for k,v in pairs(first)do copy[k]=v end;copy.group="choice"
    local other=add(2,"INVTYPE_FEET",{ITEM_MOD_INTELLECT_SHORT=7});assert(R:Quest({first,copy,other},s,style(R,s)).gain==7)
end)
test("one unknown equipment choice prevents a misleading best reward claim",function()
    local R,s,add=setup();local good=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});local missing=add(2,"INVTYPE_FEET",{ITEM_MOD_INTELLECT_SHORT=7},{cached=false})
    assert(R:Quest({good,missing},s,style(R,s)).tier==2)
end)
test("nongear choices and impossible level items do not gain score",function()
    local R,s,add=setup();local good=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});local junk=add(2,"",{})
    assert(R:Quest({good,junk},s,style(R,s)).gain==5)
    assert(R:Quest({add(3,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=50},{minimum=40})},s,style(R,s)).tier==2)
end)
test("exact hyperlink variants and explicit invalidation prevent stale stats",function()
    local R,s,add,_,records=setup();local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5})
    assert(R:Quest({item},s,style(R,s)).gain==5)
    records[1].stats={ITEM_MOD_INTELLECT_SHORT=8};R:InvalidateItem(1)
    assert(R:Quest({item},s,style(R,s)).gain==8)
    local second={itemID=1,link="item:1:0:0:0:0:0:77"};assert(R:Item(second,s).link==second.link)
end)
test("equipment revision changes baseline and old response cannot restore it",function()
    local R,s,add,equip=setup();local candidate=add(3,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=8});equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5}))
    assert(R:Quest({candidate},s,style(R,s)).gain==3);equip(1,add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10}));R:InvalidateItem(1)
    assert(R:Quest({candidate},s,style(R,s)).gain==-2)
end)
test("bounded caches no requests no idle handlers and pure comparator has no native reads",function()
    local R,s,add,_,_,calls=setup();R.limit=8
    for id=1,50 do R:Item(add(id,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=id}),s)end
    local count=0;for _ in pairs(R.cache)do count=count+1 end;assert(count==8 and #R.order==8 and calls.requests==0)
    local before=calls.info+calls.stats+calls.tooltip+calls.use
    local g=gear();local preset=style(R,s)
    for _=1,1000 do assert(R.Compare(plain(1,"INVTYPE_HEAD",{intellect=5}),g,preset,s).gain==5)end
    assert(before==calls.info+calls.stats+calls.tooltip+calls.use and R.events==nil)
end)
test("deterministic equal best choice uses exact item identity",function()
    local R,s,add=setup();local a=add(10,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});local b=add(5,"INVTYPE_FEET",{ITEM_MOD_INTELLECT_SHORT=5})
    assert(R:Quest({a,b},s,style(R,s)).itemID==5 and R:Quest({b,a},s,style(R,s)).itemID==5)
end)
test("slot filter cannot borrow a larger unrelated reward score",function()
    local R,s,add=setup();local head=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});local neck=add(2,"INVTYPE_NECK",{ITEM_MOD_INTELLECT_SHORT=50})
    assert(R:Quest({head,neck},s,style(R,s),"INVTYPE_HEAD").gain==5)
end)
test("capability revision refreshes character usability without an item identity change",function()
    local R,s,add,_,records=setup();local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5},{usable=false})
    assert(R:Quest({item},s,style(R,s)).gain==nil)
    records[1].usable=true;s.capabilityRevision=1
    assert(R:Quest({item},s,style(R,s)).gain==5)
end)
test("warm repeated whole queries do not rescan native items",function()
    local R,s,add,_,_,calls=setup();local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});local preset=style(R,s)
    R:Quest({item},s,preset);local before=calls.info+calls.stats+calls.tooltip+calls.use
    for _=1,1000 do assert(R:Quest({item},s,preset).gain==5)end
    assert(before==calls.info+calls.stats+calls.tooltip+calls.use)
end)
test("malformed option arrays and missing identity cannot silently drop uncertainty",function()
    local R,s,add=setup();local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5})
    assert(R:Quest({item,{}},s,style(R,s)).gain==nil)
    assert(R:Quest({[2]=item},s,style(R,s)).gain==nil)
    assert(R:Item(item,nil).state=="unsupported")
end)
test("shield tank cannot trade its shield for a held item or offhand weapon",function()
    local R,s,add,equip=setup("PALADIN");equip(16,add(1,"INVTYPE_WEAPONMAINHAND",{ITEM_MOD_STRENGTH_SHORT=2}))
    equip(17,add(2,"INVTYPE_SHIELD",{ITEM_MOD_STAMINA_SHORT=3}))
    assert(R:Quest({add(3,"INVTYPE_HOLDABLE",{ITEM_MOD_STAMINA_SHORT=40})},s,style(R,s,"TANK")).gain==nil)
    local g=gear();g[16]=plain(4,"INVTYPE_WEAPONMAINHAND",{weaponDps=1},{damageKnown=true});g[17]=plain(5,"INVTYPE_SHIELD",{stamina=3})
    s.capabilities={dualWield=true};assert(R.Compare(plain(6,"INVTYPE_WEAPONOFFHAND",{stamina=40,weaponDps=1},{damageKnown=true}),g,style(R,s,"TANK"),s).gain==nil)
end)
test("six hundred cached rewards are warm and old contexts are dropped",function()
    local R,s,add,_,_,calls=setup();local list={}
    for id=1,600 do list[id]=add(id,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=id});R:Quest({list[id]},s,style(R,s))end
    local before=calls.info+calls.stats+calls.tooltip+calls.use
    for _,item in ipairs(list)do R:Quest({item},s,style(R,s))end
    assert(before==calls.info+calls.stats+calls.tooltip+calls.use and #R.order==600)
    s.level=21;s.identityRevision=2;R:Quest({list[1]},s,style(R,s));assert(#R.order==1 and #R.usabilityOrder==1)
end)
test("cache accommodates the complete owned reward identity corpus and current gear",function()
    local R=setup();local N={};loadfile(ROOT.."/FindAnUpgrade/Data/Catalog.lua")("FindAnUpgrade",N)
    local ids={};for _,quest in ipairs(N.CatalogData.quests)do for _,item in ipairs(quest.items or {})do ids[item.itemID]=true end end
    local count=0;for _ in pairs(ids)do count=count+1 end
    assert(count>0 and count+19<R.limit)
end)
test("stats-only readiness changes once while equal callbacks do not invalidate",function()
    local R,s,add,_,records=setup();local item=add(1,"INVTYPE_HEAD",nil);local preset=style(R,s)
    assert(R:Quest({item},s,preset).state=="pending")
    records[1].stats={ITEM_MOD_INTELLECT_SHORT=5}
    assert(R:InvalidateItem(1,s,true)==true and R:Quest({item},s,preset).gain==5)
    for _=1,50 do assert(R:InvalidateItem(1,s,true)==false)end
end)
test("hidden callbacks and unrelated IDs perform no native reads",function()
    local R,s,add,_,records,calls=setup();local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});R:Quest({item},s,style(R,s))
    records[1].stats={ITEM_MOD_INTELLECT_SHORT=8};local before=calls.info+calls.stats+calls.tooltip+calls.use
    for _=1,1000 do assert(R:InvalidateItem(1,nil,false)==false and R:InvalidateItem(500000,s,true)==false)end
    assert(before==calls.info+calls.stats+calls.tooltip+calls.use and R:Interested(1) and not R:Interested(500000))
    assert(R:Quest({item},s,style(R,s)).gain==8)
end)
test("evicted equipped metadata remains a live invalidation dependency",function()
    local R,s,add,equip,records=setup();R.limit=8;equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5}))
    local candidate=add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10});assert(R:Quest({candidate},s,style(R,s)).gain==5)
    for id=10,50 do R:Item(add(id,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=id}),s)end
    assert(R.byID[1]==nil and R:Interested(1));records[1].stats={ITEM_MOD_INTELLECT_SHORT=20}
    assert(R:InvalidateItem(1,s,true)==true and R:Quest({candidate},s,style(R,s)).gain==-10)
end)
test("usability-only filters share a bounded native memo and event recovery",function()
    local R,s,add,_,records,calls=setup();add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5},{usable=false})
    assert(R:Usable(1,s)==false and R:Interested(1));local before=calls.use
    for _=1,1000 do assert(R:Usable(1,s)==false)end;assert(calls.use==before)
    assert(R:InvalidateItem(1,s,true)==false);records[1].usable=true
    assert(R:InvalidateItem(1,s,true)==true and R:Usable(1,s)==true)
    records[1].usable=false;s.equipmentRevision=s.equipmentRevision+1;assert(R:Usable(1,s)==false)
end)
test("generic nonzero suffix cannot borrow the equipped exact variant",function()
    local R,s,add,equip=setup();local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5});item.link="item:1:0:0:0:0:0:77";equip(1,item)
    assert(R:Item(item,s,true).state=="ready")
    assert(R:Item(item,s).reason=="reward-variant-unconfirmed")
end)
test("cosmetic sell price and hidden vendor-price argument preserve plain comparison",function()
    local R,s,add=setup();local original=C_TooltipInfo.GetHyperlink
    C_TooltipInfo.GetHyperlink=function(link,a,b,hide)assert(a==nil and b==nil and hide==true);return original(link)end
    local item=add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5},{lines={{type=22},{type=0},{type=11,leftText="Sell price"}}})
    assert(R:Quest({item},s,style(R,s)).gain==5)
end)
test("changed equipped stats flow through the guarded central metadata bridge once",function()
    local R,s,add,equip,records,_,N=setup();local candidate=add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10})
    equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5}));R:Quest({candidate},s,style(R,s))
    local delivered=0;local received
    N.Character={EquipmentMetadata=function(_,id,stamp,revision)
        assert(id==1 and revision==s.equipmentRevision and #stamp<8192 and stamp:find("intellect=20",1,true))
        delivered=delivered+1;received=stamp;return true
    end}
    records[1].stats={ITEM_MOD_INTELLECT_SHORT=20}
    local changed,forwarded=R:InvalidateItem(1,s,true)
    assert(changed and forwarded and delivered==1 and received)
    for _=1,10 do changed,forwarded=R:InvalidateItem(1,s,true);assert(not changed and not forwarded)end
    assert(delivered==1)
    records[2].stats={ITEM_MOD_INTELLECT_SHORT=30};changed,forwarded=R:InvalidateItem(2,s,true)
    assert(changed and not forwarded and delivered==1)
end)
test("pending gear tooltip retries only on a real later query without an item event",function()
    local R,s,add,equip,records,calls=setup();equip(1,add(1,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=5},{tooltipMissing=true}))
    local candidate=add(2,"INVTYPE_HEAD",{ITEM_MOD_INTELLECT_SHORT=10});assert(R:Quest({candidate},s,style(R,s)).gain==nil)
    local before=calls.tooltip;records[1].tooltipMissing=false
    assert(R:Quest({candidate},s,style(R,s)).gain==5 and calls.tooltip==before+1)
end)
PASSED=PASSES

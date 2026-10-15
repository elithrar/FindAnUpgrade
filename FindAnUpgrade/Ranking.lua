local _,N=...
local M,A=N.Model,N.Adapter
-- 2,623 distinct catalog reward IDs + current gear fit within one context.
-- Never retain a prior player/level/capability context behind this bound.
local R={version=1,limit=4096,cache={},order={},dirty={},byID={}};N.Ranking=R
-- Original leveling preferences, in estimated stat points. These are neither
-- simulations nor imported Retail/Classic conversion factors. No item-level term.
local choices={WARRIOR={"MELEE","TANK"},PALADIN={"MELEE","HEALER","TANK"},HUNTER={"RANGED","MELEE"},
    ROGUE={"MELEE"},PRIEST={"CASTER","HEALER"},SHAMAN={"MELEE","CASTER","HEALER","TANK"},
    MAGE={"CASTER"},WARLOCK={"CASTER"},DRUID={"CASTER","MELEE","HEALER","BEAR"}}
local labels={MELEE="Melee damage",RANGED="Ranged damage",CASTER="Spell damage",HEALER="Healing",TANK="Shield tank",BEAR="Bear tank"}
local automatic={ROGUE="MELEE",MAGE="CASTER",WARLOCK="CASTER"}
local function tableValue(v)return M.Readable(v) and type(v)=="table" end
local function text(v)return M.Readable(v) and type(v)=="string" and v~="" and v or nil end
local function integer(v)return M.Number(v) and v>=0 and v==math.floor(v) and v or nil end
local function sequence(v,maximum)
    if not tableValue(v) or #v>maximum then return false end
    local count=0
    for key in pairs(v) do
        if not M.Number(key) or key<1 or key>#v or key~=math.floor(key) then return false end
        count=count+1;if count>maximum then return false end
    end
    return count==#v
end
local function returns(fn,...)
    if type(fn)~="function" then return end
    local function pack(...)return {n=select("#",...),...} end
    local result=pack(pcall(fn,...));if result[1] then return unpack(result,2,result.n) end
end
local function result(state,reason,gain,itemID)
    return {state=state,reason=reason,gain=gain,itemID=itemID,estimated=true,
        tier=state=="ready" and (gain>0 and 1 or 3) or 2}
end
local function contextKey(snapshot)
    return tostring((M.QuestId(snapshot.level)))..":"..(integer(snapshot.identityRevision) or 0)
        ..":"..(integer(snapshot.capabilityRevision) or 0)..":"..(text(snapshot.guid) or "")
end
local function cacheKey(link,snapshot,equipped)
    return link.."\031"..contextKey(snapshot)..(equipped and "\031equipment" or "\031reward")
end
function R:UseContext(snapshot)
    local key=contextKey(snapshot)
    if self.contextKey~=key then
        self.contextKey=key;self.cache,self.order,self.dirty,self.byID={},{},{},{}
        self.gearKey,self.gear,self.gearByID=nil,nil,nil
        self.usabilityKey,self.usability,self.usabilityOrder,self.usabilityDirty=nil,{}, {},{}
    end
end
function R:Usable(id,snapshot)
    id=M.QuestId(id);if not id or not tableValue(snapshot) then return end
    self:UseContext(snapshot)
    local key=contextKey(snapshot)..":"..tostring(integer(snapshot.equipmentRevision))
    if self.usabilityKey~=key then
        self.usabilityKey=key;self.usability,self.usabilityOrder,self.usabilityDirty={},{},{}
    end
    local prior=self.usability[id]
    if prior and not self.usabilityDirty[id] then return prior.value end
    if not prior then
        if #self.usabilityOrder>=self.limit then local first=table.remove(self.usabilityOrder,1);self.usability[first],self.usabilityDirty[first]=nil,nil end
        self.usabilityOrder[#self.usabilityOrder+1]=id
    end
    local value
    if A.Call(C_Item and C_Item.IsItemDataCachedByID,id)==true then value=A.Call(C_PlayerInfo and C_PlayerInfo.CanUseItem,id) end
    if type(value)~="boolean" then value=nil end
    self.usability[id],self.usabilityDirty[id]={value=value},nil
    return value
end
local function weights(id,token)
    local w={strength=0,agility=0,stamina=.25,intellect=0,spirit=0,armor=.002,attackPower=0,rangedAttackPower=0,
        spellPower=0,healing=0,manaRegen=0,defense=0,block=0,weaponDps=0,offhandDps=0,rangedDps=0}
    if id=="MELEE" or id=="RANGED" then
        local agile=token=="ROGUE" or token=="HUNTER" or token=="DRUID"
        w.strength,w.agility=agile and .4 or 1,agile and 1 or .5
        w.attackPower=.45;w.rangedAttackPower=id=="RANGED" and .45 or 0
        w.weaponDps=id=="MELEE" and 4 or 0;w.offhandDps=id=="MELEE" and 2 or 0;w.rangedDps=id=="RANGED" and 4 or 0
    elseif id=="CASTER" then w.intellect,w.spirit,w.spellPower=1,.2,1.2
    elseif id=="HEALER" then w.intellect,w.spirit,w.healing,w.spellPower,w.manaRegen=.8,.8,1,.6,4
    elseif id=="TANK" then
        w.stamina,w.strength,w.agility,w.armor,w.defense,w.block=1,.45,.35,.025,.8,.3
        w.weaponDps,w.offhandDps=1,0
    elseif id=="BEAR" then w.stamina,w.agility,w.strength,w.armor,w.defense=1,.6,.35,.03,.5 end
    return w
end
function R:Styles(snapshot)
    local out={};local token=tableValue(snapshot) and text(snapshot.classToken)
    for _,id in ipairs(choices[token] or {}) do out[#out+1]={id=id,label=labels[id]} end
    return out
end
function R:Style(snapshot,saved)
    if not tableValue(snapshot) then return end
    local token,guid,group=text(snapshot.classToken),text(snapshot.guid),M.QuestId(snapshot.talentGroup)
    local key=guid and group and guid..":"..group or nil
    local id=key and tableValue(saved) and text(saved[key]) or nil
    if not id then id=automatic[token] end
    for _,allowed in ipairs(choices[token] or {}) do
        if allowed==id then return {id=id,label=labels[id],classToken=token,weights=weights(id,token),requiresShield=id=="TANK"},key end
    end
    return nil,key
end

-- Only explicitly recognized base-stat keys are normalized. Unknown nonzero
-- keys, effects and aliases with conflicting values cannot silently become zero.
local statKeys={ITEM_MOD_STRENGTH_SHORT="strength",ITEM_MOD_AGILITY_SHORT="agility",ITEM_MOD_STAMINA_SHORT="stamina",
    ITEM_MOD_INTELLECT_SHORT="intellect",ITEM_MOD_SPIRIT_SHORT="spirit",RESISTANCE0_NAME="armor",
    ITEM_MOD_ATTACK_POWER_SHORT="attackPower",ITEM_MOD_RANGED_ATTACK_POWER_SHORT="rangedAttackPower",
    ITEM_MOD_SPELL_POWER_SHORT="spellPower",ITEM_MOD_SPELL_DAMAGE_DONE_SHORT="spellPower",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT="healing",ITEM_MOD_MANA_REGENERATION_SHORT="manaRegen",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT="defense",ITEM_MOD_BLOCK_VALUE_SHORT="block"}
function R.Normalize(stats)
    if not tableValue(stats) then return nil,"stats-pending" end
    local out,count={},0
    for key,value in pairs(stats) do
        count=count+1;if count>64 or not text(key) or not M.Number(value) or math.abs(value)>1000000 then return nil,"stats-invalid" end
        local normalized=statKeys[key]
        if not normalized then if value~=0 then return nil,"unsupported-stat" end
        elseif out[normalized]~=nil and out[normalized]~=value then return nil,"stat-alias-conflict"
        else out[normalized]=value end
    end
    if count==0 then return nil,"stats-empty" end
    return out
end
local function effectCheck(link)
    local data=A.Call(C_TooltipInfo and C_TooltipInfo.GetHyperlink,link,nil,nil,true)
    if not tableValue(data) or not sequence(data.lines,128) or #data.lines<2 then return false,"tooltip-pending" end
    local types=Enum and Enum.TooltipDataLineType
    if not tableValue(types) then return false,"tooltip-contract" end
    local safe={None=true,Blank=true,ItemBinding=true,EquipSlot=true,ItemName=true,Separator=true,
        ItemLevel=true,ItemQuality=true,FlavorText=true,TradeTimeRemaining=true,UsageRequirement=true,SellPrice=true}
    local allowed={};for name in pairs(safe) do local value=types[name];if integer(value) then allowed[value]=true end end
    for _,line in ipairs(data.lines) do
        if not tableValue(line) or integer(line.type)==nil or not allowed[line.type] then return false,"unsupported-effect" end
        for _,field in ipairs({"leftText","rightText"}) do
            local value=line[field]
            if not M.Readable(value) then return false,"restricted-tooltip" end
            if type(value)=="string" then
                for _,global in ipairs({"ITEM_RANDOM_ENCHANT","ITEM_SPELL_TRIGGER_ONUSE","ITEM_SPELL_TRIGGER_ONEQUIP","ITEM_SPELL_TRIGGER_ONPROC"}) do
                    local prefix=text(_G[global]);if prefix and value:find(prefix,1,true) then return false,"unsupported-effect" end
                end
            end
        end
    end
    return true
end
local function uniqueness(link)
    local category,maximum=returns(C_Item and C_Item.GetItemUniqueness,link)
    local single,_,count,id=returns(C_Item and C_Item.GetItemUniquenessByID,link)
    if integer(category)==nil or integer(maximum)==nil or not M.Readable(single) or type(single)~="boolean"
        or not M.Readable(count) or not M.Readable(id) then return end
    if category>0 and maximum<1 or id~=nil and (integer(id)==nil or id~=category)
        or count~=nil and (integer(count)==nil or category>0 and count~=maximum) then return end
    return {category=category,maximum=maximum,single=single}
end
local function weapon(slot)
    return slot=="INVTYPE_WEAPON" or slot=="INVTYPE_WEAPONMAINHAND" or slot=="INVTYPE_WEAPONOFFHAND"
        or slot=="INVTYPE_2HWEAPON" or slot=="INVTYPE_RANGED" or slot=="INVTYPE_RANGEDRIGHT" or slot=="INVTYPE_THROWN"
end
function R:Remember(key,row)
    if not self.cache[key] then
        if #self.order>=self.limit then
            local first=table.remove(self.order,1);local old=self.cache[first]
            if old and self.byID[old.itemID] then self.byID[old.itemID][first]=nil;if not next(self.byID[old.itemID]) then self.byID[old.itemID]=nil end end
            self.cache[first],self.dirty[first]=nil,nil
        end
        self.order[#self.order+1]=key
    end
    self.byID[row.itemID]=self.byID[row.itemID] or {};self.byID[row.itemID][key]=true
    self.cache[key],self.dirty[key]=row,nil;return row
end
function R:Interested(id)
    return M.QuestId(id) and (self.byID[id]~=nil or self.gearByID and self.gearByID[id]~=nil or self.usability and self.usability[id]~=nil) or false
end
local function sameItem(a,b)
    for _,key in ipairs({"itemID","link","state","reason","slot","minimum","classID","subclassID","usable"}) do
        if a[key]~=b[key] then return false end
    end
    for _,key in ipairs({"unique","stats"}) do
        local first,second=a[key],b[key]
        if first~=second then
            if not tableValue(first) or not tableValue(second) then return false end
            for name,value in pairs(first) do if second[name]~=value then return false end end
            for name in pairs(second) do if first[name]==nil then return false end end
        end
    end
    return true
end
local function equipmentStamp(row)
    local parts={tostring(row.itemID),row.link,row.state,row.reason or "",row.slot or "",
        tostring(row.minimum),tostring(row.classID),tostring(row.subclassID),tostring(row.usable)}
    for _,name in ipairs({"unique","stats"}) do
        local keys={};for key in pairs(row[name] or {}) do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys) do parts[#parts+1]=name..":"..key.."="..tostring(row[name][key]) end
    end
    local stamp=table.concat(parts,"\031");if #stamp<=8192 then return stamp end
end
-- Item events are owned by the existing UI/character owners. Hidden delivery
-- marks retained observations dirty without reading APIs or scheduling work.
-- Visible delivery compares semantic data, so equal callbacks remain no-ops.
function R:InvalidateItem(id,snapshot,visible)
    id=M.QuestId(id);if not id then return false end
    if visible==true and tableValue(snapshot) then self:UseContext(snapshot) end
    local keys=self.byID[id] or {};local current,seen={},{}
    local relevant=self.gearByID and self.gearByID[id]~=nil or self.usability and self.usability[id]~=nil or false
    for key in pairs(keys) do
        local row=self.cache[key]
        if row and row.itemID==id then
            self.dirty[key]=true;relevant=true
            if visible==true and tableValue(snapshot) and key==cacheKey(row.link,snapshot,row.equipped) then current[#current+1]=row;seen[key]=true end
        end
    end
    -- The coherent gear view owns at most19 retained records independently of
    -- FIFO item admission. An evicted equipped record is still a dependency.
    for _,row in pairs(self.gear or {}) do
        if row.itemID==id and text(row.link) then
            relevant=true
            if visible==true and tableValue(snapshot) then
                local key=cacheKey(row.link,snapshot,true)
                if not seen[key] then self.dirty[key]=true;current[#current+1]=row;seen[key]=true end
            end
        end
    end
    if not relevant then return false end
    local priorUse=self.usability and self.usability[id]
    if priorUse then self.usabilityDirty[id]=true end
    if visible~=true or not tableValue(snapshot) then
        self.gearKey,self.gear,self.gearByID=nil,nil,nil;return false
    end
    local changed,forwarded=false,false
    if priorUse then local fresh=self:Usable(id,snapshot);changed=priorUse.value~=fresh end
    for _,prior in ipairs(current) do
        local fresh=self:Item({itemID=prior.itemID,link=prior.link},snapshot,prior.equipped)
        if not sameItem(prior,fresh) then
            changed=true
            if prior.equipped and N.Character and type(N.Character.EquipmentMetadata)=="function" then
                local stillCurrent=false
                for _,entry in pairs(snapshot.equipment or {}) do
                    if entry.itemID==id and entry.link==prior.link then stillCurrent=true;break end
                end
                local stamp=stillCurrent and equipmentStamp(fresh)
                if stamp and A.Call(N.Character.EquipmentMetadata,N.Character,id,stamp,snapshot.equipmentRevision)==true then forwarded=true end
            end
        end
    end
    if changed then self.gearKey,self.gear,self.gearByID=nil,nil,nil end
    return changed,forwarded
end
local function modifiedReward(link)
    local payload=link:match("item:([^|]+)")
    if not payload then return true end
    local fields={};for value in (payload..":"):gmatch("([^:]*):") do fields[#fields+1]=value end
    -- Native generic GetItemInfo(itemID) is not exact quest-suffix authority.
    -- Enchant/gems/suffix fields are retained for equipped gear, never borrowed
    -- as the reward's known roll or best variant.
    for i=2,7 do if fields[i] and fields[i]~="" and tonumber(fields[i])~=0 then return true end end
    return false
end
function R:Item(meta,snapshot,equipped)
    if not tableValue(snapshot) then return {state="unsupported",reason="context-invalid"} end
    local id=tableValue(meta) and M.QuestId(meta.itemID);local link=tableValue(meta) and text(meta.link)
    if not id or not link or #link>2048 or tonumber(link:match("item:(%d+)"))~=id then return {state="pending",reason="item-pending",itemID=id} end
    equipped=M.Readable(equipped) and equipped==true
    local level=tableValue(snapshot) and M.QuestId(snapshot.level)
    self:UseContext(snapshot)
    local key=cacheKey(link,snapshot,equipped)
    local cached=self.cache[key]
    if cached and not self.dirty[key] and cached.state~="pending" then
        if cached.usable==nil or cached.usable==self:Usable(id,snapshot) then return cached end
    end
    local row={itemID=id,link=link,state="pending",reason="item-pending",equipped=equipped==true}
    if not equipped and modifiedReward(link) then row.state,row.reason="unsupported","reward-variant-unconfirmed";return self:Remember(key,row) end
    if A.Call(C_Item and C_Item.IsItemDataCachedByID,id)~=true then return self:Remember(key,row) end
    local name,infoLink,_,_,minimum,_,_,_,slot,_,_,classID,subclassID,_,_,setID=returns(C_Item and C_Item.GetItemInfo,link)
    if not text(name) or not text(infoLink) or not M.Readable(slot) or type(slot)~="string" then return self:Remember(key,row) end
    if not equipped and modifiedReward(infoLink) then row.state,row.reason="unsupported","reward-variant-unconfirmed";return self:Remember(key,row) end
    row.slot,row.minimum,row.classID,row.subclassID=slot,integer(minimum),integer(classID),integer(subclassID)
    if slot=="" then row.state,row.reason="none",nil;return self:Remember(key,row) end
    row.unique=uniqueness(link)
    local use=self:Usable(id,snapshot)
    row.usable=use
    if row.minimum==nil or not level or row.classID==nil or row.subclassID==nil or type(use)~="boolean" then return self:Remember(key,row) end
    if use==false or row.minimum>level then row.state,row.reason="blocked","cannot-equip";return self:Remember(key,row) end
    row.state,row.reason="unsupported","uniqueness-unknown"
    if not row.unique then return self:Remember(key,row) end
    if not M.Readable(setID) or setID~=nil and (integer(setID)==nil or setID>0) then row.reason="set-effect";return self:Remember(key,row) end
    local complete,reason=effectCheck(link)
    if not complete then row.reason=reason;if reason=="tooltip-pending" then row.state="pending" end;return self:Remember(key,row) end
    -- Native GetItemStats has no typed weapon-DPS/speed contract. Never rank a
    -- sword's attributes while ignoring the damage of the sword it replaces.
    if weapon(slot) then row.reason="weapon-damage-unknown";return self:Remember(key,row) end
    local stats;stats,reason=R.Normalize(A.Call(C_Item and C_Item.GetItemStats,link))
    if not stats then row.reason=reason;if reason=="stats-pending" then row.state="pending" end;return self:Remember(key,row) end
    row.stats,row.state,row.reason=stats,"ready",nil
    return self:Remember(key,row)
end
function R:Gear(snapshot)
    self:UseContext(snapshot)
    local key=tostring(integer(snapshot.equipmentRevision))..":"..tostring(integer(snapshot.identityRevision))..":"..tostring(integer(snapshot.capabilityRevision))..":"..tostring(integer(snapshot.itemRevision))..":"..tostring((M.QuestId(snapshot.level)))..":"..(text(snapshot.guid) or "")
    if self.gearKey==key and self.gear and not self.gearPending then return self.gear end
    local gear={}
    for slot=1,19 do
        local entry=tableValue(snapshot.equipment) and snapshot.equipment[slot]
        if tableValue(entry) and text(entry.state)=="empty" and tableValue(snapshot.emptySlots) and M.Readable(snapshot.emptySlots[slot]) and snapshot.emptySlots[slot]==true then
            gear[slot]={state="empty",slotIndex=slot}
        elseif tableValue(entry) then gear[slot]=self:Item(entry,snapshot,true)
        else gear[slot]={state="pending",reason="equipment-pending"} end
    end
    local dependencies,pending={},false
    for _,row in pairs(gear) do if row.itemID then dependencies[row.itemID]=true end;if row.state=="pending" then pending=true end end
    self.gearPending=pending
    self.gearKey,self.gear,self.gearByID=key,gear,dependencies;return gear
end

local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},
    INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},
    INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},
    INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},INVTYPE_WEAPONOFFHAND={17},INVTYPE_2HWEAPON={16},
    INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18},INVTYPE_RELIC={18}}
local function score(row,style,slot)
    if tableValue(row) and text(row.state)=="empty" then return 0 end
    if not tableValue(row) or text(row.state)~="ready" or not tableValue(row.stats) then return end
    if weapon(text(row.slot)) and (not M.Readable(row.damageKnown) or row.damageKnown~=true) then return end
    local sum,count=0,0
    for key,value in pairs(row.stats) do
        count=count+1;if count>64 or not text(key) or not M.Number(value) or not M.Number(style.weights[key]) then return end
        local weight=style.weights[key]
        if key=="weaponDps" and slot==17 then weight=style.weights.offhandDps end
        if not M.Number(weight) then return end
        sum=sum+value*weight
    end
    return M.Number(sum) and sum or nil
end
local function legal(candidate,gear,replaced,removed)
    local u=candidate.unique;if not tableValue(u) then return nil end
    if integer(u.category)==nil or integer(u.maximum)==nil or not M.Readable(u.single) or type(u.single)~="boolean"
        or u.category>0 and u.maximum<1 then return nil end
    if u.category==0 and u.single==false then return true end
    local count,sameID=1,1
    for slot=1,19 do
        if slot~=replaced and slot~=removed then
            local row=gear[slot]
            if not tableValue(row) then return nil end
            if text(row.state)~="empty" then
                if not M.QuestId(row.itemID) then return nil end
                if row.itemID==candidate.itemID then sameID=sameID+1 end
                if u.category>0 then
                    if not tableValue(row.unique) or integer(row.unique.category)==nil then return nil end
                    if row.unique.category==u.category then count=count+1 end
                end
            end
        end
    end
    return (not u.single or sameID<=1) and (u.category==0 or count<=u.maximum)
end
-- Pure comparison entry point: normalized records only, no native calls.
function R.Compare(candidate,gear,style,context)
    if not tableValue(style) or not tableValue(style.weights) then return result("choose-style","choose-style") end
    if not tableValue(candidate) then return result("unsupported","item-pending") end
    if text(candidate.state)~="ready" then
        return result(text(candidate.state)=="pending" and "pending" or "unsupported",text(candidate.reason) or "item-pending")
    end
    if not tableValue(gear) or not M.QuestId(candidate.itemID) then return result("unsupported","context-invalid") end
    if not M.Readable(candidate.usable) or candidate.usable~=true then return result("unsupported","cannot-equip") end
    local kind=text(candidate.slot);local targets=slots[kind];if not targets then return result("none","not-equipment") end
    if kind=="INVTYPE_2HWEAPON" and (not M.Readable(style.requiresShield) or style.requiresShield==true) then return result("unsupported","shield-style") end
    local best,unknown
    for _,slot in ipairs(targets) do
        local allowed=true
        if slot==17 then
            local main=gear[16]
            if not tableValue(main) or not text(main.state) or text(main.state)=="pending" or not text(main.slot) and text(main.state)~="empty" then allowed=nil
            elseif text(main.state)=="empty" or text(main.slot)=="INVTYPE_2HWEAPON" then allowed=false end
            if allowed and (kind=="INVTYPE_WEAPON" or kind=="INVTYPE_WEAPONOFFHAND") then
                local dual=tableValue(context) and tableValue(context.capabilities) and context.capabilities.dualWield
                if not M.Readable(dual) or dual~=true then allowed=nil end
            end
            if allowed and style.requiresShield==true and kind~="INVTYPE_SHIELD" then allowed=false end
        end
        local removed=kind=="INVTYPE_2HWEAPON" and 17 or nil
        if allowed then allowed=legal(candidate,gear,slot,removed) end
        if allowed==nil then unknown=true
        elseif allowed then
            local before=score(gear[slot],style,slot);local after=score(candidate,style,slot)
            if removed then local off=score(gear[removed],style,removed);before=before and off and before+off end
            if before==nil or after==nil then unknown=true
            else local gain=after-before;if best==nil or gain>best then best=gain end end
        end
    end
    if unknown then return result("unsupported","comparison-incomplete") end
    if best==nil then return result("unsupported","no-legal-comparison") end
    if math.abs(best)<.000001 then best=0 end
    return result("ready",nil,best,candidate.itemID)
end
local function filterMatch(kind,filter,snapshot)
    if not filter or filter=="ALL" or not kind then return true end
    if filter=="MISSING" then
        for _,slot in ipairs(slots[kind] or {}) do
            if tableValue(snapshot.emptySlots) and M.Readable(snapshot.emptySlots[slot]) and snapshot.emptySlots[slot]==true then return true end
        end
        return false
    end
    if filter=="CHEST" then return kind=="INVTYPE_CHEST" or kind=="INVTYPE_ROBE" end
    if filter=="WEAPON" then return kind=="INVTYPE_WEAPON" or kind=="INVTYPE_WEAPONMAINHAND" or kind=="INVTYPE_2HWEAPON" end
    if filter=="OFFHAND" then return kind=="INVTYPE_SHIELD" or kind=="INVTYPE_HOLDABLE" or kind=="INVTYPE_WEAPONOFFHAND" end
    if filter=="RANGED" then return kind=="INVTYPE_RANGED" or kind=="INVTYPE_RANGEDRIGHT" or kind=="INVTYPE_THROWN" end
    return kind==filter
end
function R:Quest(items,snapshot,style,slotFilter)
    if not style then return result("choose-style","choose-style") end
    if not tableValue(snapshot) or not sequence(items,256) then return result("unsupported","context-invalid") end
    slotFilter=text(slotFilter)
    local gear=self:Gear(snapshot);local best,unknown,seen=nil,nil,{}
    for _,meta in ipairs(items) do
        if tableValue(meta) then
            local identity=text(meta.link) or M.QuestId(meta.itemID)
            if identity and not seen[identity] then
                seen[identity]=true
                local item=self:Item(meta,snapshot)
                if item.state~="none" and item.state~="blocked" and filterMatch(text(item.slot) or text(meta.slot),slotFilter,snapshot) then
                    local comparison=R.Compare(item,gear,style,snapshot)
                    if comparison.state=="ready" then
                        if not best or comparison.gain>best.gain or comparison.gain==best.gain and comparison.itemID<best.itemID then best=comparison end
                    elseif not unknown or comparison.state=="pending" then unknown=comparison end
                end
            elseif not identity then unknown=result("unsupported","item-invalid") end
        else unknown=result("unsupported","item-invalid") end
    end
    -- A partial best-of-choice claim is misleading. One unresolved equipment
    -- option keeps the quest unranked; no amounts/quantities/groups are summed.
    return unknown or best or result("none","no-comparable-equipment")
end

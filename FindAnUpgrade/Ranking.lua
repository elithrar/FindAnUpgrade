local _,N=...
local M,A=N.Model,N.Adapter
-- An estimated item-level difference, never a damage/healing or stat score.
-- The current 2,623 catalog reward IDs plus 19 equipped variants fit this bound.
local R={limit=4096,cache={},order={},byID={},dirty={}};N.Ranking=R
local function tab(v)return M.Readable(v) and type(v)=="table" end
local function text(v)return M.Readable(v) and type(v)=="string" and v~="" and v or nil end
local function int(v)return M.Number(v) and v>=0 and v==math.floor(v) and v or nil end
local function sequence(v,max)
    if not tab(v) or #v>max then return false end
    local n=0;for k in pairs(v) do if not M.Number(k) or k<1 or k>#v or k~=math.floor(k) then return false end;n=n+1 end
    return n==#v
end
local function values(fn,...)
    if type(fn)~="function" then return end
    local function pack(...)return {n=select("#",...),...} end
    local v=pack(pcall(fn,...));if v[1] then return unpack(v,2,v.n) end
end
local function result(state,reason,gain,id)
    return {state=state,reason=reason,gain=gain,itemID=id,estimated=true,metric="item-level",
        tier=state=="ready" and (gain>0 and 1 or 3) or 2}
end
local function identity(s)
    return tab(s) and M.QuestId(s.classID) and text(s.classToken) and M.Readable(s.faction)
        and (s.faction=="Alliance" or s.faction=="Horde")
end
local function context(s)
    return tostring((M.QuestId(s.level)))..":"..(int(s.identityRevision) or 0)..":"..(int(s.capabilityRevision) or 0)..":"..(text(s.guid) or "")
end
local function key(link,s,equipped)return link.."\031"..context(s)..(equipped and "\031gear" or "\031reward") end
function R:UseContext(s)
    local current=context(s)
    if self.contextKey~=current then
        self.contextKey=current;self.cache,self.order,self.byID,self.dirty={},{},{},{}
        self.gear,self.gearKey,self.gearByID,self.gearQuery=nil,nil,nil,nil
        self.useKey,self.useCache,self.useOrder,self.useDirty=nil,{},{},{}
    end
end
function R:Usable(id,s,query)
    id=M.QuestId(id);if not id or not tab(s) then return end;self:UseContext(s)
    local current=context(s)..":"..tostring(int(s.equipmentRevision))
    if self.useKey~=current then self.useKey=current;self.useCache,self.useOrder,self.useDirty={},{},{} end
    local prior=self.useCache[id]
    if prior and not self.useDirty[id] and (prior.value~=nil or not query or prior.query==query and prior.queryItems==int(s.itemRevision)) then return prior.value end
    if not prior then
        if #self.useOrder>=self.limit then local old=table.remove(self.useOrder,1);self.useCache[old],self.useDirty[old]=nil,nil end
        self.useOrder[#self.useOrder+1]=id
    end
    local use
    if A.Call(C_Item and C_Item.IsItemDataCachedByID,id)==true then use=A.Call(C_PlayerInfo and C_PlayerInfo.CanUseItem,id) end
    if type(use)~="boolean" then use=nil end
    self.useCache[id],self.useDirty[id]={value=use,query=use==nil and query or nil,queryItems=use==nil and int(s.itemRevision) or nil},nil;return use
end
local function retryable(row)return row.state=="pending" or row.reason=="limits-unavailable" end
function R:Remember(k,row)
    if not retryable(row) then row.query,row.queryEquipment,row.queryItems=nil,nil,nil end
    if not self.cache[k] then
        if #self.order>=self.limit then
            local old=table.remove(self.order,1);local entry=self.cache[old]
            if entry and self.byID[entry.itemID] then self.byID[entry.itemID][old]=nil;if not next(self.byID[entry.itemID]) then self.byID[entry.itemID]=nil end end
            self.cache[old],self.dirty[old]=nil,nil
        end
        self.order[#self.order+1]=k
    end
    self.byID[row.itemID]=self.byID[row.itemID] or {};self.byID[row.itemID][k]=true
    self.cache[k],self.dirty[k]=row,nil;return row
end
local function itemID(link)
    return tonumber(link:match("item:(%d+):") or link:match("item:(%d+)|") or link:match("item:(%d+)$"))
end
local function modified(link)
    local payload=link:match("item:([^|]+)");if not payload then return true end
    local fields={};for v in (payload..":"):gmatch("([^:]*):") do fields[#fields+1]=v end
    -- Generic item hydration cannot establish a quest's enchant/gem/suffix roll.
    for i=2,7 do if fields[i] and fields[i]~="" and tonumber(fields[i])~=0 then return true end end
    return false
end
local function uniqueness(link)
    local category,max=values(C_Item and C_Item.GetItemUniqueness,link)
    local single,_,count,id=values(C_Item and C_Item.GetItemUniquenessByID,link)
    if int(category)==nil or int(max)==nil or not M.Readable(single) or type(single)~="boolean" or not M.Readable(count) or not M.Readable(id) then return end
    if category>0 and max<1 or id~=nil and (int(id)==nil or id~=category) or count~=nil and (int(count)==nil or category>0 and count~=max) then return end
    return {category=category,maximum=max,single=single}
end
function R:Item(meta,s,equipped,query)
    if not tab(s) then return {state="unsupported",reason="context-invalid"} end
    local id=tab(meta) and M.QuestId(meta.itemID);local link=tab(meta) and text(meta.link)
    if not id or not link or #link>2048 or itemID(link)~=id then return {state="pending",reason="item-pending",itemID=id} end
    self:UseContext(s);equipped=M.Readable(equipped) and equipped==true
    local k=key(link,s,equipped);local old=self.cache[k]
    local sameQuery=query and old and old.query==query and old.queryEquipment==int(s.equipmentRevision) and old.queryItems==int(s.itemRevision)
    if old and not self.dirty[k] and (not retryable(old) or sameQuery) and (old.usable==nil or old.usable==self:Usable(id,s,query)) then return old end
    local row={itemID=id,link=link,state="pending",reason="item-pending",equipped=equipped,query=query,
        queryEquipment=query and int(s.equipmentRevision) or nil,queryItems=query and int(s.itemRevision) or nil}
    if not equipped and modified(link) then row.state,row.reason="unsupported","reward-variant-unconfirmed";return self:Remember(k,row) end
    if A.Call(C_Item and C_Item.IsItemDataCachedByID,id)~=true then return self:Remember(k,row) end
    local name,infoLink,_,level,minimum,_,_,_,slot,_,_,classID,subclassID=values(C_Item and C_Item.GetItemInfo,link)
    if not text(name) or not text(infoLink) or itemID(infoLink)~=id or not M.Readable(slot) or type(slot)~="string" then return self:Remember(k,row) end
    if not equipped and modified(infoLink) then row.state,row.reason="unsupported","reward-variant-unconfirmed";return self:Remember(k,row) end
    row.slot,row.itemLevel,row.minimum,row.classID,row.subclassID=slot,M.Number(level) and level>0 and level<=2000 and level or nil,int(minimum),int(classID),int(subclassID)
    if slot=="" or slot=="INVTYPE_BODY" or slot=="INVTYPE_TABARD" then
        if equipped then row.unique=uniqueness(link) end
        row.state,row.reason="none",nil;return self:Remember(k,row)
    end
    row.unique=uniqueness(link);row.usable=self:Usable(id,s,query)
    if not row.itemLevel or row.minimum==nil or row.classID==nil or row.subclassID==nil or not M.QuestId(s.level) or type(row.usable)~="boolean" then return self:Remember(k,row) end
    if not identity(s) then row.reason="identity-pending"
    elseif row.usable==false or row.minimum>s.level then row.state,row.reason="blocked","cannot-equip"
    elseif not row.unique then row.state,row.reason="unsupported","limits-unavailable"
    else row.state,row.reason="ready",nil end
    return self:Remember(k,row)
end
function R:Gear(s,query)
    self:UseContext(s)
    local current=context(s)..":"..tostring(int(s.equipmentRevision))..":"..tostring(int(s.itemRevision))
    if self.gearKey==current and self.gear and (not self.gearPending or query and self.gearQuery==query) then return self.gear end
    local gear,ids,pending={},{},false
    for slot=1,19 do
        local entry=tab(s.equipment) and s.equipment[slot]
        if tab(entry) and text(entry.state)=="empty" and tab(s.emptySlots) and M.Readable(s.emptySlots[slot]) and s.emptySlots[slot]==true then gear[slot]={state="empty"}
        elseif tab(entry) then gear[slot]=self:Item(entry,s,true,query)
        else gear[slot]={state="pending",reason="equipment-pending"} end
        if gear[slot].itemID then ids[gear[slot].itemID]=true end
        if retryable(gear[slot]) then pending=true end
    end
    self.gear,self.gearKey,self.gearByID,self.gearPending,self.gearQuery=gear,current,ids,pending,query;return gear
end
local fields={"itemID","link","state","reason","slot","itemLevel","minimum","classID","subclassID","usable"}
local function same(a,b)
    for _,field in ipairs(fields) do if a[field]~=b[field] then return false end end
    for _,field in ipairs({"category","maximum","single"}) do if (a.unique and a.unique[field])~=(b.unique and b.unique[field]) then return false end end
    return true
end
local function stamp(row)
    local out={};for _,field in ipairs(fields) do out[#out+1]=field.."="..tostring(row[field]) end
    for _,field in ipairs({"category","maximum","single"}) do out[#out+1]=field.."="..tostring(row.unique and row.unique[field]) end
    local value=table.concat(out,"\031");if #value<=8192 then return value end
end
function R:Interested(id)
    return M.QuestId(id) and (self.byID[id]~=nil or self.gearByID and self.gearByID[id]~=nil or self.useCache and self.useCache[id]~=nil) or false
end
-- Existing event owners deliver item changes. Hidden delivery never hydrates.
-- A central equipment notification owns the resulting coherent search refresh.
function R:InvalidateItem(id,s,visible)
    id=M.QuestId(id);if not id then return false end
    if visible==true and tab(s) then self:UseContext(s) end
    local current,seen={},{};local relevant=self.gearByID and self.gearByID[id] or self.useCache and self.useCache[id] or false
    for k in pairs(self.byID[id] or {}) do
        local row=self.cache[k]
        if row then
            self.dirty[k]=true;relevant=true
            if visible==true and tab(s) and k==key(row.link,s,row.equipped) then current[#current+1]=row;seen[k]=true end
        end
    end
    for _,row in pairs(self.gear or {}) do
        if row.itemID==id and text(row.link) then
            relevant=true
            if visible==true and tab(s) then local k=key(row.link,s,true);if not seen[k] then self.dirty[k]=true;current[#current+1]=row;seen[k]=true end end
        end
    end
    if not relevant then return false end
    local priorUse=self.useCache and self.useCache[id];if priorUse then self.useDirty[id]=true end
    if visible~=true or not tab(s) then self.gear,self.gearKey,self.gearByID=nil,nil,nil;return false end
    local changed,forwarded=false,false
    if priorUse then changed=priorUse.value~=self:Usable(id,s) end
    for _,prior in ipairs(current) do
        local fresh=self:Item({itemID=prior.itemID,link=prior.link},s,prior.equipped)
        if not same(prior,fresh) then
            changed=true
            if prior.equipped and N.Character and type(N.Character.EquipmentMetadata)=="function" then
                local exact=false;for _,entry in pairs(s.equipment or {}) do if entry.itemID==id and entry.link==prior.link then exact=true;break end end
                local value=exact and stamp(fresh)
                if value and A.Call(N.Character.EquipmentMetadata,N.Character,id,value,s.equipmentRevision)==true then forwarded=true end
            end
        end
    end
    if changed then self.gear,self.gearKey,self.gearByID=nil,nil,nil end
    return changed,forwarded
end
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},INVTYPE_WEAPONOFFHAND={17},INVTYPE_2HWEAPON={16},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18},INVTYPE_RELIC={18}}
local function oneHand(kind)return kind=="INVTYPE_WEAPON" or kind=="INVTYPE_WEAPONMAINHAND" or kind=="INVTYPE_WEAPONOFFHAND" end
local function level(row)
    if not tab(row) then return end
    if text(row.state)=="empty" then return 0 end
    if text(row.state)~="pending" and M.Number(row.itemLevel) and row.itemLevel>0 and row.itemLevel<=2000 then return row.itemLevel end
end
local function legal(candidate,gear,replaced,removed)
    local u=candidate.unique
    if not tab(u) or int(u.category)==nil or int(u.maximum)==nil or not M.Readable(u.single) or type(u.single)~="boolean" or u.category>0 and u.maximum<1 then return end
    if u.category==0 and not u.single then return true end
    local count,duplicates=1,1
    for slot=1,19 do
        if slot~=replaced and slot~=removed then
            local row=gear[slot];if not tab(row) then return end
            if text(row.state)~="empty" then
                if not M.QuestId(row.itemID) then return end
                if row.itemID==candidate.itemID then duplicates=duplicates+1 end
                if u.category>0 then if not tab(row.unique) or int(row.unique.category)==nil then return end;if row.unique.category==u.category then count=count+1 end end
            end
        end
    end
    return (not u.single or duplicates<=1) and (u.category==0 or count<=u.maximum)
end
local function dual(gear,s)
    local value;if tab(s) and tab(s.capabilities) then value=s.capabilities.dualWield end
    if M.Readable(value) and type(value)=="boolean" then return value end
    -- The actual equipped pair proves a currently legal dual-wield outfit.
    if tab(gear[16]) and tab(gear[17]) and oneHand(text(gear[16].slot)) and oneHand(text(gear[17].slot)) then return true end
end
local function hands(gear)
    local main,off=gear[16],gear[17];local a,b=level(main),level(off)
    if a==nil or b==nil then return end
    if a>0 and text(main.slot)~="INVTYPE_2HWEAPON" and not oneHand(text(main.slot)) then return end
    if b>0 and not oneHand(text(off.slot)) and text(off.slot)~="INVTYPE_SHIELD" and text(off.slot)~="INVTYPE_HOLDABLE" then return end
    if a>0 and text(main.slot)=="INVTYPE_2HWEAPON" and b>0 then return end
    local count=(a>0 and 1 or 0)+(b>0 and 1 or 0)
    return count>0 and (a+b)/count or 0
end
-- Pure comparison: no API reads, bag substitutions, item effects or stat weights.
function R.Compare(candidate,gear,s)
    if not identity(s) then return result("unsupported","identity-pending") end
    if not tab(candidate) or not tab(gear) or not M.QuestId(candidate.itemID) then return result("unsupported","context-invalid") end
    if text(candidate.state)~="ready" then return result(text(candidate.state)=="pending" and "pending" or "unsupported",text(candidate.reason) or "item-pending") end
    if not M.Readable(candidate.usable) or candidate.usable~=true or not level(candidate) then return result("unsupported","cannot-equip") end
    local kind=text(candidate.slot);local targets=slots[kind];if not targets then return result("none","not-equipment") end
    local best,unknown
    for _,slot in ipairs(targets) do
        local allowed,before,removed=true,nil,nil
        if kind=="INVTYPE_2HWEAPON" then before=hands(gear);removed=17
        elseif slot==16 then
            local main,off=gear[16],gear[17]
            if not tab(main) or text(main.state)=="pending" or not tab(off) or text(off.state)=="pending" then allowed=nil
            elseif text(main.state)~="empty" and not oneHand(text(main.slot)) then allowed=nil
            elseif text(off.state)~="empty" and not oneHand(text(off.slot)) and text(off.slot)~="INVTYPE_SHIELD" and text(off.slot)~="INVTYPE_HOLDABLE" then allowed=nil end
            before=level(main)
        elseif slot==17 then
            local main=gear[16]
            if not tab(main) or text(main.state)=="pending" then allowed=nil
            elseif text(main.slot)=="INVTYPE_2HWEAPON" then allowed=false
            elseif text(main.state)~="empty" and not oneHand(text(main.slot)) then allowed=nil end
            if allowed and oneHand(kind) then
                local capable=dual(gear,s);if capable==false then allowed=false elseif capable~=true or text(main.state)=="empty" then allowed=nil end
            end
            before=level(gear[17])
        else before=level(gear[slot]) end
        if allowed then allowed=legal(candidate,gear,slot,removed) end
        if allowed==nil then unknown=true
        elseif allowed then
            if before==nil then unknown=true else local gain=candidate.itemLevel-before;if best==nil or gain>best then best=gain end end
        end
    end
    if unknown then return result("unsupported","comparison-incomplete") end
    if best==nil then return result("unsupported","no-legal-comparison") end
    if math.abs(best)<.000001 then best=0 end
    return result("ready",nil,best,candidate.itemID)
end
local function matches(kind,filter,s)
    if not filter or filter=="ALL" or not kind then return true end
    if filter=="MISSING" then for _,slot in ipairs(slots[kind] or {}) do if tab(s.emptySlots) and M.Readable(s.emptySlots[slot]) and s.emptySlots[slot]==true then return true end end;return false end
    if filter=="CHEST" then return kind=="INVTYPE_CHEST" or kind=="INVTYPE_ROBE" end
    if filter=="WEAPON" then return kind=="INVTYPE_WEAPON" or kind=="INVTYPE_WEAPONMAINHAND" or kind=="INVTYPE_2HWEAPON" end
    if filter=="OFFHAND" then return kind=="INVTYPE_SHIELD" or kind=="INVTYPE_HOLDABLE" or kind=="INVTYPE_WEAPONOFFHAND" end
    if filter=="RANGED" then return kind=="INVTYPE_RANGED" or kind=="INVTYPE_RANGEDRIGHT" or kind=="INVTYPE_THROWN" end
    return kind==filter
end
function R:Quest(items,s,slotFilter,query)
    if not tab(s) or not sequence(items,256) then return result("unsupported","context-invalid") end
    local gear=self:Gear(s,query);local best,unknown,seen=nil,nil,{};slotFilter=text(slotFilter)
    for _,meta in ipairs(items) do
        if tab(meta) then
            local identity=text(meta.link) or M.QuestId(meta.itemID)
            if identity and not seen[identity] then
                seen[identity]=true;local item=self:Item(meta,s,nil,query)
                if item.state~="none" and item.state~="blocked" and matches(text(item.slot) or text(meta.slot),slotFilter,s) then
                    local rating=R.Compare(item,gear,s)
                    if rating.state=="ready" then if not best or rating.gain>best.gain or rating.gain==best.gain and rating.itemID<best.itemID then best=rating end
                    elseif not unknown or rating.state=="pending" then unknown=rating end
                end
            elseif not identity then unknown=result("unsupported","item-invalid") end
        else unknown=result("unsupported","item-invalid") end
    end
    -- Best single legal item: quantities and mutually exclusive choices aren't summed.
    return unknown or best or result("none","no-comparable-equipment")
end

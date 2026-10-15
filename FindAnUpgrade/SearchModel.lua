local _, N = ...
local M,A=N.Model,N.Adapter
local S={cache={},usability={},currentItems={},currentStamp={}}; N.SearchModel=S
S.slots={{"ALL","All rewards"},{"MISSING","Empty slots"},{"INVTYPE_HEAD","Head"},{"INVTYPE_NECK","Neck"},{"INVTYPE_SHOULDER","Shoulder"},{"INVTYPE_CLOAK","Back"},{"CHEST","Chest"},{"INVTYPE_WRIST","Wrist"},{"INVTYPE_HAND","Hands"},{"INVTYPE_WAIST","Waist"},{"INVTYPE_LEGS","Legs"},{"INVTYPE_FEET","Feet"},{"INVTYPE_FINGER","Ring"},{"INVTYPE_TRINKET","Trinket"},{"WEAPON","Weapon"},{"OFFHAND","Off hand"},{"RANGED","Ranged"}}
local function returns(fn,...)
    if type(fn)~="function" then return end
    local function pack(...) return {n=select("#",...),...} end
    local values=pack(pcall(fn,...)); if values[1] then return unpack(values,2,values.n) end
end
function S:InvalidateQuest(id)
    id=M.QuestId(id); if not id then return false end
    self.currentItems[id],self.currentStamp[id],self.usability[id]=nil,nil,nil
    return true
end
function S:Context()
    return N.Character:Get()
end
function S:Eligibility(row,context)
    local proof=context and context.nativeOffers and context.nativeOffers[row.id]
    local availability=N.Providers.Availability(proof and {id=row.id,source=row.source,availabilityProof=proof} or row,context)
    local source=row.source or {}
    if N.Providers.RequiresNativeProof(source) then
        if not N.Providers.HasNativeProof(availability) then
            return false,"Forever availability unconfirmed",availability
        end
    end
    -- The finder can inspect a recorded reward above the player's current
    -- minimum level, with the actual recorded requirement kept visible.
    if availability.authority=="recorded-level" then return true,availability.label,availability end
    return availability.state~="blocked" and availability.state~="completed",availability.label,availability
end
function S:StartPath(row,context,availability)
    local allowed,known=N.Providers.StartPath(row,context)
    if allowed then return true end
    if not availability or not N.Providers.HasNativeProof(availability) then return false end
    if availability.authority=="native-log" or availability.authority=="native-gossip" then return true end
    -- A current exact map offer can fill a missing starter identity. It cannot
    -- turn an explicitly opposing starter into a usable path for this player.
    return not known
end
local function positive(value) return M.Number(value) and value>0 end
function S:Benefit(row)
    local current=self.currentItems[row.id]
    if current then return current.benefit==true end
    local values=row.source and row.source.rewardValues or {}
    if positive(values.xp) or positive(values.money) then return true end
    for _,entry in ipairs(N.Rewards.PublishedReputation(values.reputation)) do if positive(entry.amount) then return true end end
    return false
end
local function rewardBenefit(reward)
    if reward.xp.state=="ready" and positive(reward.xp.value) or reward.money.state=="ready" and positive(reward.money.value) then return true end
    for _,entry in ipairs(reward.reputation.items or {}) do
        if positive(entry.amount) then
            local faction=entry.factionID and A.Call(C_Reputation and C_Reputation.GetFactionDataByID,entry.factionID)
            local name=M.Text(entry.name) or M.Readable(faction) and type(faction)=="table" and M.Text(faction.name)
                or entry.factionID and M.Text(A.Call(GetFactionInfoByID,entry.factionID))
            if name then return true end
        end
    end
    for _,entry in ipairs(reward.currencies.items or {}) do if M.Text(entry.name) and positive(entry.amount) then return true end end
    return false
end
-- Pinned Forever ItemWeaponSubclass values. These are search synonyms only;
-- item usability, slot selection and upgrade comparison keep their own rules.
local weaponTerms={
    [0]="axe axes one-handed",[1]="axe axes two-handed",[2]="bow bows",[3]="gun guns",
    [4]="mace maces one-handed",[5]="mace maces two-handed",[6]="polearm polearms",
    [7]="sword swords one-handed",[8]="sword swords two-handed",[9]="warglaive warglaives",
    [10]="staff staves",[13]="fist weapon unarmed",[15]="dagger daggers",[16]="thrown",
    [18]="crossbow crossbows",[19]="wand wands",[20]="fishing pole fishingpole",
}
local function itemType(row,kind,subtype,class,subclass)
    row.itemType,row.itemSubType=M.Text(kind),M.Text(subtype)
    row.classID=M.Number(class) and class>=0 and class==math.floor(class) and class or nil
    row.subclassID=M.Number(subclass) and subclass>=0 and subclass==math.floor(subclass) and subclass or nil
    local aliases=row.classID==2 and weaponTerms[row.subclassID] or nil
    row.searchTypeText=table.concat({row.itemType or "",row.itemSubType or "",aliases or ""}," "):lower()
end
function S:Item(meta)
    local id=meta.itemID
    local function rewardCopy(base)
        local result={}; for key,value in pairs(base) do result[key]=value end
        result.quantity,result.group=meta.quantity,meta.group
        if base.state~="ready" and meta.name then result.name=meta.name end
        return result
    end
    if self.cache[id] and (self.cache[id].state=="ready" or A.Call(C_Item and C_Item.IsItemDataCachedByID,id)~=true) then return rewardCopy(self.cache[id]) end
    local row={itemID=id,name=meta.name,kind="catalog",state="pending",catalog=true}
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    local name,link,quality,level,minimum,slot,texture,kind,subtype,class,subclass
    if A.Call(C_Item and C_Item.IsItemDataCachedByID,id)==true then
        local values={returns(fn,id)}
        name,link,quality,level,minimum,slot,texture=values[1],values[2],values[3],values[4],values[5],values[9],values[10]
        kind,subtype,class,subclass=values[6],values[7],values[12],values[13]
    end
    if M.Text(name) and M.Text(link) and M.Number(quality) and quality>=0 and quality<=8 and M.Readable(slot) and type(slot)=="string" and (M.Text(texture) or M.Number(texture)) then
        row.name,row.link,row.quality,row.itemLevel,row.minimum,row.slot,row.texture,row.state=name,link,quality,M.Number(level) and level or nil,M.Number(minimum) and minimum or nil,slot,texture,"ready"
    else
        local _,instantKind,instantSubtype,instantSlot,icon,instantClass,instantSubclass=returns(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,id)
        row.slot=M.Text(instantSlot); row.texture=M.Text(icon) or M.Number(icon) and icon or nil
        kind,subtype,class,subclass=instantKind,instantSubtype,instantClass,instantSubclass
    end
    itemType(row,kind,subtype,class,subclass)
    self.cache[id]=row; return rewardCopy(row)
end
function S.SlotMatch(slot,filter,context)
    if filter=="ALL" then return true end
    if not slot then return false end
    if filter=="MISSING" then return S.EmptySlot(slot,context) end
    if filter=="CHEST" then return slot=="INVTYPE_CHEST" or slot=="INVTYPE_ROBE" end
    if filter=="WEAPON" then return slot=="INVTYPE_WEAPON" or slot=="INVTYPE_WEAPONMAINHAND" or slot=="INVTYPE_2HWEAPON" end
    if filter=="OFFHAND" then return slot=="INVTYPE_SHIELD" or slot=="INVTYPE_HOLDABLE" or slot=="INVTYPE_WEAPONOFFHAND" end
    if filter=="RANGED" then return slot=="INVTYPE_RANGED" or slot=="INVTYPE_RANGEDRIGHT" or slot=="INVTYPE_THROWN" end
    return slot==filter
end
local inventorySlots={INVTYPE_HEAD={"HeadSlot"},INVTYPE_NECK={"NeckSlot"},INVTYPE_SHOULDER={"ShoulderSlot"},INVTYPE_CLOAK={"BackSlot"},INVTYPE_CHEST={"ChestSlot"},INVTYPE_ROBE={"ChestSlot"},INVTYPE_WRIST={"WristSlot"},INVTYPE_HAND={"HandsSlot"},INVTYPE_WAIST={"WaistSlot"},INVTYPE_LEGS={"LegsSlot"},INVTYPE_FEET={"FeetSlot"},INVTYPE_FINGER={"Finger0Slot","Finger1Slot"},INVTYPE_TRINKET={"Trinket0Slot","Trinket1Slot"},INVTYPE_WEAPON={"MainHandSlot"},INVTYPE_WEAPONMAINHAND={"MainHandSlot"},INVTYPE_2HWEAPON={"MainHandSlot"},INVTYPE_WEAPONOFFHAND={"SecondaryHandSlot"},INVTYPE_SHIELD={"SecondaryHandSlot"},INVTYPE_HOLDABLE={"SecondaryHandSlot"},INVTYPE_RANGED={"RangedSlot"},INVTYPE_RANGEDRIGHT={"RangedSlot"},INVTYPE_THROWN={"RangedSlot"}}
function S.EmptySlot(slot,context)
    context=context or N.Character:Get()
    for _,name in ipairs(inventorySlots[slot] or {}) do
        local index=context.inventorySlots and context.inventorySlots[name]
        if index and context.emptySlots and context.emptySlots[index]==true then return true end
    end
    return false
end
function S:DungeonPath(row,context,availability)
    if availability and N.Providers.HasNativeProof(availability)
        and (availability.authority=="native-log" or availability.authority=="native-gossip") then return true end
    local source=row.source or {}
    if source.confirmation~="published" or source.questKind=="hidden-trigger" or availability and availability.state=="blocked" then return false end
    return N.Providers.StartPath(row,context)==true and N.Providers.ChainState(source)==nil
end
function S:Query(filter)
    -- Retry incomplete metadata on the next query, never for every association.
    local rankingQuery={}
    local out={}; self.needed={}; self.questNeeded={}; self.unknownLevels=0
    local needSet={}; local context=self:Context(); local query=(filter.query or ""):lower()
    local scope=filter.scope=="LEVEL_RANGE" and "LEVEL_RANGE" or "SAME_ZONE"
    local currentCategories,zoneName=N.Catalog:CurrentCategories(context)
    local includeDungeons=filter.includeDungeons==true
    local minimum=M.Number(filter.minimum) and filter.minimum or 1
    local maximum=M.Number(filter.maximum) and filter.maximum or 200
    local slotFilter=filter.slot or "ALL"
    local sort=filter.sort or "UPGRADE"
    local status=scope=="SAME_ZONE" and not zoneName and "Zone unavailable — choose Level range" or nil
    if not M.Number(context.level) or context.level<1 then return out,"Player level unavailable" end
    for _,record in ipairs(N.Catalog.order) do
        local category=N.Catalog:Category(record.id)
        local sameZone=category and currentCategories[category.name]==true or false
        -- Exclude non-members before native metadata/item hydration. Dungeon
        -- additions require an exact tag, never a giver's position or a title.
        if scope=="LEVEL_RANGE" or sameZone or includeDungeons then
            local candidateEligible,candidateNote,candidateAvailability
            if N.Providers.RequiresNativeProof(record.source) then
                candidateEligible,candidateNote,candidateAvailability=self:Eligibility(record,context)
            end
            if candidateEligible~=false then
                if not N.Catalog:Metadata(record,context.level) then self.questNeeded[#self.questNeeded+1]=record.id end
                if not M.Number(record.level) or record.level<1 then self.unknownLevels=self.unknownLevels+1 end
                if M.Number(record.level) and record.level>=minimum and record.level<=maximum then
                    local tag=N.Catalog:QuestTag(record.id)
                    local dungeon=tag==81 -- Pinned Forever Enum.QuestTag.Dungeon.
                    local inScope=(scope=="LEVEL_RANGE" or sameZone or includeDungeons and dungeon)
                        and (includeDungeons or not dungeon)
                    if inScope then
                        local eligible,note,availability=candidateEligible,candidateNote,candidateAvailability
                        if eligible==nil then eligible,note,availability=self:Eligibility(record,context) end
                        local addition=includeDungeons and dungeon
                        if eligible and self:StartPath(record,context,availability)
                            and (not addition or self:DungeonPath(record,context,availability)) then
                            if not self.currentItems[record.id] and A.Call(HaveQuestRewardData,record.id)==true then self:Reward(record) end
                            local match=query=="" or (record.title or ""):lower():find(query,1,true) or tostring(record.id):find(query,1,true)
                            local items={}
                            for _,meta in ipairs(self.currentItems[record.id] or record.items) do
                                local item=self:Item(meta)
                                if item.state~="ready" and not needSet[item.itemID] then needSet[item.itemID]=true; self.needed[#self.needed+1]=item.itemID end
                                local usable=self.usability[record.id] and self.usability[record.id][item.itemID]
                                local capability
                                if filter.usable and N.Ranking and N.Ranking.Usable then capability=N.Ranking:Usable(item.itemID,context,rankingQuery) end
                                if S.SlotMatch(item.slot,slotFilter,context) and (not filter.usable or usable~=false and capability~=false and (not item.minimum or item.minimum<=context.level)) then
                                    items[#items+1]=item; match=match or (item.name or ""):lower():find(query,1,true)
                                        or (item.searchTypeText or ""):find(query,1,true)
                                end
                            end
                            if match and (#items>0 or slotFilter=="ALL" and self:Benefit(record)) then
                                local ranking=(sort=="UPGRADE" or sort=="BIGGEST") and N.Ranking and N.Ranking:Quest(items,context,slotFilter,rankingQuery)
                                    or {tier=2,state="unsupported"}
                                out[#out+1]={id=record.id,title=record.title,level=record.level,items=items,evidence=note,
                                    fit=math.abs(record.level-context.level),category=category and category.name,
                                    currentZone=sameZone,dungeon=dungeon,ranking=ranking}
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(out,function(a,b)
        if sort=="UPGRADE" or sort=="BIGGEST" then
            local ar,br=a.ranking,b.ranking
            if ar.tier~=br.tier then return ar.tier<br.tier end
            if ar.state=="ready" and br.state=="ready" and M.Number(ar.gain) and M.Number(br.gain) and ar.gain~=br.gain then return ar.gain>br.gain end
        end
        if sort=="LEVEL" and a.level~=b.level then return a.level<b.level end
        if sort~="LEVEL" and sort~="TITLE" and a.fit~=b.fit then return a.fit<b.fit end
        if (a.title or "")~=(b.title or "") then return (a.title or "")<(b.title or "") end
        return a.id<b.id
    end)
    return out,status
end
function S:Reward(row)
    local reward=N.Rewards.Read(row.id)
    local verified={}
    self.usability[row.id]=self.usability[row.id] or {}; local changed=false
    if reward.state=="ready" then
        local items,stamp={},{}
        for _,group in ipairs({reward.items,reward.choices}) do for _,item in ipairs(group.items or {}) do
            if item.state=="ready" and item.itemID then
                items[#items+1]={itemID=item.itemID,name=item.name,quantity=item.quantity,group=item.kind}
                stamp[#stamp+1]=tostring(item.itemID)..":"..tostring(item.quantity)..":"..tostring(item.kind)
            end
        end end
        table.sort(stamp); stamp=table.concat(stamp,",")
        items.benefit=rewardBenefit(reward)
        changed=self.currentStamp[row.id]~=stamp or self.currentItems[row.id] and self.currentItems[row.id].benefit~=items.benefit
        self.currentStamp[row.id],self.currentItems[row.id]=stamp,items
    elseif self.currentItems[row.id] then self.currentItems[row.id],self.currentStamp[row.id]=nil,nil; changed=true end
    for _,group in ipairs({reward.items,reward.choices}) do for _,item in ipairs(group.items or {}) do if item.state=="ready" then
        verified[item.itemID]=true; changed=changed or self.usability[row.id][item.itemID]~=item.usable; self.usability[row.id][item.itemID]=item.usable
    end end end
    local pending={}
    if reward.state~="ready" and not reward.recordedGroups then for _,item in ipairs(row.items) do if not verified[item.itemID] then pending[#pending+1]=item end end end
    return reward,pending,changed
end
function S.Waypoint(location)
    if not location or not M.QuestId(location.mapID) or not M.Number(location.x) or not M.Number(location.y) or location.x<0 or location.x>1 or location.y<0 or location.y>1 then return false end
    if A.Call(C_Map and C_Map.CanSetUserWaypointOnMap,location.mapID)~=true or not UiMapPoint or type(UiMapPoint.CreateFromCoordinates)~="function" then return false end
    local point=A.Call(UiMapPoint.CreateFromCoordinates,location.mapID,location.x,location.y)
    if not point or A.Call(C_Map and C_Map.SetUserWaypoint,point)~=true then return false end
    A.Call(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint,true); return true
end
function S.Coordinates(location)
    if not location or not location.x or not location.y or not location.mapID then return end
    return string.format("%s %.1f, %.1f",location.zone or ("Map "..location.mapID),location.x*100,location.y*100)
end
function S.Wowhead(id)
    if M.QuestId(id) and N.Catalog.records[id] then return "https://www.wowhead.com/forever/quest="..id end
end

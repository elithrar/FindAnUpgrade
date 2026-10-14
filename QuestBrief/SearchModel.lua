local _, N = ...
local M,A=N.Model,N.Adapter
local S={cache={},usability={},currentItems={},currentStamp={}}; N.SearchModel=S
S.slots={{"ALL","All slots"},{"MISSING","Empty slots"},{"INVTYPE_HEAD","Head"},{"INVTYPE_NECK","Neck"},{"INVTYPE_SHOULDER","Shoulder"},{"INVTYPE_CLOAK","Back"},{"CHEST","Chest"},{"INVTYPE_WRIST","Wrist"},{"INVTYPE_HAND","Hands"},{"INVTYPE_WAIST","Waist"},{"INVTYPE_LEGS","Legs"},{"INVTYPE_FEET","Feet"},{"INVTYPE_FINGER","Ring"},{"INVTYPE_TRINKET","Trinket"},{"WEAPON","Weapon"},{"OFFHAND","Off hand"},{"RANGED","Ranged"}}
local function returns(fn,...)
    if type(fn)~="function" then return end
    local function pack(...) return {n=select("#",...),...} end
    local values=pack(pcall(fn,...)); if values[1] then return unpack(values,2,values.n) end
end
function S:Context()
    local _,token,class=returns(UnitClass,"player"); local _,_,race=returns(UnitRace,"player")
    return {level=A.Call(UnitLevel,"player"),classID=M.QuestId(class),classToken=M.Text(token),raceID=M.QuestId(race),faction=M.Text(A.Call(UnitFactionGroup,"player"))}
end
function S:Eligibility(row,context)
    if A.Call(C_QuestLog and C_QuestLog.IsOnQuest,row.id)==true then return true,"In quest log" end
    local source=row.source or {}; local unknown=source.eligibilityUnknown
    if source.faction and context.faction and source.faction~=context.faction then return false end
    if source.classTokens and #source.classTokens>0 then
        local matched=false; for _,token in ipairs(source.classTokens) do if token==context.classToken then matched=true end end
        if context.classToken and not matched then return false end
        if not context.classToken then unknown=true end
    end
    for _,pair in ipairs({{source.classes,context.classID},{source.races,context.raceID}}) do
        if type(pair[1])=="table" and #pair[1]>0 then
            local matched=false; for _,id in ipairs(pair[1]) do if id==pair[2] then matched=true end end
            if pair[2] and not matched then return false end
            if not pair[2] then unknown=true end
        end
    end
    local complete=A.Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,row.id)
    local repeatable=A.Call(C_QuestLog and C_QuestLog.IsRepeatableQuest,row.id)
    if complete==true and repeatable==false then return false end
    if complete==true and repeatable~=true then return false end
    if A.Call(C_QuestLog and C_QuestLog.IsQuestDisabledForSession,row.id)==true then return false end
    local low,high=source.minimum,source.maximum
    if M.Number(context.level) and M.Number(low) and low>context.level then return true,"Recorded minimum level "..low end
    if M.Number(context.level) and M.Number(high) and high>0 and high<context.level then return false end
    local function completed(id)
        id=M.Number(id) and M.QuestId(math.abs(id)); if not id then return nil end
        return A.Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,id)
    end
    local group,single=source.prerequisites,source.prerequisiteAlternatives
    if single==nil and M.Readable(group) and type(group)=="table" and #group<=128 then
        local doneCount,unreadable=0,0
        for _,id in ipairs(group) do
            local done=completed(id)
            if done==false then
                local previous=M.QuestId(id) and N.Catalog.records[id]; local alternatives=previous and previous.source.exclusive; local alternate=false
                if M.Readable(alternatives) and type(alternatives)=="table" and #alternatives<=128 then for _,other in ipairs(alternatives) do if completed(other)==true then alternate=true end end end
                if alternate then doneCount=doneCount+1 end
            elseif done==true then doneCount=doneCount+1 else unreadable=unreadable+1 end
        end
        local required=source.prerequisiteCount or #group
        if doneCount+unreadable<required then return true,"Prerequisites unconfirmed" end
        unknown=unknown or unreadable>0
    elseif single==nil and group~=nil then unknown=true end
    if M.Readable(single) and type(single)=="table" and #single>0 and #single<=128 then
        local any,unreadable=false,false
        for _,id in ipairs(single) do local done=completed(id); any=any or done==true; unreadable=unreadable or done==nil end
        if not any and not unreadable then return true,"Prerequisites unconfirmed" end
        unknown=unknown or unreadable
    elseif single~=nil then unknown=true end
    -- The catalogue is not an authoritative server availability API. Profession,
    -- reputation, phases and special chains require later native confirmation.
    return true,complete==true and "Repeatable - availability unconfirmed" or unknown and "Availability unconfirmed" or "Availability unconfirmed"
end
function S:Item(meta)
    local id=meta.itemID
    if self.cache[id] and (self.cache[id].state=="ready" or A.Call(C_Item and C_Item.IsItemDataCachedByID,id)~=true) then return self.cache[id] end
    local row={itemID=id,name=meta.name,kind="catalog",state="pending",catalog=true,quantity=meta.quantity,group=meta.group}
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    local name,link,quality,level,minimum,slot,texture
    if A.Call(C_Item and C_Item.IsItemDataCachedByID,id)==true then
        local values={returns(fn,id)}
        name,link,quality,level,minimum,slot,texture=values[1],values[2],values[3],values[4],values[5],values[9],values[10]
    end
    if M.Text(name) and M.Text(link) and M.Number(quality) and quality>=0 and quality<=8 and M.Readable(slot) and type(slot)=="string" and (M.Text(texture) or M.Number(texture)) then
        row.name,row.link,row.quality,row.itemLevel,row.minimum,row.slot,row.texture,row.state=name,link,quality,M.Number(level) and level or nil,M.Number(minimum) and minimum or nil,slot,texture,"ready"
    else
        local _,_,_,instantSlot,icon=returns(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,id)
        row.slot=M.Text(instantSlot); row.texture=M.Text(icon) or M.Number(icon) and icon or nil
    end
    self.cache[id]=row; return row
end
function S.SlotMatch(slot,filter)
    if filter=="ALL" then return true end
    if not slot then return false end
    if filter=="MISSING" then return S.EmptySlot(slot) end
    if filter=="CHEST" then return slot=="INVTYPE_CHEST" or slot=="INVTYPE_ROBE" end
    if filter=="WEAPON" then return slot=="INVTYPE_WEAPON" or slot=="INVTYPE_WEAPONMAINHAND" or slot=="INVTYPE_2HWEAPON" end
    if filter=="OFFHAND" then return slot=="INVTYPE_SHIELD" or slot=="INVTYPE_HOLDABLE" or slot=="INVTYPE_WEAPONOFFHAND" end
    if filter=="RANGED" then return slot=="INVTYPE_RANGED" or slot=="INVTYPE_RANGEDRIGHT" or slot=="INVTYPE_THROWN" end
    return slot==filter
end
local inventorySlots={INVTYPE_HEAD={"HeadSlot"},INVTYPE_NECK={"NeckSlot"},INVTYPE_SHOULDER={"ShoulderSlot"},INVTYPE_CLOAK={"BackSlot"},INVTYPE_CHEST={"ChestSlot"},INVTYPE_ROBE={"ChestSlot"},INVTYPE_WRIST={"WristSlot"},INVTYPE_HAND={"HandsSlot"},INVTYPE_WAIST={"WaistSlot"},INVTYPE_LEGS={"LegsSlot"},INVTYPE_FEET={"FeetSlot"},INVTYPE_FINGER={"Finger0Slot","Finger1Slot"},INVTYPE_TRINKET={"Trinket0Slot","Trinket1Slot"},INVTYPE_WEAPON={"MainHandSlot"},INVTYPE_WEAPONMAINHAND={"MainHandSlot"},INVTYPE_2HWEAPON={"MainHandSlot"},INVTYPE_WEAPONOFFHAND={"SecondaryHandSlot"},INVTYPE_SHIELD={"SecondaryHandSlot"},INVTYPE_HOLDABLE={"SecondaryHandSlot"},INVTYPE_RANGED={"RangedSlot"},INVTYPE_RANGEDRIGHT={"RangedSlot"},INVTYPE_THROWN={"RangedSlot"}}
function S.EmptySlot(slot)
    if not ItemLocation or type(ItemLocation.CreateFromEquipmentSlot)~="function" then return false end
    for _,name in ipairs(inventorySlots[slot] or {}) do
        local index=M.QuestId(A.Call(GetInventorySlotInfo,name))
        local location=index and A.Call(ItemLocation.CreateFromEquipmentSlot,ItemLocation,index)
        if location and A.Call(C_Item and C_Item.DoesItemExist,location)==false then return true end
    end
    return false
end
function S:Query(filter)
    local out={}; self.needed={}; self.questNeeded={}; self.unknownLevels=0; local needSet={}; local context=self:Context(); local query=(filter.query or ""):lower()
    if not M.Number(context.level) or context.level<1 then return out,"Player level unavailable" end
    for _,record in ipairs(N.Catalog.order) do
        if not N.Catalog:Metadata(record,context.level) then self.questNeeded[#self.questNeeded+1]=record.id end
        if not M.Number(record.level) or record.level<1 then self.unknownLevels=self.unknownLevels+1 end
        if M.Number(record.level) and record.level>=filter.minimum and record.level<=filter.maximum then
            local eligible,note=self:Eligibility(record,context)
            if eligible then
                if not self.currentItems[record.id] and A.Call(HaveQuestRewardData,record.id)==true then self:Reward(record) end
                local match=query=="" or (record.title or ""):lower():find(query,1,true) or tostring(record.id):find(query,1,true)
                local items={}
                for _,meta in ipairs(self.currentItems[record.id] or record.items) do
                    local item=self:Item(meta)
                    if item.state~="ready" and not needSet[item.itemID] then needSet[item.itemID]=true; self.needed[#self.needed+1]=item.itemID end
                    local usable=self.usability[record.id] and self.usability[record.id][item.itemID]
                    if S.SlotMatch(item.slot,filter.slot) and (not filter.usable or usable~=false and (not item.minimum or item.minimum<=context.level)) then
                        items[#items+1]=item; match=match or (item.name or ""):lower():find(query,1,true)
                    end
                end
                if match and #items>0 then out[#out+1]={id=record.id,title=record.title,level=record.level,items=items,evidence=note,fit=math.abs(record.level-context.level)} end
            end
        end
    end
    table.sort(out,function(a,b)
        if filter.sort=="LEVEL" and a.level~=b.level then return a.level<b.level end
        if filter.sort~="LEVEL" and a.fit~=b.fit then return a.fit<b.fit end
        if (a.title or "")~=(b.title or "") then return (a.title or "")<(b.title or "") end
        return a.id<b.id
    end)
    return out
end
function S:Reward(row)
    local reward=N.Rewards.Read(row.id)
    local verified={}
    self.usability[row.id]=self.usability[row.id] or {}; local changed=false
    local authoritative=reward.state=="ready" and reward.items.state=="ready" and reward.choices.state=="ready"
    if authoritative then
        local items,stamp={},{}
        for _,group in ipairs({reward.items,reward.choices}) do for _,item in ipairs(group.items or {}) do
            items[#items+1]={itemID=item.itemID,name=item.name}; stamp[#stamp+1]=tostring(item.itemID)
        end end
        table.sort(stamp); stamp=table.concat(stamp,",")
        changed=self.currentStamp[row.id]~=stamp; self.currentStamp[row.id],self.currentItems[row.id]=stamp,items
    elseif self.currentItems[row.id] then self.currentItems[row.id],self.currentStamp[row.id]=nil,nil; changed=true end
    for _,group in ipairs({reward.items,reward.choices}) do for _,item in ipairs(group.items or {}) do if item.state=="ready" then
        verified[item.itemID]=true; changed=changed or self.usability[row.id][item.itemID]~=item.usable; self.usability[row.id][item.itemID]=item.usable
    end end end
    local pending={}
    if not authoritative then for _,item in ipairs(row.items) do if not verified[item.itemID] then pending[#pending+1]=item end end end
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

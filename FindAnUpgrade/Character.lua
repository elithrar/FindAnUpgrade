local _,N=...
local M,A=N.Model,N.Adapter

---@class FAUEquipment
---@field slot number Native equipment slot index.
---@field itemID number|nil Exact item identity; nil alone never means empty.
---@field link string|nil Exact equipped hyperlink, including suffix/enchant data.
---@field state string "empty", "pending", or "ready".
---@class FAUCharacterConstraints
---@field revision number Changes once per coherent non-quest capture or quest transition.
---@field identityRevision number
---@field locationRevision number
---@field questRevision number
---@field equipmentRevision number Empty-slot filtering and ranking share this dependency.
---@field itemRevision number Equipped metadata readiness changed.
---@field capabilityRevision number Invalidates derived item-use/proficiency evidence.
---@field level number|nil
---@field faction string|nil
---@field classID number|nil
---@field classToken string|nil
---@field guid string|nil Stable character identity for separate user preferences.
---@field raceID number|nil
---@field specID number|nil Forever class-wide identity, never a Retail role.
---@field talentGroup number|nil
---@field combatConfigID number|nil
---@field mapID number|nil
---@field mapHierarchy table Bounded native map hierarchy, nearest map first.
---@field zoneName string|nil
---@field instanceType string|nil
---@field instanceID number|nil
---@field equipment table<number, FAUEquipment>
---@field emptySlots table<number, boolean> Only explicit native empty proof is true.
---@field inventorySlots table<string, number> Native paper-doll name to slot index.
---@field quests table Copied active/offer maps; native facts use Character:Quest(id).
-- This session-only table contains character facts. User filter/weight preferences
-- belong to the finder/profile, never here. Consumers treat returned tables as
-- read-only; this owner commits complete domain captures before notifying them.
local C={dirty={identity=true,location=true,equipment=true},questLimit=12000,questFacts={},questTags={},equipmentStamps={}}
N.Character=C
C.snapshot={revision=0,identityRevision=0,locationRevision=0,questRevision=0,equipmentRevision=0,itemRevision=0,capabilityRevision=0,
    mapHierarchy={},equipment={},emptySlots={},inventorySlots={},quests={active={},offers={}},nativeOffers={}}
local slotNames={"HeadSlot","NeckSlot","ShoulderSlot","ShirtSlot","BackSlot","ChestSlot","WristSlot","HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot","RangedSlot","TabardSlot"}
local identityKeys={"level","faction","classID","classToken","raceID","guid","specID","talentGroup","combatConfigID"}
local locationKeys={"mapID","zoneName","instanceType","instanceID","mapHierarchy"}
local function returns(fn,...)
    if type(fn)~="function" then return end
    local function pack(...) return {n=select("#",...),...} end
    local value=pack(pcall(fn,...));if value[1] then return unpack(value,2,value.n) end
end
local function same(a,b)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table" then return false end
    for key,value in pairs(a) do if not same(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function copy(source)
    local result={};for key,value in pairs(source or {}) do result[key]=value end;return result
end
local function boolean(fn,id)
    local value=A.Call(fn,id);if type(value)=="boolean" then return value end
end
function C:Interested()
    return N.Search and N.Search:Visible() or N.Hover and N.Hover.open or false
end
function C:CaptureIdentity(levelPayload)
    local _,token,classID=returns(UnitClass,"player");local _,_,raceID=returns(UnitRace,"player")
    local spec=C_SpecializationInfo or {}
    local group=M.QuestId(A.Call(spec.GetActiveSpecGroup))
    local index=M.QuestId(A.Call(spec.GetSpecialization,false,false,group))
    return {level=levelPayload or M.QuestId(A.Call(UnitLevel,"player")),faction=M.Text(A.Call(UnitFactionGroup,"player")),
        classID=M.QuestId(classID),classToken=M.Text(token),raceID=M.QuestId(raceID),guid=M.Text(A.Call(UnitGUID,"player")),talentGroup=group,
        specID=index and M.QuestId(A.Call(spec.GetSpecializationInfo,index,false,false,nil,nil,group)),
        combatConfigID=group and M.QuestId(A.Call(spec.GetCombatConfigIDForSpecGroup,group))}
end
function C:CaptureLocation()
    local current=M.QuestId(A.Call(C_Map and C_Map.GetBestMapForUnit,"player"));local map=current
    local hierarchy,seen={},{}
    for _=1,8 do
        if not map or seen[map] then break end;seen[map]=true
        local info=A.Call(C_Map and C_Map.GetMapInfo,map)
        if not M.Readable(info) or type(info)~="table" then break end
        hierarchy[#hierarchy+1]={mapID=map,name=M.Text(info.name),mapType=M.Number(info.mapType) and info.mapType or nil}
        map=M.QuestId(info.parentMapID)
    end
    local _,instanceType,_,_,_,_,_,instanceID=returns(GetInstanceInfo)
    return {mapID=current,mapHierarchy=hierarchy,zoneName=hierarchy[1] and hierarchy[1].name,
        instanceType=M.Text(instanceType),instanceID=M.QuestId(instanceID)}
end
function C:CaptureEquipment()
    local equipped,empty,slots={},{},{}
    for _,name in ipairs(slotNames) do
        local slot=M.QuestId(A.Call(C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfo or GetInventorySlotInfo,name))
        if slot then
            slots[name]=slot
            local itemID=M.QuestId(A.Call(GetInventoryItemID,"player",slot))
            local link=M.Text(A.Call(GetInventoryItemLink,"player",slot))
            local location=ItemLocation and A.Call(ItemLocation.CreateFromEquipmentSlot,ItemLocation,slot)
            local exists=location and A.Call(C_Item and C_Item.DoesItemExist,location)
            local state="pending"
            -- A missing hyperlink can be uncached occupied gear. Only an explicit
            -- empty native location admits the empty-slot filter.
            if exists==false and not itemID and not link then state="empty";empty[slot]=true
            elseif itemID and link and A.Call(C_Item and C_Item.IsItemDataCachedByID,itemID)==true then state="ready" end
            equipped[slot]={slot=slot,itemID=itemID,link=link,state=state}
        end
    end
    return equipped,empty,slots
end
local function commitFields(snapshot,capture,keys)
    local changed=false
    for _,key in ipairs(keys) do if not same(snapshot[key],capture[key]) then changed=true end end
    if changed then for _,key in ipairs(keys) do snapshot[key]=capture[key] end end
    return changed
end
function C:Flush(notify)
    if not next(self.dirty) then return self.snapshot end
    if self.flushing then return self.snapshot end
    self.flushing=true
    local baseline=self.snapshot
    local snapshot,change=copy(baseline),{ids={},reason="character"}
    if self.dirty.identity then
        self.dirty.identity=nil
        local levelPayload=self.levelPayload
        if commitFields(snapshot,self:CaptureIdentity(levelPayload),identityKeys) then snapshot.identityRevision=snapshot.identityRevision+1;change.identity=true end
        if self.levelPayload==levelPayload then self.levelPayload=nil end
    end
    if self.dirty.location then
        self.dirty.location=nil
        if commitFields(snapshot,self:CaptureLocation(),locationKeys) then snapshot.locationRevision=snapshot.locationRevision+1;change.location=true end
    end
    if self.dirty.equipment then
        self.dirty.equipment=nil
        local equipped,empty,slots=self:CaptureEquipment()
        if not same(equipped,snapshot.equipment) or not same(empty,snapshot.emptySlots) or not same(slots,snapshot.inventorySlots) then
            -- Metadata stamps are valid only for the current exact equipped
            -- configuration. Do not retain one entry for every past item.
            for id in pairs(self.equipmentStamps) do
                local present,valid=false,true
                for slot,entry in pairs(equipped) do if entry.itemID==id then
                    present=true;local previous=snapshot.equipment[slot]
                    if not previous or previous.itemID~=id or previous.link~=entry.link then valid=false end
                end end
                for slot,entry in pairs(snapshot.equipment) do if entry.itemID==id then
                    local current=equipped[slot]
                    if not current or current.itemID~=id or current.link~=entry.link then valid=false end
                end end
                if not present or not valid then self.equipmentStamps[id]=nil end
            end
            snapshot.equipment,snapshot.emptySlots,snapshot.inventorySlots=equipped,empty,slots
            snapshot.equipmentRevision=snapshot.equipmentRevision+1;change.equipment=true
            if self.pendingItem then snapshot.itemRevision=snapshot.itemRevision+1;change.items=true end
        end
        self.pendingItem=nil
    end
    if self.dirty.metadata then
        self.dirty.metadata=nil
        local changed=false
        for id,pending in pairs(self.pendingMetadata or {}) do
            if pending.revision==snapshot.equipmentRevision then
                local current=false
                for _,entry in pairs(snapshot.equipment) do if entry.itemID==id then current=true;break end end
                if current and self.equipmentStamps[id]~=pending.stamp then self.equipmentStamps[id]=pending.stamp;changed=true end
            end
        end
        self.pendingMetadata=nil
        if changed then
            snapshot.itemRevision=snapshot.itemRevision+1;snapshot.equipmentRevision=snapshot.equipmentRevision+1
            change.equipment,change.items=true,true
        end
    end
    if self.dirty.capabilities then
        self.dirty.capabilities=nil
        -- These native events invalidate item-use/proficiency evidence; there
        -- is no cheap complete spellbook equality contract. Record one evidence
        -- invalidation per burst, rather than pretending to capture new spells.
        snapshot.capabilityRevision=snapshot.capabilityRevision+1;change.capabilities=true
    end
    if self.dirty.worldQuests then
        self.dirty.worldQuests=nil
        -- Re-entering the world invalidates previously observed completion and
        -- offer evidence even when level/map/equipment compare equal. Reuse the
        -- bounded observation set; never scan the catalogue for a world event.
        for id in pairs(self.questFacts) do change.ids[id]=true end
        for id in pairs(snapshot.quests.active) do change.ids[id]=true end
        for id in pairs(snapshot.quests.offers) do change.ids[id]=true end
        self.questFacts={};self.questFactCount=0
        snapshot.questRevision=snapshot.questRevision+1;change.quests=true
    end
    self.flushing=false
    if next(self.dirty) then self:Wake() end
    if change.identity or change.location or change.equipment or change.capabilities or change.quests then
        -- A synchronous native hook may have delivered a quest transition while
        -- these non-quest families were being read. Preserve that publication.
        if self.snapshot~=baseline then
            snapshot.quests,snapshot.nativeOffers=self.snapshot.quests,self.snapshot.nativeOffers
            snapshot.questRevision=self.snapshot.questRevision+(snapshot.questRevision-baseline.questRevision)
            snapshot.revision=self.snapshot.revision
        end
        snapshot.revision=snapshot.revision+1;change.revision=snapshot.revision
        self.snapshot=snapshot
        if change.identity or change.location then self.questFacts={};self.questFactCount=0 end
        if notify then
            local quests=N.QuestState
            if quests and quests.initialized and (change.location or change.quests) then
                if quests.stale or change.quests then quests:Prime() else quests:OfferChanged() end
            end
            if change.quests then
                local current=self.snapshot.quests
                for id in pairs(current.active) do change.ids[id]=true end
                for id in pairs(current.offers) do change.ids[id]=true end
                local evidence={ids=change.ids,reason="world-entry",revision=self.snapshot.questRevision}
                if N.Search and N.Search.QuestChanged then N.Search:QuestChanged(evidence) end
                if N.Hover and N.Hover.QuestChanged then N.Hover:QuestChanged(evidence) end
            end
            if N.Search and N.Search.CharacterChanged then N.Search:CharacterChanged(change) end
            if N.Hover and N.Hover.CharacterChanged then N.Hover:CharacterChanged(change) end
        end
    end
    return self.snapshot,change
end
function C:Wake()
    if not self.events then return end
    if not self:Interested() then self.events:SetScript("OnUpdate",nil);return end
    if self.events:GetScript("OnUpdate") then return end
    self.events:SetScript("OnUpdate",function(frame)
        frame:SetScript("OnUpdate",nil)
        if self:Interested() then self:Flush(true) end
    end)
end
function C:Sleep()
    if self.events and not self:Interested() then self.events:SetScript("OnUpdate",nil) end
end
function C:Mark(domain)
    self.dirty[domain]=true;self:Wake()
end
function C:Ensure(primeQuests)
    -- A native getter/post-hook can synchronously request this context while a
    -- capture is in progress. Keep its newly queued work and return the last
    -- complete published snapshot, rather than cancelling its updater.
    if self.flushing then return self.snapshot end
    if not self.initialized then self:Initialize() end
    if next(self.dirty) then
        if self.events then self.events:SetScript("OnUpdate",nil) end
        -- A provider/context read can run before the queued next-frame update.
        -- It must not consume a visible transition without its notification.
        self:Flush(self:Interested())
    end
    local quests=N.QuestState
    if quests and (quests.stale or primeQuests) and quests.Prime then quests:Prime() end
    if quests and not self.questPrimed then self:PrimeQuests(quests.active,quests.offers,true) end
    return self.snapshot
end
function C:Get() return self:Ensure() end
-- QuestState owns registration, bounded log scanning and event de-duplication.
-- These bridges publish its already-observed facts; never register a second log
-- listener or scan the entire catalogue to discover active quests.
function C:PrimeQuests(active,offers,reset,quiet)
    self.questPrimed=true
    if reset then self.questFacts={};self.questFactCount=0 end
    local prior=self.snapshot.quests;active,offers=active or {},offers or {}
    if same(prior.active,active) and same(prior.offers,offers) then return end
    local snapshot=copy(self.snapshot)
    snapshot.quests={active=copy(active),offers=copy(offers)};snapshot.nativeOffers=snapshot.quests.offers
    if not quiet then snapshot.questRevision=snapshot.questRevision+1;snapshot.revision=snapshot.revision+1 end
    self.snapshot=snapshot
end
function C:QuestChanged(change)
    if not change or not next(change.ids or {}) then return end
    local quests=N.QuestState
    if quests then self:PrimeQuests(quests.active,quests.offers,false,true) end
    for id in pairs(change.ids or {}) do
        if self.questFacts[id] then self.questFacts[id]=nil;self.questFactCount=math.max(0,(self.questFactCount or 0)-1) end
    end
    local snapshot=copy(self.snapshot)
    snapshot.questRevision=snapshot.questRevision+1;snapshot.revision=snapshot.revision+1;self.snapshot=snapshot
end
function C:EquipmentMetadata(id,stamp,expectedEquipmentRevision)
    id=M.QuestId(id);stamp=M.Text(stamp)
    if not id or not stamp or #stamp>8192 or expectedEquipmentRevision~=self.snapshot.equipmentRevision then return false end
    local current=false
    for _,entry in pairs(self.snapshot.equipment) do if entry.itemID==id then current=true;break end end
    if not current or self.equipmentStamps[id]==stamp then return false end
    self.pendingMetadata=self.pendingMetadata or {}
    self.pendingMetadata[id]={stamp=stamp,revision=expectedEquipmentRevision};self:Mark("metadata")
    return true
end
function C:Quest(id)
    id=M.QuestId(id);if not id then return {} end
    local snapshot=self:Ensure();local facts=self.questFacts
    if facts[id] then return facts[id] end
    if (self.questFactCount or 0)>=self.questLimit then return {} end
    local log=C_QuestLog or {};local known=snapshot.quests.active[id]
    local active=known~=nil and true or boolean(log.IsOnQuest,id)
    local complete
    if active==true then if known~=nil then complete=known else complete=boolean(log.IsComplete,id) end end
    local entry={active=active,complete=complete,
        completed=boolean(log.IsQuestFlaggedCompleted,id),repeatable=boolean(log.IsRepeatableQuest,id),disabled=boolean(log.IsQuestDisabledForSession,id)}
    facts[id]=entry;self.questFactCount=(self.questFactCount or 0)+1
    return entry
end
function C:Proof(id,npcID)
    -- Exact live gossip identity is scoped by QuestState. A generic map proof
    -- never acquires the authority of a particular opposing-faction starter.
    return N.QuestState and A.Call(N.QuestState.Proof,N.QuestState,id,npcID)
end
function C:QuestTag(id)
    id=M.QuestId(id);if not id then return end
    local cached=self.questTags[id];if cached then return cached.tagID end
    if (self.questTagCount or 0)>=self.questLimit then return end
    local info=A.Call(C_QuestLog and C_QuestLog.GetQuestTagInfo,id)
    local tag=M.Readable(info) and type(info)=="table" and M.QuestId(info.tagID) or nil
    self.questTags[id]={tagID=tag};self.questTagCount=(self.questTagCount or 0)+1
    return tag
end
function C:QuestMetadata(id)
    id=M.QuestId(id);local before=id and self.questTags[id];if not before then return false end
    self.questTags[id]=nil;self.questTagCount=math.max(0,(self.questTagCount or 0)-1)
    if not self:Interested() then return false end
    local tag=self:QuestTag(id);local changed=tag~=before.tagID
    if changed then
        local snapshot=copy(self.snapshot);snapshot.questRevision=snapshot.questRevision+1;snapshot.revision=snapshot.revision+1;self.snapshot=snapshot
    end
    return changed
end
function C:ItemData(id,success)
    id=M.QuestId(id);if not id or success==false then return end
    local current=false
    for _,entry in pairs(self.snapshot.equipment) do if entry.itemID==id then current=true;break end end
    if not current then return end
    -- Re-capture actual equipped identities before consuming an async response.
    -- If the user equipped another item meanwhile, this cannot resurrect it.
    self.pendingItem=true;self:Mark("equipment")
end
function C:Event(event,arg,success)
    if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" then self:ItemData(arg,success)
    elseif event=="PLAYER_EQUIPMENT_CHANGED" then self:Mark("equipment")
    elseif event=="SPELLS_CHANGED" or event=="SKILL_LINES_CHANGED" then self:Mark("capabilities")
    elseif event=="PLAYER_LEVEL_UP" then self.levelPayload=M.QuestId(arg);self:Mark("identity")
    elseif event=="ACTIVE_TALENT_GROUP_CHANGED" or event=="PLAYER_TALENT_UPDATE"
        or event=="PLAYER_SPECIALIZATION_CHANGED" and arg=="player" then self:Mark("identity")
    elseif event=="ZONE_CHANGED" or event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED_INDOORS" then self:Mark("location")
    elseif event=="PLAYER_ENTERING_WORLD" then
        if N.QuestState then N.QuestState.stale=true end
        self.dirty.identity,self.dirty.location,self.dirty.equipment,self.dirty.worldQuests=true,true,true,true;self:Wake()
    end
end
function C:Initialize()
    if self.initialized then return end;self.initialized=true
    local frame=CreateFrame("Frame");self.events=frame
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED_INDOORS","PLAYER_LEVEL_UP",
        "PLAYER_EQUIPMENT_CHANGED","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_TALENT_UPDATE","PLAYER_SPECIALIZATION_CHANGED","ITEM_DATA_LOAD_RESULT","GET_ITEM_INFO_RECEIVED","SPELLS_CHANGED","SKILL_LINES_CHANGED"}) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent",function(_,event,arg,success) self:Event(event,arg,success) end)
end

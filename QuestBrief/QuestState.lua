local _,N=...
local M,A=N.Model,N.Adapter
local Q={active={},offers={},revision=0,activeCount=0,signals={},signalSlots={},signalCursor=1};N.QuestState=Q
local nativeProof={['native-active']=true,['native-ready']=true,['native-available']=true,['native-map-available']=true}
local function boolean(fn,id)
    local value=A.Call(fn,id);if type(value)=="boolean" then return value end
end
local function entries(fn)
    local value=A.Call(fn)
    if M.Readable(value) and type(value)=="table" and #value<=256 then return value end
    return {}
end
function Q:Track(id)
    id=M.QuestId(id);if not id or self.active[id]~=nil or self.activeCount>=512 then return end
    -- Called only after the provider has already observed IsOnQuest=true.
    -- This learns initially collapsed log entries without a catalogue scan.
    self.active[id]=boolean(C_QuestLog and C_QuestLog.IsComplete,id)==true;self.activeCount=self.activeCount+1
end
function Q:NativeOffers()
    local out={};local sources=N.Sources
    local map=M.QuestId(A.Call(C_Map and C_Map.GetBestMapForUnit,"player"))
    local mapOffers=map and A.Call(C_QuestLine and C_QuestLine.GetAvailableQuestLines,map)
    if M.Readable(mapOffers) and type(mapOffers)=="table" and #mapOffers<=256 then
        for _,offer in ipairs(mapOffers) do
            if M.Readable(offer) and type(offer)=="table" and M.QuestId(offer.questID) and M.Readable(offer.inProgress) and offer.inProgress==false then out[offer.questID]="native-map-available" end
        end
    end
    local gossip=sources and sources.gossip
    local gossipGUID=gossip and M.Text(gossip.guid)
    if gossipGUID and gossipGUID==M.Text(A.Call(UnitGUID,"npc")) then
        for _,spec in ipairs({{"GetAvailableQuests","native-available"},{"GetActiveQuests","native-active"}}) do
            for _,entry in ipairs(entries(C_GossipInfo and C_GossipInfo[spec[1]])) do
                if M.Readable(entry) and type(entry)=="table" and M.QuestId(entry.questID) then
                    out[entry.questID]=spec[2]=="native-active" and M.Readable(entry.isComplete) and entry.isComplete==true and "native-ready" or spec[2]
                end
            end
        end
    end
    local source=sources and sources.current
    if source and source.surface=="worldmap" and A.Call(source.valid)==true then
        for _,row in ipairs(M.Entries(source.rows)) do
            local proof=row.availabilityProof
            if row.availabilityCheck then proof=A.Call(row.availabilityCheck) end
            proof=M.Text(proof);if proof and nativeProof[proof] and M.QuestId(row.id) then out[row.id]=proof end
        end
    end
    return out
end
function Q:Proof(id,npcID)
    -- Availability reads must not turn a previous hover/gossip into permanent
    -- evidence. Recheck only the requested current native association.
    local sources=N.Sources;local gossip=sources and sources.gossip
    local gossipGUID=gossip and M.Text(gossip.guid)
    local gossipNPC=gossipGUID and M.QuestId(tonumber(gossipGUID:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")))
    if gossipGUID and (not npcID or gossipNPC==npcID) and gossipGUID==M.Text(A.Call(UnitGUID,"npc")) then
        local proof=A.Call(sources.GossipAvailability,sources,gossip.guid,id)
        proof=M.Text(proof);if proof and nativeProof[proof] then return proof end
    end
    if npcID then return end
    local source=sources and sources.current
    if source and source.surface=="worldmap" and A.Call(source.valid)==true then
        for _,row in ipairs(M.Entries(source.rows)) do
            if row.id==id then
                local proof=row.availabilityProof
                if row.availabilityCheck then proof=A.Call(row.availabilityCheck) end
                proof=M.Text(proof);if proof and nativeProof[proof] then return proof end
            end
        end
    end
end
function Q:Capture()
    local log=C_QuestLog or {};local found={}
    local count=A.Call(log.GetNumQuestLogEntries)
    if M.Number(count) and count>=0 and count<=512 and count==math.floor(count) then
        for index=1,count do
            local info=A.Call(log.GetInfo,index)
            if M.Readable(info) and type(info)=="table" and M.Readable(info.isHeader) and info.isHeader~=true then
                local id=M.QuestId(info.questID);if id then found[id]=true end
            end
        end
    end
    -- Collapsed headers can hide existing entries. Absence from GetInfo is
    -- never enough to call a quest removed; confirm with IsOnQuest instead.
    for id in pairs(self.active) do found[id]=true end
    local foundCount=0;for _ in pairs(found) do foundCount=foundCount+1 end
    if foundCount>512 then return self.active,self:NativeOffers() end
    local active={}
    for id in pairs(found) do
        local onQuest=boolean(log.IsOnQuest,id)
        if onQuest==true or onQuest==nil and self.active[id]~=nil then
            local complete=boolean(log.IsComplete,id)
            if complete==nil then complete=self.active[id] end
            active[id]=complete==true
        end
    end
    return active,self:NativeOffers()
end
local function differences(before,after,ids)
    for id,value in pairs(before) do if after[id]~=value then ids[id]=true end end
    for id,value in pairs(after) do if before[id]~=value then ids[id]=true end end
end
function Q:Dispatch(ids,reason)
    if not next(ids) then return end
    self.revision=self.revision+1
    local change={ids=ids,reason=reason,revision=self.revision}
    if N.Search and N.Search.QuestChanged then N.Search:QuestChanged(change) end
    if N.Hover and N.Hover.QuestChanged then N.Hover:QuestChanged(change) end
    return change
end
function Q:Interested()
    return N.Search and N.Search:Visible() or N.Hover and N.Hover.open or false
end
function Q:Prime()
    self.active,self.offers=self:Capture();self.activeCount=0
    for _ in pairs(self.active) do self.activeCount=self.activeCount+1 end
    self.stale=false;self.signals={};self.signalSlots={};self.signalCursor=1
end
function Q:Observe()
    if not self:Interested() then self.stale=true;return end
    local active,offers=self:Capture();local ids={}
    differences(self.active,active,ids);differences(self.offers,offers,ids)
    for id in pairs(ids) do self.signals[id]=nil end
    self.active,self.offers=active,offers;self.activeCount=0
    for _ in pairs(active) do self.activeCount=self.activeCount+1 end
    return self:Dispatch(ids,"log-state")
end
function Q:OfferChanged()
    if not self.initialized then return end
    if not self:Interested() then self.stale=true;return end
    local offers=self:NativeOffers();local ids={}
    differences(self.offers,offers,ids);self.offers=offers
    return self:Dispatch(ids,"native-offer")
end
function Q:Signal(event,id)
    id=M.QuestId(id);if not id then return end
    if not self:Interested() then self.stale=true;return end
    -- Track() may learn a just-accepted quest before its event is delivered.
    -- De-duplicate explicit events independently of that baseline seeding.
    if self.signals[id]==event then return end
    if not self.signals[id] then
        local old=self.signalSlots[self.signalCursor];if old then self.signals[old]=nil end
        self.signalSlots[self.signalCursor]=id;self.signalCursor=self.signalCursor%512+1
    end
    self.signals[id]=event
    if event=="QUEST_ACCEPTED" then
        local complete=boolean(C_QuestLog and C_QuestLog.IsComplete,id)==true
        if self.active[id]==nil and self.activeCount<512 then self.activeCount=self.activeCount+1;self.active[id]=complete
        elseif self.active[id]~=nil then self.active[id]=complete end
    elseif event=="QUEST_REMOVED" then
        if self.active[id]~=nil then self.activeCount=self.activeCount-1 end;self.active[id]=nil
    elseif event=="QUEST_TURNED_IN" then
        if self.active[id]~=nil then self.activeCount=self.activeCount-1 end;self.active[id]=nil
    end
    return self:Dispatch({[id]=true},event)
end
function Q:Initialize()
    if self.initialized then return end
    self:Prime();self.initialized=true
    local f=CreateFrame("Frame");self.events=f
    for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN"}) do f:RegisterEvent(event) end
    f:SetScript("OnEvent",function(_,event,id)
        if event=="QUEST_LOG_UPDATE" then self:Observe() else self:Signal(event,id) end
    end)
end

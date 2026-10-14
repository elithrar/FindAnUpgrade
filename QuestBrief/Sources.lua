local _, N = ...
local M, A = N.Model, N.Adapter
local S = { hooked = setmetatable({}, { __mode = "k" }), identities = setmetatable({}, { __mode = "k" }) }; N.Sources = S
function S:Key(frame, signature, data)
    local identity = self.identities[frame]
    if not identity or identity.signature ~= signature or identity.data ~= data then
        identity = { signature=signature, data=data, key={} }; self.identities[frame]=identity
    end
    return identity.key
end
function S:NPC()
    local guid = M.Text(A.Call(UnitGUID, "mouseover"))
    if not guid then return end
    local npcID = M.QuestId(tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")))
    if not npcID then return end
    local rows = {}
    if self.gossip and self.gossip.guid == guid then rows = N.Providers.ResolveRows(self.gossip.rows) end
    if #rows == 0 then rows = N.Providers.ForNPC(npcID) end
    if #rows == 0 then return end
    return { key = guid, surface = "npc", rows = rows, valid = function() return true end,
        over = function() return M.Text(A.Call(UnitGUID, "mouseover")) == guid end }
end
function S:Gossip()
    local guid = M.Text(A.Call(UnitGUID, "npc"))
    self.gossip = nil
    if not guid then return end
    local rows = {}
    for _, spec in ipairs({ { "GetAvailableQuests", "native-available" }, { "GetActiveQuests", "native-active" } }) do
        local list = A.Call(C_GossipInfo and C_GossipInfo[spec[1]])
        if M.Readable(list) and type(list) == "table" and #list <= 256 then
            for _, entry in ipairs(list) do
                if M.Readable(entry) and type(entry) == "table" and M.QuestId(entry.questID) then
                    local proof=spec[2]
                    if proof=="native-active" and M.Readable(entry.isComplete) and entry.isComplete==true then proof="native-ready" end
                    local id=entry.questID
                    rows[#rows+1]={id=id,title=M.Text(entry.title),availabilityProof=proof,
                        availabilityCheck=function() return self:GossipAvailability(guid,id) end,provenance="Current native gossip session"}
                end
            end
        end
    end
    self.gossip={guid=guid,rows=rows}
    self.gossip.rows=N.Providers.ResolveRows(rows)
end
function S:GossipAvailability(guid,id)
    if not self.gossip or self.gossip.guid~=guid or M.Text(A.Call(UnitGUID,"npc"))~=guid then return end
    for _,spec in ipairs({{"GetActiveQuests","native-active"},{"GetAvailableQuests","native-available"}}) do
        local list=A.Call(C_GossipInfo and C_GossipInfo[spec[1]])
        if M.Readable(list) and type(list)=="table" and #list<=256 then
            for _,entry in ipairs(list) do
                if M.Readable(entry) and type(entry)=="table" and M.QuestId(entry.questID)==id then
                    return spec[2]=="native-active" and M.Readable(entry.isComplete) and entry.isComplete==true and "native-ready" or spec[2]
                end
            end
        end
    end
end
function S:Watch(frame)
    if self.hooked[frame] or A.Forbidden(frame) or InCombatLockdown() then return end
    self.hooked[frame] = true
    frame:HookScript("OnHide", function() self:Clear(frame) end)
end
function S:Clear(owner)
    if owner then self.identities[owner]=nil end
    if not owner or self.current and self.current.owner == owner then self.current = nil end
    if N.Hover and (not owner or N.Hover.source and N.Hover.source.owner == owner) then N.Hover:Dismiss("source") end
end
function S:Set(source)
    if not source or #source.rows == 0 then return end
    self.current = source
    N.Core:StartHoverUpdate()
    if N.Hover then N.Hover:Consider(source) end
end
function S:Pin(frame, id, rows)
    if A.Forbidden(frame) or not A.Visible(frame) then return end
    id = M.QuestId(id)
    rows = rows or (id and {{id=id,availabilityCheck=function() return self:MapAvailability(id,frame.mapID) end,provenance="Native exact-ID map pin"}})
    if not rows then return end
    self:Watch(frame)
    local ids = N.Providers.ResolveRows(rows)
    if #ids==0 then return end
    local signature = {}; for _,row in ipairs(ids) do signature[#signature+1]=row.id end
    self:Set({ owner = frame, key = self:Key(frame,table.concat(signature,",")), surface = "worldmap", rows = ids,
        over = function() return A.Over(frame) end,
        valid = function()
            if not A.Visible(frame) or not A.Visible(WorldMapFrame) then return false end
            if id then return M.QuestId(frame.GetQuestID and A.Call(frame.GetQuestID, frame) or frame.questID) == id end
            local related = A.Call(frame.GetRelatedQuests, frame)
            if not M.Readable(related) or type(related) ~= "table" then return false end
            for _, row in ipairs(ids) do if not related[row.id] then return false end end
            return true
        end })
end
function S:MapAvailability(id,mapID)
    mapID=M.QuestId(mapID) or M.QuestId(A.Call(WorldMapFrame and WorldMapFrame.GetMapID,WorldMapFrame))
    if not mapID then return end
    local offers=A.Call(C_QuestLine and C_QuestLine.GetAvailableQuestLines,mapID)
    if not M.Readable(offers) or type(offers)~="table" or #offers>256 then return end
    for _,offer in ipairs(offers) do
        if M.Readable(offer) and type(offer)=="table" and M.QuestId(offer.questID)==id and M.Readable(offer.inProgress) and offer.inProgress~=true then return "native-map-available" end
    end
end
function S:Attach()
    if InCombatLockdown() or not N.Core.supported then return end
    if EventRegistry and not self.callbacks then
        EventRegistry:RegisterCallback("MapCanvas.QuestPin.OnEnter", function(_, frame, id) self:Pin(frame, id) end, self)
        EventRegistry:RegisterCallback("TaskPOI.TooltipShown", function(_, frame) self:Pin(frame, frame and frame.questID) end, self)
        self.callbacks = true
    end
    if QuestHubPinMixin and type(QuestHubPinMixin.AddCustomTooltipData) == "function" and not self.hubHook then
        hooksecurefunc(QuestHubPinMixin, "AddCustomTooltipData", function(frame)
            local related = A.Call(frame.GetRelatedQuests, frame)
            local rows = {}
            if M.Readable(related) and type(related) == "table" then
                local count = 0
                for id, entry in pairs(related) do
                    count = count + 1; if count > 256 then return end
                    if M.QuestId(id) then
                        local relatedID=id
                        rows[#rows+1]={id=id,title=M.Readable(entry) and type(entry)=="table" and M.Text(entry.questName),availabilityCheck=function() return self:MapAvailability(relatedID,frame.mapID) end,provenance="Native quest hub relatedQuests"}
                    end
                end
            end
            table.sort(rows, function(a,b) return a.id < b.id end)
            self:Pin(frame, nil, rows)
        end)
        self.hubHook = true
    end
    if WorldMapFrame and not self.mapHide then
        self:Watch(WorldMapFrame)
        WorldMapFrame:HookScript("OnHide", function()
            if self.current and self.current.surface == "worldmap" then self.current=nil end
            if N.Hover.source and N.Hover.source.surface == "worldmap" then N.Hover:Dismiss("map") end
        end)
        self.mapHide = true
    end
    N.Questie:Attach()
end

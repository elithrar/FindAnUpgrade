local _, N = ...
local M, A = N.Model, N.Adapter
local H = { generation = 0, grace = .2 }; N.Hover = H
function H:RequestRows()
    local generation,requested=self.generation,self.requested
    for _,row in ipairs(self.source and self.source.rows or {}) do
        if not self.open or self.generation~=generation then return end
        N.Rewards.Request(row.id,requested,N.Core.profile.rewards)
    end
end
function H:Signature()
    local parts,itemIDs={},{}
    local function add(value) parts[#parts+1]=M.Readable(value) and tostring(value) or "restricted" end
    for _,row in ipairs(self.source and self.source.rows or {}) do
        add(row.id); add(M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,row.id)) or row.title)
        local availability=row.availability or {};add(availability.state);add(availability.label);add(availability.authority)
        local reward=N.Core.profile.rewards and N.Rewards.Read(row.id)
        if reward then
            add(reward.state)
            for _,key in ipairs({"xp","money"}) do local value=reward[key]; add(key); add(value.state); add(value.value); add(value.published) end
            for _,key in ipairs({"items","choices","currencies","reputation"}) do
                local group=reward[key]; add(key); add(group.state)
                for _,item in ipairs(group.items or {}) do
                    if M.QuestId(item.itemID) then itemIDs[item.itemID]=true end
                    for _,field in ipairs({"itemID","kind","index","state","texture","quality","quantity","name","currencyID","factionID","amount","isChoice","published"}) do add(item[field]) end
                end
            end
        end
    end
    return table.concat(parts,"\031"),itemIDs
end
function H:ItemData(id)
    id=M.QuestId(id)
    if self.open and id and self.itemIDs and self.itemIDs[id] then self:Refresh() end
end
function H:CharacterChanged(change)
    if change and change.equipment and N.Stack.EquipmentChanged then N.Stack:EquipmentChanged() end
    if not self.open or not change or not (change.identity or change.location) then return end
    local ids={};for _,row in ipairs(self.source and self.source.rows or {}) do ids[row.id]=true end
    -- Reuse the exact-NPC/dependency reconciliation path. No additional log
    -- scanner, metadata queue or permanently running refresh loop is needed.
    self:QuestChanged({ids=ids,reason="character"})
end
function H:QuestChanged(change)
    if not self.open or not change or not change.ids then return end
    if N.Chains then change={ids=N.Chains:Dependants(change.ids),reason=change.reason,revision=change.revision} end
    local function relevant(id)
        if change.ids[id] then return true end
        local source=N.Providers.Source(id)
        for _,key in ipairs({"prerequisites","prerequisiteAlternatives","exclusive"}) do
            for _,previous in ipairs(source and source[key] or {}) do
                if change.ids[previous] then return true end
                local parent=N.Providers.Source(previous)
                for _,alternate in ipairs(parent and parent.exclusive or {}) do if change.ids[alternate] then return true end end
            end
        end
        return false
    end
    local affected=false
    for _,row in ipairs(self.source.rows) do if relevant(row.id) then affected=true; break end end
    local npc=self.source.npcGUID and M.QuestId(tonumber(self.source.npcGUID:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")))
    -- A newly unlocked candidate may have been filtered out of the old stack.
    -- Check only this NPC's indexed candidates and their recorded dependencies.
    if npc then for _,id in ipairs(N.Providers.starters and N.Providers.starters[npc] or {}) do if relevant(id) then affected=true; break end end end
    if not affected then return end
    if npc then
        local rows={}
        local gossip=N.Sources.gossip
        if gossip and gossip.guid==self.source.npcGUID then for _,row in ipairs(gossip.rows) do rows[#rows+1]=row end end
        for _,row in ipairs(N.Providers.ForNPC(npc)) do rows[#rows+1]=row end
        -- Keep exact provider associations frozen for pointer transit, but let
        -- ResolveRows recheck every row's live proof and player constraints.
        for _,row in ipairs(self.source.rows) do rows[#rows+1]=row end
        self.source.rows=M.Entries(rows)
    end
    self:Refresh()
end
function H:Dismiss(reason)
    local source = self.source or N.Sources.current
    self.blocked = source and source.key
    self.open, self.source, self.requested, self.outsideAt = false, nil, nil, nil
    if N.Character then N.Character:Sleep() end
    self.pending, self.pendingAt, self.timedOut = nil, nil, nil
    self.signature,self.itemIDs=nil,nil
    self.mode=nil
    self.generation = self.generation+1
    if N.Stack then N.Stack:Hide() end
    if N.NativeTooltip then N.NativeTooltip:End() end
end
function H:Inspect()
    if not self.open or self.mode=="inspector" then return end
    if not self.source or not self.source.valid() then self:Dismiss("source"); return end
    self.mode="inspector"
    local nativeRect=N.NativeTooltip and N.NativeTooltip.lastRect
    if N.NativeTooltip then N.NativeTooltip:End() end
    if not N.Stack:Show(self.source,N.Core.profile,nativeRect) then self:Dismiss("geometry") end
end
function H:Consider(source)
    local c = N.Core
    if not c.ready or not c.supported or not c.profile.enabled or self.open or N.Search and N.Search:Visible() or not source or not c.profile[source.surface] then return end
    if self.blocked and self.blocked ~= source.key then self.blocked = nil end
    if self.blocked == source.key or not A.Modifier(c.profile.modifier) or not source.valid() or not source.over() then return end
    if N.Character then N.Character:Ensure(true)
    elseif N.QuestState then N.QuestState:Prime() end
    self.generation = self.generation+1
    self.open, self.source, self.outsideAt, self.requested = true, source, nil, {}
    c:StartHoverUpdate()
    self.openAt = A.Call(GetTime) or 0
    self.pendingAt = self.openAt
    self.timedOut = false
    self.lastModifier = A.Modifier(c.profile.modifier)
    local openingGeneration=self.generation
    self.signature,self.itemIDs=self:Signature()
    if not self.open or self.generation~=openingGeneration then self.signature,self.itemIDs=nil,nil; return end
    self.anchorX,self.anchorY=A.Cursor()
    if N.NativeTooltip and N.NativeTooltip.hooked and not A.Forbidden(GameTooltip) and c.profile.previewLayout=="tooltip" and c.profile.modifier~="NONE" then
        self.mode="native"; N.NativeTooltip:Begin(); N.NativeTooltip:Try(source,c.profile)
    else self:Inspect() end
    self:RequestRows()
end
function H:Modifier()
    local down = A.Modifier(N.Core.profile.modifier)
    if not down then self.blocked = nil end
    if self.open and self.mode=="native" and not down then self:Inspect() end
    -- Inspection persists on release; Shift retains its native compare meaning.
    self:Consider(N.Sources.current)
    if N.Stack then N.Stack:Compare() end
end
function H:Tick(now)
    local down = A.Modifier(N.Core.profile.modifier)
    if self.lastModifier ~= down then self.lastModifier=down; self:Modifier() end
    if self.open then
        if not self.source.valid() then self:Dismiss("source"); return end
        if self.mode=="native" then
            local shown=down and N.NativeTooltip:Try(self.source,N.Core.profile)
            if not down or not self.source.over() or not shown and now-self.openAt>=.2 then self:Inspect() end
            if not self.open or self.mode=="native" then return end
        end
        local inside=N.Stack:Contains(now)
        if self.source.over() or inside then self.outsideAt = nil
        else self.outsideAt = self.outsideAt or now; if now-self.outsideAt >= self.grace then self:Dismiss("leave") end end
        N.Stack:ItemTransit(now)
        N.Stack:Compare() -- Reconcile native Shift comparison after missed focus events.
        if self.open and self.pending and not N.Stack.item and now-self.pendingAt >= .5 then
            self.pendingAt=now
            if now-self.openAt>=5 then self.timedOut=true end
            N.Stack:Refresh()
            if self.open then self.signature,self.itemIDs=self:Signature() end
            if self.timedOut then self.pending=false end
        end
    elseif N.Sources.current then
        if not N.Sources.current.valid() then N.Sources:Clear(nil,true)
        elseif not N.Sources.current.over() then self.blocked = nil; N.Sources:Clear(nil,true)
        else self:Consider(N.Sources.current) end
    end
end
function H:Refresh(id)
    if not self.open then return end
    local generation=self.generation
    if id then
        id = M.QuestId(id); if not id or not self.requested[id] then return end
    end
    self.source.rows=N.Providers.ResolveRows(self.source.rows)
    if #self.source.rows==0 then self:Dismiss("eligibility"); return end
    self:RequestRows()
    if not self.open or self.generation~=generation then return end
    local signature,itemIDs=self:Signature()
    if not self.open or self.generation~=generation then return end
    self.itemIDs=itemIDs
    if signature==self.signature then return end
    self.signature=signature
    -- Never relayout under an inspected item. A controlled close is safer than
    -- reusing its reward index after player/quest context changes.
    if self.mode=="native" then
        N.NativeTooltip.dirty=true
        return
    end
    if N.Stack.item then self:Dismiss("rewards") else N.Stack:Refresh() end
end

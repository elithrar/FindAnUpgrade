local _, N = ...
local M, A = N.Model, N.Adapter
local H = { generation = 0, grace = .2 }; N.Hover = H
function H:Dismiss(reason)
    local source = self.source or N.Sources.current
    self.blocked = source and source.key
    self.open, self.source, self.requested, self.outsideAt = false, nil, nil, nil
    self.pending, self.pendingAt, self.timedOut = nil, nil, nil
    self.generation = self.generation+1
    if N.Stack then N.Stack:Hide() end
end
function H:Consider(source)
    local c = N.Core
    if not c.ready or not c.supported or not c.profile.enabled or self.open or N.Search and N.Search:Visible() or not source or not c.profile[source.surface] then return end
    if self.blocked and self.blocked ~= source.key then self.blocked = nil end
    if self.blocked == source.key or not A.Modifier(c.profile.modifier) or not source.valid() or not source.over() then return end
    self.generation = self.generation+1
    self.open, self.source, self.outsideAt, self.requested = true, source, nil, {}
    self.openAt = A.Call(GetTime) or 0
    self.pendingAt = self.openAt
    self.timedOut = false
    self.lastModifier = A.Modifier(c.profile.modifier)
    if not N.Stack:Show(source, c.profile) then self:Dismiss("geometry"); return end
    local generation, requested = self.generation, self.requested
    for _, row in ipairs(source.rows) do
        if not self.open or self.generation ~= generation then return end
        N.Rewards.Request(row.id, requested, c.profile.rewards)
    end
end
function H:Modifier()
    local down = A.Modifier(N.Core.profile.modifier)
    if not down then self.blocked = nil end
    -- Inspection persists on release; Shift retains its native compare meaning.
    self:Consider(N.Sources.current)
    if N.Stack then N.Stack:Compare() end
end
function H:Tick(now)
    local down = A.Modifier(N.Core.profile.modifier)
    if self.lastModifier ~= down then self.lastModifier=down; self:Modifier() end
    if self.open then
        if not self.source.valid() then self:Dismiss("source"); return end
        if self.source.over() or N.Stack:Contains() then self.outsideAt = nil
        else self.outsideAt = self.outsideAt or now; if now-self.outsideAt >= self.grace then self:Dismiss("leave") end end
        N.Stack:ItemTransit(now)
        N.Stack:Compare() -- Reconcile native Shift comparison after missed focus events.
        if self.open and self.pending and not N.Stack.item and now-self.pendingAt >= .5 then
            self.pendingAt=now
            if now-self.openAt>=5 then self.timedOut=true end
            N.Stack:Refresh()
            if self.timedOut then self.pending=false end
        end
    elseif N.Sources.current then
        if not N.Sources.current.valid() then N.Sources.current = nil
        elseif not N.Sources.current.over() then self.blocked = nil; N.Sources.current = nil
        else self:Consider(N.Sources.current) end
    end
end
function H:Refresh(id)
    if not self.open then return end
    if id then
        id = M.QuestId(id); if not id or not self.requested[id] then return end
    end
    -- Never relayout under an inspected item. A controlled close is safer than
    -- reusing its reward index after player/quest context changes.
    if N.Stack.item then self:Dismiss("rewards") else N.Stack:Refresh() end
end

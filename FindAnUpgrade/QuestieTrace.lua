local _,N=...
local B={};N.Trace=B
-- External diagnostic API inspected at Questie/QuestieTrace ff4ee3a46d642410bc4b6ab3d19cea9a2715d7c9.
-- Schema/recording-contract changes disable this optional read-only bridge.
local M,D=N.Model,N.ObservationData
local function object(value)return M.Readable(value) and type(value)=="table" and value or nil end
local function session()
    local saved,core=object(QuestieTrace),object(QuestieTraceCore)
    local settings=saved and object(saved.settings)
    if not saved or D.Integer(saved.schemaVersion,14,14)~=14 or not settings or not M.Readable(settings.dataCollectionConsent)
        or settings.dataCollectionConsent~=true or not core or type(core.GetDiagnosticSession)~="function" then return end
    local ok,value,state=pcall(core.GetDiagnosticSession)
    value=ok and object(value)
    if not value or not M.Readable(state) or state~="active" or D.Integer(value.schemaVersion,14,14)~=14
        or D.Integer(value.recordingContractVersion,1,1)~=1 or not object(value.events) then return end
    return value
end
function B:Reset(attach)
    self.generation=(self.generation or 0)+1
    if self.timer then pcall(self.timer.Cancel,self.timer);self.timer=nil end
    self.queue={};self.session=nil;self.cursor=0
    if attach then self.session=session();self.cursor=self.session and #self.session.events or 0 end
end
function B:Reconcile()
    local current=session()
    if current~=self.session then self:Reset(current~=nil) end
end
function B:Observe(event,id,row)
    if not row or not N.Recorder.active then return end
    local current=session()
    if not current then return end
    if current~=self.session then self:Reset(true);return end -- no history backfill on a new capture
    if #self.queue==8 then table.remove(self.queue,1) end
    self.queue[#self.queue+1]={event=event,id=id,row=row}
    if self.timer or not C_Timer or type(C_Timer.NewTimer)~="function" then return end
    local generation=self.generation
    self.timer=C_Timer.NewTimer(0,function()
        if generation~=self.generation then return end
        self.timer=nil
        if not N.Recorder.active or session()~=self.session then self:Reset(false);return end
        local events=self.session.events;local count=#events
        if count<self.cursor then self:Reset(true);return end
        -- Inspect at most eight new event headers; never inspect function streams,
        -- saved sessions, free text, identity, or unrelated event arguments.
        for i=math.max(self.cursor+1,count-7),count do
            local entry=object(events[i])
            local event=entry and M.Readable(entry.e) and entry.e
            if event=="QUEST_ACCEPTED" or event=="QUEST_TURNED_IN" then
                local args=object(entry.a);local id=args and D.Integer(args[1],1,2147483647)
                if id then
                    for _,pending in ipairs(self.queue) do
                        if pending.event==event and pending.id==id then pending.row.trace={schema=14,contract=1} end
                    end
                end
            end
        end
        self.cursor=count;self.queue={}
    end)
end

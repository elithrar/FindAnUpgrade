local _, N = ...
local R={};N.Recorder=R
local M,A,D=N.Model,N.Adapter,N.ObservationData
local function pack(...) return {n=select("#",...),...} end
local function read(fn,...)
    if type(fn)~="function" then return {} end
    local values=pack(pcall(fn,...))
    if not values[1] then return {} end
    local result={}
    for i=2,values.n do if not M.Readable(values[i]) then return {} end;result[i-1]=values[i] end
    return result
end
local function scalar(fn,...) return read(fn,...)[1] end
local function integer(value,low,high) return D.Integer(value,low or 1,high or 2147483647) end
local function known(value) return integer(value,0) and {state="ready",value=value} or {state="unknown"} end
local function unknown() return {state="unknown",slots={}} end
local function guid()
    local value=scalar(UnitGUID,"npc")
    return type(value)=="string" and #value<=128 and value or nil
end
local function source(value,role,itemID)
    if integer(itemID) then return {kind="item",id=itemID,role="starter"} end
    if value then
        local kind,id=value:match("^(%a+)%-[^%-]*%-[^%-]*%-[^%-]*%-[^%-]*%-(%d+)%-")
        id=integer(tonumber(id))
        if id and (kind=="Creature" or kind=="Vehicle" or kind=="GameObject") then
            return {kind=kind=="GameObject" and "object" or "npc",id=id,role=role}
        end
    end
    return {kind="unknown",role="unknown"}
end
local function context()
    local class,race=read(UnitClass,"player"),read(UnitRace,"player")
    local faction=scalar(UnitFactionGroup,"player")
    return {classID=integer(class[3],1,64),raceID=integer(race[3],1,256),level=integer(scalar(UnitLevel,"player"),1,200),
        faction=(faction=="Alliance" or faction=="Horde" or faction=="Neutral") and faction or nil}
end
local function location()
    local result={kind="observer"}
    if not C_Map then return result end
    result.uiMapID=integer(scalar(C_Map.GetBestMapForUnit,"player"))
    if result.uiMapID then
        local position=scalar(C_Map.GetPlayerMapPosition,result.uiMapID,"player")
        if position and (type(position)=="table" or type(position)=="userdata") then
            local values=read(position.GetXY,position);local x,y=values[1],values[2]
            if M.Number(x) and M.Number(y) and x>=0 and x<=1 and y>=0 and y<=1 then
                result.x=math.floor(x*10000+.5)/10000;result.y=math.floor(y*10000+.5)/10000
            end
        end
    end
    return result
end
local function title(id)
    local value=C_QuestLog and scalar(C_QuestLog.GetTitleForQuestID,id)
    if type(value)~="string" or #value==0 or #value>256 or value:find("[%z\1-\31\127|]") then return nil,"unknown" end
    -- Persist canonical titles only, never dialog/gossip prose. Even a quest
    -- title may contain the observer's name; redact before it reaches storage.
    local name=scalar(UnitName,"player")
    if type(name)~="string" or #name==0 or #name>128 then return nil,"unknown" end
    local state="ready";local start=1;local parts={}
    while true do
        local first,last=value:lower():find(name:lower(),start,true)
        if not first then parts[#parts+1]=value:sub(start);break end
        parts[#parts+1]=value:sub(start,first-1);parts[#parts+1]="<player>";start=last+1;state="redacted"
    end
    value=table.concat(parts)
    if #value>256 then return nil,"unknown" end
    return value,state
end
function R:Base(id,stage,provider,where,observer)
    local value,state=title(id)
    return {questID=id,stage=stage,title=value,titleState=state,client=self.client,context=observer or context(),
        location=where or location(),source=provider or {kind="unknown",role="unknown"},
        questLevel=known(C_QuestLog and scalar(C_QuestLog.GetQuestDifficultyLevel,id)),
        rewards={guaranteed=unknown(),choices=unknown(),xp={state="unknown"},money={state="unknown"}}}
end
function R:Cancel()
    self.generation=(self.generation or 0)+1
    if self.timer then pcall(self.timer.Cancel,self.timer);self.timer=nil end
    self.dialog=nil
end
function R:Current(dialog)
    return self.active and self.dialog==dialog and dialog.generation==self.generation
        and A.QuestId()==dialog.id and guid()==dialog.guid
end
local function items(kind,count,choice)
    if not integer(count,0,32) then return unknown() end
    local result={state="ready",expected=count,slots={}}
    if choice then result.choose=count>0 and 1 or 0 end
    for i=1,count do
        local slot={slot=i,state="unknown"}
        local lootType=not choice and 0 or scalar(GetQuestItemInfoLootType,kind,i)
        if lootType==0 then
            local values=read(GetQuestItemInfo,kind,i)
            local id,quantity=integer(values[6]),integer(values[3])
            if id and quantity then
                slot={slot=i,state="ready",kind="item",id=id,quantity=quantity,contextFlags=integer(values[7],0)}
            end
        elseif lootType==1 and C_QuestOffer then
            local currency=scalar(C_QuestOffer.GetQuestRewardCurrencyInfo,kind,i)
            if M.Readable(currency) and type(currency)=="table" then
                local id,quantity=integer(currency.currencyID),integer(currency.totalRewardAmount)
                if id and quantity then slot={slot=i,state="ready",kind="currency",id=id,quantity=quantity,contextFlags=integer(currency.questRewardContextFlags,0)} end
            end
        end
        if slot.state~="ready" then result.state="partial" end
        result.slots[i]=slot
    end
    return result
end
function R:Save(row)
    local clean=D.Record(row);if not clean then return end
    local signature=D.Encode(clean)
    if self.dialog and self.dialog.signature==signature then return end
    if self.dialog then self.dialog.signature=signature end
    local _,stored=D:Add(clean)
    if not D.db.enabled then self:Activate(false) end
    if N.Options.frame and N.Options.frame:IsShown() then N.Options:RefreshRecorder() end
    return stored
end
function R:Sample(dialog)
    if not self:Current(dialog) or dialog.attempts>=8 then return end
    dialog.attempts=dialog.attempts+1
    -- QUEST_DETAIL may precede the native frame handler showing QuestFrame.
    -- Keep bounded settling attempts without reading a hidden dialog's facts.
    if not A.Visible(QuestFrame) then return end
    local row=self:Base(dialog.id,dialog.stage,dialog.source,dialog.location,dialog.context)
    -- Match the 70425 Mainline renderer's readiness guard. Counts of zero
    -- outside this context say nothing about whether rewards exist.
    local visible=dialog.stage=="completion" and A.Visible(QuestFrameRewardPanel)
        or dialog.stage=="offered" and C_QuestLog and scalar(C_QuestLog.ShouldShowQuestRewards,dialog.id)==true
    if visible then
        row.rewards.guaranteed=items("reward",scalar(GetNumQuestRewards),false)
        row.rewards.choices=items("choice",scalar(GetNumQuestChoices),true)
        row.rewards.xp=known(scalar(GetRewardXP));row.rewards.money=known(scalar(GetRewardMoney))
    end
    -- All global dialog reads must finish in the same dialog/NPC generation.
    if self:Current(dialog) then self:Save(row) end
end
function R:Schedule(dialog)
    if self.timer or not self:Current(dialog) or dialog.attempts>=8 or not C_Timer or type(C_Timer.NewTimer)~="function" then return end
    local generation=self.generation
    self.timer=C_Timer.NewTimer(dialog.attempts<3 and .15 or .4,function()
        if self.generation~=generation then return end
        self.timer=nil
        if self:Current(dialog) then self:Sample(dialog);self:Schedule(dialog) end
    end)
end
function R:Open(stage,itemID)
    self:Cancel()
    local id=A.QuestId();if not id then return end
    local npc=guid()
    local dialog={id=id,stage=stage,generation=self.generation,guid=npc,attempts=0,
        source=source(npc,stage=="offered" and "starter" or "ender",itemID),location=location(),context=context()}
    self.dialog=dialog;self:Sample(dialog);self:Schedule(dialog)
end
function R:Gossip()
    self:Cancel()
    if not C_GossipInfo then return end
    local npc=guid();local where,observer=location(),context()
    for _,definition in ipairs({{"listed",C_GossipInfo.GetAvailableQuests,"starter"},{"listed_active",C_GossipInfo.GetActiveQuests,"unknown"}}) do
        local rows=scalar(definition[2])
        if M.Readable(rows) and type(rows)=="table" then
            for i=1,50 do
                local row=rows[i];if row==nil then break end
                if M.Readable(row) and type(row)=="table" then
                    local id=integer(row.questID)
                    if id and guid()==npc and self.active then self:Save(self:Base(id,definition[1],source(npc,definition[3]),where,observer)) end
                end
            end
        end
    end
end
function R:Event(event,id,xp,money)
    if not self.active then return end
    N.Trace:Reconcile()
    if event=="ADDON_LOADED" then if id=="QuestieTrace" then N.Trace:Reset(true) end
    elseif event=="QUEST_DETAIL" then self:Open("offered",id) -- payload is start item ID, not quest ID
    elseif event=="QUEST_PROGRESS" then self:Open("progress")
    elseif event=="QUEST_COMPLETE" then self:Open("completion")
    elseif event=="GOSSIP_SHOW" then self:Gossip()
    elseif event=="QUEST_ACCEPTED" or event=="QUEST_TURNED_IN" then
        id=integer(id);local dialog=self.dialog
        local role=event=="QUEST_ACCEPTED" and "starter" or "ender"
        local matches=dialog and dialog.id==id and dialog.guid==guid() and dialog.source.role==role
        if id then
            local row=self:Base(id,event=="QUEST_ACCEPTED" and "accepted" or "turned_in",
                matches and dialog.source or nil,matches and dialog.location or nil,matches and dialog.context or nil)
            if event=="QUEST_TURNED_IN" then row.rewards.xp=known(xp);row.rewards.money=known(money) end
            local stored=self:Save(row);N.Trace:Observe(event,id,stored)
        end
        self:Cancel()
    elseif event=="QUEST_ITEM_UPDATE" or event=="QUEST_DATA_LOAD_RESULT" or event=="ITEM_DATA_LOAD_RESULT" then
        if self.dialog and (event~="QUEST_DATA_LOAD_RESULT" or id==self.dialog.id) then self:Schedule(self.dialog) end
    else self:Cancel();if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LOGOUT" then N.Trace:Reset(false) end end
end
function R:Activate(enabled)
    self:Cancel();self.active=false
    N.Trace:Reset(false)
    if self.events then self.events:UnregisterAllEvents() end
    if not enabled or D.readOnly or D.full or not self.client or not N.Core.supported or not N.Core.profile.enabled then return false end
    self.events=self.events or CreateFrame("Frame")
    self.events:SetScript("OnEvent",function(_,event,...) self:Event(event,...) end)
    for _,event in ipairs({"QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_ACCEPTED","QUEST_TURNED_IN","QUEST_FINISHED",
        "QUEST_GREETING","GOSSIP_SHOW","GOSSIP_CLOSED","QUEST_ITEM_UPDATE","QUEST_DATA_LOAD_RESULT","ITEM_DATA_LOAD_RESULT","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","ADDON_LOADED"}) do
        if not pcall(self.events.RegisterEvent,self.events,event) then self.events:UnregisterAllEvents();return false end
    end
    self.active=true;N.Trace:Reset(true);return true
end
function R:Enable(enabled)
    if D.readOnly then return end
    D.db.enabled=enabled==true and self:Activate(true) or false
    if not D.db.enabled then self:Activate(false) end
    if N.Options.frame and N.Options.frame:IsShown() then N.Options:RefreshRecorder() end
end
function R:Clear()
    if D.readOnly then return end
    self:Activate(false);D.full=nil;FindAnUpgradeObservations=D:Initialize(nil)
end
function R:Status()
    return D.readOnly and "Newer data is read-only." or D.full and "Full: export, then clear."
        or (not self.client or not N.Core.supported) and "Client unavailable." or not N.Core.profile.enabled and "Paused: addon is off."
        or (self.active and "Recording" or "Paused")..": "..#D.db.records.." records; "..D.db.dropped.." dropped."
end
function R:Initialize()
    FindAnUpgradeObservations=D:Initialize(FindAnUpgradeObservations)
    local build=read(GetBuildInfo);local locale=scalar(GetLocale)
    self.client=D.Record({questID=1,stage="offered",client={version=build[1],build=tonumber(build[2]),interface=build[4],locale=locale}})
    self.client=self.client and self.client.client
    self:Enable(D.db.enabled)
end

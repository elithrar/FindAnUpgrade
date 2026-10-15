local _,N=...
local M,A,U=N.Model,N.Adapter,N.UI
local S={cards={},offset=0,expanded={},locationChoice={}}; N.Search=S
-- One grid owns both the controls and the result viewport. Dimensions are in
-- local UI units; Fit adapts the frame before applying the user's scale.
local G={width=476,height=680,minWidth=420,minHeight=400,maxWidth=680,maxHeight=900,
    inset=16,gap=10,control=30,menuWidth=144,scrollTop=178,scrollBottom=16,
    cardInset=8,rowGap=5,icon=112/3,iconGap=6}
S.geometry=G
local function rewardStamp(reward)
    local parts={}
    local function add(...)
        local values={...}
        for i=1,select("#",...) do parts[#parts+1]=type(values[i])..":"..tostring(values[i]) end
    end
    add(reward.state)
    for _,key in ipairs({"items","choices"}) do
        local group=reward[key] or {};add(key,group.state)
        for _,row in ipairs(group.items or {}) do add(row.itemID,row.kind,row.index,row.quantity,row.quality,row.usable,row.name,row.texture,row.state,row.itemLevel) end
    end
    for _,key in ipairs({"xp","money"}) do local value=reward[key] or {};add(key,value.state,value.value,value.published) end
    for _,row in ipairs((reward.currencies or {}).items or {}) do add("currency",row.name,row.amount,row.isChoice) end
    for _,row in ipairs((reward.reputation or {}).items or {}) do add("rep",row.factionID,row.name,row.amount,row.published) end
    return table.concat(parts,"\030")
end
local function text(parent,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY","GameTooltipText"); U:Font(f,size or 12)
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetWordWrap(false); f:SetTextColor(unpack(color or {.93,.94,.97})); return f
end
local function surface(f) U:Border(f,"tooltip"); f:SetBackdropColor(.045,.045,.05,.96); f:SetBackdropBorderColor(.5,.5,.5,.8) end
local function controlArt(frame,height)
    -- Sidebar inputs and dropdowns share the exact native border slices.
    -- The dropdown's padded textholder cannot establish opaque-edge alignment.
    if frame.Background then frame.Background:Hide() end
    for _,key in ipairs({"Left","Right","Middle"}) do
        local region=frame[key]
        if not region then region=frame:CreateTexture(nil,"BACKGROUND"); frame[key]=region end
        region:SetAtlas("common-search-border-"..key:lower()); region:SetHeight(height)
        if key~="Middle" then region:SetWidth(8) end
        region:ClearAllPoints()
    end
    frame.Left:SetPoint("LEFT",frame,"LEFT",0,0); frame.Right:SetPoint("RIGHT",frame,"RIGHT",0,0)
    frame.Middle:SetPoint("LEFT",frame.Left,"RIGHT",0,0); frame.Middle:SetPoint("RIGHT",frame.Right,"LEFT",0,0)
end
local function edit(parent,width,height)
    height=height or 26
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); e:SetSize(width,height); e:SetAutoFocus(false); e:SetMaxLetters(100); e:SetTextInsets(8,8,0,0); e:SetJustifyV("MIDDLE"); U:Font(e,12)
    controlArt(e,height)
    return e
end
function S:Visible() return self.frame and A.Visible(self.frame) end
function S:MenuOpen()
    local manager=Menu and A.Call(Menu.GetManager)
    return manager and A.Call(manager.IsAnyMenuOpen,manager)==true or false
end
function S:CloseMenu()
    if self.menu and type(self.menu.Close)=="function" then self.menu:Close() end
    self.menu=nil
    for _,dropdown in ipairs({self.slot,self.scope,self.sort}) do if type(dropdown.CloseMenu)=="function" then dropdown:CloseMenu() end end
    if self.footerTooltip then self.footerTooltip:Hide() end
    self:CloseTextTip()
end
function S:CloseTextTip()
    if self.textTooltip then self.textTooltip:Hide() end
end
function S:TextTip(owner,value)
    -- Finder text is measured and wrapped in-place. Only items invoke a hover
    -- tooltip; ordinary row text must not cover the nearby reward controls.
    self:CloseTextTip()
end
function S:Changed(reset,passive)
    -- Background quest/cache events must not dismiss an open native menu.
    -- User edits close it deliberately; Tick defers data/layout until release.
    if passive then self:DataChanged(); return end
    self:CloseMenu(); self.inspector:ClearItem()
    self.dirty=true; self.changeAt=(A.Call(GetTime) or 0)+.15
    if reset then self.offset=0; self.bottomTarget=nil end
    self:Wake()
end
function S:Wake()
    if self:Visible() and not self.frame:GetScript("OnUpdate") then self.frame:SetScript("OnUpdate",function(_,elapsed) self:Tick(elapsed) end) end
end
function S:DataChanged()
    self.dirty=true
    local deadline=(A.Call(GetTime) or 0)+.15
    self.changeAt=math.min(self.changeAt or deadline,deadline)
    self:Wake()
end
function S:AppearanceChanged()
    -- Restyle reusable objects after an open menu is released. Appearance
    -- changes do not replace transient search state or re-read character data.
    self.appearanceDirty=true
    if self.inspector then self.inspector:ClearItem() end
    if self.footerTooltip then self.footerTooltip:Hide() end
    self:Wake()
end
function S:ApplyAppearance()
    self.appearanceDirty=nil; self.appearanceLayout=true
    self:Fit()
    if self.copyFrame then U:Border(self.copyFrame,"dialog") end
    if self.results then self:LayoutResults(); self:Scroll(self.offset) end
    self.appearanceLayout=nil
end
function S:Indexes()
    local data=N.CatalogData
    if self.dependencyData~=data then
        self.dependencyData,self.dependents,self.itemQuests=data,{},{}
        for _,source in ipairs(data and data.quests or {}) do
            for _,item in ipairs(source.items or {}) do
                local id=M.QuestId(item.itemID)
                if id then local set=self.itemQuests[id] or {};self.itemQuests[id]=set;set[source.id]=true end
            end
            for _,key in ipairs({"prerequisites","prerequisiteAlternatives","exclusive"}) do
                local list=source[key]
                if M.Readable(list) and type(list)=="table" and #list<=128 then
                    for _,id in ipairs(list) do
                        id=M.QuestId(id)
                        if id then local set=self.dependents[id] or {};self.dependents[id]=set;set[source.id]=true end
                    end
                end
            end
        end
    end
end
function S:QuestRelevant(ids)
    if not self.filter then return false end
    self:Indexes()
    local candidates,queue={},{}
    for id in pairs(ids) do candidates[id]=true;queue[#queue+1]=id end
    local cursor=1
    while cursor<=#queue and cursor<=10000 do
        for dependent in pairs(self.dependents[queue[cursor]] or {}) do
            if not candidates[dependent] then candidates[dependent]=true;queue[#queue+1]=dependent end
        end
        cursor=cursor+1
    end
    for id in pairs(candidates) do
        local row=N.Catalog.records[id];local source=row and row.source or N.Providers.Source(id)
        if source then
            local level=row and row.level or source.level
            if not M.Number(level) or level>=self.filter.minimum and level<=self.filter.maximum then return true end
        end
    end
    return false
end
function S:ItemData(id)
    id=M.QuestId(id);if not id then return end
    local rankingChanged,forwarded=N.Ranking:InvalidateItem(id,N.Character.snapshot,self:Visible()==true)
    if rankingChanged and not forwarded and self:Visible() and self.filter and (self.filter.usable or self.filter.sort=="UPGRADE") then self:DataChanged() end
    id=M.QuestId(id);if not id or not (N.SearchModel.cache[id] or self.itemRequests and self.itemRequests[id]) then return end
    local previous=N.SearchModel.cache[id]
    if not self:Visible() then N.SearchModel.cache[id]=nil;return end
    N.SearchModel.cache[id]=nil
    N.SearchModel:Item({itemID=id,name=previous and previous.name})
    local current=N.SearchModel.cache[id];local changed=previous==nil
    for _,key in ipairs({"state","name","link","quality","itemLevel","minimum","slot","texture","itemType","itemSubType","classID","subclassID","searchTypeText"}) do
        if not previous or previous[key]~=current[key] then changed=true end
    end
    if not changed then
        N.SearchModel.cache[id]=previous
        return
    end
    self:Indexes()
    if self:QuestRelevant(self.itemQuests[id] or {}) then self:DataChanged();return end
    for quest,items in pairs(N.SearchModel.currentItems) do
        for _,item in ipairs(items) do
            if item.itemID==id and self:QuestRelevant({[quest]=true}) then self:DataChanged();return end
        end
    end
end
function S:QuestChanged(change)
    for id in pairs(change.ids or {}) do N.SearchModel:InvalidateQuest(id) end
    if not self:Visible() or not self:QuestRelevant(change.ids or {}) then return end
    -- Membership/completion changes affect availability and dependencies, not
    -- the entire catalogue's title, level or native item metadata caches.
    self:DataChanged()
end
function S:QuestData(id)
    id=M.QuestId(id);local row=id and N.Catalog.records[id];if not row then return end
    local taxonomyChanged=N.Character:QuestMetadata(id)
    self.rewardDirty=self.rewardDirty or {};self.rewardDirty[id]=true
    if not self:Visible() then
        if row.metadataReady~=nil then N.Catalog:Invalidate(id) end
        return
    end
    local before=self:QuestRelevant({[id]=true})
    local _,metadataChanged=N.Catalog:Metadata(row,self.contextLevel,true)
    local after=self:QuestRelevant({[id]=true})
    if not before and not after then return end
    local direct=not M.Number(row.level) or row.level>=self.filter.minimum and row.level<=self.filter.maximum
    if not direct then if metadataChanged then self:DataChanged() end;return end
    local reward=N.SearchModel:Reward(row)
    local stamp=rewardStamp(reward);self.rewardStamps=self.rewardStamps or {}
    local staleUsability=reward.state~="ready" and next(N.SearchModel.usability[id] or {})~=nil
    local changed=taxonomyChanged or metadataChanged or staleUsability or self.rewardStamps[id]~=stamp
    self.rewardStamps[id]=stamp;self.rewardDirty[id]=nil
    if changed then
        if staleUsability then N.SearchModel:InvalidateQuest(id) end
        self:DataChanged()
    end
end
function S:Enqueue(kind,ids)
    self.queues=self.queues or {}; self.queued=self.queued or {}; self.cursors=self.cursors or {}
    local queue=self.queues[kind] or {}; self.queues[kind]=queue
    local queued=self.queued[kind] or {}; self.queued[kind]=queued
    local requested=kind=="item" and self.itemRequests or kind=="reward" and self.rewardRequests or self.questRequests
    for _,id in ipairs(ids) do if not requested[id] and not queued[id] then queue[#queue+1]=id; queued[id]=true end end
    self:Wake()
end
function S:NextRequest(kind)
    local queue=self.queues and self.queues[kind]; local cursor=self.cursors[kind] or 1
    local id=queue and queue[cursor]
    if id then self.cursors[kind]=cursor+1 end
    return id
end
function S:HasRequests()
    for kind,queue in pairs(self.queues or {}) do if queue[self.cursors[kind] or 1] then return true end end
    return false
end
function S:RequestStep(now)
    if now<(self.nextRequestAt or 0) then return end
    self.nextRequestAt=now+.1
    for _=1,2 do
        local id=self:NextRequest("item"); if not id then break end
        self.itemRequests[id]=true; A.Call(C_Item and C_Item.RequestLoadItemDataByID,id)
        if not self:Visible() then return end
    end
    for _=1,2 do
        local kind=self.requestTurn or "reward"; local other=kind=="reward" and "quest" or "reward"
        local id=self:NextRequest(kind)
        if not id then kind=other; id=self:NextRequest(kind) end
        self.requestTurn=kind=="reward" and "quest" or "reward"
        if id and kind=="quest" then self.questRequests[id]=true; A.Call(C_QuestLog and C_QuestLog.RequestLoadQuestByID,id)
        elseif id then self.rewardRequests[id]=true; if A.Call(HaveQuestRewardData,id)~=true then A.Call(C_TaskQuest and C_TaskQuest.RequestPreloadRewardData,id) end end
        if not self:Visible() then return end
        if not id then break end
    end
end
function S:Dropdown(parent,width,entries,get,choose,height)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle1DropdownTemplate"); d:SetSize(width,height or 26)
    controlArt(d,height or 26)
    d.Text:ClearAllPoints(); d.Text:SetPoint("LEFT",d,"LEFT",9,0); d.Text:SetWidth(width-31); d.Text:SetHeight(height or 26); d.Text:SetJustifyH("LEFT"); d.Text:SetJustifyV("MIDDLE"); d.Text:SetWordWrap(false); U:Font(d.Text,12)
    d:SetupMenu(function(_,root)
        if self.inspector then self.inspector:ClearItem() end; if self.CloseTextTip then self:CloseTextTip() end; root:SetScrollMode(220)
        root:AddMenuReleasedCallback(function() self:Wake() end)
        for _,entry in ipairs(entries) do
            local value,label=entry[1],entry[2]
            local row=root:CreateRadio(label,function(v) return get()==v end,function(v) choose(v); d:SetDefaultText(label) end,value)
            row:AddInitializer(function(button) button.fontString:SetFontObject(self.menuFont) end)
        end
    end)
    -- Native DropdownButton owns mouse down/up and outside-click dismissal.
    -- Clearing edit focus is additive, as in ATCF; never toggle on mouse-up.
    d:HookScript("OnMouseDown",function()
        self:CommitRange(true); self.search:ClearFocus(); self.minimumInput:ClearFocus(); self.maximumInput:ClearFocus()
    end)
    return d
end
function S:CharacterSnapshot()
    return N.Character:Get()
end
function S:CharacterChanged(change)
    if not self.filter or not self.minimumInput or not self.maximumInput or not self:Visible() then self.contextDirty=true;return end
    local snapshot=self:CharacterSnapshot()
    self.contextLevel,self.contextMap=snapshot.level,snapshot.mapID
    if change.identity or change.equipment or change.capabilities then
        N.SearchModel.usability,N.SearchModel.currentItems,N.SearchModel.currentStamp={},{},{}
    end
    if change.identity and not self.manualRange then self:DefaultRange(snapshot.level) end
    if change.identity or change.equipment or change.items or change.capabilities or change.location and self.filter.scope=="SAME_ZONE" then self:DataChanged() end
end
function S:SortButton(parent)
    -- Use the sorting arrow from the pinned AuctionHouse header, without
    -- inheriting auction or bag actions. Two directions convey ordering.
    local d=CreateFrame("DropdownButton",nil,parent);d:SetSize(28,26)
    d.arrows={}; local loaded=true
    for i=1,2 do
        local icon=d:CreateTexture(nil,"ARTWORK"); d.arrows[i]=icon
        icon:SetSize(9,12); icon:SetPoint("CENTER",d,"CENTER",i==1 and -4 or 4,0)
        local ok=pcall(icon.SetAtlas,icon,"auctionhouse-ui-sortarrow")
        if ok and type(icon.GetAtlas)=="function" then ok=A.Call(icon.GetAtlas,icon)=="auctionhouse-ui-sortarrow" end
        if i==2 then icon:SetRotation(math.pi) end
        loaded=loaded and ok
    end
    if not loaded then
        for _,icon in ipairs(d.arrows) do icon:Hide() end
        d.fallback=text(d,11); d.fallback:SetAllPoints(); d.fallback:SetJustifyH("CENTER"); d.fallback:SetJustifyV("MIDDLE"); d.fallback:SetText("Sort")
    end
    local highlight=d:CreateTexture(nil,"HIGHLIGHT");highlight:SetSize(24,23);highlight:SetPoint("CENTER");highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square");highlight:SetBlendMode("ADD");d:SetHighlightTexture(highlight)
    d:HookScript("OnEnter",function() self.footerTooltip:SetOwner(d,"ANCHOR_LEFT"); self.footerTooltip:SetText("Sort by"); self.footerTooltip:Show() end)
    d:HookScript("OnLeave",function() self.footerTooltip:Hide() end)
    d:SetupMenu(function(_,root)
        if self.inspector then self.inspector:ClearItem() end;root:SetScrollMode(260);root:AddMenuReleasedCallback(function()self:Wake()end)
        root:CreateTitle("Sort by")
        root:CreateTitle("Item-level estimate")
        root:CreateTitle("Item level and usable slots; not a performance score")
        for _,entry in ipairs({{"UPGRADE","Biggest upgrade"},{"FIT","Level fit"},{"LEVEL","Quest level"},{"TITLE","Quest title"}})do
            local key,label=entry[1],entry[2]
            local row=root:CreateRadio(label,function(value)return self.filter.sort==value end,function(value)self.filter.sort=value;self:Changed(true)end,key)
            self:MenuFont(row)
        end
    end)
    d:HookScript("OnMouseDown",function()self:CommitRange(true);self.search:ClearFocus();self.minimumInput:ClearFocus();self.maximumInput:ClearFocus()end)
    return d
end
function S:CommitRange(passive)
    local lo,hi=tonumber(self.minimumInput:GetText()),tonumber(self.maximumInput:GetText())
    local valid=M.Number(lo) and M.Number(hi) and lo>=1 and hi<=200 and lo<=hi and lo==math.floor(lo) and hi==math.floor(hi)
    if not valid then self.minimumInput:SetText(tostring(self.filter.minimum or "")); self.maximumInput:SetText(tostring(self.filter.maximum or "")); return false end
    if lo~=self.filter.minimum or hi~=self.filter.maximum then
        self.filter.minimum,self.filter.maximum,self.manualRange=lo,hi,true
        if passive then self.offset=0;self.bottomTarget=nil;self:DataChanged() else self:Changed(true) end
    end
    return true
end
function S:CancelRange()
    self.minimumInput:SetText(tostring(self.filter.minimum or ""))
    self.maximumInput:SetText(tostring(self.filter.maximum or ""))
    self.minimumInput:ClearFocus(); self.maximumInput:ClearFocus()
end
function S:Create()
    if self.frame then return end
    self.filter={query="",usable=true,slot="ALL",sort="UPGRADE",scope="SAME_ZONE",includeDungeons=false}
    local f=CreateFrame("Frame","FindAnUpgradeSearch",UIParent,"BackdropTemplate"); self.frame=f; f:Hide()
    f:SetSize(G.width,G.height); f:SetPoint("RIGHT",UIParent,"RIGHT",-24,0); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true); f:SetResizeBounds(G.minWidth,G.minHeight,G.maxWidth,G.maxHeight); U:Dialog(f)
    self.menuFont=CreateFont("FindAnUpgradeSearchMenuFont"); U:Font(self.menuFont,12)
    self.footerTooltip=CreateFrame("GameTooltip","FindAnUpgradeSearchFooterTooltip",f,"SharedTooltipTemplate"); self.footerTooltip:Hide()
    self.title=text(f,16,{1,.82,.2}); self.title:SetPoint("TOPLEFT",16,-14); self.title:SetText("FindAnUpgrade")
    local drag=CreateFrame("Frame",nil,f); self.drag=drag; drag:SetPoint("TOPLEFT",0,0); drag:SetPoint("TOPRIGHT",-76,0); drag:SetHeight(38); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() self:CloseMenu(); self.inspector:ClearItem(); f:StartMoving() end); drag:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); self.close=close; close:SetSize(24,24); close:SetPoint("TOPRIGHT",-8,-8); close:SetScript("OnClick",function() f:Hide() end)
    local options=CreateFrame("Button",nil,f); self.options=options; options:SetSize(26,26); options:SetPoint("TOPRIGHT",-40,-8); options:SetFrameLevel(f:GetFrameLevel()+3)
    options.icon=options:CreateTexture(nil,"ARTWORK"); options.icon:SetSize(20,20); options.icon:SetPoint("CENTER"); options.icon:SetTexture("Interface\\WorldMap\\GEAR_64GREY")
    options:SetScript("OnEnter",function() options.icon:SetVertexColor(1,.82,.2) end)
    options:SetScript("OnLeave",function() options.icon:SetVertexColor(1,1,1) end)
    options:SetScript("OnClick",function() self:CloseMenu(); self.inspector:ClearItem(); self.search:ClearFocus(); self:CancelRange(); N.Options:Toggle(N.Core) end)
    self.search=edit(f,1,G.control); self.search:SetPoint("TOPLEFT",G.inset,-44); self.search:SetTextInsets(8,32,0,0)
    self.placeholder=text(self.search,11,{.7,.7,.72}); self.placeholder:SetPoint("LEFT",8,0); self.placeholder:SetText("Quest or reward")
    local clear=CreateFrame("Button",nil,self.search); self.clearSearch=clear
    clear:SetSize(24,24); clear:SetPoint("RIGHT",self.search,"RIGHT",-3,0)
    clear.text=text(clear,16,{.7,.7,.72,.65}); clear.text:SetAllPoints(); clear.text:SetJustifyH("CENTER"); clear.text:SetJustifyV("MIDDLE"); clear.text:SetText("\195\151"); clear:Hide()
    clear:SetScript("OnEnter",function() clear.text:SetTextColor(.95,.95,.97,1) end)
    clear:SetScript("OnLeave",function() clear.text:SetTextColor(.7,.7,.72,.65) end)
    clear:SetScript("OnClick",function()
        if self.search:GetText()=="" then return end
        self.search:SetText(""); clear:Hide(); self.placeholder:Show(); self.filter.query=""; self.search:SetFocus(); self:Changed(true)
    end)
    self.search:SetScript("OnTextChanged",function(e,user)
        local empty=e:GetText()==""; self.placeholder:SetShown(empty); clear:SetShown(not empty)
        if user then self.filter.query=e:GetText():sub(1,100); self:Changed(true) end
    end)
    self.search:SetScript("OnEscapePressed",function(e) e:ClearFocus(); f:Hide() end)
    self.search:SetScript("OnEnterPressed",function(e) e:ClearFocus() end)
    self.usable=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); self.usable:SetPoint("TOPLEFT",12,-114); self.usable:SetSize(24,24)
    self.usable.Text:ClearAllPoints(); self.usable.Text:SetPoint("LEFT",self.usable,"RIGHT",2,0); self.usable.Text:SetHeight(24); self.usable.Text:SetJustifyH("LEFT"); self.usable.Text:SetJustifyV("MIDDLE"); self.usable.Text:SetWordWrap(false)
    self.usable.Text:SetText("Hide unusable"); self.usable.Text:SetWidth(116); U:Font(self.usable.Text,12); self.usable:SetHitRectInsets(0,-118,0,0)
    self.usable:SetScript("OnClick",function(b) self.filter.usable=b:GetChecked()==true; self:Changed(true) end)
    self.dungeons=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");self.dungeons:SetSize(24,24)
    self.dungeons.Text:ClearAllPoints();self.dungeons.Text:SetPoint("LEFT",self.dungeons,"RIGHT",2,0);self.dungeons.Text:SetHeight(24)
    self.dungeons.Text:SetJustifyH("LEFT");self.dungeons.Text:SetJustifyV("MIDDLE");self.dungeons.Text:SetWordWrap(false);U:Font(self.dungeons.Text,12)
    self.dungeons.Text:SetText("Include dungeon quests")
    self.dungeons:SetScript("OnClick",function(b)self.filter.includeDungeons=b:GetChecked()==true;self:Changed(true)end)
    self.scope=self:Dropdown(f,G.menuWidth,{{"SAME_ZONE","Same zone"},{"LEVEL_RANGE","Level range"}},function()return self.filter.scope end,function(value)self.filter.scope=value;self:Changed(true)end)
    self.scope:SetPoint("TOPLEFT",16,-82);self.scope:SetDefaultText("Same zone")
    self.levelLabel=text(f,12); self.levelLabel:SetText("Levels"); self.levelLabel:SetHeight(26); self.levelLabel:SetJustifyV("MIDDLE")
    self.minimumInput,self.maximumInput=edit(f,38),edit(f,38)
    self.maximumInput:SetPoint("TOPRIGHT",-16,-82); self.minimumInput:SetPoint("RIGHT",self.maximumInput,"LEFT",-12,0)
    self.levelLabel:SetPoint("RIGHT",self.minimumInput,"LEFT",-8,0)
    local separator=text(f,12); self.rangeSeparator=separator; separator:SetPoint("CENTER",self.maximumInput,"LEFT",-6,0); separator:SetHeight(26); separator:SetJustifyV("MIDDLE"); separator:SetText("-")
    for _,e in ipairs({self.minimumInput,self.maximumInput}) do
        e:SetNumeric(true);e:SetMaxLetters(3)
        e:SetScript("OnEnterPressed",function(b) self:CommitRange();b:ClearFocus() end)
        e:SetScript("OnEditFocusLost",function() self:CommitRange(true) end)
        e:SetScript("OnEscapePressed",function() self:CancelRange() end)
    end
    self.slot=self:Dropdown(f,G.menuWidth,N.SearchModel.slots,function() return self.filter.slot end,function(value) self.filter.slot=value; self:Changed(true) end,G.control); self.slot:SetPoint("TOPRIGHT",-G.inset,-44); self.slot:SetDefaultText("All rewards")
    self.count=text(f,11,{.7,.7,.72}); self.count:SetPoint("TOPLEFT",16,-146); self.count:SetHeight(26);self.count:SetWordWrap(true); self.count:SetJustifyV("MIDDLE")
    self.sort=self:SortButton(f);self.sort:SetPoint("TOPRIGHT",-16,-146)
    local scroll=CreateFrame("ScrollFrame",nil,f); self.scroll=scroll; scroll:SetPoint("TOPLEFT",12,-G.scrollTop); scroll:SetPoint("BOTTOMRIGHT",-26,G.scrollBottom); scroll:EnableMouse(true); scroll:EnableMouseWheel(true)
    self.child=CreateFrame("Frame",nil,scroll); self.child:SetSize(G.width-38,1); scroll:SetScrollChild(self.child)
    self.inspector=N.Stack.NewInspector(f,scroll,function() return self:Visible() and not self:MenuOpen() and not (self.copyFrame and self.copyFrame:IsShown()) end)
    self.bar=U:VerticalBar(f); self.bar:SetPoint("TOPRIGHT",-6,-(G.scrollTop+2)); self.bar:SetPoint("BOTTOMRIGHT",-6,18); self.bar:SetWidth(12); self.bar:SetOrientation("VERTICAL"); self.bar:SetValueStep(1)
    local thumb=A.Call(self.bar.GetThumbTexture,self.bar); if thumb then thumb:SetSize(12,22) end
    self.bar:SetScript("OnValueChanged",function(_,value) if not self.refreshing then self:Scroll(value) end end)
    scroll:SetScript("OnMouseWheel",function(_,delta) if M.Number(delta) then self:Scroll(self.offset-delta*40) end end)
    self.empty=text(self.child,12,{.7,.7,.72}); self.empty:SetPoint("TOPLEFT",8,-14); self.empty:SetWordWrap(true)
    local resize=CreateFrame("Button",nil,f); self.resize=resize; resize:SetPoint("BOTTOMRIGHT",-2,2); resize:SetSize(18,18); resize.texture=resize:CreateTexture(nil,"ARTWORK"); resize.texture:SetAllPoints(); resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then self:CloseMenu(); self.inspector:ClearItem(); f:StartSizing("BOTTOMRIGHT") end end); resize:SetScript("OnMouseUp",function() f:StopMovingOrSizing(); self:AppearanceChanged() end)
    f:SetScript("OnSizeChanged",function()
        if not self.inspector or self.appearanceLayout then return end
        self:AppearanceChanged()
    end)
    f:SetScript("OnHide",function() f:StopMovingOrSizing(); f:SetScript("OnUpdate",nil); self.search:ClearFocus(); self:CancelRange(); self.inspector:ClearItem(); self.footerTooltip:Hide(); self:CloseMenu(); if self.copyFrame then self.copyFrame:Hide() end;if N.Character then N.Character:Sleep()end end)
    f:SetScript("OnEvent",function(_,event,id)
        if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" then
            self:ItemData(id);return
        elseif event=="QUEST_DATA_LOAD_RESULT" then
            self:QuestData(id);return
        end
        if not self:Visible() then
            self.contextDirty=true
            return
        end
        if event=="TOOLTIP_DATA_UPDATE" then
            local i=self.inspector
            if i.item and not i:InspectionCurrent(i.item) then i:ClearItem()
            elseif i.item and i:HasTooltipData(id) then i:Inspect(i.item.button,i.item.row,true); self:Wake() end
            return
        elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then self:AppearanceChanged();return
        elseif event=="ADDON_LOADED" then
            local data=N.Catalog.data;N.Catalog:Begin();if N.Catalog.data==data then return end
        end
        if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" or event=="QUEST_DATA_LOAD_RESULT" then
            self:DataChanged(); return
        end
        self:Changed(nil,true)
    end)
    for _,event in ipairs({"ITEM_DATA_LOAD_RESULT","GET_ITEM_INFO_RECEIVED","QUEST_DATA_LOAD_RESULT","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","ADDON_LOADED","TOOLTIP_DATA_UPDATE"}) do f:RegisterEvent(event) end
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"FindAnUpgradeSearch")
end
function S:DefaultRange(level)
    level=M.Number(level) and level or self:CharacterSnapshot().level
    if not M.Number(level) or level<1 then level=1 end
    local defaults=M.SearchDefaults(N.Core.profile.searchDefaults)
    self.filter.minimum,self.filter.maximum=math.max(1,math.floor(level)-defaults.levelsBelow),math.min(200,math.floor(level)+defaults.levelsAbove)
    self.minimumInput:SetText(self.filter.minimum); self.maximumInput:SetText(self.filter.maximum)
end
function S:Fit()
    local w,h=A.Call(UIParent.GetWidth,UIParent),A.Call(UIParent.GetHeight,UIParent)
    if M.Number(w) and M.Number(h) and w>24 and h>24 then
        self.fitting=true
        local scale=N.Core.profile.scale
        local availableW,availableH=(w-24)/scale,(h-24)/scale
        local currentW,currentH=self.frame:GetWidth(),self.frame:GetHeight()
        if currentW~=self.fitWidth then self.preferredWidth=currentW end
        if currentH~=self.fitHeight then self.preferredHeight=currentH end
        local width=math.min(self.preferredWidth or currentW,G.maxWidth,availableW)
        local height=math.min(self.preferredHeight or currentH,G.maxHeight,availableH)
        self.fitWidth,self.fitHeight=width,height
        self.frame:SetResizeBounds(math.min(G.minWidth,availableW),math.min(G.minHeight,availableH),math.min(G.maxWidth,availableW),math.min(G.maxHeight,availableH))
        self.frame:SetSize(width,height); self.frame:SetScale(scale); U:Border(self.frame,"dialog")
        self:LayoutControls()
        self.fitting=nil
    end
end
function S:LayoutControls()
    local width=self.frame:GetWidth()
    local menuWidth=math.max(112,math.min(G.menuWidth,math.floor(width*.31)))
    local slotWidth=math.max(menuWidth,(A.Call(self.slot.Text.GetStringWidth,self.slot.Text) or 0)+35)
    local scopeWidth=math.max(menuWidth,(A.Call(self.scope.Text.GetStringWidth,self.scope.Text) or 0)+35)
    self.slot:SetWidth(slotWidth);self.scope:SetWidth(scopeWidth)
    self.slot.Text:SetWidth(slotWidth-31);self.scope.Text:SetWidth(scopeWidth-31)
    local main=math.max(1,width-G.inset*2-slotWidth-G.gap)
    self.search:SetWidth(main);self.count:SetWidth(math.max(1,width-70));self.title:SetWidth(math.max(1,width-100))
    self.empty:SetWidth(math.max(1,width-54));self.child:SetWidth(math.max(1,width-38))
    if self.copyFrame then self.copyFrame:SetWidth(math.min(380,width-24));self.copyEdit:SetWidth(self.copyFrame:GetWidth()-30)end
    local caption=math.max(116,(A.Call(self.usable.Text.GetStringWidth,self.usable.Text) or 0)+2)
    self.usable.Text:SetWidth(caption);self.usable:SetHitRectInsets(0,-caption-2,0,0)
    local dungeonCaption=(A.Call(self.dungeons.Text.GetStringWidth,self.dungeons.Text) or 126)+2
    self.dungeons.Text:SetWidth(dungeonCaption);self.dungeons:SetHitRectInsets(0,-dungeonCaption-2,0,0)
    local levelCaption=A.Call(self.levelLabel.GetStringWidth,self.levelLabel) or 36
    local rangeExtra=width<G.inset+scopeWidth+G.gap+levelCaption+8+38+12+38+G.inset and 32 or 0
    local checkExtra=width<12+24+2+caption+G.gap+24+2+dungeonCaption+G.inset and 30 or 0
    self.maximumInput:ClearAllPoints();self.maximumInput:SetPoint("TOPRIGHT",-16,-82-rangeExtra)
    self.usable:ClearAllPoints();self.usable:SetPoint("TOPLEFT",12,-114-rangeExtra)
    self.dungeons:ClearAllPoints();self.dungeons:SetPoint("TOPLEFT",width-G.inset-24-2-dungeonCaption,-114-rangeExtra-checkExtra)
    local extra=rangeExtra+checkExtra
    self.count:ClearAllPoints();self.count:SetPoint("TOPLEFT",16,-146-extra)
    self.sort:ClearAllPoints();self.sort:SetPoint("TOPRIGHT",-16,-146-extra)
    self.count:SetHeight(0)
    local countHeight=math.max(26,A.Call(self.count.GetStringHeight,self.count) or 26);self.count:SetHeight(countHeight)
    self.scrollTop=G.scrollTop+extra+countHeight-26
    self.scroll:ClearAllPoints();self.scroll:SetPoint("TOPLEFT",12,-self.scrollTop);self.scroll:SetPoint("BOTTOMRIGHT",-26,G.scrollBottom)
    self.bar:ClearAllPoints();self.bar:SetPoint("TOPRIGHT",-6,-self.scrollTop-2);self.bar:SetPoint("BOTTOMRIGHT",-6,18)
end
function S:ViewportHeight() return math.max(1,self.frame:GetHeight()-(self.scrollTop or G.scrollTop)-G.scrollBottom) end
function S:Toggle()
    if not N.Core.supported or not N.Core.profile.enabled then N.Core:Print("Enable FindAnUpgrade to search rewards."); return end
    self:Create(); if self:Visible() then self.frame:Hide(); return end
    N.Hover:Dismiss("search"); self.questRequests,self.rewardRequests,self.itemRequests,self.pending={}, {},{},false
    self.queues,self.queued,self.cursors,self.nextRequestAt,self.requestTurn={},{},{},nil,nil
    N.SearchModel.usability,N.SearchModel.currentItems,N.SearchModel.currentStamp={},{},{}
    self.rewardStamps,self.rewardDirty={},{}
    local snapshot=N.Character:Ensure(true)
    local defaults=M.SearchDefaults(N.Core.profile.searchDefaults)
    self.filter.usable,self.filter.includeDungeons=defaults.hideUnusable,defaults.includeDungeons
    self.manualRange=nil; self:DefaultRange(snapshot.level)
    self.dataDeadline=(A.Call(GetTime) or 0)+5
    self.usable:SetChecked(self.filter.usable);self.dungeons:SetChecked(self.filter.includeDungeons);N.Catalog:Begin()
    self.contextLevel,self.contextMap=snapshot.level,snapshot.mapID;self.contextDirty=nil
    self:Fit(); self.appearanceDirty=nil; self.frame:Show(); self.search:SetFocus(); self:Changed(true)
    self:Wake()
end
function S:Tick()
    if not self:Visible() then return end
    local now=A.Call(GetTime) or 0
    if now<(self.menuCheckAt or 0) then return end
    if self:MenuOpen() then self.inspector:ClearItem(); self.menuCheckAt=now+.1; return end
    self.menuCheckAt=nil
    if self.appearanceDirty then self:ApplyAppearance() end
    self.inspector:ItemTransit(now); self.inspector:Compare()
    if self.inspector.item then return end
    if N.Catalog:Step() then self.dirty=true; self.changeAt=self.changeAt or now+.2 end
    if self.dirty and now>=(self.changeAt or 0) then self:Refresh(); self.changeAt=nil end
    self:RequestStep(now)
    if not self:Visible() then return end
    if self.pending and now>=self.dataDeadline then self.pending=false; self:Render() end
    if not self.dirty and not self.appearanceDirty and not self.pending and not self.inspector.item and (N.Catalog.done or not N.Catalog.ids) and not self:HasRequests() then self.frame:SetScript("OnUpdate",nil) end
end
function S:Refresh()
    self.dirty=false; self.inspector:ClearItem(); self.inspector.generation=self.inspector.generation+1
    for id in pairs(self.rewardDirty or {}) do
        if self:QuestRelevant({[id]=true}) then N.SearchModel:InvalidateQuest(id);self.rewardDirty[id]=nil end
    end
    self.results,self.error=N.SearchModel:Query(self.filter); self:Enqueue("item",N.SearchModel.needed); self:Enqueue("quest",N.SearchModel.questNeeded)
    local count=#self.results.." quests"
    if N.Catalog.ids and not N.Catalog.done then count="Indexing rewards - "..math.floor((N.Catalog.cursor-1)/math.max(1,#N.Catalog.ids)*100).."%  -  "..count end
    if self.filter.scope=="SAME_ZONE" then
        local snapshot=self:CharacterSnapshot();if snapshot.zoneName then count=count.." - "..snapshot.zoneName end
    end
    local empty="No matching quest rewards. Try a wider level range or another slot."
    if N.Catalog.ids and not N.Catalog.done then empty="Loading quests."
    elseif #N.SearchModel.needed>0 and (A.Call(GetTime) or 0)<self.dataDeadline then empty="Loading item details." end
    self.count:SetText(count);self:LayoutControls();self:LayoutResults(); self.empty:SetText(N.Catalog.error or self.error or (#self.results==0 and empty or "")); self.empty:SetShown(#self.results==0)
    self:Scroll(self.offset)
end
function S:LayoutResults()
    self.positions={}; local y=0
    for i,row in ipairs(self.results) do self.positions[i]=y; y=y+(self.heights and self.heights[row.id] or 96)+G.rowGap end
    self.contentHeight=y; self.child:SetWidth(self.frame:GetWidth()-38); self.child:SetHeight(math.max(y,1))
    self.maximum=math.max(0,y-self:ViewportHeight()); self.refreshing=true; self.bar:SetMinMaxValues(0,self.maximum); self.bar:SetShown(self.maximum>0); self.refreshing=false
    if self.bottomTarget or self.offset>self.maximum then self.offset=self.maximum; self.scroll:SetVerticalScroll(self.offset); self.refreshing=true; self.bar:SetValue(self.offset); self.refreshing=false end
end
function S:Card(index)
    if self.cards[index] then return self.cards[index] end
    local c=CreateFrame("Frame",nil,self.child,"BackdropTemplate"); self.cards[index]=c; surface(c); c:EnableMouse(true)
    c.title,c.tag,c.location,c.evidence=text(c,13,{1,.82,.2}),text(c,10,{.82,.73,.53}),text(c,11,{.75,.75,.77}),text(c,11,{.75,.75,.77})
    c.title:SetPoint("TOPLEFT",8,-7); c.tag:SetPoint("TOPRIGHT",-8,-9); c.tag:SetJustifyH("RIGHT"); c.location:SetPoint("TOPLEFT",8,-27); c.evidence:SetPoint("TOPLEFT",8,-42)
    c.groupMeasure=text(c,10); c.groupMeasure:Hide()
    c.titleHit=CreateFrame("Frame",nil,c); c.titleHit:SetPoint("TOPLEFT",8,-5); c.titleHit:SetHeight(18); c.titleHit:EnableMouse(true)
    c.titleHit:SetScript("OnMouseUp",function(_,button) if button=="RightButton" and c.row and A.Over(self.scroll) and A.Over(c.titleHit) then self:ContextMenu(c.row,c) end end)
    c.locationHit=CreateFrame("Frame",nil,c); c.locationHit:SetPoint("TOPLEFT",8,-25); c.locationHit:SetHeight(16); c.locationHit:EnableMouse(true)
    c.locationHit:SetScript("OnMouseUp",function(_,button) if button=="RightButton" and c.row and A.Over(self.scroll) and A.Over(c.locationHit) then self:ContextMenu(c.row,c) end end)
    c.giver=CreateFrame("Button",nil,c); c.giver:SetPoint("TOPRIGHT",-8,-26); c.giver:SetSize(80,16); c.giver.text=text(c.giver,10,{1,.82,.2}); c.giver.text:SetAllPoints(); c.giver.text:SetJustifyH("RIGHT")
    c.giver:SetScript("OnClick",function() if c.row and A.Over(self.scroll) and A.Over(c.giver) then self:LocationMenu(c.row,c.giver) end end)
    c.icons={}; c.footer={text(c,11),text(c,11),text(c,11)}; c.footerHits={}
    for i=1,3 do
        local hit=CreateFrame("Frame",nil,c); c.footerHits[i]=hit; hit:EnableMouse(true); hit:SetHeight(18)
    end
    c.more=CreateFrame("Button",nil,c); c.more:SetSize(80,16); c.more.text=text(c.more,10); c.more.text:SetAllPoints(); c.more:SetPoint("TOPRIGHT",-8,-42)
    c.more:SetScript("OnClick",function() self.expanded[c.row.id]=not self.expanded[c.row.id]; self:Changed() end)
    c:SetScript("OnMouseUp",function(_,button) if button=="RightButton" and c.row and A.Over(self.scroll) and A.Over(c) then self:ContextMenu(c.row,c) end end)
    return c
end
function S:Icon(card,index)
    if card.icons[index] then return card.icons[index] end
    local b=CreateFrame("Button",nil,card); card.icons[index]=b; b:SetSize(G.icon,G.icon); b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(); b.border=b:CreateTexture(nil,"OVERLAY"); b.border:SetAllPoints(); b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    b.name,b.group=text(card,11),text(card,10,{.7,.7,.72})
    b.count=b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall"); b.count:SetPoint("BOTTOMRIGHT",-1,1); b.count:SetJustifyH("RIGHT")
    b.level=b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall"); b.level:SetPoint("BOTTOMLEFT",2,2); b.level:SetJustifyH("LEFT")
    b:SetScript("OnEnter",function() self.footerTooltip:Hide(); self:CloseTextTip(); if b.row then self.inspector:Inspect(b,b.row) end; self:Wake() end); b:SetScript("OnLeave",function() self.inspector.itemOutsideAt=nil end)
    b:RegisterForClicks("RightButtonUp"); b:SetScript("OnClick",function() if A.Over(self.scroll) and A.Over(b) then self:ContextMenu(card.row,card) end end)
    return b
end
local function measured(label,width,value)
    label:SetWidth(math.max(1,width)); label:SetText(value or "")
    local visible=M.Text(value)~=nil; label:SetShown(visible)
    return visible and math.max(12,A.Call(label.GetStringHeight,label) or 12) or 0
end
function S:Fill(card,row)
    card.row=row; local width=self.child:GetWidth(); card:SetWidth(width); U:Border(card,"tooltip")
    local title=(row.level and "["..row.level.."] " or "")..(row.title or ("Quest "..row.id))
    local status=M.Status(row.id); local accent=N.Core.profile.accents and status
    local badge=accent=="verifiedNew" and "New in Forever" or accent=="verifiedUpdated" and "Modified" or ""
    card.tag:SetText(badge); card.tag:SetShown(badge~="")
    local badgeWidth=badge~="" and (A.Call(card.tag.GetStringWidth,card.tag) or 80)+10 or 0
    local titleWidth=width-16-badgeWidth
    card.title:SetWordWrap(true); local titleHeight=measured(card.title,titleWidth,title)
    card.titleHit:SetWidth(titleWidth); card.titleHit:SetHeight(titleHeight)
    local r,g,b=M.AccentFill(N.Core.profile,accent,.06,.06,.07); card:SetBackdropColor(r,g,b,.97)
    local reward,catalog,usabilityChanged=N.SearchModel:Reward(row); local items={}; local matching={}
    self.rewardStamps=self.rewardStamps or {};self.rewardStamps[row.id]=rewardStamp(reward)
    for _,item in ipairs(row.items) do matching[item.itemID]=item end
    if usabilityChanged then self:DataChanged() end
    for _,group in ipairs({{reward.items,"Guaranteed"},{reward.choices,"Choose one"}}) do
        for _,item in ipairs(group[1].items or {}) do
            if matching[item.itemID] and (not self.filter.usable or item.usable~=false) then items[#items+1]={item=item,meta=matching[item.itemID],label=group[2]} end
        end
    end
    for _,item in ipairs(catalog) do items[#items+1]={item=item,meta=item,label="Reward"} end
    local limit=self.expanded[row.id] and #items or math.min(4,#items)
    local groups={}; for i=1,limit do
        local entry=items[i]; local group=groups[#groups]
        if not group or group.label~=entry.label then group={label=entry.label,items={}}; groups[#groups+1]=group end
        group.items[#group.items+1]=entry
    end
    local stride=G.icon+G.iconGap
    local maxReward=math.max(G.icon,math.min(174,math.floor(width*.4)))
    local columns=math.max(1,math.floor((maxReward+G.iconGap)/stride))
    local rewardWidth,totalGroupWidth=0,0
    for _,group in ipairs(groups) do
        local labelled=group.label=="Choose one" or #groups>1
        local natural=math.min(columns,#group.items)*stride-G.iconGap
        if labelled then card.groupMeasure:SetText(group.label); natural=math.max(natural,(A.Call(card.groupMeasure.GetStringWidth,card.groupMeasure) or 0)) end
        group.width=natural; rewardWidth=math.max(rewardWidth,natural); totalGroupWidth=totalGroupWidth+natural
    end
    local horizontal=#groups>1 and totalGroupWidth+G.gap*(#groups-1)<=maxReward
    if horizontal then rewardWidth=totalGroupWidth+G.gap*(#groups-1) end
    if #items>4 then rewardWidth=math.max(rewardWidth,82) end
    local locations=N.Catalog:Locations(row.id)
    card.giver.text:SetText(#locations.." locations")
    local giverWidth=(A.Call(card.giver.text.GetStringWidth,card.giver.text) or 0)+2
    card.giver:SetWidth(giverWidth)
    if #locations>1 then rewardWidth=math.max(rewardWidth,giverWidth) end
    local bodyWidth=width-16-(rewardWidth>0 and rewardWidth+12 or 0)
    local top=8+titleHeight+4
    local location=self.locationChoice[row.id] or N.Catalog:Location(row.id); row.location=location
    local place=location and self:LocationLabel(location) or nil
    card.location:SetWordWrap(true); card.location:ClearAllPoints(); card.location:SetPoint("TOPLEFT",8,-top)
    card.locationHit:ClearAllPoints(); card.locationHit:SetPoint("TOPLEFT",8,-top)
    local placeHeight=measured(card.location,bodyWidth,place)
    card.locationHit:SetSize(bodyWidth,placeHeight); card.locationHit:SetShown(place~=nil)
    local y=top+placeHeight+(placeHeight>0 and 3 or 0)
    local note=M.Text(row.evidence)
    local actionable=note and note~="Availability unconfirmed" and note~="Available" and note~="Recorded availability"
    if actionable then
        note=note:gsub("^Recorded minimum level ","Req. lvl "):gsub("^Requires level ","Req. lvl "):gsub("^Recorded ","")
    end
    card.evidence:SetWordWrap(true); card.evidence:ClearAllPoints(); card.evidence:SetPoint("TOPLEFT",8,-y)
    local evidenceHeight=measured(card.evidence,bodyWidth,actionable and note or nil)
    y=y+evidenceHeight+(evidenceHeight>0 and 3 or 0); card.fullTitle=title
    local rewardY=top
    card.giver:SetShown(#locations>1); card.giver.text:SetText(#locations.." locations")
    local iconIndex,groupCursor,groupMaximum=0,0,0; local rewardTop=rewardY
    for _,group in ipairs(groups) do
        local labelled=group.label=="Choose one" or #groups>1
        local rows=math.ceil(#group.items/columns); local labelHeight=labelled and 14 or 0
        for i,entry in ipairs(group.items) do
            local item=entry.item; iconIndex=iconIndex+1; local icon=self:Icon(card,iconIndex); icon.row=item
            local groupX=width-8-rewardWidth+(horizontal and groupCursor or 0)
            local x,iy=groupX+((i-1)%columns)*stride,rewardY+math.floor((i-1)/columns)*stride
            icon:ClearAllPoints(); icon:SetPoint("TOPLEFT",x,-iy)
            icon.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            local color=item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
            icon.border:SetVertexColor(color and color.r or .6,color and color.g or .6,color and color.b or .6)
            icon.count:SetText(item.quantity and item.quantity>1 and tostring(item.quantity) or "")
            local level=entry.meta and entry.meta.itemLevel or item.itemLevel
            icon.level:SetText(M.Number(level) and level>0 and level==math.floor(level) and tostring(level) or "")
            local crowded=icon.level:GetText()~="" and icon.count:GetText()~="" and
                (A.Call(icon.level.GetStringWidth,icon.level) or 0)+(A.Call(icon.count.GetStringWidth,icon.count) or 0)+5>G.icon
            icon.count:ClearAllPoints();icon.count:SetPoint(crowded and "TOPRIGHT" or "BOTTOMRIGHT",-1,crowded and -1 or 1)
            icon.group:ClearAllPoints(); icon.group:SetPoint("TOPLEFT",groupX,-(rewardY+rows*stride-G.iconGap+3)); icon.group:SetWidth(group.width)
            icon.group:SetText(group.label); icon.group:SetShown(labelled and i==1)
            icon.name:Hide(); icon:Show()
        end
        local groupHeight=labelHeight+rows*stride-G.iconGap+5
        if horizontal then groupMaximum=math.max(groupMaximum,groupHeight);groupCursor=groupCursor+group.width+G.gap
        else rewardY=rewardY+groupHeight end
    end
    if horizontal then rewardY=rewardTop+groupMaximum end
    card.giver:ClearAllPoints(); card.giver:SetPoint("TOPRIGHT",-8,-rewardY)
    if #locations>1 then rewardY=rewardY+18 end
    for i=iconIndex+1,#card.icons do local icon=card.icons[i]; icon.row=nil; icon:Hide(); icon.name:Hide(); icon.group:Hide(); icon.level:SetText(""); icon.count:SetText("") end
    card.more:SetShown(#items>4); card.more.text:SetText(self.expanded[row.id] and "Fewer rewards" or "+"..math.max(0,#items-4).." rewards")
    if #items>4 then card.more:ClearAllPoints(); card.more:SetPoint("TOPRIGHT",-8,-rewardY); rewardY=rewardY+18 end
    local values={}
    local money=reward.money.state=="ready" and N.Rewards.Money(reward.money.value)
    if money then values[#values+1]=money end
    if reward.xp.state=="ready" and reward.xp.value>0 then values[#values+1]=reward.xp.value.." XP" end
    local hasChoices=#(reward.choices.items or {})>0
    for _,currency in ipairs(reward.currencies.items or {}) do if currency.isChoice then hasChoices=true end end
    for _,currency in ipairs(reward.currencies.items or {}) do
        values[#values+1]=(currency.isChoice and "Choose one: " or hasChoices and "Guaranteed: " or "")..currency.name.." "..currency.amount
    end
    for _,entry in ipairs(reward.reputation.items or {}) do
        local amount=(entry.amount>0 and "+" or "")..entry.amount
        values[#values+1]=(entry.name or "Faction "..entry.factionID).." "..amount
    end
    for i,label in ipairs(card.footer) do label:Hide(); card.footerHits[i]:Hide(); card.footerHits[i].value=nil end
    if #values>0 then
        local label,hit=card.footer[1],card.footerHits[1]
        label:SetWordWrap(true); label:ClearAllPoints(); label:SetPoint("TOPLEFT",8,-y)
        local h=measured(label,bodyWidth,table.concat(values,"  "))
        hit:ClearAllPoints(); hit:SetPoint("TOPLEFT",8,-y); hit:SetSize(bodyWidth,h); hit.value=table.concat(values,"\n")
        y=y+h+3
    end
    local height=math.max(y,rewardY)+5; card:SetHeight(height); self.heights=self.heights or {}
    local resized=self.heights[row.id]~=height; self.heights[row.id]=height
    if reward.state=="pending" and (A.Call(GetTime) or 0)<self.dataDeadline then self.pending=true end
    self:Enqueue("reward",{row.id})
    return height,resized
end
function S:Render()
    if not self.results then return end
    self:CloseTextTip(); self.footerTooltip:Hide(); self.inspector:ClearItem()
    for _=1,4 do
        local first,last=1,0; local bottom=self.offset+self:ViewportHeight()
        for i,row in ipairs(self.results) do if self.positions[i]+(self.heights and self.heights[row.id] or 96)>=self.offset and self.positions[i]<=bottom then if last==0 then first=i end; last=i end end
        local count,resized=0,false
        for i=first,last do count=count+1; local c=self:Card(count); c.resultIndex=i; c:ClearAllPoints(); c:SetPoint("TOPLEFT",0,-self.positions[i]); local _,changed=self:Fill(c,self.results[i]); resized=resized or changed; c:Show() end
        for i=count+1,#self.cards do self.cards[i].row=nil; self.cards[i]:Hide() end
        if not resized then return end
        self:LayoutResults()
    end
    -- Keep final anchors and range coherent even if old estimates reveal more
    -- rows than four passes can settle. The scheduler finishes that work later.
    local bottom=self.offset+self:ViewportHeight()
    for _,card in ipairs(self.cards) do
        local y=card.row and self.positions[card.resultIndex]
        if y and y+card:GetHeight()>=self.offset and y<=bottom then card:ClearAllPoints(); card:SetPoint("TOPLEFT",0,-y)
        else card.row=nil; card:Hide() end
    end
    if self.appearanceLayout then self.appearanceDirty=true; self:Wake() else self:DataChanged() end
end
function S:Scroll(value)
    if not M.Number(value) then return end
    local maximum=self.maximum or 0; self.bottomTarget=maximum>0 and value>=maximum
    self:CloseMenu(); self.inspector:ClearItem(); self.footerTooltip:Hide(); self.offset=math.max(0,math.min(maximum,value)); self.scroll:SetVerticalScroll(self.offset); self.refreshing=true; self.bar:SetValue(self.offset); self.refreshing=false; self:Render()
end
function S:Copy(value)
    if not M.Text(value) then return end
    self:CloseMenu(); self.inspector:ClearItem()
    if not self.copyFrame then
        local f=CreateFrame("Frame","FindAnUpgradeCopy",self.frame,"BackdropTemplate"); self.copyFrame=f; f:SetSize(math.min(380,self.frame:GetWidth()-24),90); f:SetPoint("CENTER"); f:SetClampedToScreen(true); f:SetFrameStrata("FULLSCREEN_DIALOG"); U:Dialog(f)
        local label=text(f,12); label:SetPoint("TOPLEFT",12,-12); label:SetText("Ctrl+C to copy")
        self.copyEdit=edit(f,f:GetWidth()-30); self.copyEdit:SetPoint("TOPLEFT",15,-42); self.copyEdit:SetMaxLetters(1024); self.copyEdit:SetScript("OnEscapePressed",function() f:Hide() end); self.copyEdit:SetScript("OnEnterPressed",function() f:Hide() end)
        f:SetScript("OnHide",function() self.copyEdit:ClearFocus() end); UISpecialFrames[#UISpecialFrames+1]="FindAnUpgradeCopy"
    end
    U:Border(self.copyFrame,"dialog"); self.copyFrame:SetWidth(math.min(380,self.frame:GetWidth()-24)); self.copyEdit:SetWidth(self.copyFrame:GetWidth()-30); self.copyFrame:Show(); self.copyEdit:SetText(value); self.copyEdit:HighlightText(); self.copyEdit:SetFocus()
end
function S:ContextMenu(row,owner)
    if not row or not self:Visible() or not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then return end
    self:CloseMenu(); self.inspector:ClearItem(); self.footerTooltip:Hide(); self.search:ClearFocus()
    local location=row.location; local coordinates=N.SearchModel.Coordinates(location); local wowhead=N.SearchModel.Wowhead(row.id)
    local waypointReason=not coordinates and "Coordinates unavailable." or location.phase and "This location depends on phase or has conflicting positions." or A.Call(C_Map and C_Map.CanSetUserWaypointOnMap,location.mapID)~=true and "This map cannot accept a user waypoint." or nil
    local nameKind=location and (location.npcID and "NPC" or location.objectID and "object" or location.itemID and "item")
    local giverName=nameKind and location.nameKnown==true and M.Text(location.name) or nil
    self.menu=MenuUtil.CreateContextMenu(owner,function(_,root)
        self:MenuLifetime(root)
        local function button(label,callback,enabled,reason)
            local entry=root:CreateButton(label,callback); entry:SetEnabled(enabled~=false); self:MenuFont(entry)
            if reason then entry:SetTooltip(function(t) t:SetText(reason) end) end; return entry
        end
        button("Set waypoint",function() if not N.SearchModel.Waypoint(location) then N.Core:Print("Waypoint unavailable.") end end,waypointReason==nil,waypointReason)
        button("Copy coordinates",function() self:Copy(coordinates) end,coordinates~=nil,not coordinates and "Coordinates unavailable." or nil)
        button("Copy quest ID",function() self:Copy(tostring(row.id)) end)
        button("Copy "..(nameKind or "starter").." name",function() self:Copy(giverName) end,giverName~=nil,not giverName and (nameKind or "Starter").." name unavailable." or nil)
        local link=button("Copy Wowhead link",function() self:Copy(wowhead) end,wowhead~=nil)
        link:SetTooltip(function(t) t:SetText(wowhead and "Forever quest reference" or "No catalogue reference for this variant.") end)
        if #N.Catalog:Locations(row.id)>1 then local giver=button("Choose location"); self:GiverChoices(giver,row) end
    end)
end
function S:MenuFont(entry)
    entry:AddInitializer(function(button) button.fontString:SetFontObject(self.menuFont) end)
end
function S:MenuLifetime(root)
    root:AddMenuReleasedCallback(function(menu) if self.menu==menu then self.menu=nil end; self:Wake() end)
end
function S:LocationLabel(location)
    if not location then return "Quest giver unavailable" end
    local parts={}; local zone=M.Text(location.zone); local name=M.Text(location.name)
    if zone then parts[#parts+1]=zone end
    if name then parts[#parts+1]=(location.itemID and "Starts from " or "")..name end
    if N.SearchModel.Coordinates(location) then parts[#parts+1]=string.format("%.1f, %.1f",location.x*100,location.y*100) end
    return #parts>0 and table.concat(parts," \226\128\162 ") or "Quest giver unavailable"
end
function S:GiverChoices(root,row)
    root:SetScrollMode(220)
    for _,location in ipairs(N.Catalog:Locations(row.id)) do
        local entry=root:CreateRadio(self:LocationLabel(location),function(value) return (self.locationChoice[row.id] or N.Catalog:Location(row.id))==value end,function(value)
            self.locationChoice[row.id]=value; row.location=value; self:Changed()
        end,location)
        self:MenuFont(entry)
        entry:SetTooltip(function(t)
            t:SetText(self:LocationLabel(location))
            if location.phase then t:AddLine("This location depends on phase or has conflicting positions.",.7,.7,.72,true)
            elseif location.mobile then t:AddLine("This giver may move.",.7,.7,.72,true)
            elseif not N.SearchModel.Coordinates(location) then t:AddLine("Coordinates unavailable.",.7,.7,.72,true) end
        end)
    end
end
function S:LocationMenu(row,owner)
    if not row or not self:Visible() or not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then return end
    self:CloseMenu(); self.inspector:ClearItem(); self.search:ClearFocus()
    self.menu=MenuUtil.CreateContextMenu(owner,function(_,root) self:MenuLifetime(root); self:GiverChoices(root,row) end)
end

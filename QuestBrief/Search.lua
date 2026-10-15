local _,N=...
local M,A,U=N.Model,N.Adapter,N.UI
local S={cards={},offset=0,expanded={},locationChoice={}}; N.Search=S
local skin={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=10,insets={left=2,right=2,top=2,bottom=2}}
local function text(parent,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY","GameTooltipText"); U:Font(f,size or 12)
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetWordWrap(false); f:SetTextColor(unpack(color or {.93,.94,.97})); return f
end
local function surface(f) f:SetBackdrop(skin); f:SetBackdropColor(.045,.045,.05,.96); f:SetBackdropBorderColor(.5,.5,.5,.8) end
local function edit(parent,width)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); e:SetSize(width,24); e:SetAutoFocus(false); e:SetMaxLetters(100); e:SetTextInsets(6,6,0,0); U:Font(e,12); return e
end
function S:Visible() return self.frame and A.Visible(self.frame) end
function S:MenuOpen()
    local manager=Menu and A.Call(Menu.GetManager)
    return manager and A.Call(manager.IsAnyMenuOpen,manager)==true or false
end
function S:CloseMenu()
    if self.menu and type(self.menu.Close)=="function" then self.menu:Close() end
    self.menu=nil
    for _,dropdown in ipairs({self.slot,self.sort}) do if type(dropdown.CloseMenu)=="function" then dropdown:CloseMenu() end end
    if self.footerTooltip then self.footerTooltip:Hide() end
    self:CloseTextTip()
end
function S:CloseTextTip()
    if self.textTooltip then self.textTooltip:Hide() end
end
function S:TextTip(owner,value)
    self:CloseTextTip()
    if not M.Text(value) or not self:Visible() or not A.Over(self.scroll) or not A.Over(owner) or self:MenuOpen() or self.copyFrame and self.copyFrame:IsShown() then return end
    self.inspector:ClearItem(); self.footerTooltip:Hide()
    if not self.textTooltip then self.textTooltip=CreateFrame("GameTooltip","QuestBriefSearchTextTooltip",self.frame,"SharedTooltipTemplate") end
    self.textTooltip:SetOwner(owner,"ANCHOR_TOP"); self.textTooltip:SetText(value); self.textTooltip:Show()
end
function S:Changed(reset)
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
function S:Dropdown(parent,width,entries,get,choose)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle1DropdownTemplate"); d:SetSize(width,24)
    d.Text:ClearAllPoints(); d.Text:SetPoint("LEFT",d,"LEFT",9,0); d.Text:SetWidth(width-31); d.Text:SetHeight(24); d.Text:SetJustifyH("LEFT"); d.Text:SetJustifyV("MIDDLE"); d.Text:SetWordWrap(false); U:Font(d.Text,12)
    d:SetupMenu(function(_,root)
        if self.inspector then self.inspector:ClearItem() end; if self.CloseTextTip then self:CloseTextTip() end; root:SetScrollMode(220)
        root:AddMenuReleasedCallback(function() self:Wake() end)
        for _,entry in ipairs(entries) do
            local value,label=entry[1],entry[2]
            local row=root:CreateRadio(label,function(v) return get()==v end,function(v) choose(v); d:SetDefaultText(label) end,value)
            row:AddInitializer(function(button) button.fontString:SetFontObject(self.menuFont) end)
        end
    end)
    return d
end
function S:CancelRange()
    self.minimumInput:SetText(tostring(self.filter.minimum or ""))
    self.maximumInput:SetText(tostring(self.filter.maximum or ""))
    self.minimumInput:ClearFocus(); self.maximumInput:ClearFocus()
end
function S:Create()
    if self.frame then return end
    self.filter={query="",usable=true,slot="ALL",sort="FIT"}
    local f=CreateFrame("Frame","QuestBriefSearch",UIParent,"BackdropTemplate"); self.frame=f; f:Hide()
    f:SetSize(560,600); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true); f:SetResizeBounds(520,400,900,900); U:Dialog(f)
    self.menuFont=CreateFont("QuestBriefSearchMenuFont"); U:Font(self.menuFont,12)
    self.footerTooltip=CreateFrame("GameTooltip","QuestBriefSearchFooterTooltip",f,"SharedTooltipTemplate"); self.footerTooltip:Hide()
    self.title=text(f,16,{1,.82,.2}); self.title:SetPoint("TOPLEFT",16,-14); self.title:SetText("QuestBrief")
    local drag=CreateFrame("Frame",nil,f); drag:SetPoint("TOPLEFT",0,0); drag:SetPoint("TOPRIGHT",-40,0); drag:SetHeight(38); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() self:CloseMenu(); self.inspector:ClearItem(); f:StartMoving() end); drag:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetSize(24,24); close:SetPoint("TOPRIGHT",-8,-8); close:SetScript("OnClick",function() f:Hide() end)
    self.search=edit(f,520); self.search:SetPoint("TOPLEFT",16,-44); self.search:SetPoint("TOPRIGHT",-16,-44)
    self.placeholder=text(self.search,11,{.7,.7,.72}); self.placeholder:SetPoint("LEFT",7,0); self.placeholder:SetText("Quest or reward")
    self.search:SetScript("OnTextChanged",function(e,user) self.placeholder:SetShown(e:GetText()==""); if user then self.filter.query=e:GetText():sub(1,100); self:Changed(true) end end)
    self.search:SetScript("OnEscapePressed",function(e) e:ClearFocus(); f:Hide() end)
    self.search:SetScript("OnEnterPressed",function(e) e:ClearFocus() end)
    self.usable=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); self.usable:SetPoint("TOPLEFT",12,-77); self.usable:SetSize(24,24); self.usable.Text:SetText("Usable for my class"); self.usable.Text:SetWidth(142); U:Font(self.usable.Text,12); self.usable:SetHitRectInsets(0,-144,0,0)
    self.usable:SetScript("OnClick",function(b) self.filter.usable=b:GetChecked()==true; self:Changed(true) end)
    self.levelLabel=text(f,11); self.levelLabel:SetPoint("TOPLEFT",194,-83); self.levelLabel:SetText("Quest level")
    self.minimumInput,self.maximumInput=edit(f,36),edit(f,36); self.minimumInput:SetPoint("TOPLEFT",264,-78); self.maximumInput:SetPoint("TOPLEFT",310,-78)
    local separator=text(f,12); separator:SetPoint("TOPLEFT",301,-83); separator:SetText("-")
    local function range()
        local lo,hi=tonumber(self.minimumInput:GetText()),tonumber(self.maximumInput:GetText())
        if M.Number(lo) and M.Number(hi) and lo>=1 and hi<=200 and lo<=hi and lo==math.floor(lo) and hi==math.floor(hi) then self.filter.minimum,self.filter.maximum,self.manualRange=lo,hi,true; self:Changed(true)
        else self.minimumInput:SetText(self.filter.minimum or ""); self.maximumInput:SetText(self.filter.maximum or "") end
    end
    for _,e in ipairs({self.minimumInput,self.maximumInput}) do e:SetNumeric(true); e:SetMaxLetters(3); e:SetScript("OnEnterPressed",function(b) range(); b:ClearFocus() end); e:SetScript("OnEscapePressed",function() self:CancelRange() end) end
    self.slot=self:Dropdown(f,144,N.SearchModel.slots,function() return self.filter.slot end,function(value) self.filter.slot=value; self:Changed(true) end); self.slot:SetPoint("TOPRIGHT",-16,-78); self.slot:SetDefaultText("All slots")
    self.count=text(f,11,{.7,.7,.72}); self.count:SetPoint("TOPLEFT",16,-115); self.count:SetWidth(310)
    self.sort=self:Dropdown(f,144,{{"FIT","Level fit"},{"LEVEL","Quest level"}},function() return self.filter.sort end,function(value) self.filter.sort=value; self:Changed(true) end); self.sort:SetPoint("TOPRIGHT",-16,-109); self.sort:SetDefaultText("Level fit")
    local scroll=CreateFrame("ScrollFrame",nil,f); self.scroll=scroll; scroll:SetPoint("TOPLEFT",12,-142); scroll:SetPoint("BOTTOMRIGHT",-26,16); scroll:EnableMouse(true); scroll:EnableMouseWheel(true)
    self.child=CreateFrame("Frame",nil,scroll); self.child:SetSize(512,1); scroll:SetScrollChild(self.child)
    self.inspector=N.Stack.NewInspector(f,scroll,function() return self:Visible() and not self:MenuOpen() and not (self.copyFrame and self.copyFrame:IsShown()) end)
    self.bar=U:VerticalBar(f); self.bar:SetPoint("TOPRIGHT",-6,-144); self.bar:SetPoint("BOTTOMRIGHT",-6,18); self.bar:SetWidth(12); self.bar:SetOrientation("VERTICAL"); self.bar:SetValueStep(1)
    local thumb=A.Call(self.bar.GetThumbTexture,self.bar); if thumb then thumb:SetSize(12,22) end
    self.bar:SetScript("OnValueChanged",function(_,value) if not self.refreshing then self:Scroll(value) end end)
    scroll:SetScript("OnMouseWheel",function(_,delta) if M.Number(delta) then self:Scroll(self.offset-delta*40) end end)
    self.empty=text(self.child,12,{.7,.7,.72}); self.empty:SetPoint("TOPLEFT",8,-14); self.empty:SetWidth(490)
    local resize=CreateFrame("Button",nil,f); resize:SetPoint("BOTTOMRIGHT",-2,2); resize:SetSize(18,18); resize.texture=resize:CreateTexture(nil,"ARTWORK"); resize.texture:SetAllPoints(); resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then self:CloseMenu(); self.inspector:ClearItem(); f:StartSizing("BOTTOMRIGHT") end end); resize:SetScript("OnMouseUp",function() f:StopMovingOrSizing(); self:Changed() end)
    f:SetScript("OnSizeChanged",function() if self.inspector then self:Fit(); self:Changed() end end)
    f:SetScript("OnHide",function() f:StopMovingOrSizing(); f:SetScript("OnUpdate",nil); self.search:ClearFocus(); self:CancelRange(); self.inspector:ClearItem(); self.footerTooltip:Hide(); self:CloseMenu(); if self.copyFrame then self.copyFrame:Hide() end end)
    f:SetScript("OnEvent",function(_,event,id)
        if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" then
            id=M.QuestId(id); if not id or not (N.SearchModel.cache[id] or self.itemRequests and self.itemRequests[id]) then return end
            N.SearchModel.cache[id]=nil
        elseif event=="QUEST_DATA_LOAD_RESULT" then
            id=M.QuestId(id); if not id or not N.Catalog.records[id] then return end
            N.Catalog:Invalidate(id); N.SearchModel.currentItems[id],N.SearchModel.currentStamp[id],N.SearchModel.usability[id]=nil,nil,nil
        elseif event=="QUEST_LOG_UPDATE" or event=="QUEST_TURNED_IN" or event=="PLAYER_LEVEL_UP" or event=="PLAYER_ENTERING_WORLD" then N.Catalog:Invalidate()
        end
        if event=="PLAYER_LEVEL_UP" or event=="PLAYER_EQUIPMENT_CHANGED" or event=="QUEST_LOG_UPDATE" or event=="QUEST_TURNED_IN" or event=="PLAYER_ENTERING_WORLD" or event=="SPELLS_CHANGED" or event=="SKILL_LINES_CHANGED" then N.SearchModel.usability,N.SearchModel.currentItems,N.SearchModel.currentStamp={},{},{} end
        if not self:Visible() then return end
        if event=="TOOLTIP_DATA_UPDATE" then
            local i=self.inspector
            if i.item and not i:InspectionCurrent(i.item) then i:ClearItem()
            elseif i.item and i:HasTooltipData(id) then i:Inspect(i.item.button,i.item.row,true); self:Wake() end
            return
        elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then self:Fit()
        elseif event=="PLAYER_LEVEL_UP" and not self.manualRange then self:DefaultRange(id)
        elseif event=="ADDON_LOADED" then N.Catalog:Begin() end
        if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" or event=="QUEST_DATA_LOAD_RESULT" then
            self:DataChanged(); return
        end
        self:Changed()
    end)
    for _,event in ipairs({"ITEM_DATA_LOAD_RESULT","GET_ITEM_INFO_RECEIVED","QUEST_DATA_LOAD_RESULT","QUEST_LOG_UPDATE","QUEST_TURNED_IN","PLAYER_ENTERING_WORLD","PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","ADDON_LOADED","TOOLTIP_DATA_UPDATE"}) do f:RegisterEvent(event) end
    for _,event in ipairs({"SPELLS_CHANGED","SKILL_LINES_CHANGED"}) do pcall(f.RegisterEvent,f,event) end
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"QuestBriefSearch")
end
function S:DefaultRange(level)
    level=M.Number(level) and level or A.Call(UnitLevel,"player")
    if not M.Number(level) or level<1 then level=1 end
    self.filter.minimum,self.filter.maximum=math.max(1,math.floor(level)-5),math.floor(level)+3
    self.minimumInput:SetText(self.filter.minimum); self.maximumInput:SetText(self.filter.maximum)
end
function S:Fit()
    local w,h=A.Call(UIParent.GetWidth,UIParent),A.Call(UIParent.GetHeight,UIParent)
    if M.Number(w) and M.Number(h) then self.frame:SetScale(math.min(N.Core.profile.scale,(w-24)/self.frame:GetWidth(),(h-24)/self.frame:GetHeight())) end
end
function S:Toggle()
    if not N.Core.supported or not N.Core.profile.enabled then N.Core:Print("Enable QuestBrief to search rewards."); return end
    self:Create(); if self:Visible() then self.frame:Hide(); return end
    N.Hover:Dismiss("search"); self.questRequests,self.rewardRequests,self.itemRequests,self.pending={}, {},{},false
    self.queues,self.queued,self.cursors,self.nextRequestAt,self.requestTurn={},{},{},nil,nil
    N.SearchModel.usability,N.SearchModel.currentItems,N.SearchModel.currentStamp={},{},{}
    self.dataDeadline=(A.Call(GetTime) or 0)+5; if not self.manualRange then self:DefaultRange() end
    self.usable:SetChecked(self.filter.usable); N.Catalog:Begin(); self:Fit(); self.frame:Show(); self.search:SetFocus(); self:Changed(true)
    self:Wake()
end
function S:Tick()
    if not self:Visible() then return end
    local now=A.Call(GetTime) or 0
    if now<(self.menuCheckAt or 0) then return end
    if self:MenuOpen() then self.inspector:ClearItem(); self.menuCheckAt=now+.1; return end
    self.menuCheckAt=nil
    self.inspector:ItemTransit(now); self.inspector:Compare()
    if self.inspector.item then return end
    if N.Catalog:Step() then self.dirty=true; self.changeAt=self.changeAt or now+.2 end
    if self.dirty and now>=(self.changeAt or 0) then self:Refresh(); self.changeAt=nil end
    self:RequestStep(now)
    if not self:Visible() then return end
    if self.pending and now>=self.dataDeadline then self.pending=false; self:Render() end
    if not self.dirty and not self.pending and not self.inspector.item and (N.Catalog.done or not N.Catalog.ids) and not self:HasRequests() then self.frame:SetScript("OnUpdate",nil) end
end
function S:Refresh()
    self.dirty=false; self.inspector:ClearItem(); self.inspector.generation=self.inspector.generation+1
    self.results,self.error=N.SearchModel:Query(self.filter); self:Enqueue("item",N.SearchModel.needed); self:Enqueue("quest",N.SearchModel.questNeeded); self:LayoutResults()
    local count=#self.results.." quests"
    if N.Catalog.ids and not N.Catalog.done then count="Indexing rewards - "..math.floor((N.Catalog.cursor-1)/math.max(1,#N.Catalog.ids)*100).."% · "..count end
    if N.SearchModel.unknownLevels>0 then count=count.." · "..N.SearchModel.unknownLevels.." levels unavailable" end
    self.count:SetText(count); self.empty:SetText(N.Catalog.error or self.error or (#self.results==0 and "No matching equipment rewards in this catalogue." or "")); self.empty:SetShown(#self.results==0)
    self:Scroll(self.offset)
end
function S:LayoutResults()
    self.positions={}; local y=0
    for i,row in ipairs(self.results) do self.positions[i]=y; y=y+(self.heights and self.heights[row.id] or 116)+5 end
    self.contentHeight=y; self.child:SetWidth(self.frame:GetWidth()-38); self.child:SetHeight(math.max(y,1))
    self.maximum=math.max(0,y-(self.frame:GetHeight()-158)); self.refreshing=true; self.bar:SetMinMaxValues(0,self.maximum); self.bar:SetShown(self.maximum>0); self.refreshing=false
    if self.bottomTarget or self.offset>self.maximum then self.offset=self.maximum; self.scroll:SetVerticalScroll(self.offset); self.refreshing=true; self.bar:SetValue(self.offset); self.refreshing=false end
end
function S:Card(index)
    if self.cards[index] then return self.cards[index] end
    local c=CreateFrame("Frame",nil,self.child,"BackdropTemplate"); self.cards[index]=c; surface(c); c:EnableMouse(true)
    c.title,c.tag,c.location,c.evidence=text(c,13),text(c,10,{.7,.7,.72}),text(c,11,{.7,.7,.72}),text(c,10,{.7,.7,.72})
    c.title:SetPoint("TOPLEFT",8,-7); c.tag:SetPoint("TOPRIGHT",-8,-9); c.tag:SetJustifyH("RIGHT"); c.location:SetPoint("TOPLEFT",8,-27); c.evidence:SetPoint("TOPLEFT",8,-42)
    c.titleHit=CreateFrame("Frame",nil,c); c.titleHit:SetPoint("TOPLEFT",8,-5); c.titleHit:SetHeight(18); c.titleHit:EnableMouse(true)
    c.titleHit:SetScript("OnEnter",function() if c.row then self:TextTip(c.titleHit,c.title:GetText()) end end); c.titleHit:SetScript("OnLeave",function() self:CloseTextTip() end)
    c.titleHit:SetScript("OnMouseUp",function(_,button) if button=="RightButton" and c.row and A.Over(self.scroll) and A.Over(c.titleHit) then self:ContextMenu(c.row,c) end end)
    c.locationHit=CreateFrame("Frame",nil,c); c.locationHit:SetPoint("TOPLEFT",8,-25); c.locationHit:SetHeight(16); c.locationHit:EnableMouse(true)
    c.locationHit:SetScript("OnEnter",function() if c.row then self:TextTip(c.locationHit,c.location:GetText()) end end); c.locationHit:SetScript("OnLeave",function() self:CloseTextTip() end)
    c.locationHit:SetScript("OnMouseUp",function(_,button) if button=="RightButton" and c.row and A.Over(self.scroll) and A.Over(c.locationHit) then self:ContextMenu(c.row,c) end end)
    c.giver=CreateFrame("Button",nil,c); c.giver:SetPoint("TOPRIGHT",-8,-26); c.giver:SetSize(80,16); c.giver.text=text(c.giver,10,{1,.82,.2}); c.giver.text:SetAllPoints(); c.giver.text:SetJustifyH("RIGHT")
    c.giver:SetScript("OnClick",function() if c.row and A.Over(self.scroll) and A.Over(c.giver) then self:LocationMenu(c.row,c.giver) end end)
    c.icons={}; c.footer={text(c,11),text(c,11),text(c,11)}; c.footerHits={}
    for i=1,3 do
        local hit=CreateFrame("Frame",nil,c); c.footerHits[i]=hit; hit:EnableMouse(true); hit:SetHeight(18)
        hit:SetScript("OnEnter",function() if A.Over(self.scroll) and A.Over(hit) and not self:MenuOpen() and hit.value then self:CloseTextTip(); self.inspector:ClearItem(); self.footerTooltip:SetOwner(hit,"ANCHOR_TOP"); self.footerTooltip:SetText(hit.value); self.footerTooltip:Show() end end)
        hit:SetScript("OnLeave",function() self.footerTooltip:Hide() end)
    end
    c.more=CreateFrame("Button",nil,c); c.more:SetSize(80,16); c.more.text=text(c.more,10); c.more.text:SetAllPoints(); c.more:SetPoint("TOPRIGHT",-8,-42)
    c.more:SetScript("OnClick",function() self.expanded[c.row.id]=not self.expanded[c.row.id]; self:Changed() end)
    c:SetScript("OnMouseUp",function(_,button) if button=="RightButton" and c.row and A.Over(self.scroll) and A.Over(c) then self:ContextMenu(c.row,c) end end)
    return c
end
function S:Icon(card,index)
    if card.icons[index] then return card.icons[index] end
    local b=CreateFrame("Button",nil,card); card.icons[index]=b; b:SetSize(28,28); b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(); b.border=b:CreateTexture(nil,"OVERLAY"); b.border:SetAllPoints(); b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    b.name,b.group=text(card,11),text(card,10,{.7,.7,.72})
    b.count=b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall"); b.count:SetPoint("BOTTOMRIGHT",-1,1); b.count:SetJustifyH("RIGHT")
    b:SetScript("OnEnter",function() self.footerTooltip:Hide(); self:CloseTextTip(); if b.row then self.inspector:Inspect(b,b.row) end; self:Wake() end); b:SetScript("OnLeave",function() self.inspector.itemOutsideAt=nil end)
    b:RegisterForClicks("RightButtonUp"); b:SetScript("OnClick",function() if A.Over(self.scroll) and A.Over(b) then self:ContextMenu(card.row,card) end end)
    return b
end
function S:Fill(card,row)
    card.row=row; local width=self.child:GetWidth(); card:SetWidth(width); card.title:SetWidth(width-155); card.titleHit:SetWidth(width-155); card.title:SetText("["..row.level.."] "..(row.title or ("Quest "..row.id)))
    local status=M.Status(row.id); card.tag:SetText(status=="verifiedNew" and "New" or status=="verifiedUpdated" and "Modified" or "")
    local accent=N.Core.profile.accents and status; local strength=N.Core.profile.strength
    local r,g,b=M.AccentFill(N.Core.profile,accent,.06,.06,.07)
    card:SetBackdropColor(r,g,b,.97)
    local location=self.locationChoice[row.id] or N.Catalog:Location(row.id); row.location=location
    local place=self:LocationLabel(location); local locations=N.Catalog:Locations(row.id); local locationWidth=width-(#locations>1 and 100 or 16)
    card.giver:SetShown(#locations>1); card.giver.text:SetText(#locations.." locations")
    card.location:SetWidth(locationWidth); card.locationHit:SetWidth(locationWidth); card.location:SetText(place); card.evidence:SetWidth(width-100); card.evidence:SetText(row.evidence)
    local reward,catalog,usabilityChanged=N.SearchModel:Reward(row); local items={}; local matching={}
    for _,item in ipairs(row.items) do matching[item.itemID]=true end
    if usabilityChanged then self:DataChanged() end
    for _,group in ipairs({{reward.items,"Guaranteed"},{reward.choices,"Choose one"}}) do for _,item in ipairs(group[1].items or {}) do if matching[item.itemID] and (not self.filter.usable or item.usable~=false) then items[#items+1]={item=item,label=group[2]} end end end
    for _,item in ipairs(catalog) do items[#items+1]={item=item,label="Recorded reward"} end
    local limit=self.expanded[row.id] and #items or math.min(4,#items); local columns=math.max(1,math.floor((width-16)/118)); local chip=(width-16)/columns
    for i=1,limit do
        local entry=items[i]; local item,b=entry.item,self:Icon(card,i); b.row=item
        local x,y=8+((i-1)%columns)*chip,52+math.floor((i-1)/columns)*44
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",x,-y); b.name:ClearAllPoints(); b.name:SetPoint("TOPLEFT",x+32,-y-14); b.name:SetWidth(chip-36); b.name:SetText(item.name or "Loading item")
        b.group:ClearAllPoints(); b.group:SetPoint("TOPLEFT",x+32,-y); b.group:SetWidth(chip-36); b.group:SetText(entry.label)
        b.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark"); local color=item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]; b.border:SetVertexColor(color and color.r or .6,color and color.g or .6,color and color.b or .6); b.name:SetTextColor(color and color.r or .85,color and color.g or .85,color and color.b or .85)
        b.count:SetText(item.quantity and item.quantity>1 and tostring(item.quantity) or ""); b:Show(); b.name:Show(); b.group:Show()
    end
    for i=limit+1,#card.icons do local b=card.icons[i]; b.row=nil; b:Hide(); b.name:Hide(); b.group:Hide() end
    card.more:SetShown(#items>4); card.more.text:SetText(self.expanded[row.id] and "Fewer rewards" or "+"..math.max(0,#items-4).." rewards")
    local uncertain=false; for _,entry in ipairs(items) do uncertain=uncertain or entry.item.usable==nil end
    if uncertain then card.evidence:SetText((row.evidence and row.evidence.." · " or "").."Item usability unconfirmed") end
    local footerY=87+math.max(0,math.ceil(limit/columns)-1)*44; local height=footerY+18
    local money=reward.money.state=="ready" and N.Rewards.Money(reward.money.value) or ""
    money=money or ""
    if money~="" and reward.money.published then money=money.." (base)" end
    local currencies={}; for _,currency in ipairs(reward.currencies.items or {}) do currencies[#currencies+1]=(currency.isChoice and "Choice " or "")..currency.name.." "..currency.amount end
    if #currencies>0 then money=money.." · "..table.concat(currencies,", ") end
    local reputation={}; for _,entry in ipairs(reward.reputation.items or {}) do reputation[#reputation+1]=(entry.name or "Faction "..entry.factionID)..": "..entry.amount..(entry.published and " (base)" or "") end
    local values={money,reward.xp.state=="ready" and tostring(reward.xp.value).." XP"..(reward.xp.published and " (base)" or "") or "XP unavailable",#reputation>0 and "Rep (partial)" or "Rep unavailable"}
    for i,label in ipairs(card.footer) do
        local x=8+(i-1)*(width-16)/3; label:ClearAllPoints(); label:SetPoint("TOPLEFT",x,-footerY); label:SetWidth((width-16)/3-8); label:SetText(values[i])
        local hit=card.footerHits[i]; hit:ClearAllPoints(); hit:SetPoint("TOPLEFT",x,-footerY); hit:SetWidth((width-16)/3-8); hit.value=i==3 and #reputation>0 and table.concat(reputation,"\n").."\nOther reputation rewards unavailable." or values[i]
    end
    card:SetHeight(height); self.heights=self.heights or {}; local resized=self.heights[row.id]~=height; self.heights[row.id]=height
    if reward.state=="pending" and (A.Call(GetTime) or 0)<self.dataDeadline then self.pending=true end
    self:Enqueue("reward",{row.id})
    return height,resized
end
function S:Render()
    if not self.results then return end
    self:CloseTextTip(); self.footerTooltip:Hide(); self.inspector:ClearItem()
    for _=1,4 do
        local first,last=1,0; local bottom=self.offset+self.frame:GetHeight()-158
        for i,row in ipairs(self.results) do if self.positions[i]+(self.heights and self.heights[row.id] or 116)>=self.offset and self.positions[i]<=bottom then if last==0 then first=i end; last=i end end
        local count,resized=0,false
        for i=first,last do count=count+1; local c=self:Card(count); c.resultIndex=i; c:ClearAllPoints(); c:SetPoint("TOPLEFT",0,-self.positions[i]); local _,changed=self:Fill(c,self.results[i]); resized=resized or changed; c:Show() end
        for i=count+1,#self.cards do self.cards[i].row=nil; self.cards[i]:Hide() end
        if not resized then return end
        self:LayoutResults()
    end
    -- Keep final anchors and range coherent even if old estimates reveal more
    -- rows than four passes can settle. The scheduler finishes that work later.
    local bottom=self.offset+self.frame:GetHeight()-158
    for _,card in ipairs(self.cards) do
        local y=card.row and self.positions[card.resultIndex]
        if y and y+card:GetHeight()>=self.offset and y<=bottom then card:ClearAllPoints(); card:SetPoint("TOPLEFT",0,-y)
        else card.row=nil; card:Hide() end
    end
    self:DataChanged()
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
        local f=CreateFrame("Frame","QuestBriefCopy",self.frame,"BackdropTemplate"); self.copyFrame=f; f:SetSize(380,90); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); U:Dialog(f)
        local label=text(f,12); label:SetPoint("TOPLEFT",12,-12); label:SetText("Copy - Ctrl+C")
        self.copyEdit=edit(f,350); self.copyEdit:SetPoint("TOPLEFT",15,-42); self.copyEdit:SetMaxLetters(1024); self.copyEdit:SetScript("OnEscapePressed",function() f:Hide() end); self.copyEdit:SetScript("OnEnterPressed",function() f:Hide() end)
        f:SetScript("OnHide",function() self.copyEdit:ClearFocus() end); UISpecialFrames[#UISpecialFrames+1]="QuestBriefCopy"
    end
    self.copyFrame:Show(); self.copyEdit:SetText(value); self.copyEdit:HighlightText(); self.copyEdit:SetFocus()
end
function S:ContextMenu(row,owner)
    if not row or not self:Visible() or not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then return end
    self:CloseMenu(); self.inspector:ClearItem(); self.footerTooltip:Hide(); self.search:ClearFocus()
    local location=row.location; local coordinates=N.SearchModel.Coordinates(location); local wowhead=N.SearchModel.Wowhead(row.id)
    local waypointReason=not coordinates and "Recorded coordinates unavailable." or location.phase and "Recorded location depends on phase or conflicts with other records." or A.Call(C_Map and C_Map.CanSetUserWaypointOnMap,location.mapID)~=true and "This map cannot accept a user waypoint." or nil
    local npcName=location and location.nameKnown==true and M.Text(location.name) or nil
    self.menu=MenuUtil.CreateContextMenu(owner,function(_,root)
        self:MenuLifetime(root)
        local function button(label,callback,enabled,reason)
            local entry=root:CreateButton(label,callback); entry:SetEnabled(enabled~=false); self:MenuFont(entry)
            if reason then entry:SetTooltip(function(t) t:SetText(reason) end) end; return entry
        end
        button("Set waypoint",function() if not N.SearchModel.Waypoint(location) then N.Core:Print("Waypoint unavailable.") end end,waypointReason==nil,waypointReason)
        button("Copy coordinates",function() self:Copy(coordinates) end,coordinates~=nil,not coordinates and "Recorded coordinates unavailable." or nil)
        button("Copy quest ID",function() self:Copy(tostring(row.id)) end)
        button("Copy NPC name",function() self:Copy(npcName) end,npcName~=nil,not npcName and "Recorded NPC name unavailable." or nil)
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
    local label=(location.zone and location.zone.." · " or "")..location.name
    if N.SearchModel.Coordinates(location) then label=label.." · "..string.format("%.1f, %.1f",location.x*100,location.y*100) end
    return label
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
            if location.phase then t:AddLine("Recorded location depends on phase or conflicts with other records.",.7,.7,.72,true)
            elseif location.mobile then t:AddLine("This giver may move from its recorded location.",.7,.7,.72,true)
            elseif not N.SearchModel.Coordinates(location) then t:AddLine("Recorded coordinates unavailable.",.7,.7,.72,true) end
        end)
    end
end
function S:LocationMenu(row,owner)
    if not row or not self:Visible() or not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then return end
    self:CloseMenu(); self.inspector:ClearItem(); self.search:ClearFocus()
    self.menu=MenuUtil.CreateContextMenu(owner,function(_,root) self:MenuLifetime(root); self:GiverChoices(root,row) end)
end

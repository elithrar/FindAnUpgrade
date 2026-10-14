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
end
function S:Changed(reset)
    self:CloseMenu(); self.inspector:ClearItem()
    self.dirty=true; self.changeAt=(A.Call(GetTime) or 0)+.15
    if reset then self.offset=0 end
end
function S:Dropdown(parent,width,entries,get,choose)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle1DropdownTemplate"); d:SetSize(width,24)
    d.Text:ClearAllPoints(); d.Text:SetPoint("LEFT",d,"LEFT",9,0); d.Text:SetWidth(width-31); d.Text:SetHeight(24); d.Text:SetJustifyH("LEFT"); d.Text:SetJustifyV("MIDDLE"); d.Text:SetWordWrap(false); U:Font(d.Text,12)
    d:SetupMenu(function(_,root)
        if self.inspector then self.inspector:ClearItem() end; root:SetScrollMode(220)
        for _,entry in ipairs(entries) do
            local value,label=entry[1],entry[2]
            local row=root:CreateRadio(label,function(v) return get()==v end,function(v) choose(v); d:SetDefaultText(label) end,value)
            row:AddInitializer(function(button) button.fontString:SetFontObject(self.menuFont) end)
        end
    end)
    return d
end
function S:Create()
    if self.frame then return end
    self.filter={query="",usable=true,slot="ALL",sort="FIT"}
    local f=CreateFrame("Frame","QuestBriefSearch",UIParent,"BackdropTemplate"); self.frame=f; f:Hide()
    f:SetSize(560,600); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true); f:SetResizeBounds(520,400,900,900); surface(f)
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
    for _,e in ipairs({self.minimumInput,self.maximumInput}) do e:SetNumeric(true); e:SetMaxLetters(3); e:SetScript("OnEnterPressed",function(b) range(); b:ClearFocus() end); e:SetScript("OnEditFocusLost",range); e:SetScript("OnEscapePressed",function(b) b:ClearFocus() end) end
    self.slot=self:Dropdown(f,144,N.SearchModel.slots,function() return self.filter.slot end,function(value) self.filter.slot=value; self:Changed(true) end); self.slot:SetPoint("TOPRIGHT",-16,-78); self.slot:SetDefaultText("All slots")
    self.count=text(f,11,{.7,.7,.72}); self.count:SetPoint("TOPLEFT",16,-115); self.count:SetWidth(310)
    self.sort=self:Dropdown(f,144,{{"FIT","Level fit"},{"LEVEL","Quest level"}},function() return self.filter.sort end,function(value) self.filter.sort=value; self:Changed(true) end); self.sort:SetPoint("TOPRIGHT",-16,-109); self.sort:SetDefaultText("Level fit")
    local scroll=CreateFrame("ScrollFrame",nil,f); self.scroll=scroll; scroll:SetPoint("TOPLEFT",12,-142); scroll:SetPoint("BOTTOMRIGHT",-26,16); scroll:EnableMouse(true); scroll:EnableMouseWheel(true)
    self.child=CreateFrame("Frame",nil,scroll); self.child:SetSize(512,1); scroll:SetScrollChild(self.child)
    self.inspector=N.Stack.NewInspector(f,scroll,function() return self:Visible() and not self:MenuOpen() and not (self.copyFrame and self.copyFrame:IsShown()) end)
    self.bar=CreateFrame("Slider",nil,f,"UISliderTemplate"); self.bar:SetPoint("TOPRIGHT",-6,-144); self.bar:SetPoint("BOTTOMRIGHT",-6,18); self.bar:SetWidth(12); self.bar:SetOrientation("VERTICAL"); self.bar:SetValueStep(1)
    local thumb=A.Call(self.bar.GetThumbTexture,self.bar); if thumb then thumb:SetSize(12,22) end
    self.bar:SetScript("OnValueChanged",function(_,value) if not self.refreshing then self:Scroll(value) end end)
    scroll:SetScript("OnMouseWheel",function(_,delta) if M.Number(delta) then self:Scroll(self.offset-delta*40) end end)
    self.empty=text(self.child,12,{.7,.7,.72}); self.empty:SetPoint("TOPLEFT",8,-14); self.empty:SetWidth(490)
    local resize=CreateFrame("Button",nil,f); resize:SetPoint("BOTTOMRIGHT",-2,2); resize:SetSize(18,18); resize.texture=resize:CreateTexture(nil,"ARTWORK"); resize.texture:SetAllPoints(); resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then self:CloseMenu(); self.inspector:ClearItem(); f:StartSizing("BOTTOMRIGHT") end end); resize:SetScript("OnMouseUp",function() f:StopMovingOrSizing(); self:Changed() end)
    f:SetScript("OnSizeChanged",function() if self.inspector then self:Fit(); self:Changed() end end)
    f:SetScript("OnHide",function() f:StopMovingOrSizing(); f:SetScript("OnUpdate",nil); self.search:ClearFocus(); self.minimumInput:ClearFocus(); self.maximumInput:ClearFocus(); self.inspector:ClearItem(); self.footerTooltip:Hide(); self:CloseMenu(); if self.copyFrame then self.copyFrame:Hide() end end)
    f:SetScript("OnEvent",function(_,event,id)
        if not self:Visible() then return end
        if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" then if not self.itemRequests[id] then return end; N.SearchModel.cache[id]=nil
        elseif event=="QUEST_DATA_LOAD_RESULT" then if not self.questRequests[id] and not self.rewardRequests[id] then return end
        elseif event=="TOOLTIP_DATA_UPDATE" then local i=self.inspector; if i.item and A.Call(i.tooltip.HasDataInstanceID,i.tooltip,id)==true then i:Inspect(i.item.button,i.item.row,true) end; return
        elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then self:Fit()
        elseif event=="PLAYER_LEVEL_UP" and not self.manualRange then self:DefaultRange(id)
        elseif event=="ADDON_LOADED" then N.Catalog:Begin() end
        if event=="PLAYER_LEVEL_UP" or event=="PLAYER_EQUIPMENT_CHANGED" or event=="QUEST_LOG_UPDATE" or event=="SPELLS_CHANGED" or event=="SKILL_LINES_CHANGED" then N.SearchModel.usability,N.SearchModel.currentItems,N.SearchModel.currentStamp={},{},{} end
        if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" or event=="QUEST_DATA_LOAD_RESULT" then
            self.dirty=true; self.changeAt=(A.Call(GetTime) or 0)+.15; return
        end
        self:Changed()
    end)
    for _,event in ipairs({"ITEM_DATA_LOAD_RESULT","GET_ITEM_INFO_RECEIVED","QUEST_DATA_LOAD_RESULT","QUEST_LOG_UPDATE","QUEST_TURNED_IN","PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","ADDON_LOADED","TOOLTIP_DATA_UPDATE"}) do f:RegisterEvent(event) end
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
    if M.Number(w) and M.Number(h) then self.frame:SetScale(math.min(1,(w-24)/self.frame:GetWidth(),(h-24)/self.frame:GetHeight())) end
end
function S:Toggle()
    if not N.Core.supported or not N.Core.profile.enabled then N.Core:Print("Enable QuestBrief to search rewards."); return end
    self:Create(); if self:Visible() then self.frame:Hide(); return end
    N.Hover:Dismiss("search"); self.questRequests,self.rewardRequests,self.itemRequests,self.pending={}, {},{},false
    N.SearchModel.usability,N.SearchModel.currentItems,N.SearchModel.currentStamp={},{},{}
    self.dataDeadline=(A.Call(GetTime) or 0)+5; if not self.manualRange then self:DefaultRange() end
    self.usable:SetChecked(self.filter.usable); N.Catalog:Begin(); self:Fit(); self.frame:Show(); self.search:SetFocus(); self:Changed(true)
    self.frame:SetScript("OnUpdate",function(_,elapsed) self:Tick(elapsed) end)
end
function S:Tick()
    if not self:Visible() then return end
    local now=A.Call(GetTime) or 0
    if self:MenuOpen() then self.inspector:ClearItem(); return end
    self.inspector:ItemTransit(now); self.inspector:Compare()
    if self.inspector.item then return end
    if N.Catalog:Step() then self.dirty=true; self.changeAt=self.changeAt or now+.2 end
    if self.dirty and now>=(self.changeAt or 0) then self:Refresh(); self.changeAt=nil end
    for _=1,2 do
        local quest=self.questQueue and self.questQueue[self.questCursor or 1]
        if quest then
            self.questCursor=(self.questCursor or 1)+1
            if not self.questRequests[quest] then self.questRequests[quest]=true; A.Call(C_QuestLog and C_QuestLog.RequestLoadQuestByID,quest) end
        end
        local id=self.itemQueue and self.itemQueue[self.itemCursor or 1]
        if not id then break end
        self.itemCursor=(self.itemCursor or 1)+1
        if not self.itemRequests[id] then self.itemRequests[id]=true; A.Call(C_Item and C_Item.RequestLoadItemDataByID,id) end
    end
    if self.pending and now>=self.dataDeadline then self.pending=false; self:Render() end
end
function S:Refresh()
    self.dirty=false; self.inspector:ClearItem(); self.inspector.generation=self.inspector.generation+1
    self.results,self.error=N.SearchModel:Query(self.filter); self.itemQueue=N.SearchModel.needed; self.itemCursor=1; self.questQueue=N.SearchModel.questNeeded; self.questCursor=1; self:LayoutResults()
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
    if self.offset>self.maximum then self.offset=self.maximum; self.scroll:SetVerticalScroll(self.offset); self.refreshing=true; self.bar:SetValue(self.offset); self.refreshing=false end
end
function S:Card(index)
    if self.cards[index] then return self.cards[index] end
    local c=CreateFrame("Frame",nil,self.child,"BackdropTemplate"); self.cards[index]=c; surface(c); c:EnableMouse(true)
    c.title,c.tag,c.location,c.evidence=text(c,13),text(c,10,{.7,.7,.72}),text(c,11,{.7,.7,.72}),text(c,10,{.7,.7,.72})
    c.title:SetPoint("TOPLEFT",8,-7); c.tag:SetPoint("TOPRIGHT",-8,-9); c.tag:SetJustifyH("RIGHT"); c.location:SetPoint("TOPLEFT",8,-27); c.evidence:SetPoint("TOPLEFT",8,-42)
    c.icons={}; c.footer={text(c,11),text(c,11),text(c,11)}; c.footerHits={}
    for i=1,3 do
        local hit=CreateFrame("Frame",nil,c); c.footerHits[i]=hit; hit:EnableMouse(true); hit:SetHeight(18)
        hit:SetScript("OnEnter",function() if A.Over(self.scroll) and A.Over(hit) and not self:MenuOpen() and hit.value then self.inspector:ClearItem(); self.footerTooltip:SetOwner(hit,"ANCHOR_TOP"); self.footerTooltip:SetText(hit.value); self.footerTooltip:Show() end end)
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
    b.name,b.group,b.count=text(card,11),text(card,10,{.7,.7,.72}),text(b,10); b.count:SetPoint("BOTTOMRIGHT",-1,1)
    b:SetScript("OnEnter",function() self.footerTooltip:Hide(); if b.row then self.inspector:Inspect(b,b.row) end end); b:SetScript("OnLeave",function() self.inspector.itemOutsideAt=nil end)
    b:RegisterForClicks("RightButtonUp"); b:SetScript("OnClick",function() if A.Over(self.scroll) and A.Over(b) then self:ContextMenu(card.row,card) end end)
    return b
end
function S:Fill(card,row)
    card.row=row; local width=self.child:GetWidth(); card:SetWidth(width); card.title:SetWidth(width-155); card.title:SetText("["..row.level.."] "..(row.title or ("Quest "..row.id)))
    local status=M.Status(row.id); card.tag:SetText(status=="verifiedNew" and "New" or status=="verifiedUpdated" and "Modified" or "")
    card:SetBackdropColor(.06+(status=="verifiedNew" and .045 or 0),.06+(status=="verifiedUpdated" and .045 or 0),.07,.97)
    local location=self.locationChoice[row.id] or N.Catalog:Location(row.id); row.location=location
    local place=location and ((location.zone and location.zone.." · " or "")..location.name..(N.SearchModel.Coordinates(location) and " · "..string.format("%.1f, %.1f",location.x*100,location.y*100) or "")) or "Quest giver unavailable"
    card.location:SetWidth(width-16); card.location:SetText(place); card.evidence:SetWidth(width-100); card.evidence:SetText(row.evidence)
    local reward,catalog,usabilityChanged=N.SearchModel:Reward(row); local items={}; local matching={}
    for _,item in ipairs(row.items) do matching[item.itemID]=true end
    if usabilityChanged then self.dirty=true; self.changeAt=(A.Call(GetTime) or 0)+.15 end
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
    if uncertain then card.evidence:SetText(row.evidence.." · usability unconfirmed") end
    local footerY=87+math.max(0,math.ceil(limit/columns)-1)*44; local height=footerY+18
    local money=reward.money.state=="ready" and (M.Text(A.Call(GetCoinTextureString,reward.money.value)) or tostring(reward.money.value).." copper") or "Gold unavailable"
    local currencies={}; for _,currency in ipairs(reward.currencies.items or {}) do currencies[#currencies+1]=(currency.isChoice and "Choice " or "")..currency.name.." "..currency.amount end
    if #currencies>0 then money=money.." · "..table.concat(currencies,", ") end
    local reputation={}; for _,entry in ipairs(reward.reputation.items or {}) do reputation[#reputation+1]="Faction "..entry.factionID..": "..entry.amount end
    local values={money,reward.xp.state=="ready" and tostring(reward.xp.value).." XP" or "XP unavailable",#reputation>0 and "Rep (partial)" or "Rep unavailable"}
    for i,label in ipairs(card.footer) do
        local x=8+(i-1)*(width-16)/3; label:ClearAllPoints(); label:SetPoint("TOPLEFT",x,-footerY); label:SetWidth((width-16)/3-8); label:SetText(values[i])
        local hit=card.footerHits[i]; hit:ClearAllPoints(); hit:SetPoint("TOPLEFT",x,-footerY); hit:SetWidth((width-16)/3-8); hit.value=i==3 and #reputation>0 and table.concat(reputation,"\n").."\nOther reputation rewards unavailable." or values[i]
    end
    card:SetHeight(height); self.heights=self.heights or {}; local resized=self.heights[row.id]~=height; self.heights[row.id]=height
    if reward.state=="pending" and (A.Call(GetTime) or 0)<self.dataDeadline then self.pending=true end
    N.Rewards.Request(row.id,self.rewardRequests,true)
    return height,resized
end
function S:Render()
    if not self.results then return end
    self.inspector:ClearItem(); local first,last=1,0; local bottom=self.offset+self.frame:GetHeight()-158
    for i,row in ipairs(self.results) do if self.positions[i]+(self.heights and self.heights[row.id] or 116)>=self.offset and self.positions[i]<=bottom then if last==0 then first=i end; last=i end end
    local count,resized=0,false
    for i=first,last do count=count+1; local c=self:Card(count); c:ClearAllPoints(); c:SetPoint("TOPLEFT",0,-self.positions[i]); local _,changed=self:Fill(c,self.results[i]); resized=resized or changed; c:Show() end
    for i=count+1,#self.cards do self.cards[i].row=nil; self.cards[i]:Hide() end
    if resized and not self.measuring then self.measuring=true; self:LayoutResults(); self:Render(); self.measuring=false end
end
function S:Scroll(value)
    if not M.Number(value) then return end
    self:CloseMenu(); self.inspector:ClearItem(); self.footerTooltip:Hide(); self.offset=math.max(0,math.min(self.maximum or 0,value)); self.scroll:SetVerticalScroll(self.offset); self.refreshing=true; self.bar:SetValue(self.offset); self.refreshing=false; self:Render()
end
function S:Copy(value)
    if not M.Text(value) then return end
    self:CloseMenu(); self.inspector:ClearItem()
    if not self.copyFrame then
        local f=CreateFrame("Frame","QuestBriefCopy",self.frame,"BackdropTemplate"); self.copyFrame=f; f:SetSize(380,90); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); surface(f)
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
    self.menu=MenuUtil.CreateContextMenu(owner,function(_,root)
        root:AddMenuReleasedCallback(function(menu) if self.menu==menu then self.menu=nil end end)
        local function button(label,callback,enabled)
            local entry=root:CreateButton(label,callback); entry:SetEnabled(enabled~=false); entry:AddInitializer(function(b) b.fontString:SetFontObject(self.menuFont) end); return entry
        end
        button("Set waypoint",function() if not N.SearchModel.Waypoint(location) then N.Core:Print("Waypoint unavailable.") end end,coordinates~=nil and not location.phase and A.Call(C_Map and C_Map.CanSetUserWaypointOnMap,location.mapID)==true)
        button("Copy coordinates",function() self:Copy(coordinates) end,coordinates~=nil)
        button("Copy quest ID",function() self:Copy(tostring(row.id)) end)
        button("Copy NPC name",function() self:Copy(location and location.name) end,location~=nil)
        local link=button("Copy Wowhead link",function() self:Copy(wowhead) end,wowhead~=nil)
        link:SetTooltip(function(t) t:SetText(wowhead and "Forever quest reference" or "No catalogue reference for this variant.") end)
    end)
end

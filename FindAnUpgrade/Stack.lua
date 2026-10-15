local _, N = ...
local M, A, U = N.Model, N.Adapter, N.UI
local V = { cards = {}, offset = 0 }; N.Stack = V
local function nearSegment(x,y,ax,ay,bx,by,padding)
    local dx,dy=bx-ax,by-ay
    local length=dx*dx+dy*dy
    local t=length>0 and math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/length)) or 0
    return (x-ax-t*dx)^2+(y-ay-t*dy)^2<=padding*padding
end
local function text(parent, header)
    local f = parent:CreateFontString(nil, "OVERLAY", header == true and "GameTooltipHeaderText" or "GameTooltipText")
    U:Font(f,header==true and 14 or M.Number(header) and header or 12)
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetWordWrap(true)
    return f
end
local function height(f, width, value, minimum)
    f:SetWidth(width); f:SetText(value or ""); f:SetShown(M.Text(value)~=nil)
    if not M.Text(value) then return 0 end
    local measured = A.Call(f.GetStringHeight, f)
    return M.Number(measured) and math.max(minimum or 12, measured) or minimum or 12
end
local function cycleHints()
    local hints={}
    local binding=M.Text(A.Call(GetBindingKeyForAction,"ITEMCOMPARISONCYCLING"))
    local function add(text)
        if M.Text(text) then hints[text]=true end
    end
    add(ITEM_COMPARISON_CYCLING_DISABLED_MSG_MAINHAND); add(ITEM_COMPARISON_CYCLING_DISABLED_MSG_OFFHAND)
    if binding then
        local function formatted(format)
            if M.Text(format) then add(A.Call(string.format,format,binding)) end
        end
        formatted(ITEM_COMPARISON_SWAP_ITEM_MAINHAND_DESCRIPTION); formatted(ITEM_COMPARISON_SWAP_ITEM_OFFHAND_DESCRIPTION)
    end
    return hints
end
function V:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "FindAnUpgradeStack", UIParent); self.frame = f
    f:Hide() -- Constructor cleanup must not dismiss the first opening session.
    f:SetFrameStrata("TOOLTIP"); f:SetClampedToScreen(true); f:EnableMouse(true)
    self.header = text(f); self.header:SetPoint("TOPLEFT",8,0); self.header:Hide()
    local scroll = CreateFrame("ScrollFrame", nil, f); self.scroll = scroll
    scroll:SetPoint("TOPLEFT",0,0); scroll:EnableMouse(true); scroll:EnableMouseWheel(true)
    self.child = CreateFrame("Frame", nil, scroll); self.child:SetSize(292,1); scroll:SetScrollChild(self.child)
    self.bar = U:VerticalBar(f); self.bar:SetPoint("TOPRIGHT",-2,-18); self.bar:SetPoint("BOTTOMRIGHT",-2,0)
    self.bar:SetWidth(12); self.bar:SetOrientation("VERTICAL"); self.bar:SetValueStep(1); self.bar:SetMinMaxValues(0,0)
    local thumb=A.Call(self.bar.GetThumbTexture,self.bar)
    if thumb and not A.Forbidden(thumb) then thumb:SetSize(12,22) end
    self.bar:SetScript("OnValueChanged",function(_,value) if not self.refreshing then self:Scroll(value) end end)
    scroll:SetScript("OnMouseWheel",function(_,delta) if M.Number(delta) then self:Scroll(self.offset-delta*40) end end)
    f:SetScript("OnHide",function() if N.Hover.open then N.Hover:Dismiss("escape") else self:ClearItem() end end)
    UISpecialFrames = UISpecialFrames or {}; table.insert(UISpecialFrames,"FindAnUpgradeStack"); f:Hide()
end
function V:Card(index)
    if self.cards[index] then return self.cards[index] end
    local c = CreateFrame("Frame",nil,self.child,"TooltipBorderedFrameTemplate"); self.cards[index] = c
    c:SetWidth(320); c:EnableMouse(true)
    c.title, c.status, c.evidence, c.summary = text(c,true), text(c), text(c), text(c)
    c.title:SetTextColor(1,1,1); c.title:SetPoint("TOPLEFT",8,-6)
    c.status:SetTextColor(.83,.83,.83); c.evidence:SetTextColor(.7,.7,.72)
    c.groups = {}; c.icons = {}
    return c
end
function V:Icon(c,index)
    if c.icons[index] then return c.icons[index] end
    local b = CreateFrame("Button",nil,c); c.icons[index] = b; b:SetSize(24,24)
    b.icon = b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints()
    b.border = b:CreateTexture(nil,"OVERLAY"); b.border:SetAllPoints(); b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    b.count = b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall"); b.count:SetPoint("BOTTOMRIGHT",-1,1); b.count:SetJustifyH("RIGHT")
    b:SetScript("OnEnter",function() if b.row then self:Inspect(b,b.row) end end)
    -- The icon's leave event starts a grace interval; tooltip geometry keeps it alive.
    b:SetScript("OnLeave",function() self.itemOutsideAt = nil end)
    return b
end
function V:Group(c,key,label,group,y,nextIcon)
    local g = c.groups[key]
    if not g then
        g = { label = text(c,11), expanded = false }; c.groups[key] = g
        g.more = CreateFrame("Button",nil,c); g.more:SetSize(140,20); g.more.text = text(g.more,11); g.more.text:SetAllPoints()
        g.more:SetScript("OnClick",function() self:ClearItem(); g.expanded = not g.expanded; self:Refresh() end)
    end
    local width=c:GetWidth()-16
    g.label:ClearAllPoints(); g.label:SetPoint("TOPLEFT",8,-y)
    local list = group.items
    if label then y=y+height(g.label,width,label,12)+3 else g.label:Hide() end
    local limit = g.expanded and #list or math.min(#list,8)
    local columns=math.max(1,math.floor((width+4)/28))
    for i=1,limit do
        local row, b = list[i], self:Icon(c,nextIcon); nextIcon=nextIcon+1
        b.row = row; b:ClearAllPoints(); b:SetPoint("TOPLEFT",8+((i-1)%columns)*28,-y-math.floor((i-1)/columns)*28)
        b.icon:SetTexture(row.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        local color = row.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[row.quality]
        b.border:SetVertexColor(color and color.r or .6,color and color.g or .6,color and color.b or .6)
        b.count:SetText(row.quantity and row.quantity > 1 and tostring(row.quantity) or ""); b:Show()
    end
    y=y+math.ceil(limit/columns)*28-4
    if #list>8 then
        g.more:ClearAllPoints(); g.more:SetPoint("TOPLEFT",8,-y); g.more.text:SetText(g.expanded and "Fewer rewards" or "+" .. (#list-8) .. " rewards"); g.more:Show(); y=y+20
    else g.more:Hide() end
    return y,nextIcon
end
function V:Fill(c,row,profile)
    if c.questID ~= row.id then for _,g in pairs(c.groups) do g.expanded=false end end
    c.questID = row.id
    for _,b in ipairs(c.icons) do b.row=nil; b:Hide() end
    for _,g in pairs(c.groups) do g.label:Hide(); g.more:Hide() end
    local title = M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,row.id)) or row.title or "Quest " .. row.id
    local width=c:GetWidth()-16
    local classification=profile.accents and M.Status(row.id)
    local suffix=classification=="verifiedNew" and " |cffffb36bNew|r" or classification=="verifiedUpdated" and " |cff9fdf9fModified|r" or ""
    local y=6+height(c.title,width,title..suffix,14)
    c.status:Hide() -- Classification is inline; unchanged/unknown IDs use no extra row.
    -- The source has already established eligibility. Repeating Available or
    -- In quest log on its own line made every small preview unnecessarily tall.
    c.evidence:Hide()
    local rewardY=y+3
    y=rewardY
    local reward=profile.rewards and N.Rewards.Read(row.id); local nextIcon=1
    local pending=reward and (reward.state=="pending" or reward.items.state=="pending" or reward.choices.state=="pending")
    if pending and not N.Hover.timedOut then N.Hover.pending=true end
    local lines={}; local inlineWidth=0
    if reward then
        local guaranteed,choices=#reward.items.items,#reward.choices.items
        local choiceCurrency=false
        for _,currency in ipairs(reward.currencies.items or {}) do if currency.isChoice then choiceCurrency=true end end
        if guaranteed>0 and guaranteed<=4 and choices==0 and not choiceCurrency then inlineWidth=guaranteed*28+8
        elseif choices>0 and choices<=4 and guaranteed==0 then inlineWidth=choices*28+8 end
        if guaranteed>0 then y,nextIcon=self:Group(c,"items",(choices>0 or choiceCurrency) and "Guaranteed" or nil,reward.items,y,nextIcon) end
        if choices>0 then y,nextIcon=self:Group(c,"choices","Choose one",reward.choices,y,nextIcon) end
        local values={}
        if reward.money.state=="ready" and reward.money.value>0 then values[#values+1]=N.Rewards.Money(reward.money.value)..(reward.money.published and " (base)" or "") end
        if reward.xp.state=="ready" and reward.xp.value>0 then values[#values+1]=reward.xp.value .. " XP"..(reward.xp.published and " (base)" or "") end
        if #values>0 then lines[#lines+1]=table.concat(values,"  ") end
        for _,currency in ipairs(reward.currencies.items or {}) do
            if currency.amount>0 then lines[#lines+1]=(currency.isChoice and "Choose one: " or (choices>0 or choiceCurrency) and "Guaranteed: " or "") .. currency.name .. " " .. currency.amount end
        end
        for _,rep in ipairs(reward.reputation.items or {}) do
            if rep.amount~=0 then lines[#lines+1]=(rep.name or "Major faction " .. rep.factionID) .. ": " .. (rep.amount>=0 and "+" or "") .. rep.amount..(rep.published and " (base)" or "") end
        end
        if pending and not N.Hover.timedOut and guaranteed+choices==0 and #lines==0 then lines[#lines+1]="Loading rewards…" end
    end
    local inline=inlineWidth>0 and width-inlineWidth>=100 and #lines>0
    local summaryX,summaryY=inline and 8+inlineWidth or 8,inline and rewardY or y
    c.summary:ClearAllPoints(); c.summary:SetPoint("TOPLEFT",summaryX,-summaryY)
    local summaryHeight=height(c.summary,inline and width-inlineWidth or width,table.concat(lines,"\n"),12)
    y=math.max(y,summaryY+summaryHeight)
    if nextIcon==1 and summaryHeight==0 then y=rewardY-3 end
    y=y+6
    local titleWidth=A.Call(c.title.GetUnboundedStringWidth,c.title) or width
    local summaryWidth=A.Call(c.summary.GetUnboundedStringWidth,c.summary) or 0
    c.naturalWidth=math.max(titleWidth+16,summaryWidth+16+(inline and inlineWidth or 0),nextIcon>1 and math.min(nextIcon-1,8)*28+16 or 0)
    c:SetHeight(y)
    local new,modified=classification=="verifiedNew",classification=="verifiedUpdated"
    local r,g,b=.09,.09,.19
    if TOOLTIP_DEFAULT_BACKGROUND_COLOR and type(TOOLTIP_DEFAULT_BACKGROUND_COLOR.GetRGB)=="function" then
        r,g,b=TOOLTIP_DEFAULT_BACKGROUND_COLOR:GetRGB()
    end
    r,g,b=M.AccentFill(profile,classification,r,g,b)
    U:Border(c,"tooltip"):SetBackdropColor(r,g,b,.96)
    -- The native silver border is retained for every classification.
    return y
end
function V:Place()
    local scale=self.frame:GetScale()
    local w,h=self.frame:GetWidth()*scale,self.frame:GetHeight()*scale
    local beside=N.Core.profile.inspectionPosition=="tooltip"
    local left=self.anchorX+56
    if self.nativeRect then
        local r=self.nativeRect
        local rightSide,leftSide=r.x+r.w+12,r.x-w-12
        local rightFits,leftFits=rightSide+w<=self.screenWidth-8,leftSide>=8
        if beside then
            if leftFits and not rightFits then left=leftSide else left=rightSide end
        elseif left<r.x+r.w+12 and left+w>r.x-12 then
            left=rightFits and rightSide or leftFits and leftSide or left
        end
    elseif left+w>self.screenWidth-8 then left=self.anchorX-w-56 end
    left=math.max(8,math.min(self.screenWidth-w-8,left))
    local top=beside and self.nativeRect and self.nativeRect.y+self.nativeRect.h or self.anchorY+24
    local bottom=math.max(8,math.min(self.screenHeight-h-8,top-h))
    self.placement={left=left,bottom=bottom,width=w,height=h}
    self.frame:ClearAllPoints(); self.frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left/scale,bottom/scale)
end
function V:Refresh()
    if not self.source then return end
    self:ClearItem(); self.refreshing=true; N.Hover.pending=false
    local p=N.Core.profile
    self.source.rows=N.Providers.ResolveRows(self.source.rows)
    if #self.source.rows==0 then self.refreshing=false; N.Hover:Dismiss("eligibility"); return end
    local scale=self.frame:GetScale()
    local cap=math.min(320,self.screenHeight*.6/scale,(self.screenHeight-16)/scale)
    local y,natural=0,232
    local function fill(width)
        y=0; self.child:SetWidth(width)
        for i,row in ipairs(self.source.rows) do
            local c=self:Card(i); c:SetWidth(width); c:ClearAllPoints(); c:SetPoint("TOPLEFT",0,-y)
            y=y+self:Fill(c,row,p)+2; natural=math.max(natural,c.naturalWidth or 0); c:Show()
        end
        y=math.max(1,y-2)
    end
    fill(280)
    local width=math.min(280,math.ceil(natural))
    if width<280 then fill(width) end
    local overflow=y>cap
    if overflow then fill(width-16) end
    for i=#self.source.rows+1,#self.cards do self.cards[i]:Hide(); self.cards[i].questID=nil end
    local header=overflow and 18 or 0
    self.viewportHeight=math.min(y,math.max(1,cap-header))
    self.child:SetHeight(y); self.contentHeight=y
    self.frame:SetSize(width,self.viewportHeight+header)
    self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT",0,-header); self.scroll:SetSize(overflow and width-16 or width,self.viewportHeight)
    self.maximum=math.max(0,y-self.viewportHeight); self.bar:SetMinMaxValues(0,self.maximum); self.bar:SetShown(overflow)
    self.header:SetText(#self.source.rows .. (#self.source.rows==1 and " quest" or " quests") .. " · scroll"); self.header:SetShown(overflow)
    self:Place(); self.refreshing=false; self:Scroll(self.offset)
end
function V:Show(source,profile,nativeRect)
    self:Create()
    local x,y=N.Hover.anchorX,N.Hover.anchorY
    if not M.Number(x) or not M.Number(y) then x,y=A.Cursor() end
    local parentScale=A.Call(UIParent.GetEffectiveScale,UIParent)
    local sw,sh=A.Call(UIParent.GetWidth,UIParent),A.Call(UIParent.GetHeight,UIParent)
    if not x or not M.Number(parentScale) or parentScale<=0 or not M.Number(sw) or not M.Number(sh) or sw<340 or sh<180 then return false end
    self.source,self.offset=source,0
    self.screenWidth,self.screenHeight,self.parentScale=sw,sh,parentScale
    self.openingTransitAt,self.openingTransitConsumed=nil,false
    self.anchorX,self.anchorY=x/parentScale,y/parentScale
    self.nativeRect,self.nativeFrame,self.nativeOwner,self.nativeData,self.nativePhysicalRect=nil,nil,nil,nil,nil
    local native=A.Rect(GameTooltip) or nativeRect
    if native then
        local r={x=native.x/parentScale,y=native.y/parentScale,w=native.w/parentScale,h=native.h/parentScale}
        -- Ignore a remote, fixed-corner native tooltip. Preserve nearby native
        -- content and keep the pointer route to our first card short.
        if self.anchorX>=r.x-80 and self.anchorX<=r.x+r.w+80 and self.anchorY>=r.y-80 and self.anchorY<=r.y+r.h+80 then
            self.nativeRect,self.nativePhysicalRect,self.nativeFrame=r,native,GameTooltip
            self.nativeOwner=A.Call(GameTooltip.GetOwner,GameTooltip)
            self.nativeData=A.Call(GameTooltip.GetPrimaryTooltipData or GameTooltip.GetTooltipData,GameTooltip)
            self.nativeRebuild=M.Readable(GameTooltip._Rebuild) and GameTooltip._Rebuild or nil
            self.nativeHeader=M.Text(A.Call(GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText,GameTooltipTextLeft1))
            self.nativeToken={}
            if type(self.nativeData)=="table" then
                for _,key in ipairs({"id","type","guid","dataInstanceID"}) do
                    local value=self.nativeData[key]; if M.Readable(value) then self.nativeToken[key]=value end
                end
            end
        end
    end
    self.frame:SetScale(math.min(profile.scale,(sw-16)/320))
    self:Refresh()
    if not self.source then return false end
    self.frame:Show(); return true
end
function V:Scroll(value)
    if not M.Number(value) then return end
    self:ClearItem(); self.offset=math.max(0,math.min(self.maximum or 0,value)); self.scroll:SetVerticalScroll(self.offset)
    self.refreshing=true; self.bar:SetValue(self.offset); self.refreshing=false
end
function V:Hide()
    self.source=nil; self:ClearItem()
    if self.frame then self.frame:Hide() end
end
function V:Tooltips()
    if self.tooltip then return true end
    if type(TooltipDataHandlerMixin)~="table" or type(Mixin)~="function" then return false end
    local function create(name)
        -- SharedTooltipTemplate has isolated cleanup. GameTooltipTemplate's
        -- OnLoad/OnHide mutate global battle-pet/comparison state.
        local t=CreateFrame("GameTooltip",name,UIParent,"SharedTooltipTemplate")
        -- Above this inspector's own card/button subtree when screen clamping
        -- causes overlap; comparison headers remain one level below their tip.
        t:SetFrameLevel((self.frame or UIParent):GetFrameLevel()+6)
        Mixin(t,TooltipDataHandlerMixin); t.suppressAutomaticCompareItem=true
        t:HookScript("OnHide",function() t:ClearHandlerInfo() end)
        return t
    end
    local prefix=self.tooltipPrefix or "FindAnUpgrade"
    self.tooltip=create(prefix.."ItemTooltip")
    self.tooltip.shoppingTooltips={create(prefix.."Comparison1"),create(prefix.."Comparison2")}
    for _,t in ipairs(self.tooltip.shoppingTooltips) do
        local addLine=t.AddLine
        local processInfo=t.ProcessInfo
        t.ProcessInfo=function(tooltip,...)
            local previous=tooltip.questBriefItemData
            tooltip.questBriefItemData=true
            local ok,result=pcall(processInfo,tooltip,...)
            tooltip.questBriefItemData=previous
            if not ok then error(result,0) end
            return result
        end
        -- Native comparison cycling is owned by the global manager. Omit only
        -- its unsupported instruction while rendering our comparison frames.
        t.AddLine=function(tooltip,value,...)
            if self.cycleHints and not tooltip.questBriefItemData and M.Text(value) and self.cycleHints[value] then return end
            return addLine(tooltip,value,...)
        end
        t.CompareHeader=CreateFrame("Frame",nil,t); t.CompareHeader:SetPoint("BOTTOMLEFT",t,"TOPLEFT",0,-1); t.CompareHeader:SetSize(100,22)
        t.CompareHeader:SetFrameLevel(t:GetFrameLevel()-1)
        t.CompareHeader.Background=t.CompareHeader:CreateTexture(nil,"BACKGROUND"); t.CompareHeader.Background:SetAllPoints(); t.CompareHeader.Background:SetAtlas("tooltip-compare-label")
        t.CompareHeader.Label=t.CompareHeader:CreateFontString(nil,"ARTWORK","GameTooltipText"); t.CompareHeader.Label:SetPoint("CENTER"); t.CompareHeader.Label:SetTextColor(NORMAL_FONT_COLOR:GetRGB()); t.CompareHeader:Hide()
    end
    self.comparison={}
    if type(TooltipComparisonManager)=="table" then
        for key,fn in pairs(TooltipComparisonManager) do if type(fn)=="function" then self.comparison[key]=fn end end
    end
    local getData=self.comparison.GetComparisonItemData
    if type(getData)=="function" then
        self.comparison.GetComparisonItemData=function(manager,displayedItem)
            local data=getData(manager,displayedItem)
            if M.Readable(displayedItem) and displayedItem~=nil and M.Readable(data) and data==nil then self.comparisonCold=true end
            return data
        end
        self.comparisonRetries=true
    end
    return true
end
function V:InspectionOpen()
    if self.isOpen then return self:isOpen() end
    return N.Hover.open
end
function V:InspectionCurrent(item)
    return type(item)=="table" and item.button~=nil and item.row~=nil and self.item==item
        and item.button.row==item.row and item.generation==(self.generation or N.Hover.generation) and self:InspectionOpen()
end
function V:HasTooltipData(id)
    if not self:InspectionCurrent(self.item) or not M.Readable(id) or id~=nil and not M.Number(id) then return false end
    local function matches(t)
        return A.Visible(t) and (id==nil or A.Call(t.HasDataInstanceID,t,id)==true)
    end
    if matches(self.tooltip) then return true end
    for _,t in ipairs(self.tooltip.shoppingTooltips) do if matches(t) then return true end end
    return false
end
function V:Inspect(button,row,refresh)
    local previous,outside=self.item,self.itemOutsideAt
    if refresh and previous and not self:InspectionCurrent(previous) then self:ClearItem(); return end
    local preserve=refresh and previous and previous.button==button and previous.row.itemID==row.itemID and previous.generation==(self.generation or N.Hover.generation)
    self:ClearItem()
    local open=N.Hover.open
    if self.isOpen then open=self:isOpen() end
    if not open or not refresh and (not A.Over(self.scroll) or not A.Over(button)) or row.state~="ready" or not M.QuestId(row.itemID) or not self:Tooltips() then return end
    self.item={ button=button,row=row,generation=self.generation or N.Hover.generation,pending=true }
    local inspection=self.item
    if preserve then
        self.itemOutsideAt=outside
        inspection.bridgeAt=previous.bridgeAt
        inspection.compareDeadline,inspection.compareRetryAt,inspection.compareTimedOut=previous.compareDeadline,previous.compareRetryAt,previous.compareTimedOut
        inspection.comparisonLoads=previous.comparisonLoads
        inspection.primaryDeadline,inspection.primaryRetryAt=previous.primaryDeadline,previous.primaryRetryAt
    end
    local getter=C_TooltipInfo and C_TooltipInfo.GetQuestLogItem
    if row.kind=="catalog" then getter=C_TooltipInfo and C_TooltipInfo.GetHyperlink end
    if type(getter)~="function" then self:ClearItem(); return end
    local ok,data
    if row.kind=="catalog" then ok,data=pcall(getter,row.link)
    else ok,data=pcall(getter,row.kind,row.index,row.questID) end
    if not ok or not M.Readable(data) or not self:InspectionCurrent(inspection) then self:ClearItem(); return end
    if data==nil then
        local now=A.Call(GetTime) or 0
        inspection.primaryDeadline=inspection.primaryDeadline or now+5
        inspection.primaryRetryAt=now+.2
        return
    end
    if type(data)~="table" or type(canaccessallvalues)=="function" and A.Call(canaccessallvalues,data)~=true
        or not M.Readable(data.type) or not M.QuestId(data.id) or data.id~=row.itemID
        or not Enum or not Enum.TooltipDataType or data.type~=Enum.TooltipDataType.Item then self:ClearItem(); return end
    inspection.pending,inspection.primaryDeadline,inspection.primaryRetryAt=false,nil,nil
    inspection.data=data
    local t=self.tooltip; t:SetOwner(button,"ANCHOR_NONE"); t:ClearAllPoints()
    local rect=A.Rect(self.frame); local screenWidth=A.Call(UIParent.GetWidth,UIParent); local parentScale=A.Call(UIParent.GetEffectiveScale,UIParent)
    local buttonRect,tipScale=A.Rect(button),A.Call(t.GetEffectiveScale,t)
    if not rect or not buttonRect or not M.Number(tipScale) or tipScale<=0 then self:ClearItem(); return end
    local right=M.Number(screenWidth) and M.Number(parentScale) and screenWidth*parentScale-rect.x-rect.w>300
    local edge=right and rect.x+rect.w or rect.x
    local buttonEdge=right and buttonRect.x+buttonRect.w or buttonRect.x
    -- Keep the horizontal edge beside the stack, but align vertically to the
    -- inspected icon so bottom-row rewards have a short pointer route.
    t:SetPoint(right and "TOPLEFT" or "TOPRIGHT",button,right and "TOPRIGHT" or "TOPLEFT",(edge-buttonEdge)/tipScale+(right and 6 or -6),0)
    local ok,result=pcall(t.ProcessInfo,t,{tooltipData=data})
    if not ok or result~=true or not self:InspectionCurrent(inspection) then self:ClearItem(); return end
    self:Compare()
end
function V:Compare()
    if not self.item or not self.comparison or not self.comparison.CompareItem then return end
    if not self:InspectionCurrent(self.item) then self:ClearItem(); return end
    if self.item.pending then return end
    -- Native ShouldDoItemComparison gates the CVar on automatic comparison.
    -- Our isolated manager owns that work, so honor both native inputs without
    -- handing the private tooltip back to the global manager.
    local should=A.Call(GetCVarBool,"alwaysCompareItems")==true or A.Call(IsModifiedClick,"COMPAREITEMS")==true
    local inspection=self.item; local now=A.Call(GetTime) or 0
    if not should then
        inspection.compareDeadline,inspection.compareRetryAt,inspection.compareTimedOut=nil,nil,nil
        if self.compareState==false then return end
        self.compareState=false; if self.comparison.Clear then self.comparison:Clear(self.tooltip) end; return
    end
    if inspection.compareDeadline and now>=inspection.compareDeadline then
        inspection.compareRetryAt=nil; inspection.compareTimedOut=true
    end
    if inspection.compareTimedOut or inspection.compareRetryAt and now<inspection.compareRetryAt then self.compareState=true; return end
    if self.compareState==true and not inspection.compareRetryAt then return end
    self.compareState=true
    local comparisonItem=A.Call(self.comparison.CreateComparisonItem,self.comparison,self.item.data)
    if comparisonItem then
        -- The native manager caches a nil comparison result by item identity.
        -- Clear only our clone before retrying so it asks for current metadata.
        if self.comparisonRetries and self.comparison.comparisonItem and self.comparison.compareInfo==nil then self.comparison:Clear(self.tooltip) end
        self.comparisonCold=false
        self.cycleHints=cycleHints()
        local ok=pcall(self.comparison.CompareItem,self.comparison,comparisonItem,self.tooltip,self.tooltip)
        self.cycleHints=nil
        if not ok or not self:InspectionCurrent(inspection) then self:ClearItem(); return end
        if self.comparisonRetries and (self.comparisonCold or self.comparison.compareInfo==nil) then
            inspection.compareDeadline=inspection.compareDeadline or now+5
            inspection.compareRetryAt=now+.2
        else
            inspection.compareDeadline,inspection.compareRetryAt,inspection.compareTimedOut=nil,nil,nil
        end
    else
        inspection.compareDeadline,inspection.compareRetryAt,inspection.compareTimedOut=nil,nil,nil
        if self.comparison.Clear then self.comparison:Clear(self.tooltip) end
    end
end
function V:ComparisonChanged()
    -- The native manager keys its cache by candidate identity, not equipment,
    -- metadata readiness or the comparison CVar. Invalidate our clone only.
    local item=self.item
    if not item then return end
    if not self:InspectionCurrent(item) then self:ClearItem(); return end
    item.compareDeadline,item.compareRetryAt,item.compareTimedOut=nil,nil,nil
    self.compareState=nil
    if self.comparison and self.comparison.Clear then self.comparison:Clear(self.tooltip) end
    self:Compare()
end
function V:EquipmentChanged()
    local item=self.item
    if not item then return end
    if not self:InspectionCurrent(item) then self:ClearItem(); return end
    item.compareDeadline,item.compareRetryAt,item.compareTimedOut=nil,nil,nil
    item.comparisonLoads=nil
    -- Refresh native candidate text as well as equipped comparisons. The
    -- refresh preserves pointer transit while discarding prior equipped data.
    self:Inspect(item.button,item.row,true)
end
function V:ComparisonItemData(id)
    -- An equipped item's ID need not be the inspected reward's ID. A completed
    -- load may revive a bounded cold comparison even after its retry deadline.
    local item=self.item
    if not item or not item.compareTimedOut then return end
    if not self:InspectionCurrent(item) then self:ClearItem(); return end
    id=M.QuestId(id)
    -- Existing polling already observes new data within 0.2 s. Unrelated item
    -- floods must not extend its deadline or query native comparisons per event.
    if not id then return end
    local related=id==item.row.itemID
    local function matches(entry)
        local link=entry and M.Text(entry.hyperlink)
        return link and tonumber(link:match("item:(%d+)"))==id
    end
    local info=self.comparison and self.comparison.compareInfo
    if info then
        related=related or matches(info.item)
        for _,entry in ipairs(info.additionalItems or {}) do related=related or matches(entry) end
    end
    for _,entry in pairs(N.Character and N.Character.snapshot.equipment or {}) do related=related or entry.itemID==id end
    item.comparisonLoads=item.comparisonLoads or {}
    if related and not item.comparisonLoads[id] then
        item.comparisonLoads[id]=true
        self:ComparisonChanged()
    end
end
function V:ClearItem()
    self.item,self.itemOutsideAt,self.compareState=nil,nil,nil
    self.comparisonCold=nil
    if self.comparison and self.comparison.Clear then self.comparison:Clear(self.tooltip) end
    if self.tooltip then self.tooltip:Hide(); for _,t in ipairs(self.tooltip.shoppingTooltips) do t:Hide() end end
end
function V:ItemContains(now)
    if not self.item then return false end
    if A.Over(self.scroll) and A.Over(self.item.button) or A.Over(self.tooltip) then self.item.bridgeAt=nil; return true end
    for _,t in ipairs(self.tooltip.shoppingTooltips) do
        if A.Over(t) or A.Visible(t) and A.Over(t.CompareHeader) then self.item.bridgeAt=nil; return true end
    end
    local button,tip,viewport=A.Rect(self.item.button),A.Rect(self.tooltip),A.Rect(self.scroll)
    local x,y=A.Cursor()
    if button and tip and viewport and x then
        local left,right=math.max(button.x,viewport.x),math.min(button.x+button.w,viewport.x+viewport.w)
        local bottom,top=math.max(button.y,viewport.y),math.min(button.y+button.h,viewport.y+viewport.h)
        if left>=right or bottom>=top then return false end
        local ax,ay=(left+right)/2,(bottom+top)/2
        local bx,by=math.max(tip.x,math.min(tip.x+tip.w,ax)),math.max(tip.y,math.min(tip.y+tip.h,ay))
        if nearSegment(x,y,ax,ay,bx,by,math.min(16,(top-bottom)/2)) then
            now=now or A.Call(GetTime) or 0; self.item.bridgeAt=self.item.bridgeAt or now
            return now-self.item.bridgeAt<=1.25
        end
    end
    return false
end
function V:ItemTransit(now)
    if not self.item then return end
    if not self:InspectionCurrent(self.item) then self:ClearItem(); return end
    if self:ItemContains(now) then self.itemOutsideAt=nil
    else self.itemOutsideAt=self.itemOutsideAt or now; if now-self.itemOutsideAt>=N.Hover.grace then self:ClearItem(); return end end
    local item=self.item
    if item and item.pending then
        if now>=item.primaryDeadline then self:ClearItem()
        elseif now>=item.primaryRetryAt then self:Inspect(item.button,item.row,true) end
    end
end
function V:NativeTransit()
    local frame,original=self.nativeFrame,self.nativePhysicalRect
    if not frame or frame~=GameTooltip or not original or A.Call(frame.GetOwner,frame)~=self.nativeOwner then return false end
    if A.Call(frame.GetPrimaryTooltipData or frame.GetTooltipData,frame)~=self.nativeData then return false end
    if not M.Readable(frame._Rebuild) or frame._Rebuild~=self.nativeRebuild then return false end
    if M.Text(A.Call(GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText,GameTooltipTextLeft1))~=self.nativeHeader then return false end
    if not self.nativeData and not self.nativeRebuild and not self.nativeHeader then return false end
    if type(self.nativeData)=="table" then
        for _,key in ipairs({"id","type","guid","dataInstanceID"}) do
            if not M.Readable(self.nativeData[key]) or self.nativeData[key]~=self.nativeToken[key] then return false end
        end
    end
    local current=A.Rect(frame)
    if not current then return false end
    for _,key in ipairs({"x","y","w","h"}) do if math.abs(current[key]-original[key])>.5 then return false end end
    return A.Over(frame)
end
function V:OpeningTransit(now)
    if self.openingTransitConsumed or not self.placement or not self.source then return false end
    if self.source.over() then return false end
    local x,y=A.Cursor(); if not x then return false end
    x,y=x/self.parentScale,y/self.parentScale
    local p=self.placement
    local bx,by=math.max(p.left,math.min(p.left+p.width,x)),math.max(p.bottom+8,math.min(p.bottom+p.height-8,self.anchorY))
    if not nearSegment(x,y,self.anchorX,self.anchorY,bx,by,20) then return false end
    now=now or A.Call(GetTime) or 0; self.openingTransitAt=self.openingTransitAt or now
    return now-self.openingTransitAt<=1.25
end
function V:Contains(now)
    if A.Over(self.frame) then self.openingTransitConsumed=true; return true end
    return self:NativeTransit() or self:OpeningTransit(now) or self:ItemContains(now)
end
function V.NewInspector(frame,scroll,isOpen)
    return setmetatable({frame=frame,scroll=scroll,isOpen=isOpen,tooltipPrefix="FindAnUpgradeSearch",generation=0},{__index=V})
end

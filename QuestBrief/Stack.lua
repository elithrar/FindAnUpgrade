local _, N = ...
local M, A, U = N.Model, N.Adapter, N.UI
local V = { cards = {}, offset = 0 }; N.Stack = V
local skin = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 10, insets = { left=2, right=2, top=2, bottom=2 } }
local function text(parent, size)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    U:Font(f, size or 12); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetWordWrap(true)
    return f
end
local function height(f, width, value, minimum)
    f:SetWidth(width); f:SetText(value)
    local measured = A.Call(f.GetStringHeight, f)
    return M.Number(measured) and math.max(minimum or 16, measured+2) or minimum or 16
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
    local f = CreateFrame("Frame", "QuestBriefStack", UIParent, "BackdropTemplate"); self.frame = f
    f:Hide() -- Constructor cleanup must not dismiss the first opening session.
    f:SetFrameStrata("TOOLTIP"); f:SetClampedToScreen(true); f:EnableMouse(true); f:SetBackdrop(skin)
    f:SetBackdropColor(.04,.04,.05,.96); f:SetBackdropBorderColor(.5,.5,.5,.8)
    self.header = text(f,12); self.header:SetPoint("TOPLEFT",10,-8)
    local scroll = CreateFrame("ScrollFrame", nil, f); self.scroll = scroll
    scroll:SetPoint("TOPLEFT",6,-30); scroll:SetPoint("BOTTOMRIGHT",-22,8); scroll:EnableMouse(true); scroll:EnableMouseWheel(true)
    self.child = CreateFrame("Frame", nil, scroll); self.child:SetSize(292,1); scroll:SetScrollChild(self.child)
    self.bar = CreateFrame("Slider", nil, f, "UISliderTemplate"); self.bar:SetPoint("TOPRIGHT",-6,-32); self.bar:SetPoint("BOTTOMRIGHT",-6,10)
    self.bar:SetWidth(12); self.bar:SetOrientation("VERTICAL"); self.bar:SetValueStep(1); self.bar:SetMinMaxValues(0,0)
    local thumb=A.Call(self.bar.GetThumbTexture,self.bar)
    if thumb and not A.Forbidden(thumb) then thumb:SetSize(12,22) end
    self.bar:SetScript("OnValueChanged",function(_,value) if not self.refreshing then self:Scroll(value) end end)
    scroll:SetScript("OnMouseWheel",function(_,delta) if M.Number(delta) then self:Scroll(self.offset-delta*40) end end)
    f:SetScript("OnHide",function() if N.Hover.open then N.Hover:Dismiss("escape") else self:ClearItem() end end)
    UISpecialFrames = UISpecialFrames or {}; table.insert(UISpecialFrames,"QuestBriefStack"); f:Hide()
end
function V:Card(index)
    if self.cards[index] then return self.cards[index] end
    local c = CreateFrame("Frame",nil,self.child,"BackdropTemplate"); self.cards[index] = c
    c:SetWidth(292); c:EnableMouse(true); c:SetBackdrop(skin)
    c.title, c.status, c.evidence, c.summary = text(c,13), text(c,11), text(c,11), text(c,11)
    c.title:SetTextColor(1,1,1); c.title:SetPoint("TOPLEFT",10,-10)
    c.status:SetTextColor(.83,.83,.83); c.evidence:SetTextColor(.7,.7,.72)
    c.groups = {}; c.icons = {}
    return c
end
function V:Icon(c,index)
    if c.icons[index] then return c.icons[index] end
    local b = CreateFrame("Button",nil,c); c.icons[index] = b; b:SetSize(28,28)
    b.icon = b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints()
    b.border = b:CreateTexture(nil,"OVERLAY"); b.border:SetAllPoints(); b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    b.count = text(b,10); b.count:SetPoint("BOTTOMRIGHT",-1,1); b.count:SetJustifyH("RIGHT")
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
    g.label:ClearAllPoints(); g.label:SetPoint("TOPLEFT",10,-y); g.label:SetWidth(270)
    local list = group.items
    g.label:SetText(label .. (group.state ~= "ready" and " - " .. (group.state == "pending" and "loading" or "unavailable") or "")); g.label:Show()
    y=y+18
    local limit = g.expanded and #list or math.min(#list,8)
    for i=1,limit do
        local row, b = list[i], self:Icon(c,nextIcon); nextIcon=nextIcon+1
        b.row = row; b:ClearAllPoints(); b:SetPoint("TOPLEFT",10+((i-1)%8)*34,-y-math.floor((i-1)/8)*34)
        b.icon:SetTexture(row.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        local color = row.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[row.quality]
        b.border:SetVertexColor(color and color.r or .6,color and color.g or .6,color and color.b or .6)
        b.count:SetText(row.quantity and row.quantity > 1 and tostring(row.quantity) or ""); b:Show()
    end
    y=y+math.max(1,math.ceil(limit/8))*34
    if #list>8 then
        g.more:ClearAllPoints(); g.more:SetPoint("TOPLEFT",10,-y); g.more.text:SetText(g.expanded and "Fewer " .. key or "+" .. (#list-8) .. " " .. key); g.more:Show(); y=y+22
    else g.more:Hide() end
    return y,nextIcon
end
function V:Fill(c,row,profile)
    if c.questID ~= row.id then for _,g in pairs(c.groups) do g.expanded=false end end
    c.questID = row.id
    for _,b in ipairs(c.icons) do b.row=nil; b:Hide() end
    for _,g in pairs(c.groups) do g.label:Hide(); g.more:Hide() end
    local title = M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,row.id)) or row.title or "Quest " .. row.id
    local y=10+height(c.title,270,title,18)
    c.status:ClearAllPoints(); c.status:SetPoint("TOPLEFT",10,-y)
    y=y+height(c.status,270,M.Label(row.id),16)
    c.evidence:ClearAllPoints(); c.evidence:SetPoint("TOPLEFT",10,-y)
    y=y+height(c.evidence,270,row.evidence or "",16)+4
    local reward=profile.rewards and N.Rewards.Read(row.id); local nextIcon=1
    if reward and (reward.state == "pending" or reward.items.state == "pending" or reward.choices.state == "pending") then
        N.Hover.pending=true
        if N.Hover.timedOut then
            reward.state="unavailable"
            if reward.items.state == "pending" then reward.items.state="unavailable" end
            if reward.choices.state == "pending" then reward.choices.state="unavailable" end
        end
    end
    local lines={}
    if profile.rewards then
        if #reward.items.items>0 or reward.items.state~="ready" then y,nextIcon=self:Group(c,"items","Guaranteed",reward.items,y,nextIcon) end
        if #reward.choices.items>0 then y,nextIcon=self:Group(c,"choices","Choose one",reward.choices,y,nextIcon) end
        if reward.choices.state~="ready" and #reward.choices.items==0 then lines[#lines+1]="Choices: unavailable" end
        if reward.money.state=="ready" and reward.money.value>0 then lines[#lines+1]=M.Text(A.Call(GetCoinTextureString,reward.money.value)) or (reward.money.value .. " copper") end
        if reward.xp.state=="ready" and reward.xp.value>0 then lines[#lines+1]=reward.xp.value .. " XP" end
        for _,currency in ipairs(reward.currencies.items) do lines[#lines+1]=(currency.isChoice and "Choose one: " or "Guaranteed: ") .. currency.name .. " " .. currency.amount end
        for _,rep in ipairs(reward.reputation.items or {}) do lines[#lines+1]="Major faction " .. rep.factionID .. ": " .. (rep.amount>=0 and "+" or "") .. rep.amount end
        lines[#lines+1]="Reputation: unavailable" -- Ordinary faction scope remains unverified.
        if reward.money.state~="ready" or reward.xp.state~="ready" then lines[#lines+1]=reward.state=="pending" and "Rewards loading" or "Some rewards unavailable" end
    end
    c.summary:ClearAllPoints(); c.summary:SetPoint("TOPLEFT",10,-y)
    y=y+height(c.summary,270,table.concat(lines,"\n"),profile.rewards and 16 or 0)+10
    c:SetHeight(y)
    local status=profile.accents and M.Status(row.id)
    local new, modified=status=="verifiedNew", status=="verifiedUpdated"
    local strength=profile.strength
    c:SetBackdropColor(.06+(new and .08*strength or 0),.06+(modified and .08*strength or 0),.07,.97)
    c:SetBackdropBorderColor(new and .65 or .4,modified and .6 or .4,new and .25 or .4,.75)
    return y
end
function V:Refresh()
    if not self.source then return end
    self:ClearItem(); local y=0; self.refreshing=true; N.Hover.pending=false
    local p=N.Core.profile
    local revision=U.fontRevision or 0
    for pass=1,2 do
        y=0
        for i,row in ipairs(self.source.rows) do
            local c=self:Card(i); c:ClearAllPoints(); c:SetPoint("TOPLEFT",0,-y); y=y+self:Fill(c,row,p)+5; c:Show()
        end
        U:RefreshFonts()
        if revision==(U.fontRevision or 0) then break end
        revision=U.fontRevision or 0
    end
    for i=#self.source.rows+1,#self.cards do self.cards[i]:Hide(); self.cards[i].questID=nil end
    self.child:SetHeight(math.max(y,1)); self.contentHeight=y
    self.maximum=math.max(0,y-self.viewportHeight); self.bar:SetMinMaxValues(0,self.maximum); self.bar:SetShown(self.maximum>0)
    self.header:SetText(#self.source.rows .. " quests" .. (self.maximum>0 and " - scroll" or ""))
    self.refreshing=false; self:Scroll(self.offset)
end
function V:Show(source,profile)
    self:Create()
    local x,y=A.Cursor(); local parentScale=A.Call(UIParent.GetEffectiveScale,UIParent)
    local sw,sh=A.Call(UIParent.GetWidth,UIParent),A.Call(UIParent.GetHeight,UIParent)
    if not x or not M.Number(parentScale) or parentScale<=0 or not M.Number(sw) or not M.Number(sh) or sw<340 or sh<180 then return false end
    self.source,self.offset=source,0
    local scale=math.min(profile.scale,(sw-16)/320)
    self.frame:SetScale(scale); self.frame:SetSize(320,math.min(400,sh*.6/scale)); self.viewportHeight=self.frame:GetHeight()-38
    x,y=x/parentScale,y/parentScale
    local left=x+14
    if left+320*scale>sw-8 then left=x-14-320*scale end
    left=math.max(8,math.min(sw-320*scale-8,left)); local bottom=math.max(8,math.min(sh-self.frame:GetHeight()*scale-8,y-self.frame:GetHeight()*scale+24))
    self.frame:ClearAllPoints(); self.frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left/scale,bottom/scale)
    self:Refresh(); self.frame:Show(); return true
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
        Mixin(t,TooltipDataHandlerMixin); t.suppressAutomaticCompareItem=true
        t:HookScript("OnHide",function() t:ClearHandlerInfo() end)
        return t
    end
    local prefix=self.tooltipPrefix or "QuestBrief"
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
        t.CompareHeader=CreateFrame("Frame",nil,t); t.CompareHeader:SetPoint("BOTTOMLEFT",t,"TOPLEFT",0,0); t.CompareHeader:SetHeight(20)
        t.CompareHeader.Label=t.CompareHeader:CreateFontString(nil,"OVERLAY","GameTooltipText"); t.CompareHeader.Label:SetPoint("CENTER"); t.CompareHeader:Hide()
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
    return item~=nil and self.item==item and item.button.row==item.row and item.generation==(self.generation or N.Hover.generation) and self:InspectionOpen()
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
        inspection.compareDeadline,inspection.compareRetryAt,inspection.compareTimedOut=previous.compareDeadline,previous.compareRetryAt,previous.compareTimedOut
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
    local right=rect and M.Number(screenWidth) and M.Number(parentScale) and screenWidth*parentScale-rect.x-rect.w>300
    t:SetPoint(right and "TOPLEFT" or "TOPRIGHT",self.frame,right and "TOPRIGHT" or "TOPLEFT",right and 6 or -6,0)
    local ok,result=pcall(t.ProcessInfo,t,{tooltipData=data})
    if not ok or result~=true or not self:InspectionCurrent(inspection) then self:ClearItem(); return end
    self:Compare()
end
function V:Compare()
    if not self.item or not self.comparison or not self.comparison.CompareItem then return end
    if not self:InspectionCurrent(self.item) then self:ClearItem(); return end
    if self.item.pending then return end
    local should=TooltipUtil and A.Call(TooltipUtil.ShouldDoItemComparison,self.tooltip) == true or false
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
function V:ClearItem()
    self.item,self.itemOutsideAt,self.compareState=nil,nil,nil
    self.comparisonCold=nil
    if self.comparison and self.comparison.Clear then self.comparison:Clear(self.tooltip) end
    if self.tooltip then self.tooltip:Hide(); for _,t in ipairs(self.tooltip.shoppingTooltips) do t:Hide() end end
end
function V:ItemContains()
    if not self.item then return false end
    if A.Over(self.scroll) and A.Over(self.item.button) or A.Over(self.tooltip) then return true end
    for _,t in ipairs(self.tooltip.shoppingTooltips) do if A.Over(t) then return true end end
    return false
end
function V:ItemTransit(now)
    if not self.item then return end
    if not self:InspectionCurrent(self.item) then self:ClearItem(); return end
    if self:ItemContains() then self.itemOutsideAt=nil
    else self.itemOutsideAt=self.itemOutsideAt or now; if now-self.itemOutsideAt>=N.Hover.grace then self:ClearItem(); return end end
    local item=self.item
    if item and item.pending then
        if now>=item.primaryDeadline then self:ClearItem()
        elseif now>=item.primaryRetryAt then self:Inspect(item.button,item.row,true) end
    end
end
function V:Contains() return A.Over(self.frame) or self:ItemContains() end
function V.NewInspector(frame,scroll,isOpen)
    return setmetatable({frame=frame,scroll=scroll,isOpen=isOpen,tooltipPrefix="QuestBriefSearch",generation=0},{__index=V})
end

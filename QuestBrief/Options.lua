local _, N = ...
local O = {}; N.Options = O
local U = N.UI
local gold, ink, muted = {1,.82,.2}, {.93,.94,.97}, {.7,.7,.72}
local backdrop = {bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=10,insets={left=2,right=2,top=2,bottom=2}}
function O:Label(parent,value,x,y,width,size,color)
    local t=parent:CreateFontString(nil,"OVERLAY"); t:SetPoint("TOPLEFT",x,y); t:SetSize(width,20); t:SetJustifyH("LEFT"); t:SetJustifyV("TOP"); t:SetWordWrap(true)
    t:SetText(value); t:SetTextColor(unpack(color or ink)); t:SetShadowColor(0,0,0,.65); t:SetShadowOffset(1,-1)
    self.texts[#self.texts+1]={object=t,size=size or 12}; U:Font(t,size or 12); return t
end
function O:Button(parent,value,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate"); b:SetPoint("TOPLEFT",x,y); b:SetSize(width,24); b:SetBackdrop(backdrop)
    b:SetBackdropColor(.06,.06,.065,.8); b:SetBackdropBorderColor(.45,.45,.45,.65)
    b.text=self:Label(b,value,6,-5,width-12,12); b.text:SetJustifyH("CENTER"); b.text:SetWordWrap(false)
    b:SetScript("OnEnter",function() b:SetBackdropBorderColor(.9,.8,.5,.9) end); b:SetScript("OnLeave",function() b:SetBackdropBorderColor(.45,.45,.45,.65) end)
    b:SetScript("OnClick",callback); self.controls[#self.controls+1]=b; return b
end
function O:Check(parent,key,value,x,y,width)
    local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); b:SetPoint("TOPLEFT",x,y); b:SetSize(24,24)
    b.Text:SetText(value); b.Text:SetTextColor(unpack(ink)); b.Text:SetWidth(width-28); b:SetHitRectInsets(0,-width+28,0,0)
    self.texts[#self.texts+1]={object=b.Text,size=12}; self.checks[key]=b; self.controls[#self.controls+1]=b
    b:SetScript("OnClick",function() self.owner:Change(key,b:GetChecked()==true) end); return b
end
function O:Slider(parent,key,value,x,y,low,high,step)
    self:Label(parent,value,x,y,200,12,gold)
    local b=CreateFrame("Slider",nil,parent,"UISliderTemplate"); b:SetPoint("TOPLEFT",x,y-24); b:SetSize(180,16); b:SetOrientation("HORIZONTAL")
    b:SetMinMaxValues(low,high); b:SetValueStep(step); b:SetObeyStepOnDrag(true)
    b.valueLabel=self:Label(parent,"",x+194,y-22,54,12)
    b:SetScript("OnValueChanged",function(_,v) if not self.refreshing then self.owner:Change(key,v/100) end end)
    self.sliders[key]=b; self.controls[#self.controls+1]=b; return b
end
function O:Create(owner)
    self.owner=owner; self.texts={}; self.controls={}; self.checks={}; self.sliders={}; self.keys={}
    local f=CreateFrame("Frame","QuestBriefOptions",UIParent,"BackdropTemplate"); self.frame=f
    f:SetSize(540,426); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetBackdrop(backdrop); f:SetBackdropColor(.045,.045,.05,.95); f:SetBackdropBorderColor(.65,.65,.65,1)
    f:SetScript("OnDragStart",function() f:StartMoving() end); f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    self:Label(f,"QuestBrief",20,-18,440,16,gold)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetSize(24,24); close:SetPoint("TOPRIGHT",-8,-8); close:SetScript("OnClick",function() f:Hide() end)
    self:Check(f,"enabled","Enabled",16,-54,250)
    self:Label(f,"Reveal key",24,-92,220,12,gold)
    for i,entry in ipairs({{"Shift","SHIFT"},{"Ctrl","CTRL"},{"Alt","ALT"},{"None","NONE"}}) do
        local key=entry[2]; self.keys[key]=self:Button(f,entry[1],24+(i-1)*76,-116,68,function() owner:Change("modifier",key) end)
    end
    self:Label(f,"Inspect after revealing. Escape or move away to close.",24,-151,494,11,muted)
    self:Label(f,"Show previews",24,-182,240,12,gold)
    self:Check(f,"npc","NPCs",20,-207,150); self:Check(f,"worldmap","World map",180,-207,160); self:Check(f,"minimap","Minimap",350,-207,150)
    self:Label(f,"Minimap: Questie markers only. NPCs need known quest IDs.",24,-237,494,11,muted)
    self:Check(f,"rewards","Reward details",20,-264,240); self:Check(f,"accents","Quest colors",280,-264,230)
    self:Check(f,"dialogTint","Quest dialog tint",20,-292,260)
    self:Slider(f,"scale","Panel scale",24,-327,80,120,5); self:Slider(f,"strength","Tint strength",280,-327,10,100,5)
    self:Button(f,"Reset",24,-387,84,function() owner:Defaults() end)
    self.status=self:Label(f,"",120,-391,400,11,muted)
    f:SetScript("OnShow",function() self:Refresh() end); f:SetScript("OnHide",function() f:StopMovingOrSizing() end)
    f:RegisterEvent("UI_SCALE_CHANGED"); f:RegisterEvent("DISPLAY_SIZE_CHANGED"); f:SetScript("OnEvent",function() self:Refresh() end)
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"QuestBriefOptions"); f:Hide()
end
function O:Refresh()
    if not self.frame then return end
    self.refreshing=true; local p=self.owner.profile
    for _,entry in ipairs(self.texts) do U:Font(entry.object,entry.size) end
    U:RefreshFonts()
    for key,b in pairs(self.checks) do b:SetChecked(p[key]) end
    for key,b in pairs(self.keys) do b.text:SetTextColor(unpack(p.modifier==key and gold or ink)) end
    for key,b in pairs(self.sliders) do b:SetValue(p[key]*100); b.valueLabel:SetText(math.floor(p[key]*100+.5).."%") end
    for _,b in ipairs(self.controls) do if self.owner.readOnly then b:Disable() else b:Enable() end end
    self.status:SetText(self.owner.readOnly and "Newer settings are read-only." or not self.owner.supported and "Unsupported client." or "Native contrast takes priority.")
    self.frame:SetScale(math.min(1,(UIParent:GetHeight()-24)/426,(UIParent:GetWidth()-24)/540))
    self.refreshing=false
end
function O:Toggle(owner)
    if not self.frame then self:Create(owner) end
    if self.frame:IsShown() then self.frame:Hide() else self:Refresh(); self.frame:Show() end
end

local _, N = ...
local O = {}; N.Options = O
local U = N.UI
local gold, ink, muted = {1,.82,.2}, {.93,.94,.97}, {.7,.7,.72}
local panelWidth,panelHeight=620,458
local backdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=10,insets={left=2,right=2,top=2,bottom=2}}

-- Reuse current XPIsland's bounded native controls and scale-aware text fitting.
local function bounded(text,width,height)
    text.qOptionsWidth,text.qOptionsHeight=width,height; text:SetWordWrap(false)
end
local function fitBounded(text)
    if not text.qOptionsWidth then return end
    text:SetScale(1)
    local width,height=U:Measure(text); text.qNaturalWidth=width
    local available=math.min(text.qOptionsWidth,width*text.qOptionsHeight/math.max(1,height))
    local scale=U:FitText(text,available)
    text:SetSize(text.qOptionsWidth/scale,text.qOptionsHeight/scale)
    if text.qOptionsAnchor then U:AnchorText(text,unpack(text.qOptionsAnchor)) end
end
-- WoW objects are permanent. Reuse deterministic constructor slots after a
-- transient failure rather than abandoning a new subtree on every retry.
function O:Frame(kind,parent,template)
    self.frameSlot=self.frameSlot+1
    local entry=self.framePool[self.frameSlot]
    if not entry then
        entry={object=CreateFrame(kind,nil,parent,template),kind=kind,parent=parent,template=template}
        self.framePool[self.frameSlot]=entry
    end
    assert(entry.kind==kind and entry.parent==parent and entry.template==template,"Options constructor order changed")
    return entry.object
end
function O:Text(parent)
    self.textSlot=self.textSlot+1
    local entry=self.textPool[self.textSlot]
    if not entry then
        entry={object=parent:CreateFontString(nil,"OVERLAY","GameFontNormal"),parent=parent}
        self.textPool[self.textSlot]=entry
    end
    assert(entry.parent==parent,"Options text owner changed")
    return entry.object
end
function O:Label(parent,value,x,y,width,size,color)
    local t=self:Text(parent)
    self.texts[#self.texts+1]={object=t,size=size or 12}; U:Font(t,size or 12)
    t:SetPoint("TOPLEFT",x,y); t:SetJustifyH("LEFT"); t:SetJustifyV("MIDDLE")
    t:SetShadowColor(0,0,0,.8); t:SetShadowOffset(1,-1); t:SetTextColor(unpack(color or ink))
    if width then bounded(t,width,20) end
    t:SetText(value); return t
end
function O:Button(parent,value,x,y,width,callback)
    local b=self:Frame("Button",parent,"BackdropTemplate"); b:SetPoint("TOPLEFT",x,y); b:SetSize(width,22)
    b:SetBackdrop(backdrop); b:SetBackdropColor(.06,.06,.065,.8); b:SetBackdropBorderColor(.45,.45,.45,.65)
    b.text=self:Label(b,value,0,0,width-12,12); b.text:ClearAllPoints(); b.text:SetPoint("CENTER")
    b:SetScript("OnEnter",function() b:SetBackdropBorderColor(.9,.8,.5,.9) end)
    b:SetScript("OnLeave",function() b:SetBackdropBorderColor(.45,.45,.45,.65) end)
    b:SetScript("OnClick",callback); self.controls[#self.controls+1]=b; return b
end
function O:Section(parent,value,x,y,width,height)
    local box=self:Frame("Frame",parent,"BackdropTemplate")
    box:SetFrameLevel(parent:GetFrameLevel()-1); box:SetPoint("TOPLEFT",x,y-9); box:SetSize(width,height)
    box:SetBackdrop(backdrop); box:SetBackdropColor(.035,.035,.04,.35); box:SetBackdropBorderColor(.35,.35,.35,.5)
    self:Label(parent,value,x+10,y,width-20,12,gold)
    self.sections[#self.sections+1]=box; return box
end
function O:Dropdown(parent,x,y,width,entries,get,choose)
    local d=self:Frame("DropdownButton",parent,"WowStyle1DropdownTemplate")
    d:SetPoint("TOPLEFT",x,y); d:SetSize(width,24)
    self.texts[#self.texts+1]={object=d.Text,size=12}; U:Font(d.Text,12)
    d:SetDefaultText("Choose"); d.Text:ClearAllPoints(); d.Text:SetPoint("LEFT",d,"LEFT",9,0)
    d.Text.qOptionsAnchor={"LEFT",d,"LEFT",9,0}; bounded(d.Text,width-31,24)
    d.Text:SetHeight(24); d.Text:SetJustifyV("MIDDLE"); d.Text:SetJustifyH("LEFT"); d.text=d.Text
    d:SetupMenu(function(_,root)
        root:SetScrollMode(220)
        for _,entry in ipairs(entries) do
            local row=root:CreateRadio(entry.label,function(value) return get()==value end,choose,entry.value)
            row:AddInitializer(function(button)
                -- Native compositor text accepts an owned Font object, not SetFont.
                button.fontString:SetFontObject(self.menuFont)
            end)
        end
    end)
    self.dropdowns[#self.dropdowns+1]=d; self.controls[#self.controls+1]=d; return d
end
function O:CloseMenu()
    for _,d in ipairs(self.dropdowns or {}) do d:CloseMenu() end
end
function O:Check(parent,key,value,x,y)
    local b=self:Frame("CheckButton",parent,"UICheckButtonTemplate")
    b:SetPoint("TOPLEFT",x-4,y); b:SetSize(24,24); b.key,b.caption=key,value; b.text=b.Text
    self.texts[#self.texts+1]={object=b.Text,size=12}; U:Font(b.Text,12)
    b.Text:SetJustifyH("LEFT"); b.Text:SetTextColor(unpack(ink)); bounded(b.Text,250,24)
    b:SetHitRectInsets(0,-250,0,0); b.Text:SetText(value)
    b:SetScript("OnClick",function() self.owner:Change(key,b:GetChecked()==true) end)
    self.checks[key]=b; self.controls[#self.controls+1]=b; return b
end
function O:Slider(parent,key,value,x,y,low,high,step)
    self:Label(parent,value,x,y,260,12)
    local b=self:Frame("Slider",parent,"UISliderTemplate")
    b:SetPoint("TOPLEFT",x,y-25); b:SetSize(180,16); b:SetOrientation("HORIZONTAL")
    b:SetMinMaxValues(low,high); b:SetValueStep(step); b:SetObeyStepOnDrag(true)
    local e=self:Frame("EditBox",parent,"InputBoxTemplate")
    self.texts[#self.texts+1]={object=e,size=12}
    e:SetPoint("TOPLEFT",x+202,y-20); e:SetSize(58,22); U:Font(e,12)
    e:SetTextInsets(6,6,0,0); e:SetAutoFocus(false); e:SetMaxLetters(48)
    self.edits[key]=e; b.edit=e
    b:SetScript("OnValueChanged",function(_,v)
        if not self.refreshing then self.owner:Change(key,math.floor(v+.5)/100) end
    end)
    e:SetScript("OnEnterPressed",function()
        local v=tonumber(e:GetText()) or self.owner.profile[key]*100
        v=math.max(low,math.min(high,math.floor(v+.5))); e:ClearFocus()
        if not self.owner:Change(key,v/100) then self:Refresh() end
    end)
    e:SetScript("OnEscapePressed",function() e:ClearFocus(); self:Refresh() end)
    self:Label(parent,low.."-"..high.."%",x,y-47,260,11,muted)
    self.sliders[key]=b; self.controls[#self.controls+1]=b; self.controls[#self.controls+1]=e; return b
end
function O:Build(owner,f,parent)
    parent:SetAllPoints(f)
    f:SetSize(panelWidth,panelHeight); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    U:Dialog(f)
    f:EnableMouse(true); f:SetClampedToScreen(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() f:StartMoving() end); f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    self.menuFont=self.menuFont or CreateFont("QuestBriefMenuFont"); U:Font(self.menuFont,12)
    self:Label(parent,"QuestBrief",20,-15,560,16,gold)
    self.close=self:Frame("Button",parent,"UIPanelCloseButton")
    self.close:SetSize(24,24); self.close:SetPoint("TOPRIGHT",-8,-8); self.close:SetScript("OnClick",function() f:Hide() end)
    self:Section(parent,"Appearance",16,-58,288,330); self:Section(parent,"Behavior",316,-58,288,330)
    self:Check(parent,"accents","Quest colors",28,-82)
    self:Check(parent,"dialogTint","Quest dialog tint",28,-110)
    self:Check(parent,"rewards","Reward details",28,-138)
    self:Label(parent,"Preview layout",28,-179,260,12)
    self.layout=self:Dropdown(parent,28,-201,260,{
        {value="tooltip",label="Game tooltip"},{value="inspector",label="Compact inspector"}
    },function() return owner.profile.previewLayout end,function(value) owner:Change("previewLayout",value) end)
    self:Slider(parent,"scale","Preview and search scale",28,-248,80,120,5)
    self:Slider(parent,"strength","Tint strength",28,-319,10,100,5)
    self:Check(parent,"enabled","Enabled",328,-82)
    self:Label(parent,"Reveal key",328,-118,260,12)
    self.modifier=self:Dropdown(parent,328,-140,260,{
        {value="SHIFT",label="Shift"},{value="CTRL",label="Ctrl"},{value="ALT",label="Alt"},{value="NONE",label="None"}
    },function() return owner.profile.modifier end,function(value) owner:Change("modifier",value) end)
    self.hint=self:Label(parent,"Release to inspect. Escape closes.",328,-174,260,11,muted)
    self:Label(parent,"Inspection position",328,-201,260,12)
    self.position=self:Dropdown(parent,328,-223,260,{
        {value="right",label="Right of cursor"},{value="tooltip",label="Beside game tooltip"}
    },function() return owner.profile.inspectionPosition end,function(value) owner:Change("inspectionPosition",value) end)
    self:Check(parent,"npc","NPC previews",328,-277)
    self:Check(parent,"worldmap","World map previews",328,-305)
    self:Check(parent,"minimap","Minimap previews",328,-333)
    self:Check(parent,"launcher","Minimap launcher",328,-361)
    self.reset=self:Button(parent,"Reset",20,-416,86,function() owner:Defaults() end)
    self.status=self:Label(parent,"",116,-416,484,11,muted)
    f:SetScript("OnShow",function() self:Refresh() end)
    f:SetScript("OnHide",function()
        self:CloseMenu(); for _,e in pairs(self.edits) do e:ClearFocus() end; f:StopMovingOrSizing()
    end)
    f:RegisterEvent("UI_SCALE_CHANGED"); f:RegisterEvent("DISPLAY_SIZE_CHANGED"); f:SetScript("OnEvent",function() self:Refresh() end)
end
function O:Create(owner)
    if self.frame then return end
    self.owner=owner; self.texts={}; self.controls={}; self.checks={}; self.sliders={}; self.edits={}; self.dropdowns={}; self.sections={}
    -- Publish only complete controls. A failed construction leaves a hidden
    -- shell that the next slash invocation can reuse, never a cached blank UI.
    local f=self.shell or CreateFrame("Frame","QuestBriefOptions",UIParent,"BackdropTemplate"); self.shell=f; f:Hide()
    local parent=self.content or CreateFrame("Frame",nil,f); self.content=parent
    self.framePool,self.textPool=self.framePool or {},self.textPool or {}
    self.frameSlot,self.textSlot=0,0
    parent:Show()
    local ok,err=pcall(self.Build,self,owner,f,parent)
    if not ok then
        parent:Hide(); f:Hide(); f:UnregisterAllEvents(); self:CloseMenu()
        f:SetScript("OnShow",nil); f:SetScript("OnEvent",nil)
        for _,entry in ipairs(self.texts) do
            if U.fontSizes then U.fontSizes[entry.object]=nil end
            if U.fontApplications then U.fontApplications[entry.object]=nil end
        end
        if U.fontSizes and self.menuFont then U.fontSizes[self.menuFont]=nil end
        if U.fontApplications and self.menuFont then U.fontApplications[self.menuFont]=nil end
        self.texts={}; self.controls={}; self.checks={}; self.sliders={}; self.edits={}; self.dropdowns={}; self.sections={}
        self.status=nil; self.modifier=nil; self.close=nil; self.reset=nil
        error(err,0)
    end
    self.frame=f; self.content=parent
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"QuestBriefOptions")
end
function O:RefreshFonts(regenerate)
    if not self.frame then return end
    local oldPath,oldSize,oldFlags=self.menuFont:GetFont(); U:Font(self.menuFont,12)
    for _,entry in ipairs(self.texts) do U:Font(entry.object,entry.size) end
    U:RefreshFonts()
    local path,size,flags=self.menuFont:GetFont()
    if regenerate or path~=oldPath or size~=oldSize or flags~=oldFlags then
        for _,d in ipairs(self.dropdowns) do d:GenerateMenu() end
    end
    for _,entry in ipairs(self.texts) do fitBounded(entry.object) end
end
function O:Refresh()
    if not self.frame then return end
    self.refreshing=true; local p=self.owner.profile
    self.frame:SetScale(math.max(.3,math.min(1,(UIParent:GetWidth()-24)/panelWidth,(UIParent:GetHeight()-24)/panelHeight)))
    for key,b in pairs(self.checks) do b.Text:SetText(b.caption); b:SetChecked(p[key]) end
    for key,b in pairs(self.sliders) do b:SetValue(p[key]*100); b.edit:SetText(tostring(math.floor(p[key]*100+.5))) end
    for _,b in ipairs(self.controls) do if self.owner.readOnly then b:Disable() else b:Enable() end end
    self.status:SetText(self.owner.readOnly and "Newer settings are read-only." or not self.owner.supported and "Unsupported client." or "")
    self.hint:SetText(p.modifier~="NONE" and p.previewLayout=="tooltip" and "Release to inspect. Escape closes." or "Escape closes the preview.")
    self:RefreshFonts(true); self.refreshing=false
end
function O:Toggle(owner)
    if not self.frame then self:Create(owner) end
    self.frame:SetShown(not self.frame:IsShown())
end

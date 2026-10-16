local _, N = ...
local O = {}; N.Options = O
local U, M = N.UI, N.Model
local gold, ink, muted = {1,.82,.2}, {.93,.94,.97}, {.7,.7,.72}
local panelWidth,panelHeight,bodyWidth,bodyHeight=620,690,572,600
local rowStep,sectionGap,labelGap=28,24,20
local backdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=10,insets={left=2,right=2,top=2,bottom=2}}

-- Reuse current XPIsland's bounded native controls and scale-aware text fitting.
local function bounded(text,width,height)
    text.qOptionsWidth,text.qOptionsHeight=width,height; text:SetWordWrap(false)
end
local function fitBounded(text)
    if not text.qOptionsWidth then return end
    text:SetScale(1)
    if text.qNoFit then text:SetSize(text.qOptionsWidth,text.qOptionsHeight);return end
    local width,height=U:Measure(text); text.qNaturalWidth=width
    local available=math.min(text.qOptionsWidth,width*text.qOptionsHeight/math.max(1,height))
    local scale=U:FitText(text,available)
    text:SetSize(text.qOptionsWidth/scale,text.qOptionsHeight/scale)
    if text.qOptionsAnchor then U:AnchorText(text,unpack(text.qOptionsAnchor)) end
end
function O:FontCaption(object)
    if self.formattingFont or not self.fontMeasure then return end
    local value=self.owner.profile.font;local caption=value
    for _,entry in ipairs(U:FontEntries()) do if entry.value==value then caption=entry.label;break end end
    local path,size,flags=object:GetFont()
    local key=caption..":"..tostring(path)..":"..tostring(size)..":"..tostring(flags)..":"..object:GetEffectiveScale()
    if self.fontCaptionKey==key and object:GetText()==self.fontCaption then return end
    self.formattingFont=true
    local label=caption;local available=object.qOptionsWidth
    self.fontMeasure:SetText(label)
    local width=U:Measure(self.fontMeasure)
    if width>available then
        repeat
            local last=#label
            while last>1 and label:byte(last)>=128 and label:byte(last)<192 do last=last-1 end
            label=label:sub(1,last-1)
            self.fontMeasure:SetText(label.."...");width=U:Measure(self.fontMeasure)
        until width<=available or label==""
        label=label.."..."
    end
    self.fontCaptionKey,self.fontCaption=key,label
    if object:GetText()~=label then object:SetText(label) end
    self.formattingFont=nil
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
        for _,entry in ipairs(type(entries)=="function" and entries() or entries) do
            local row=root:CreateRadio(entry.label,function(value) return get()==value end,choose,entry.value)
            row:AddInitializer(function(button)
                -- Native compositor text accepts an owned Font object, not SetFont.
                button.fontString:SetFontObject(self.menuFont)
            end)
        end
    end)
    d.qEntries,d.qGet=entries,get
    self.dropdowns[#self.dropdowns+1]=d; self.controls[#self.controls+1]=d; return d
end
function O:CloseMenu()
    for _,d in ipairs(self.dropdowns or {}) do d:CloseMenu() end
end
function O:Check(parent,key,value,x,y,searchDefault)
    local b=self:Frame("CheckButton",parent,"UICheckButtonTemplate")
    b:SetPoint("TOPLEFT",x-4,y); b:SetSize(24,24); b.key,b.caption=key,value; b.text=b.Text
    self.texts[#self.texts+1]={object=b.Text,size=12}; U:Font(b.Text,12)
    b.Text:SetJustifyH("LEFT"); b.Text:SetTextColor(unpack(ink)); bounded(b.Text,240,24)
    b:SetHitRectInsets(0,-240,0,0); b.Text:SetText(value)
    b.searchDefault=searchDefault
    b:SetScript("OnClick",function()
        if searchDefault then self.owner:ChangeSearchDefault(key,b:GetChecked()==true) else self.owner:Change(key,b:GetChecked()==true) end
    end)
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
-- Scrolling keeps the shell, reset and status fixed, and never commits an
-- unfinished numeric edit. The same native vertical control is used by Search.
function O:Scroll(value,layout)
    if not M.Number(value) then return end
    local offset=math.max(0,math.min(self.maximum or 0,value))
    local changed=offset~=(self.offset or 0)
    self.offset=offset;self.scrolling=true
    self.scroll:SetVerticalScroll(offset);self.bar:SetValue(offset);self.scrolling=nil
    if changed and not layout then
        self:CloseMenu();for _,e in pairs(self.edits) do e:ClearFocus() end
        self:Refresh()
    end
end
function O:Layout()
    local scale=math.min(1,math.max(.1,(UIParent:GetWidth()-24)/panelWidth))
    local height=math.max(100,math.min(panelHeight,(UIParent:GetHeight()-24)/scale))
    local key=scale..":"..height..":"..UIParent:GetEffectiveScale()
    if self.layoutKey and self.layoutKey~=key then
        self:CloseMenu();for _,e in pairs(self.edits) do e:ClearFocus() end
    end
    self.layoutKey=key
    self.frame:SetScale(scale);self.frame:SetHeight(height)
    local viewport=height-90
    self.scroll:SetSize(bodyWidth,viewport);self.body:SetSize(bodyWidth,bodyHeight)
    self.bar:SetHeight(math.max(22,viewport-4))
    self.maximum=math.max(0,bodyHeight-viewport)
    self.scrolling=true;self.bar:SetMinMaxValues(0,self.maximum);self.bar:SetShown(self.maximum>0);self.scrolling=nil
    self:Scroll(self.offset or 0,true)
end
function O:SearchNumber(parent,key,label,x,y)
    -- Short numeric rows keep their field near the label, centered in the same
    -- 24px row as the native checkboxes rather than at the slider value column.
    local caption=self:Label(parent,label,x,y,108,12);bounded(caption,108,24)
    local e=self:Frame("EditBox",parent,"InputBoxTemplate")
    e:SetPoint("TOPLEFT",x+120,y-1);e:SetSize(58,22);e:SetTextInsets(6,6,0,0);e:SetAutoFocus(false);e:SetMaxLetters(8);U:Font(e,12)
    self.texts[#self.texts+1]={object=e,size=12};self.edits[key]=e;self.controls[#self.controls+1]=e
    e.searchDefault=key
    e:SetScript("OnEnterPressed",function()
        local value=tonumber(e:GetText())
        if not M.Number(value) then value=self.owner.profile.searchDefaults[key] end
        e:ClearFocus();if not self.owner:ChangeSearchDefault(key,value) then self:Refresh() end
    end)
    e:SetScript("OnEscapePressed",function()e:ClearFocus();self:Refresh()end)
end
function O:Build(owner,f,parent)
    parent:SetAllPoints(f)
    f:SetSize(panelWidth,panelHeight); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    U:Dialog(f)
    f:EnableMouse(true); f:SetClampedToScreen(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() f:StartMoving() end); f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    self.menuFont=self.menuFont or CreateFont("FindAnUpgradeMenuFont"); U:Font(self.menuFont,12)
    self:Label(parent,"FindAnUpgrade",20,-15,560,16,gold)
    self.close=self:Frame("Button",parent,"UIPanelCloseButton")
    self.close:SetSize(24,24); self.close:SetPoint("TOPRIGHT",-8,-8); self.close:SetScript("OnClick",function() f:Hide() end)
    local scroll=self:Frame("ScrollFrame",parent);self.scroll=scroll
    scroll:SetPoint("TOPLEFT",16,-46);scroll:SetSize(bodyWidth,bodyHeight)
    scroll:EnableMouse(true);scroll:EnableMouseWheel(true)
    local page=self:Frame("Frame",scroll);self.body=page;page:SetSize(bodyWidth,bodyHeight);scroll:SetScrollChild(page)
    self.bar=self:Frame("Slider",parent,"BackdropTemplate");U:VerticalBar(parent,self.bar)
    self.bar:SetPoint("TOPRIGHT",-14,-48);self.bar:SetHeight(bodyHeight-4);self.bar:SetValueStep(1)
    self.bar:SetScript("OnValueChanged",function(_,value)if not self.scrolling then self:Scroll(value)end end)
    scroll:SetScript("OnMouseWheel",function(_,delta)if M.Number(delta)then self:Scroll((self.offset or 0)-delta*40)end end)
    local secondaryY=-212-sectionGap;local searchY=secondaryY-132-sectionGap
    self:Section(page,"Appearance",0,0,280,212);self:Section(page,"Inspection",292,0,280,212)
    self:Section(page,"Quest previews",0,secondaryY,280,248);self:Section(page,"Surfaces",292,secondaryY,280,132)
    self:Section(page,"Search defaults",292,searchY,280,188)
    self:Label(page,"Font",12,-25,260,12)
    self.font=self:Dropdown(page,12,-25-labelGap,260,function()return U:FontEntries()end,function()return owner.profile.font end,function(value)owner:Change("font",value)end)
    self.font.Text.qNoFit=true
    self.fontMeasure=self:Text(parent);U:Font(self.fontMeasure,12);self.fontMeasure:SetWordWrap(false);self.fontMeasure:Hide()
    self.texts[#self.texts+1]={object=self.fontMeasure,size=12}
    if not self.font.qCaptionHooked then
        hooksecurefunc(self.font.Text,"SetText",function(object)self:FontCaption(object)end);self.font.qCaptionHooked=true
    end
    self:Label(page,"Border",12,-83,260,12)
    self.border=self:Dropdown(page,12,-83-labelGap,260,{
        {value="default",label="Default"},{value="none",label="None"},{value="tooltip",label="Tooltip"},{value="dialog",label="Dialog"},{value="thin",label="Thin"}
    },function()return owner.profile.border end,function(value)owner:Change("border",value)end)
    self:Slider(page,"scale","Preview and search scale",12,-142,80,120,5)
    self:Check(page,"accents","Quest colors",12,secondaryY-25)
    self:Check(page,"dialogTint","Quest dialog tint",12,secondaryY-25-rowStep)
    self:Check(page,"rewards","Reward details",12,secondaryY-25-rowStep*2)
    self:Label(page,"Preview layout",12,secondaryY-117,260,12)
    self.layout=self:Dropdown(page,12,secondaryY-117-labelGap,260,{
        {value="tooltip",label="Game tooltip"},{value="inspector",label="Compact inspector"}
    },function() return owner.profile.previewLayout end,function(value) owner:Change("previewLayout",value) end)
    self:Slider(page,"strength","Tint strength",12,secondaryY-177,10,100,5)
    self:Check(page,"enabled","Enabled",304,-25)
    self:Label(page,"Reveal key",304,-65,260,12)
    self.modifier=self:Dropdown(page,304,-65-labelGap,260,{
        {value="SHIFT",label="Shift"},{value="CTRL",label="Ctrl"},{value="ALT",label="Alt"},{value="NONE",label="None"}
    },function() return owner.profile.modifier end,function(value) owner:Change("modifier",value) end)
    self.hint=self:Label(page,"Release to inspect. Escape closes.",304,-115,260,11,muted)
    self:Label(page,"Inspection position",304,-147,260,12)
    self.position=self:Dropdown(page,304,-147-labelGap,260,{
        {value="right",label="Right of cursor"},{value="tooltip",label="Beside game tooltip"}
    },function() return owner.profile.inspectionPosition end,function(value) owner:Change("inspectionPosition",value) end)
    self:Check(page,"npc","NPC previews",304,secondaryY-25)
    self:Check(page,"worldmap","World map previews",304,secondaryY-25-rowStep)
    self:Check(page,"minimap","Minimap previews",304,secondaryY-25-rowStep*2)
    self:Check(page,"launcher","Minimap launcher",304,secondaryY-25-rowStep*3)
    self:Check(page,"hideUnusable","Hide unusable",304,searchY-25,true)
    self:Check(page,"includeDungeons","Include dungeon quests",304,searchY-25-rowStep,true)
    self:SearchNumber(page,"levelsBelow","Levels below",304,searchY-25-rowStep*2)
    self:SearchNumber(page,"levelsAbove","Levels above",304,searchY-25-rowStep*3)
    self:Label(page,"Applies next time search opens.",304,searchY-145,260,11,muted)
    self:Label(page,"Starts in the current zone.",304,searchY-165,260,11,muted)
    self.reset=self:Button(parent,"Reset",0,0,86,function() owner:Defaults() end)
    self.reset:ClearAllPoints();self.reset:SetPoint("BOTTOMLEFT",20,16)
    self.status=self:Label(parent,"",0,0,484,11,muted)
    self.status:ClearAllPoints();self.status:SetPoint("BOTTOMLEFT",116,16)
    f:SetScript("OnShow",function() self:Refresh() end)
    f:SetScript("OnHide",function()
        self:CloseMenu(); for _,e in pairs(self.edits) do e:ClearFocus() end; f:StopMovingOrSizing();f:SetScript("OnUpdate",nil);self.menuWaiting=nil
    end)
    f:RegisterEvent("UI_SCALE_CHANGED"); f:RegisterEvent("DISPLAY_SIZE_CHANGED"); f:SetScript("OnEvent",function() self:Refresh() end)
end
function O:Create(owner)
    if self.frame then return end
    self.owner=owner; self.texts={}; self.controls={}; self.checks={}; self.sliders={}; self.edits={}; self.dropdowns={}; self.sections={}
    -- Publish only complete controls. A failed construction leaves a hidden
    -- shell that the next slash invocation can reuse, never a cached blank UI.
    local f=self.shell or CreateFrame("Frame","FindAnUpgradeOptions",UIParent,"BackdropTemplate"); self.shell=f; f:Hide()
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
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"FindAnUpgradeOptions")
end
function O:FlushMenus()
    local pending=false
    for _,d in ipairs(self.dropdowns) do
        if d.qMenuKey~=d.qWantedMenuKey then
            local open=type(d.IsMenuOpen)=="function" and d:IsMenuOpen() or d.menuOpen==true
            if open then pending=true else d:GenerateMenu();d.qMenuKey=d.qWantedMenuKey end
        end
    end
    if pending and self.frame:IsShown() and not self.menuWaiting then
        self.menuWaiting=true
        self.frame:SetScript("OnUpdate",function()
            if self:FlushMenus() then self.menuWaiting=nil;self.frame:SetScript("OnUpdate",nil);self:RefreshFonts() end
        end)
    end
    return not pending
end
function O:SyncMenus()
    local path,size,flags=self.menuFont:GetFont()
    local font=tostring(path)..":"..tostring(size)..":"..tostring(flags)
    for _,d in ipairs(self.dropdowns) do
        local entries=type(d.qEntries)=="function" and d.qEntries() or d.qEntries
        d.qWantedMenuKey=font..":"..tostring(d.qGet())..":"..tostring(entries)
    end
    return self:FlushMenus()
end
function O:RefreshFonts(regenerate)
    if not self.frame then return end
    local oldPath,oldSize,oldFlags=self.menuFont:GetFont(); U:Font(self.menuFont,12)
    for _,entry in ipairs(self.texts) do U:Font(entry.object,entry.size) end
    U:RefreshFonts()
    local path,size,flags=self.menuFont:GetFont()
    if regenerate or path~=oldPath or size~=oldSize or flags~=oldFlags then
        self:SyncMenus()
    end
    self:FontCaption(self.font.Text)
    for _,entry in ipairs(self.texts) do fitBounded(entry.object) end
end
function O:Refresh()
    if not self.frame then return end
    self.refreshing=true; local p=self.owner.profile
    self:Layout()
    for key,b in pairs(self.checks) do b.Text:SetText(b.caption); b:SetChecked(b.searchDefault and p.searchDefaults[key] or not b.searchDefault and p[key]) end
    for key,b in pairs(self.sliders) do b:SetValue(p[key]*100); b.edit:SetText(tostring(math.floor(p[key]*100+.5))) end
    for key,e in pairs(self.edits) do if e.searchDefault then e:SetText(tostring(p.searchDefaults[key])) end end
    for _,b in ipairs(self.controls) do if self.owner.readOnly and not b.navigation then b:Disable() else b:Enable() end end
    self.status:SetText(self.owner.readOnly and "Newer settings are read-only." or not self.owner.supported and "Unsupported client." or "")
    self.hint:SetText(p.modifier~="NONE" and p.previewLayout=="tooltip" and "Release to inspect. Escape closes." or "Escape closes the preview.")
    self:RefreshFonts(); self:SyncMenus(); self.refreshing=false
end
function O:Toggle(owner)
    if N.Copy then N.Copy:Hide() end
    if N.Search and N.Search.frame then N.Search:CloseMenu();N.Search.inspector:ClearItem() end
    if not self.frame then self:Create(owner) end
    self.frame:SetShown(not self.frame:IsShown())
end

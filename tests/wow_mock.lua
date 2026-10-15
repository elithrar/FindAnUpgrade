local W = {frames = {}, writes = 0, nativeMutations = 0, hooks = {}, messages = {}, interface = 16001, combat = false, quest = 0, contrast = false}
local Methods = {}
local function layout(self)
    if self.native then W.nativeMutations = W.nativeMutations + 1; error("addon modified native frame layout/visibility") end
end
function Methods:IsForbidden() return self.forbidden == true end
function Methods:IsShown() return self.shown end
function Methods:SetParent(parent) self.parent=parent end
function Methods:HasFocus() return self.focused==true end
function Methods:GetVertexColor() if self.colorSecret then return W.secret, 1, 1, 1 end; return unpack(self.color or {1,1,1,1}) end
function Methods:SetVertexColor(r,g,b,a) if self.failWrite then error("blocked region") end; W.writes = W.writes + 1; self.color = {r,g,b,a} end
function Methods:HookScript(name, fn) if W.combat and self.native then error("hook in combat") end; self.hooks[name] = self.hooks[name] or {}; table.insert(self.hooks[name], fn) end
function Methods:SetScript(name, fn) if self.native then error("native script replaced") end; self.scripts[name] = fn end
function Methods:GetScript(name) return self.scripts[name] end
function Methods:Fire(name, ...) if self.scripts[name] then self.scripts[name](self, ...) end; for _, fn in ipairs(self.hooks[name] or {}) do fn(self, ...) end end
function Methods:Show() layout(self); if not self.shown then self.shown = true; self:Fire("OnShow") end end
function Methods:Hide() layout(self); if self.shown then self.shown = false; self:Fire("OnHide") end end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:RegisterEvent(e) self.events[e] = true end
function Methods:UnregisterAllEvents() self.events={} end
function Methods:SetPoint(...)
    layout(self); self.point = {...}; self.points=self.points or {}; self.points[self.point[1]]=self.point
end
function Methods:SetSize(w,h) layout(self); self.width = w; self.height = h end
function Methods:SetHeight(h) layout(self); self.height = h end
function Methods:ClearAllPoints() layout(self); self.point=nil; self.points={} end
function Methods:GetNumPoints()local n=0;for _ in pairs(self.points or {})do n=n+1 end;return n end
function Methods:SetAllPoints(relative)
    layout(self); self:ClearAllPoints(); relative=relative or self.parent
    if relative then self:SetPoint("TOPLEFT",relative,"TOPLEFT",0,0); self:SetPoint("BOTTOMRIGHT",relative,"BOTTOMRIGHT",0,0) end
end
function Methods:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
function Methods:GetRect() if self.rectSecret then return W.secret,0,10,10 end; return self.x or 0,self.y or 0,self:GetWidth(),self:GetHeight() end
function Methods:GetLeft()local x=self:GetRect();return x end
function Methods:GetRight()local x,_,w=self:GetRect();return x+w end
function Methods:GetAnchorType()return self.anchor end
function Methods:SetAnchorType(anchor)self.anchor=anchor end
-- Font-dependent approximate logical extents. These are fixture measurements,
-- not native glyph metrics or proof of in-game pixel layout.
local function visibleText(object)
    return tostring(object.text or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        :gsub('|H.-|h(.-)|h','%1'):gsub('|T.-|t','M'):gsub('|A.-|a','M')
end
local function glyphCount(value) return #(value:gsub('[\128-\191]','')) end
function Methods:GetStringWidth()
    local text=visibleText(self); if text=='' then return 0 end
    local _,size=self:GetFont(); local width=0
    for line in (text..'\n'):gmatch('(.-)\n') do width=math.max(width,glyphCount(line)*(size or 12)*.5) end
    return width
end
function Methods:GetUnboundedStringWidth() return self:GetStringWidth() end
function Methods:GetStringHeight()
    local text=visibleText(self); if text=='' then return 0 end
    local _,size=self:GetFont(); size=math.max(1,math.ceil(size or 12)); local lines=0
    for line in (text..'\n'):gmatch('(.-)\n') do
        local wraps=self.wordWrap~=false and math.ceil(glyphCount(line)*size*.5/math.max(1,self:GetWidth())) or 1
        lines=lines+math.max(1,wraps)
    end
    return lines*size
end
function Methods:SetWordWrap(value) self.wordWrap=value end
function Methods:SetScrollChild(child) self.scrollChild=child end
function Methods:SetVerticalScroll(value) self.scrollValue=value end
function Methods:GetVerticalScroll() return self.scrollValue or 0 end
function Methods:CreateTexture() local texture=W.Object(); texture.parent=self; return texture end
function Methods:SetOwner(owner,anchor) self.owner=owner; self.anchor=anchor end
function Methods:GetOwner() return self.owner end
function Methods:ClearLines() self.lines={}; self:Fire("OnTooltipCleared") end
function Methods:NumLines() return #(self.lines or {}) end
function Methods:GetThumbTexture() return self.thumb end
function Methods:SetThumbTexture(value) self.thumb=self.thumb or W.Object();self.thumb:SetTexture(value) end
function Methods:SetWidth(w) layout(self); self.width = w end
function Methods:GetWidth() return self.width or 1920 end
function Methods:GetHeight() return self.height or 1080 end
function Methods:SetScale(s) layout(self); self.scale = s end
function Methods:GetScale() return self.scale or 1 end
function Methods:GetFrameLevel() return self.frameLevel or (self.parent and self.parent:GetFrameLevel()+1) or 1 end
function Methods:SetFrameLevel(value) layout(self); self.frameLevel=value end
function Methods:SetFont(path,size,flags) self.fontWrites = (self.fontWrites or 0) + 1; if W.missingFont == path then return false end; self.font = {path,size * .999,flags}; return true end
function Methods:GetFont()
    if self.font then return unpack(self.font) end
    if self.fontObject and type(self.fontObject.GetFont)=="function" then return self.fontObject:GetFont() end
    if self.isFontString then return nil,0,"" end
    return "Fonts\\FRIZQT__.TTF",12,""
end
function Methods:SetFontObject(font) self.fontObject = font; self.font=nil end
function Methods:SetText(t)
    if self.isFontString and not self:GetFont() then error("FontString:SetText(): Font not set",2) end
    self.text = t
end
function Methods:GetText() return self.text or "" end
function Methods:GetCenter() return self.x or 200,self.y or 200 end
function Methods:SetDefaultText(value) self.defaultText=value end
function Methods:SetupMenu(fn) self.menuGenerator=fn end
function Methods:GenerateMenu()
    self.menuGenerations=(self.menuGenerations or 0)+1
    local root={entries={}}
    function root:SetScrollMode(height) self.scrollHeight=height end
    function root:AddMenuReleasedCallback(fn)self.release=fn end
    function root:CreateTitle(label)self.titles=self.titles or {};self.titles[#self.titles+1]=label;return {}end
    function root:CreateRadio(label,checked,choose,value)
        local row={label=label,checked=function() return checked(value) end,callback=function() choose(value) end,value=value}
        function row:AddInitializer(fn)
            local font=W.Object(); font.isFontString=true
            setmetatable(font,{__index=function(_,key)
                if key=='SetFont' then error('compositor font setter lookup') end
                return Methods[key]
            end})
            fn({fontString=font}); self.fontObject=font.fontObject
        end
        function row:SetEnabled(value)self.enabled=value end
        self.entries[#self.entries+1]=row; return row
    end
    self.menuGenerator(self,root); self.menu=root
    for _,row in ipairs(root.entries) do if self.Text and row.checked() then self.Text:SetText(row.label) end end
    return root
end
function Methods:CloseMenu() self.menuOpen=false; self.menuClosures=(self.menuClosures or 0)+1 end
function Methods:SetFocus() self.focused=true end
function Methods:ClearFocus() self.focused=false end
function Methods:Disable() self.disabled=true end
function Methods:Enable() self.disabled=false end
function Methods:SetJustifyH(value) self.justifyH=value end
function Methods:SetJustifyV(value) self.justifyV=value end
function Methods:AddLine(value) self.lines=self.lines or {}; table.insert(self.lines,value) end
function Methods:SetTextColor(...) self.textColor = {...} end
function Methods:SetChecked(v) self.checked = v end
function Methods:GetChecked() return self.checked end
function Methods:SetValue(v) self.value = v; self:Fire("OnValueChanged", v) end
function Methods:SetBackdropColor(...) self.backdropColor = {...} end
function Methods:SetBackdropBorderColor(...) self.border = {...} end
function Methods:SetBackdrop(v) self.backdrop = v end
function Methods:GetBackdrop() return self.backdrop end
function Methods:GetBackdropColor() return unpack(self.backdropColor or {0,0,0,0}) end
function Methods:GetBackdropBorderColor() return unpack(self.border or {0,0,0,0}) end
function Methods:CreateFontString(name,layer,template)
    local f=W.Object(); f.isFontString=true; f.parent=self; f.name=name; f.layer=layer; f.template=template
    if template and _G[template] then f:SetFontObject(_G[template]) end
    W.fontStrings[#W.fontStrings+1]=f
    return f
end
function Methods:SetAtlas(atlas) self.atlas = atlas end
function Methods:SetRotation(value) self.rotation=value end
function Methods:SetTexture(tex) self.texture = tex end
function Methods:SetColorTexture(...) self.colorTexture={...} end
function Methods:SetNormalTexture(value)self.normalTexture=value end
function Methods:GetNormalTexture()return self.normalTexture end
function Methods:SetPushedTexture(value)self.pushedTexture=value end
function Methods:GetPushedTexture()return self.pushedTexture end
function Methods:SetHighlightTexture(value)self.highlightTexture=value end
function Methods:GetHighlightTexture()return self.highlightTexture end
function Methods:SetBlendMode(value)self.blendMode=value end
function Methods:SetResizeBounds(...)self.resizeBounds={...}end
function Methods:SetHitRectInsets(...)self.hitInsets={...}end
function Methods:SetTextInsets(...)self.textInsets={...}end
for _,name in ipairs({"SetShadowColor","SetShadowOffset","SetFrameStrata","SetClampedToScreen","EnableMouse","EnableMouseWheel","SetMovable","RegisterForDrag","RegisterForClicks","StartMoving","StartSizing","StopMovingOrSizing","SetResizable","SetAutoFocus","SetNumeric","SetMaxLetters","HighlightText","SetTexCoord","SetOrientation","SetMinMaxValues","SetValueStep","SetObeyStepOnDrag","SetAlphaGradient"}) do Methods[name] = function() end end
-- Resolve declared anchors for layout assertions. Existing pointer fixtures
-- keep explicit rects; native pixel rounding and font metrics remain unmodeled.
local fractions={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
function W.Bounds(object,seen)
    seen=seen or {};assert(not seen[object],"cyclic anchor fixture");seen[object]=true
    local width=object.width or (object.isFontString and object:GetStringWidth()) or 0
    local height=object.height or (object.isFontString and object:GetStringHeight()) or 0
    local x,y=object.x,object.y;local anchors={}
    for name,p in pairs(object.points or {})do
        local relative,relativePoint,dx,dy
        if type(p[2])=="table" then relative=p[2];relativePoint=p[3];dx=p[4] or 0;dy=p[5] or 0
        else relative=object.parent;relativePoint=name;dx=p[2] or 0;dy=p[3] or 0 end
        local rx,ry,rw,rh=0,0,0,0
        if relative then rx,ry,rw,rh=W.Bounds(relative,seen)end
        local f=assert(fractions[relativePoint or name]);anchors[#anchors+1]={fractions[name],rx+rw*f[1]+dx,ry+rh*f[2]+dy}
    end
    for _,a in ipairs(anchors)do for _,b in ipairs(anchors)do
        if a[1][1]~=b[1][1]then width=(b[2]-a[2])/(b[1][1]-a[1][1])end
        if a[1][2]~=b[1][2]then height=(b[3]-a[3])/(b[1][2]-a[1][2])end
    end end
    if x==nil and anchors[1]then x=anchors[1][2]-width*anchors[1][1][1]end
    if y==nil and anchors[1]then y=anchors[1][3]-height*anchors[1][1][2]end
    seen[object]=nil;return x or 0,y or 0,width,height
end
function W.Object(native)
    return setmetatable({native = native, shown = true, scripts = {}, hooks = {}, events = {}}, {__index = Methods})
end
function W.Reset(config)
    config = config or {}; W.frames = {}; W.fontStrings={}; W.hooks = {}; W.writes = 0; W.nativeMutations = 0; W.messages = {}; W.quest = config.quest or 0
    W.interface = config.interface or 16001; W.combat = config.combat or false; W.contrast = false; W.secret = {}; W.missingFont = nil
    W.shift,W.ctrl,W.alt,W.time=false,false,false,0; W.mouseX,W.mouseY=700,700; W.guid=nil; W.npcGuid=nil
    W.playerGuid=config.playerGuid or "Player-1-00000001"
    GetTime=function() return W.time end
    GetCursorPosition=function() return W.mouseX,W.mouseY end
    IsShiftKeyDown=function() return W.shift end; IsControlKeyDown=function() return W.ctrl end; IsAltKeyDown=function() return W.alt end
    UnitGUID=function(unit)
        if unit=='player' then return W.playerGuid end
        return unit=='npc' and W.npcGuid or W.guid
    end
    EventRegistry={callbacks={}}
    function EventRegistry:RegisterCallback(event,fn,owner) self.callbacks[event]={fn=fn,owner=owner} end
    function EventRegistry:TriggerEvent(event,...) local e=self.callbacks[event]; if e then e.fn(e.owner,...) end end
    GameTooltip=nil
    WorldMapFrame=W.Object(); WorldMapFrame.width=1000; WorldMapFrame.height=1000
    QuestHubPinMixin=nil; QuestieLoader=nil; LibQuestieDB=nil; C_GossipInfo=nil
    W.rewardReady=true; W.items={}; W.choices={}; W.rewardRequests={}; W.metadataRequests={}
    HaveQuestRewardData=function() return W.rewardReady end
    GetNumQuestLogRewards=function() return #W.items end; GetNumQuestLogChoices=function() return #W.choices end
    GetQuestLogRewardInfo=function(i) return unpack(W.items[i] or {}) end
    GetQuestLogChoiceInfo=function(i) return unpack(W.choices[i] or {}) end
    GetQuestLogRewardMoney=function() return 12345 end; GetQuestLogRewardXP=function() return 450,400 end
    GetCoinTextureString=nil -- Current Forever uses the C_CurrencyInfo namespace.
    C_CurrencyInfo={GetCoinTextureString=function(value) return '|Tcoin:12|t'..value end}
    C_QuestLog={GetTitleForQuestID=function(id) return 'Quest '..id end, RequestLoadQuestByID=function(id) W.metadataRequests[id]=(W.metadataRequests[id] or 0)+1 end,GetQuestRewardCurrencies=function() return {} end,GetQuestRewardCurrencyInfo=function()end}
    C_TaskQuest={RequestPreloadRewardData=function(id) W.rewardRequests[id]=(W.rewardRequests[id] or 0)+1 end}
    ITEM_QUALITY_COLORS={[2]={r=.1,g=1,b=.1},[3]={r=.1,g=.3,b=1}}
    Mixin=function(object,mixin) for k,v in pairs(mixin) do object[k]=v end; return object end
    TooltipDataHandlerMixin={ProcessInfo=function(t,info) t.infoList={info}; t.data=info.tooltipData; t:Show(); return true end,ClearHandlerInfo=function(t) t.infoList=nil end,HasDataInstanceID=function(t,id) return t.data and t.data.dataInstanceID==id end}
    C_TooltipInfo={GetQuestLogItem=function(kind,index,id) W.tooltipRoute={kind,index,id}; local item=(kind=='choice' and W.choices or W.items)[index]; return item and {id=item[6],type=0,hyperlink='item:'..item[6],lines={},dataInstanceID=123} end}
    canaccessallvalues=function() return true end
    Enum={TooltipDataType={Item=0}}
    W.alwaysCompare=false; W.compareClick=nil
    GetCVarBool=function(name)return name=="alwaysCompareItems" and W.alwaysCompare or false end
    IsModifiedClick=function(action)return action=="COMPAREITEMS" and (W.compareClick==nil and W.shift or W.compareClick) or false end
    -- Matches the pinned native helper's automatic-manager guard.
    TooltipUtil={ShouldDoItemComparison=function(tooltip)return (not tooltip.suppressAutomaticCompareItem and GetCVarBool("alwaysCompareItems")) or IsModifiedClick("COMPAREITEMS") end}
    TooltipComparisonManager={Clear=function(manager,tip) assert(manager~=TooltipComparisonManager,'global comparison touched'); manager.clears=(manager.clears or 0)+1 end,CreateComparisonItem=function(_,data) return {hyperlink=data.hyperlink} end,CompareItem=function(manager) assert(manager~=TooltipComparisonManager,'global comparison touched'); manager.calls=(manager.calls or 0)+1 end}
    issecretvalue = function(value) return value == W.secret end
    GetBuildInfo = function() return "1.60.1", "70338", "2026-10-01", W.interface end
    InCombatLockdown = function() return W.combat end
    GetQuestID = function() return W.quest end
    UIParent = W.Object(); UIParent.width = 1920; UIParent.height = 1080
    Minimap=nil; C_Item=nil; ItemLocation=nil; GetInventorySlotInfo=nil; C_Map=nil; UiMapPoint=nil; C_SuperTrack=nil
    C_PaperDollInfo=nil;C_SpecializationInfo=nil;GetInventoryItemID=nil;GetInventoryItemLink=nil;GetInstanceInfo=nil
    UnitLevel=function() return 20 end; UnitClass=function() return "Warrior","WARRIOR",1 end; UnitRace=function() return "Human","Human",1 end; UnitFactionGroup=function() return "Alliance" end
    CreateFont=function() return W.Object() end
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"; GameFontNormal = W.Object(); GameFontNormal.font={STANDARD_TEXT_FONT,12,""}
    GameTooltipTextLeft2=nil; GameTooltipText=W.Object(); GameTooltipText.font={STANDARD_TEXT_FONT,12,""}
    GameTooltipHeaderText=W.Object(); GameTooltipHeaderText.font={STANDARD_TEXT_FONT,14,""}
    NumberFontNormalSmall=W.Object(); NumberFontNormalSmall.font={"Fonts\\ARIALN.TTF",12,"OUTLINE"}
    NORMAL_FONT_COLOR={r=1,g=.82,b=0,GetRGB=function(self)return self.r,self.g,self.b end}
    UISpecialFrames = {}; SlashCmdList = {}; LibStub = nil
    QuestTextContrast = {IsEnabled = function() return W.contrast end, GetDefaultBackgroundAtlas = function() return "QuestBG-Parchment" end}
    DEFAULT_CHAT_FRAME = {AddMessage = function(_, text) table.insert(W.messages, text) end}
    CreateFrame = function(kind,name,parent,template)
        local f = W.Object(); f.name = name; f.parent = parent; f.template = template
        if template == "SharedTooltipTemplate" then f.shown = false end
        if template == "TooltipBorderedFrameTemplate" then
            f.NineSlice=W.Object(); f.nativeTooltipArt=true
            f.backdropColor={.09,.09,.19,.8}; f.border={.6,.6,.6,1}
        end
        if template == "UISliderTemplate" then f.thumb=W.Object();f.thumb.width=32;f.thumb.height=32 end
        if kind == "CheckButton" or kind=="DropdownButton" and template then f.Text = f:CreateFontString(nil,"OVERLAY","GameFontNormal") end
        if kind=="DropdownButton" and template=="WowStyle1DropdownTemplate" then
            f.Background=W.Object(); f.Background.parent=f
            f.Background:SetPoint("TOPLEFT",f,"TOPLEFT",-9,8); f.Background:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",8,-9)
            f.Arrow=W.Object(); f.Arrow.parent=f; f.Arrow:SetSize(24,24); f.Arrow:SetPoint("RIGHT",f,"RIGHT",-1,0)
        end
        if template=="UICheckButtonTemplate"then f.Text:SetPoint("LEFT",f,"RIGHT",-2,0)end
        if template=="InputBoxTemplate"then
            for _,key in ipairs({"Left","Right","Middle"})do f[key]=W.Object();f[key].parent=f;f[key]:SetSize(key=="Middle" and 10 or 8,20)end
            f.Left:SetPoint("LEFT",f,"LEFT",-5,0); f.Right:SetPoint("RIGHT",f,"RIGHT",0,0)
            f.Middle:SetPoint("LEFT",f.Left,"RIGHT",0,0); f.Middle:SetPoint("RIGHT",f.Right,"LEFT",0,0)
        end
        table.insert(W.frames, f); if name then _G[name] = f end; return f
    end
    QuestFrame = W.Object(true); QuestFrame.shown = true
    QuestFrameDetailPanel = W.Object(true); QuestFrameDetailPanel.shown = false
    for _,key in ipairs({"Bg","MaterialTopLeft","MaterialTopRight","MaterialBotLeft","MaterialBotRight","SealMaterialBG"}) do QuestFrameDetailPanel[key] = W.Object(true) end
    for _,key in ipairs({"MaterialTopLeft","MaterialTopRight","MaterialBotLeft","MaterialBotRight","SealMaterialBG"}) do QuestFrameDetailPanel[key].shown = false end
    QuestDetailScrollChildFrame = W.Object(); QUEST_TEMPLATE_DETAIL = {}; QuestInfoDescriptionText = W.Object()
    QuestInfo_Display = function(template,parent) W.displayCalls = (W.displayCalls or 0) + 1; return "native-return", 123 end
    QuestFrameDetailPanel_OnShow = function() QuestInfo_Display(QUEST_TEMPLATE_DETAIL, QuestDetailScrollChildFrame) end
    QuestFrameDetailPanel.scripts.OnShow = QuestFrameDetailPanel_OnShow
    hooksecurefunc = function(name, fn, callback)
        if type(name)=='table' then local object,key=name,fn; local original=object[key]; assert(type(original)=='function'); object[key]=function(...) local results={original(...)}; callback(...); return unpack(results) end; return end
        W.hooks[name] = (W.hooks[name] or 0) + 1
        local original = _G[name]
        _G[name] = function(...) local results = {original(...)}; fn(...); return unpack(results) end
    end
    FindAnUpgradeCharacterDB = config.characterSaved
    FindAnUpgradeDB = config.saved
    QuestBriefDB = config.previous
    QuestTintDB = config.legacy
    local N = {}
    for _,file in ipairs({"Model.lua","Shortlist.lua","Data/Quests.lua","Data/Catalog.lua","Adapter.lua","Character.lua","UI.lua","Copy.lua","Rewards.lua","Providers.lua","Chains.lua","Questie.lua","Sources.lua","Stack.lua","NativeTooltip.lua","Hover.lua","QuestState.lua","Catalog.lua","Ranking.lua","SearchModel.lua","Search.lua","SearchViews.lua","Launcher.lua","Options.lua","Core.lua"}) do assert(loadfile(ROOT .. "/FindAnUpgrade/" .. file))("FindAnUpgrade", N) end
    W.N = N
    return N
end
function W.Event(event, ...)
    for _,frame in ipairs(W.frames) do if frame.events[event] then frame:Fire("OnEvent", event, ...) end end
end
function W.Init(config) local N = W.Reset(config); W.Event("ADDON_LOADED", "FindAnUpgrade"); return N end
function W.Offer(id)
    W.quest = id; QuestFrameDetailPanel.shown = true; QuestFrameDetailPanel:Fire("OnShow")
end
function W.Close()
    QuestFrameDetailPanel.shown = false; QuestFrameDetailPanel:Fire("OnHide")
end
return W

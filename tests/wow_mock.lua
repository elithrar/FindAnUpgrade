local W = {frames = {}, writes = 0, nativeMutations = 0, hooks = {}, messages = {}, interface = 16001, combat = false, quest = 0, contrast = false}
local Methods = {}
local function layout(self)
    if self.native then W.nativeMutations = W.nativeMutations + 1; error("addon modified native frame layout/visibility") end
end
function Methods:IsForbidden() return self.forbidden == true end
function Methods:IsShown() return self.shown end
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
function Methods:SetPoint(...) layout(self); self.point = {...} end
function Methods:SetSize(w,h) layout(self); self.width = w; self.height = h end
function Methods:SetHeight(h) layout(self); self.height = h end
function Methods:ClearAllPoints() layout(self); self.point=nil end
function Methods:SetAllPoints() layout(self) end
function Methods:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
function Methods:GetRect() if self.rectSecret then return W.secret,0,10,10 end; return self.x or 0,self.y or 0,self:GetWidth(),self:GetHeight() end
function Methods:GetLeft()local x=self:GetRect();return x end
function Methods:GetRight()local x,_,w=self:GetRect();return x+w end
function Methods:GetAnchorType()return self.anchor end
function Methods:SetAnchorType(anchor)self.anchor=anchor end
function Methods:GetStringHeight() return math.ceil(#(self.text or '') / math.max(1,math.floor(self:GetWidth()/6)))*14 end
function Methods:SetScrollChild(child) self.scrollChild=child end
function Methods:SetVerticalScroll(value) self.scrollValue=value end
function Methods:CreateTexture() return W.Object() end
function Methods:SetOwner(owner,anchor) self.owner=owner; self.anchor=anchor end
function Methods:GetOwner() return self.owner end
function Methods:ClearLines() self.lines={} end
function Methods:NumLines() return #(self.lines or {}) end
function Methods:GetThumbTexture() return self.thumb end
function Methods:SetWidth(w) layout(self); self.width = w end
function Methods:GetWidth() return self.width or 1920 end
function Methods:GetHeight() return self.height or 1080 end
function Methods:SetScale(s) layout(self); self.scale = s end
function Methods:SetFont(path,size,flags) self.fontWrites = (self.fontWrites or 0) + 1; if W.missingFont == path then return false end; self.font = {path,size * .999,flags}; return true end
function Methods:GetFont() return unpack(self.font or {"Fonts\\FRIZQT__.TTF",12,""}) end
function Methods:SetFontObject(font) self.fontObject = font end
function Methods:SetText(t) self.text = t end
function Methods:GetText() return self.text or "" end
function Methods:GetCenter() return self.x or 200,self.y or 200 end
function Methods:SetDefaultText(value) self.defaultText=value end
function Methods:SetupMenu(fn) self.menuGenerator=fn end
function Methods:AddLine(value) self.lines=self.lines or {}; table.insert(self.lines,value) end
function Methods:SetTextColor(...) self.textColor = {...} end
function Methods:SetChecked(v) self.checked = v end
function Methods:GetChecked() return self.checked end
function Methods:SetValue(v) self.value = v; self:Fire("OnValueChanged", v) end
function Methods:SetBackdropColor(...) self.backdropColor = {...} end
function Methods:SetBackdropBorderColor(...) self.border = {...} end
function Methods:SetBackdrop(v) self.backdrop = v end
function Methods:CreateFontString() return W.Object() end
function Methods:SetAtlas(atlas) self.atlas = atlas end
function Methods:SetTexture(tex) self.texture = tex end
for _,name in ipairs({"SetJustifyH","SetJustifyV","SetWordWrap","SetShadowColor","SetShadowOffset","SetFrameStrata","SetClampedToScreen","EnableMouse","EnableMouseWheel","SetMovable","RegisterForDrag","RegisterForClicks","StartMoving","StartSizing","StopMovingOrSizing","SetResizable","SetResizeBounds","SetAutoFocus","SetNumeric","SetMaxLetters","SetTextInsets","SetFocus","ClearFocus","HighlightText","SetTexCoord","SetHitRectInsets","SetOrientation","SetMinMaxValues","SetValueStep","SetObeyStepOnDrag","SetAlphaGradient","Disable","Enable"}) do Methods[name] = function() end end
function W.Object(native)
    return setmetatable({native = native, shown = true, scripts = {}, hooks = {}, events = {}}, {__index = Methods})
end
function W.Reset(config)
    config = config or {}; W.frames = {}; W.hooks = {}; W.writes = 0; W.nativeMutations = 0; W.messages = {}; W.quest = config.quest or 0
    W.interface = config.interface or 16001; W.combat = config.combat or false; W.contrast = false; W.secret = {}; W.missingFont = nil
    W.shift,W.ctrl,W.alt,W.time=false,false,false,0; W.mouseX,W.mouseY=700,700; W.guid=nil; W.npcGuid=nil
    GetTime=function() return W.time end
    GetCursorPosition=function() return W.mouseX,W.mouseY end
    IsShiftKeyDown=function() return W.shift end; IsControlKeyDown=function() return W.ctrl end; IsAltKeyDown=function() return W.alt end
    UnitGUID=function(unit) return unit=='npc' and W.npcGuid or W.guid end
    EventRegistry={callbacks={}}
    function EventRegistry:RegisterCallback(event,fn,owner) self.callbacks[event]={fn=fn,owner=owner} end
    function EventRegistry:TriggerEvent(event,...) local e=self.callbacks[event]; if e then e.fn(e.owner,...) end end
    WorldMapFrame=W.Object(); WorldMapFrame.width=1000; WorldMapFrame.height=1000
    QuestHubPinMixin=nil; QuestieLoader=nil; LibQuestieDB=nil; C_GossipInfo=nil
    W.rewardReady=true; W.items={}; W.choices={}; W.rewardRequests={}; W.metadataRequests={}
    HaveQuestRewardData=function() return W.rewardReady end
    GetNumQuestLogRewards=function() return #W.items end; GetNumQuestLogChoices=function() return #W.choices end
    GetQuestLogRewardInfo=function(i) return unpack(W.items[i] or {}) end
    GetQuestLogChoiceInfo=function(i) return unpack(W.choices[i] or {}) end
    GetQuestLogRewardMoney=function() return 12345 end; GetQuestLogRewardXP=function() return 450,400 end
    GetCoinTextureString=function(value) return value..' copper' end
    C_QuestLog={GetTitleForQuestID=function(id) return 'Quest '..id end, RequestLoadQuestByID=function(id) W.metadataRequests[id]=(W.metadataRequests[id] or 0)+1 end,GetQuestRewardCurrencies=function() return {} end,GetQuestRewardCurrencyInfo=function()end}
    C_TaskQuest={RequestPreloadRewardData=function(id) W.rewardRequests[id]=(W.rewardRequests[id] or 0)+1 end}
    ITEM_QUALITY_COLORS={[2]={r=.1,g=1,b=.1},[3]={r=.1,g=.3,b=1}}
    Mixin=function(object,mixin) for k,v in pairs(mixin) do object[k]=v end; return object end
    TooltipDataHandlerMixin={ProcessInfo=function(t,info) t.infoList={info}; t.data=info.tooltipData; t:Show(); return true end,ClearHandlerInfo=function(t) t.infoList=nil end,HasDataInstanceID=function(t,id) return t.data and t.data.dataInstanceID==id end}
    C_TooltipInfo={GetQuestLogItem=function(kind,index,id) W.tooltipRoute={kind,index,id}; local item=(kind=='choice' and W.choices or W.items)[index]; return item and {id=item[6],type=0,hyperlink='item:'..item[6],lines={},dataInstanceID=123} end}
    canaccessallvalues=function() return true end
    Enum={TooltipDataType={Item=0}}
    TooltipUtil={ShouldDoItemComparison=function() return W.shift end}
    TooltipComparisonManager={Clear=function(manager,tip) assert(manager~=TooltipComparisonManager,'global comparison touched'); manager.clears=(manager.clears or 0)+1 end,CreateComparisonItem=function(_,data) return {hyperlink=data.hyperlink} end,CompareItem=function(manager) assert(manager~=TooltipComparisonManager,'global comparison touched'); manager.calls=(manager.calls or 0)+1 end}
    issecretvalue = function(value) return value == W.secret end
    GetBuildInfo = function() return "1.60.1", "70338", "2026-10-01", W.interface end
    InCombatLockdown = function() return W.combat end
    GetQuestID = function() return W.quest end
    UIParent = W.Object(); UIParent.width = 1920; UIParent.height = 1080
    Minimap=nil; C_Item=nil; ItemLocation=nil; GetInventorySlotInfo=nil; C_Map=nil; UiMapPoint=nil; C_SuperTrack=nil
    UnitLevel=function() return 20 end; UnitClass=function() return "Warrior","WARRIOR",1 end; UnitRace=function() return "Human","Human",1 end; UnitFactionGroup=function() return "Alliance" end
    CreateFont=function() return W.Object() end
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"; GameFontNormal = {}; UISpecialFrames = {}; SlashCmdList = {}; LibStub = nil
    QuestTextContrast = {IsEnabled = function() return W.contrast end, GetDefaultBackgroundAtlas = function() return "QuestBG-Parchment" end}
    DEFAULT_CHAT_FRAME = {AddMessage = function(_, text) table.insert(W.messages, text) end}
    CreateFrame = function(kind,name,parent,template)
        local f = W.Object(); f.name = name; f.parent = parent; f.template = template
        if template == "SharedTooltipTemplate" then f.shown = false end
        if template == "UISliderTemplate" then f.thumb=W.Object();f.thumb.width=32;f.thumb.height=32 end
        if kind == "CheckButton" or kind=="DropdownButton" then f.Text = W.Object() end
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
    QuestBriefDB = config.saved
    QuestTintDB = config.legacy
    local N = {}
    for _,file in ipairs({"Model.lua","Data/Quests.lua","Data/Catalog.lua","Adapter.lua","UI.lua","Rewards.lua","Providers.lua","Questie.lua","Sources.lua","Stack.lua","Hover.lua","Catalog.lua","SearchModel.lua","Search.lua","Launcher.lua","Options.lua","Core.lua"}) do assert(loadfile(ROOT .. "/QuestBrief/" .. file))("QuestBrief", N) end
    W.N = N
    return N
end
function W.Event(event, ...)
    for _,frame in ipairs(W.frames) do if frame.events[event] then frame:Fire("OnEvent", event, ...) end end
end
function W.Init(config) local N = W.Reset(config); W.Event("ADDON_LOADED", "QuestBrief"); return N end
function W.Offer(id)
    W.quest = id; QuestFrameDetailPanel.shown = true; QuestFrameDetailPanel:Fire("OnShow")
end
function W.Close()
    QuestFrameDetailPanel.shown = false; QuestFrameDetailPanel:Fire("OnHide")
end
return W

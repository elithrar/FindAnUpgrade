local _, N = ...
local M, A = N.Model, N.Adapter
local U = { owned = {} }; N.UI = U

-- Shared with Options: the XPIsland-style tab uses an ordinary owned button,
-- native tooltip edge and one restrained selected underline.
function U:Tab(frame,label,width)
    frame:SetSize(width,22)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
    frame:SetBackdropColor(.06,.06,.065,.8);frame:SetBackdropBorderColor(.45,.45,.45,.65)
    if not frame.text then frame.text=frame:CreateFontString(nil,"OVERLAY","GameFontNormal") end
    self:Font(frame.text,12);frame.text:ClearAllPoints();frame.text:SetPoint("CENTER");frame.text:SetWidth(width-12);frame.text:SetHeight(20)
    frame.text:SetJustifyH("CENTER");frame.text:SetJustifyV("MIDDLE");frame.text:SetWordWrap(false);frame.text:SetTextColor(.93,.94,.97);frame.text:SetText(label)
    if not frame.activeLine then
        frame.activeLine=frame:CreateTexture(nil,"OVERLAY");frame.activeLine:SetHeight(1);frame.activeLine:SetColorTexture(1,.82,.2,.8)
        frame.activeLine:SetPoint("BOTTOMLEFT",4,0);frame.activeLine:SetPoint("BOTTOMRIGHT",-4,0)
    end
    frame:SetScript("OnEnter",function()frame:SetBackdropBorderColor(.9,.8,.5,.9)end)
    frame:SetScript("OnLeave",function()frame:SetBackdropBorderColor(.45,.45,.45,.65)end)
    return frame
end

-- Shared shell matches the installed XPIsland/ATCF dialog constructors.
function U:Dialog(frame)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=8,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    frame:SetBackdropColor(.045,.045,.05,.94); frame:SetBackdropBorderColor(.65,.65,.65,1)
end
local borderFiles={tooltip={"Interface\\Tooltips\\UI-Tooltip-Border",10},dialog={"Interface\\DialogFrame\\UI-DialogBox-Border",16},thin={"Interface\\Buttons\\WHITE8X8",1}}
local function rgba(frame,method)
    if type(method)~="function" then return end
    local ok,r,g,b,a=pcall(method,frame)
    if ok and M.Number(r) and M.Number(g) and M.Number(b) and M.Number(a) then return {r,g,b,a} end
end
function U:Border(frame,defaultKind)
    local preference=N.Core and N.Core.profile.border or "default"
    local selected=preference=="default" and defaultKind or preference
    -- TooltipBorderedFrameTemplate owns NineSlice art, not BackdropTemplate.
    -- Keep its center/background unchanged; only its edge becomes transparent.
    -- Explicit replacement edges reuse one owned edge-only backdrop.
    if frame.NineSlice then
        if preference=="default" then
            if frame.qNativeBorder then frame:SetBackdropBorderColor(unpack(frame.qNativeBorder));frame.qNativeBorder=nil end
            if frame.qBorderFrame then frame.qBorderFrame:Hide() end
            return frame
        end
        frame.qNativeBorder=frame.qNativeBorder or rgba(frame,frame.GetBackdropBorderColor) or {.6,.6,.6,1}
        frame:SetBackdropBorderColor(frame.qNativeBorder[1],frame.qNativeBorder[2],frame.qNativeBorder[3],0)
        if selected=="none" then if frame.qBorderFrame then frame.qBorderFrame:Hide() end;return frame end
        local edge=borderFiles[selected]
        if edge and not frame.qBorderFrame then
            local background=CreateFrame("Frame",nil,frame,"BackdropTemplate")
            background:SetAllPoints(frame); background:SetFrameLevel(frame:GetFrameLevel()); frame.qBorderFrame=background
        end
        local overlay=frame.qBorderFrame
        if overlay then
            if overlay.qBorderKey~=selected then
                overlay:SetBackdrop({edgeFile=edge[1],edgeSize=edge[2],insets={left=2,right=2,top=2,bottom=2}})
                overlay:SetBackdropBorderColor(unpack(frame.qNativeBorder));overlay.qBorderKey=selected
            end
            overlay:Show()
        end
        return frame
    end
    local key=tostring(selected)..":"..tostring(defaultKind)
    if frame.qBorderKey~=key then
        local inset=defaultKind=="dialog" and 4 or 2
        local edge=borderFiles[selected]
        local color=rgba(frame,frame.GetBackdropColor)
        local border=rgba(frame,frame.GetBackdropBorderColor)
        frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile=edge and edge[1],tile=true,tileSize=8,edgeSize=edge and edge[2] or 0,insets={left=inset,right=inset,top=inset,bottom=inset}})
        if color then frame:SetBackdropColor(unpack(color)) else frame:SetBackdropColor(.045,.045,.05,.94) end
        if border then frame:SetBackdropBorderColor(unpack(border)) else frame:SetBackdropBorderColor(.65,.65,.65,1) end
        frame.qBorderKey=key
    end
    return frame
end
function U:VerticalBar(parent)
    -- Same native vertical asset/backdrop pattern as installed Questie/AceGUI.
    -- UISliderTemplate supplies horizontal NineSlice and thumb art.
    local bar=CreateFrame("Slider",nil,parent,"BackdropTemplate")
    bar:SetOrientation("VERTICAL"); bar:EnableMouse(true); bar:SetHitRectInsets(0,0,-10,0)
    bar:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background",edgeFile="Interface\\Buttons\\UI-SliderBar-Border",tile=true,tileSize=8,edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
    bar:SetWidth(12); bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    local thumb=bar:GetThumbTexture(); thumb:SetSize(12,22)
    return bar
end
function U:Restore()
    for region, edit in pairs(self.owned) do
        -- Another skin may have changed the same texture after our post-hook.
        -- Restore only the color still owned by this addon.
        local current = A.Color(region)
        if current and not M.SameColor(current, edit.applied) then self.owned[region] = nil
        elseif current and A.SetColor(region, edit.original) then self.owned[region] = nil end
    end
end
function U:Apply(profile, status)
    self:Restore()
    if not profile.enabled or not profile.dialogTint or not profile.accents or A.ContrastEnabled() then return end
    for _, region in ipairs(A.Backgrounds()) do
        local original = A.Color(region)
        if original and not self.owned[region] then
            local applied = M.Tint(profile, original, status)
            if A.SetColor(region, applied) then self.owned[region] = { original = original, applied = applied } end
        end
    end
end

-- Match current XPIsland's default: use the native tooltip family. Installing
-- SharedMedia must not silently select a different face for owned controls.
local function samePath(a, b)
    return type(a) == "string" and type(b) == "string" and a:gsub("/", "\\"):lower() == b:gsub("/", "\\"):lower()
end
local function setFont(object, path, size)
    local ok, result = pcall(object.SetFont, object, path, size, "")
    if not ok or result == false then return false end
    local actual, height = object:GetFont()
    return samePath(actual, path) and M.Number(height) and height > 0
end
function U:Font(object, size)
    self.fontSizes = self.fontSizes or {}; self.fontSizes[object]=size
    local fallback = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local tooltip=GameTooltipTextLeft2 or GameTooltipText
    local native=tooltip and M.Text(A.Call(tooltip.GetFont,tooltip)) or fallback
    local preference=N.Core and N.Core.profile.font or "Game tooltip"
    local lib=self:Media()
    local key=preference..":"..native..":"..tostring(self.mediaRevision or 0)..":"..tostring(lib)
    if not self.fontProbe then self.fontProbe = UIParent:CreateFontString(nil, "OVERLAY"); self.fontProbe:Hide() end
    if not self.fontState or self.fontState.key ~= key then
        local requested=preference=="Arial" and "Fonts\\ARIALN.TTF" or preference=="Friz Quadrata" and "Fonts\\FRIZQT__.TTF" or native
        if preference~="Game tooltip" and preference~="Arial" and preference~="Friz Quadrata" and lib and A.Call(lib.IsValid,lib,"font",preference)==true then requested=M.Text(A.Call(lib.Fetch,lib,"font",preference)) or native end
        local path=setFont(self.fontProbe,requested,12) and requested or setFont(self.fontProbe,native,12) and native or fallback
        self.fontState = { key=key, requested=requested, path=path, default=native }
        self.fontRevision=(self.fontRevision or 0)+1
    end
    self.fontApplications = self.fontApplications or {}
    local cached = self.fontApplications[object]
    local path, height, flags = object:GetFont()
    if cached and cached.path == self.fontState.path and cached.size == size
        and path == cached.actual and height == cached.height and flags == cached.flags then return end
    if not setFont(object, self.fontState.path, size) then
        local target=self.fontState.path~=self.fontState.default and self.fontState.default or fallback
        if self.fontState.path ~= target then self.fontRevision=(self.fontRevision or 0)+1 end
        self.fontState.path = target
        if not setFont(object,target,size) then
            if target~=fallback and setFont(object,fallback,size) then self.fontState.path=fallback
            else object:SetFontObject(GameFontNormal); self.fontState.path=M.Text(A.Call(GameFontNormal.GetFont,GameFontNormal)) or fallback end
            self.fontRevision=(self.fontRevision or 0)+1
        end
    end
    path, height, flags = object:GetFont()
    self.fontApplications[object] = { path = self.fontState.path, size = size, actual = path, height = height, flags = flags }
end
-- XPIsland's bounded controls account for native rounding at effective scale.
function U:Measure(text)
    local path,size,flags=text:GetFont(); local scale=text:GetEffectiveScale()
    local key=tostring(path)..":"..size..":"..tostring(flags)..":"..scale..":"..(text:GetText() or "")
    if text.qMeasureKey~=key then
        text.qMeasureKey=key
        text.qTextWidth=(math.ceil(text:GetUnboundedStringWidth()*scale)+4)/scale
        text.qTextHeight=(math.ceil(text:GetStringHeight()*scale)+2)/scale
    end
    return text.qTextWidth,text.qTextHeight
end
function U:FitText(text,available)
    local fit=math.min(1,available/math.max(1,text.qNaturalWidth))
    text:SetScale(fit); text.qFitScale=fit; text:SetWidth(available/fit)
    return fit
end
function U:AnchorText(text,point,parent,relativePoint,x,y)
    local fit=text.qFitScale or 1
    text:SetPoint(point,parent,relativePoint,(x or 0)/fit,(y or 0)/fit)
end
local function getMedia() return LibStub and LibStub("LibSharedMedia-3.0",true) end
function U:Media(refresh)
    if self.mediaChecked and not refresh then return self.mediaLibrary end
    local lib=A.Call(getMedia)
    self.mediaChecked=true
    self.mediaLibrary=M.Readable(lib) and type(lib)=="table" and lib or nil
    return self.mediaLibrary
end
function U:FontEntries()
    local lib=self:Media()
    local preference=N.Core and N.Core.profile.font or "Game tooltip"
    local key=preference..":"..tostring(self.mediaRevision or 0)..":"..tostring(lib)
    if self.fontEntriesCache and self.fontEntriesCache.key==key then return self.fontEntriesCache.entries end
    local names={["Game tooltip"]=true,Arial=true,["Friz Quadrata"]=true}
    local registered=lib and A.Call(lib.HashTable,lib,"font")
    if M.Readable(registered) and type(registered)=="table" then
        local count=0
        for name in pairs(registered) do if M.FontName(name) then names[name]=true;count=count+1;if count>=512 then break end end end
    end
    names[preference]=true
    local list={}
    for name in pairs(names) do
        local builtIn=name=="Game tooltip" or name=="Arial" or name=="Friz Quadrata"
        local available=builtIn or lib and A.Call(lib.IsValid,lib,"font",name)==true
        list[#list+1]={value=name,label=name=="Game tooltip" and "Game tooltip (default)" or name..(available and "" or " (unavailable)")}
    end
    table.sort(list,function(a,b) if a.value=="Game tooltip" then return b.value~="Game tooltip" elseif b.value=="Game tooltip" then return false end return a.value<b.value end)
    self.fontEntriesCache={key=key,entries=list}
    return list
end
function U:RefreshFonts()
    local before=self.fontPath
    -- A later object can reject an otherwise usable family. Settle the bounded
    -- requested -> native -> standard fallback before returning to layout.
    for _=1,3 do
        local revision=self.fontRevision or 0
        for object,size in pairs(self.fontSizes or {}) do self:Font(object,size) end
        if revision==self.fontRevision then break end
    end
    self.fontPath=self.fontState and self.fontState.path
    return before ~= self.fontPath
end
function U:WatchFonts()
    local lib=self:Media(true)
    if not lib or self.fontLibrary==lib or type(lib.RegisterCallback)~="function" then return end
    self.fontChanged=self.fontChanged or function(_,kind)
        if kind~="font" then return end
        self.mediaRevision=(self.mediaRevision or 0)+1
        self.fontEntriesCache=nil
        self.fontState=nil
        local changed=self:RefreshFonts()
        if changed and N.Hover.open and N.Hover.mode=="inspector" then N.Stack:Refresh() end
        if N.Options.frame then N.Options:Refresh() end
        if changed and N.Search and N.Search:Visible() then
            if N.Search.AppearanceChanged then N.Search:AppearanceChanged() else N.Search:Changed(nil,true) end
        end
    end
    local a=pcall(lib.RegisterCallback,self,"LibSharedMedia_Registered",self.fontChanged)
    local b=pcall(lib.RegisterCallback,self,"LibSharedMedia_SetGlobal",self.fontChanged)
    if a and b then self.fontLibrary=lib end
    self.fontChanged(nil,"font")
end

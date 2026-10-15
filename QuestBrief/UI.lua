local _, N = ...
local M, A = N.Model, N.Adapter
local U = { owned = {} }; N.UI = U

-- Shared shell matches the installed XPIsland/ATCF dialog constructors.
function U:Dialog(frame)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=8,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    frame:SetBackdropColor(.045,.045,.05,.94); frame:SetBackdropBorderColor(.65,.65,.65,1)
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
    local requested=tooltip and M.Text(A.Call(tooltip.GetFont,tooltip)) or fallback
    if not self.fontProbe then self.fontProbe = UIParent:CreateFontString(nil, "OVERLAY"); self.fontProbe:Hide() end
    if not self.fontState or self.fontState.requested ~= requested then
        self.fontState = { requested = requested, path = setFont(self.fontProbe, requested, 12) and requested or fallback }
        self.fontRevision=(self.fontRevision or 0)+1
    end
    self.fontApplications = self.fontApplications or {}
    local cached = self.fontApplications[object]
    local path, height, flags = object:GetFont()
    if cached and cached.path == self.fontState.path and cached.size == size
        and path == cached.actual and height == cached.height and flags == cached.flags then return end
    if not setFont(object, self.fontState.path, size) then
        if self.fontState.path ~= fallback then self.fontRevision=(self.fontRevision or 0)+1 end
        self.fontState.path = fallback
        if not setFont(object, fallback, size) then object:SetFontObject(GameFontNormal) end
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
function U:Media()
    local lib=A.Call(getMedia)
    if M.Readable(lib) and type(lib)=="table" then return lib end
end
function U:RefreshFonts()
    local before=self.fontPath
    local revision=self.fontRevision or 0
    for object,size in pairs(self.fontSizes or {}) do self:Font(object,size) end
    if self.fontState and revision ~= self.fontRevision then
        -- A late control can reject the requested font after the probe succeeded.
        -- Replay all owned text with the final fallback, including earlier labels.
        for object,size in pairs(self.fontSizes or {}) do self:Font(object,size) end
    end
    self.fontPath=self.fontState and self.fontState.path
    return before ~= self.fontPath
end
function U:WatchFonts()
    local lib=self:Media()
    if not lib or self.fontLibrary==lib or type(lib.RegisterCallback)~="function" then return end
    self.fontChanged=self.fontChanged or function(_,kind)
        if kind~="font" then return end
        self.fontState=nil
        if self:RefreshFonts() and N.Hover.open then N.Hover:Dismiss("font") end
        if N.Options.frame then N.Options:Refresh() end
        if N.Search and N.Search:Visible() then N.Search:Changed(nil,true) end
    end
    local a=pcall(lib.RegisterCallback,self,"LibSharedMedia_Registered",self.fontChanged)
    local b=pcall(lib.RegisterCallback,self,"LibSharedMedia_SetGlobal",self.fontChanged)
    if a and b then self.fontLibrary=lib end
    self.fontChanged(nil,"font")
end

local _, N = ...
local M, A = N.Model, N.Adapter
local U = { owned = {} }; N.UI = U

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

-- Owned settings text follows the same checked Expressway/SharedMedia fallback
-- as XPIsland and ATCF. Blizzard's quest fonts remain entirely native.
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
    local lsm = self:Media()
    local requested = fallback
    if lsm and A.Call(lsm.IsValid,lsm,"font","Expressway") == true then requested = M.Text(A.Call(lsm.Fetch,lsm,"font","Expressway")) or fallback end
    if not self.fontProbe then self.fontProbe = UIParent:CreateFontString(nil, "OVERLAY"); self.fontProbe:Hide() end
    if not self.fontState or self.fontState.requested ~= requested or self.fontState.library ~= lsm then
        self.fontState = { requested = requested, library = lsm, path = setFont(self.fontProbe, requested, 12) and requested or fallback }
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
        if N.Search and N.Search:Visible() then N.Search:Changed() end
    end
    local a=pcall(lib.RegisterCallback,self,"LibSharedMedia_Registered",self.fontChanged)
    local b=pcall(lib.RegisterCallback,self,"LibSharedMedia_SetGlobal",self.fontChanged)
    if a and b then self.fontLibrary=lib end
    self.fontChanged(nil,"font")
end

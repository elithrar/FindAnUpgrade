local ADDON, N = ...
local M, A, U = N.Model, N.Adapter, N.UI
local C = { version = "0.1.4" }; N.Core = C

function C:Reset()
    self.questId = nil
    U:Restore()
end
function C:Offer()
    if not self.ready or not self.supported then return end
    self:Reset()
    local id = A.QuestId()
    if id and (M.IsNew(id) or M.Status(id) == "verifiedUpdated") and A.Visible(QuestFrameDetailPanel) then
        self.questId = id
        U:Apply(self.profile, M.Status(id))
    end
end
function C:Refresh()
    if self.questId and self.questId == A.QuestId() and A.Visible(QuestFrameDetailPanel) then U:Apply(self.profile, M.Status(self.questId)) else self:Reset() end
end
function C:Change(key, value)
    if key=="enabled" and value==false then N.Recorder:Enable(false) end
    if self.readOnly then return false end
    local saved = M.Copy(self.profile); saved[key] = value
    self.profile = M.Load(saved); FindAnUpgradeDB = self.profile
    local appearance=key=="font" or key=="border" or key=="scale" or key=="accents" or key=="strength"
    if key~="font" and key~="border" and key~="scale" and key~="searchDefaults" then N.Sources:Clear() end
    if key=="font" then U.fontState=nil;U:RefreshFonts() end
    self:Refresh()
    if N.Options.frame then N.Options:Refresh() end
    N.Launcher:Refresh()
    if not self.profile.enabled and N.Search.frame then N.Search.frame:Hide() end
    if appearance and N.Hover.open and N.Hover.mode=="inspector" and N.Stack.source then
        if N.Stack.frame and M.Number(N.Stack.screenWidth) then N.Stack.frame:SetScale(math.min(self.profile.scale,(N.Stack.screenWidth-16)/320)) end
        N.Stack:Refresh()
    end
    if N.Search:Visible() and appearance then
        if N.Search.AppearanceChanged then N.Search:AppearanceChanged() else N.Search:Fit(); N.Search:Changed(nil,true) end
    end
    return true
end
function C:ChangeSearchDefault(key,value)
    if self.readOnly or M.defaults.searchDefaults[key]==nil then return false end
    local defaults=M.Copy(self.profile.searchDefaults);defaults[key]=value
    return self:Change("searchDefaults",M.SearchDefaults(defaults))
end
function C:Defaults()
    if self.readOnly then return false end
    self.profile = M.Copy(M.defaults); FindAnUpgradeDB = self.profile
    U.fontState=nil;U:RefreshFonts()
    N.Sources:Clear()
    self:Refresh(); if N.Options.frame then N.Options:Refresh() end
    N.Launcher:Refresh()
    if N.Search:Visible() then
        if N.Search.AppearanceChanged then N.Search:AppearanceChanged() else N.Search:Fit(); N.Search:Changed(nil,true) end
    end
    return true
end
function C:Attach()
    if not self.supported or self.hooked or InCombatLockdown() then return end
    if not QuestFrameDetailPanel or not QuestFrame or type(QuestFrameDetailPanel_OnShow) ~= "function" or type(QuestInfo_Display) ~= "function" then return end
    if A.Forbidden(QuestFrameDetailPanel) or A.Forbidden(QuestFrame) then return end
    -- XML can retain the original renderer function reference. An additive
    -- script hook observes that path as well as calls through the global name.
    QuestFrameDetailPanel:HookScript("OnShow", function() self:Offer() end)
    hooksecurefunc("QuestInfo_Display", function(template, parent)
        if parent == QuestDetailScrollChildFrame and template == QUEST_TEMPLATE_DETAIL then self:Offer() end
    end)
    QuestFrameDetailPanel:HookScript("OnHide", function() self:Reset() end)
    QuestFrame:HookScript("OnHide", function() self:Reset() end)
    self.hooked = true
    -- Covers a reload with an offer already visible without opening any UI.
    if A.Visible(QuestFrameDetailPanel) then self:Offer() end
end
function C:Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100FindAnUpgrade|r: " .. text) end
end
function C:Slash(input)
    local command = (input or ""):match("^%s*(.-)%s*$"):lower()
    local slot=command:match("^slot%s+(.+)$")
    if slot then N.Search:OpenSlot(slot)
    elseif command=="" or command=="search" or command=="s" then
        N.Search:Toggle()
    elseif command=="minimap" or command=="mm" then
        if not self:Change("launcher",not self.profile.launcher) then self:Print("Settings are read-only.") end
    elseif command == "on" or command == "off" then
        if not self:Change("enabled", command == "on") then self:Print("Settings are read-only.") end
    elseif command == "status" then
        self:Print((self.supported and (self.profile.enabled and "Enabled" or "Disabled") or "Unsupported client") .. "; " .. N.Data.newCount .. " verified new IDs. Data: " .. N.Data.collectedAt .. ".")
    elseif command == "options" or command == "opts" then
        N.Options:Toggle(self)
    else self:Print("/fau search | slot <slot> | minimap | opts | on | off | status") end
end
function C:Initialize()
    if self.ready then return end
    local saved=M.RenameSeed(FindAnUpgradeDB,QuestBriefDB)
    self.profile, self.readOnly = M.Load(saved)
    -- Retain newer-schema data verbatim, including when seeded by the rename.
    FindAnUpgradeDB = self.readOnly and saved or self.profile
    FindAnUpgradeCharacterDB=N.Shortlist:Load(FindAnUpgradeCharacterDB)
    self.supported = A.Supported(); self.ready = true
    N.Recorder:Initialize()
    SLASH_FINDANUPGRADE1 = "/findanupgrade"
    SLASH_FINDANUPGRADE2 = "/fau"
    SlashCmdList.FINDANUPGRADE = function(input) self:Slash(input) end
    self:Attach()
    N.Sources:Attach()
    if N.NativeTooltip then N.NativeTooltip:Attach() end
    if N.Character and self.supported then N.Character:Initialize() end
    if N.QuestState and self.supported then N.QuestState:Initialize() end
    U:WatchFonts()
    N.Launcher:Refresh()
end
function C:StartHoverUpdate()
    if self.updating then return end
    self.updating = true
    self.events:SetScript("OnUpdate", function()
        local now = A.Call(GetTime)
        if M.Number(now) then N.Hover:Tick(now) end
        if not N.Hover.open and not N.Sources.current then self.events:SetScript("OnUpdate",nil); self.updating=false end
    end)
end
local events = CreateFrame("Frame"); C.events = events
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "QUEST_FINISHED", "QUEST_GREETING", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "GOSSIP_CLOSED", "PLAYER_ENTERING_WORLD", "UPDATE_MOUSEOVER_UNIT", "MODIFIER_STATE_CHANGED", "QUEST_DATA_LOAD_RESULT", "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED", "TOOLTIP_DATA_UPDATE", "CVAR_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then C:Initialize() elseif C.ready then
            C:Attach(); N.Sources:Attach(); U:WatchFonts()
            if N.NativeTooltip then N.NativeTooltip:Attach() end
            local fontChanged=U:RefreshFonts()
            if fontChanged and N.Hover.open and N.Hover.mode=="inspector" then N.Stack:Refresh() end
            if fontChanged and N.Search:Visible() then
                if N.Search.AppearanceChanged then N.Search:AppearanceChanged() else N.Search:Changed(nil,true) end
            end
            if N.Options.frame then N.Options:Refresh() end
        end
    elseif not C.ready then return
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        C:Attach(); N.Sources:Attach(); C:Refresh()
        if N.NativeTooltip then N.NativeTooltip:Attach() end
        N.Launcher:Refresh()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        local source = C.supported and C.profile.enabled and C.profile.npc and not N.Search:Visible() and N.Sources:NPC()
        if source then N.Sources:Set(source) elseif N.Sources.current and N.Sources.current.surface == "npc" then N.Sources:Clear(nil,true) end
    elseif event == "MODIFIER_STATE_CHANGED" then N.Hover:Modifier()
    elseif event == "QUEST_DATA_LOAD_RESULT" then N.Hover:Refresh(name)
    elseif event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then N.Hover:ItemData(name);N.Stack:ComparisonItemData(name)
    elseif event == "CVAR_UPDATE" then
        if type(name)=="string" and name:lower()=="alwayscompareitems" then
            N.Stack:ComparisonChanged()
            if N.Search.inspector then N.Search.inspector:ComparisonChanged();N.Search:Wake() end
        end
    elseif event == "TOOLTIP_DATA_UPDATE" then
        local v = N.Stack
        if v.item and not v:InspectionCurrent(v.item) then v:ClearItem()
        elseif v.item and v:HasTooltipData(name) then
            local item = v.item
            v:Inspect(item.button,item.row,true)
        end
    elseif event == "GOSSIP_SHOW" then
        C:Reset(); N.Sources:Gossip()
        if N.QuestState then N.QuestState:OfferChanged() end
    else
        C:Reset(); N.Sources:Clear()
        if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" or event == "PLAYER_ENTERING_WORLD" then
            N.Sources.gossip=nil
            if N.QuestState and event~="PLAYER_ENTERING_WORLD" then N.QuestState:OfferChanged() end
        end
    end
end)

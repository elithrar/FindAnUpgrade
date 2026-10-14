local ADDON, N = ...
local M, A, U = N.Model, N.Adapter, N.UI
local C = { version = "0.1.0" }; N.Core = C

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
    if self.readOnly then return false end
    local saved = M.Copy(self.profile); saved[key] = value
    self.profile = M.Load(saved); QuestBriefDB = self.profile
    N.Hover:Dismiss("settings"); N.Sources.current = nil
    self:Refresh()
    if N.Options.frame then N.Options:Refresh() end
    return true
end
function C:Defaults()
    if self.readOnly then return false end
    self.profile = M.Copy(M.defaults); QuestBriefDB = self.profile
    N.Hover:Dismiss("settings"); N.Sources.current = nil
    self:Refresh(); if N.Options.frame then N.Options:Refresh() end
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
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100QuestBrief|r: " .. text) end
end
function C:Slash(input)
    local command = (input or ""):match("^%s*(.-)%s*$"):lower()
    if command == "on" or command == "off" then
        if not self:Change("enabled", command == "on") then self:Print("Settings are read-only.") end
    elseif command == "status" then
        self:Print((self.supported and (self.profile.enabled and "Enabled" or "Disabled") or "Unsupported client") .. "; " .. N.Data.newCount .. " verified new IDs. Data: " .. N.Data.collectedAt .. ".")
    elseif command == "" or command == "options" or command == "opts" then
        if InCombatLockdown() then self:Print("Open settings after combat.") else N.Options:Toggle(self) end
    else self:Print("/questbrief opts | on | off | status") end
end
function C:Initialize()
    if self.ready then return end
    self.profile, self.readOnly = M.Load(M.LegacySeed(QuestBriefDB,QuestTintDB))
    if not self.readOnly then QuestBriefDB = self.profile end
    self.supported = A.Supported(); self.ready = true
    SLASH_QUESTBRIEF1 = "/questbrief"
    SlashCmdList.QUESTBRIEF = function(input) self:Slash(input) end
    self:Attach()
    N.Sources:Attach()
    U:WatchFonts()
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
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "QUEST_FINISHED", "QUEST_GREETING", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "GOSSIP_CLOSED", "PLAYER_ENTERING_WORLD", "UPDATE_MOUSEOVER_UNIT", "MODIFIER_STATE_CHANGED", "QUEST_DATA_LOAD_RESULT", "QUEST_LOG_UPDATE", "TOOLTIP_DATA_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_LEVEL_UP" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then C:Initialize() elseif C.ready then
            C:Attach(); N.Sources:Attach(); U:WatchFonts()
            if U:RefreshFonts() and N.Hover.open then N.Hover:Dismiss("font") end
            if N.Options.frame then N.Options:Refresh() end
        end
    elseif not C.ready then return
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        C:Attach(); N.Sources:Attach(); C:Refresh()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        local source = C.supported and N.Sources:NPC()
        if source then N.Sources:Set(source) elseif N.Sources.current and N.Sources.current.surface == "npc" then N.Sources.current=nil end
    elseif event == "MODIFIER_STATE_CHANGED" then N.Hover:Modifier()
    elseif event == "QUEST_DATA_LOAD_RESULT" then N.Hover:Refresh(name)
    elseif event == "QUEST_LOG_UPDATE" then N.Hover:Refresh()
    elseif event == "TOOLTIP_DATA_UPDATE" then
        local v = N.Stack
        if v.item and A.Call(v.tooltip.HasDataInstanceID,v.tooltip,name) == true then
            local item = v.item
            v:Inspect(item.button,item.row,true)
        end
    elseif event == "GOSSIP_SHOW" then C:Reset(); N.Sources:Gossip()
    else
        C:Reset(); N.Hover:Dismiss(event); N.Sources.current=nil
        if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" or event == "PLAYER_ENTERING_WORLD" then N.Sources.gossip=nil end
    end
end)

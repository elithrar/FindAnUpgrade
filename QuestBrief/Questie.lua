local _, N = ...
local M, A = N.Model, N.Adapter
local Q = { tokens=setmetatable({}, {__mode="k"}) }; N.Questie = Q
function Q:Observe(tooltip)
    self.tokens[tooltip]=M.Readable(tooltip._Rebuild) and tooltip._Rebuild or false
end
function Q.Rows(tooltip)
    local rows = {}
    local quests = tooltip.questOrder
    if M.Readable(quests) and type(quests) == "table" then
        local n = 0
        for id in pairs(quests) do n=n+1; if n>256 then return {} end
            if M.QuestId(id) then rows[#rows+1] = { id = id, evidence = "Questie objective", provenance = "Questie rendered questOrder" } end
        end
    end
    local groups = tooltip.npcAndObjectOrder
    if M.Readable(groups) and type(groups) == "table" then
        local n = 0
        for _, group in pairs(groups) do
            if M.Readable(group) and type(group) == "table" then
                for _, tip in pairs(group) do n=n+1; if n>256 then return {} end
                    if M.Readable(tip) and type(tip) == "table" and M.QuestId(tip.questId) then rows[#rows+1] = { id = tip.questId, evidence = "Questie quest - availability unconfirmed", provenance = "Questie rendered npcAndObjectOrder exact questId" } end
                end
            end
        end
    end
    table.sort(rows, function(a,b) return a.id < b.id end)
    return M.Entries(rows)
end
function Q:Shown(icon, tooltip)
    if not icon or not tooltip or A.Forbidden(icon) or not A.Visible(icon) or not A.Visible(tooltip) or icon.hidden or icon._needsUnload or tooltip._owner ~= icon then return end
    local color=A.Color(icon.texture)
    if not color or color[4]<=0 then return end
    local token=tooltip._Rebuild
    if not M.Readable(token) or type(token)~="function" then return end
    local previous=self.tokens[tooltip];self.tokens[tooltip]=token
    -- Successful Questie renders replace _Rebuild; alpha/throttle early returns
    -- leave it unchanged. Unknown tooltips must establish a baseline first.
    if previous==nil or previous==token then return end
    local data = icon.data
    if not M.Readable(data) or type(data) ~= "table" then return end
    local dataID = M.QuestId(data.Id)
    if not dataID then return end
    local rows = Q.Rows(tooltip); if #rows == 0 then return end
    local primary=false;for _,row in ipairs(rows) do if row.id==dataID then primary=true;break end end
    if not primary then return end
    local surface = icon.miniMapIcon == true and "minimap" or "worldmap"
    N.Sources:Watch(icon)
    local signature = {}; for _,row in ipairs(rows) do signature[#signature+1]=row.id end
    N.Sources:Set({ key = N.Sources:Key(icon,table.concat(signature,","),data), owner = icon, surface = surface, rows = rows,
        over = function() return A.Over(icon) end,
        valid = function() return A.Visible(icon) and not icon.hidden and not icon._needsUnload and icon.data == data and M.QuestId(data.Id) == dataID and (icon.miniMapIcon == true) == (surface == "minimap") and (surface == "minimap" or A.Visible(WorldMapFrame)) end })
end
function Q:Attach()
    if self.module or InCombatLockdown() or not QuestieLoader or type(QuestieLoader.ImportModule) ~= "function" then return end
    local module = A.Call(QuestieLoader.ImportModule, QuestieLoader, "MapIconTooltip")
    if type(module) ~= "table" or type(module.ShowOnTooltip) ~= "function" then return end
    if GameTooltip then self:Observe(GameTooltip) end
    -- The installed Forever Questie 12.1.0 publishes exact grouped IDs after
    -- ShowOnTooltip. No marker is created, hidden, recolored or reassigned.
    hooksecurefunc(module, "ShowOnTooltip", function(icon, tooltip) self:Shown(icon, tooltip) end)
    self.module = module
end

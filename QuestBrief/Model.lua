local _, N = ...
local M = {}; N.Model = M
M.presets = {
    sage = { .88, 1, .88 },
    blue = { .88, .95, 1 },
    amber = { 1, .94, .82 },
}
M.defaults = { version = 3, enabled = true, preset = "blue", strength = .55,
    modifier = "SHIFT", npc = true, worldmap = true, minimap = true,
    accents = true, dialogTint = true, rewards = true, scale = 1,
    launcher = true, launcherAngle = 200, previewLayout = "tooltip", inspectionPosition = "right" }

function M.Readable(value)
    if not issecretvalue then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and not secret
end
function M.Number(value)
    return M.Readable(value) and type(value) == "number"
        and value == value and value ~= math.huge and value ~= -math.huge
end
function M.QuestId(value)
    if M.Number(value) and value > 0 and value == math.floor(value) then return value end
end
function M.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}; for key, item in pairs(value) do copy[key] = M.Copy(item) end
    return copy
end
function M.Load(saved)
    local profile = M.Copy(M.defaults)
    if not M.Readable(saved) or type(saved) ~= "table" then return profile, false end
    if M.Number(saved.version) and saved.version > 3 then
        -- Preserve an explicit opt-out even when the newer schema is read-only.
        if M.Readable(saved.enabled) and saved.enabled == false then profile.enabled = false end
        return profile, true
    end
    if M.Readable(saved.enabled) and type(saved.enabled) == "boolean" then profile.enabled = saved.enabled end
    if M.Readable(saved.preset) and type(saved.preset) == "string" and M.presets[saved.preset] then profile.preset = saved.preset end
    if M.Number(saved.strength) then profile.strength = math.max(.1, math.min(1, saved.strength)) end
    for _, key in ipairs({ "npc", "worldmap", "minimap", "accents", "dialogTint", "rewards", "launcher" }) do
        if M.Readable(saved[key]) and type(saved[key]) == "boolean" then profile[key] = saved[key] end
    end
    if M.Readable(saved.modifier) and (saved.modifier == "SHIFT" or saved.modifier == "CTRL" or saved.modifier == "ALT" or saved.modifier == "NONE") then profile.modifier = saved.modifier end
    if M.Number(saved.scale) then profile.scale = math.max(.8, math.min(1.2, saved.scale)) end
    if M.Number(saved.launcherAngle) then profile.launcherAngle=saved.launcherAngle%360 end
    if M.Readable(saved.previewLayout) and (saved.previewLayout=="tooltip" or saved.previewLayout=="inspector") then profile.previewLayout=saved.previewLayout end
    if M.Readable(saved.inspectionPosition) and (saved.inspectionPosition=="right" or saved.inspectionPosition=="tooltip") then profile.inspectionPosition=saved.inspectionPosition end
    return profile, false
end
function M.Status(id)
    id = M.QuestId(id)
    return id and N.Data.statusById[id] or nil
end
function M.IsNew(id) return M.Status(id) == "verifiedNew" end
function M.Tint(profile, base, status)
    local color = status == "verifiedNew" and {1,.94,.82} or status == "verifiedUpdated" and {.88,1,.88} or M.presets[profile.preset] or M.presets.sage
    local result = {}
    for i = 1, 3 do result[i] = base[i] * (1 - profile.strength * (1 - color[i])) end
    result[4] = base[4]
    return result
end
function M.AccentFill(profile,status,r,g,b)
    local target=profile.accents and (status=="verifiedNew" and {.20,.14,.025} or status=="verifiedUpdated" and {.055,.18,.055})
    if not target then return r,g,b end
    local strength=profile.strength
    return r+(target[1]-r)*strength,g+(target[2]-g)*strength,b+(target[3]-b)*strength
end
function M.Label(id)
    local status = M.Status(id)
    return status == "verifiedNew" and "New in Forever" or status == "verifiedUpdated" and "Modified in Forever" or not status and "Status not verified" or ""
end
function M.Text(value)
    return M.Readable(value) and type(value) == "string" and value ~= "" and value or nil
end
function M.Field(value)
    if not M.Readable(value) then return { state = "restricted" } end
    if M.Number(value) then return { state = "ready", value = value } end
    return { state = "unavailable" }
end
function M.Entries(rows)
    local result, seen = {}, {}
    for _, row in ipairs(rows or {}) do
        if M.Readable(row) and type(row) == "table" then
            local id = M.QuestId(row.id)
            if id and not seen[id] then seen[id] = true; result[#result+1] = row end
        end
    end
    return result
end
function M.LegacySeed(current,legacy)
    -- A renamed TOC cannot read a disabled old addon's SavedVariables file.
    -- Only use an already-restored global when no QuestBrief configuration exists.
    if current ~= nil then return current end
    if not M.Readable(legacy) or type(legacy) ~= "table" then return nil end
    local seed=M.Load(legacy)
    if M.Number(legacy.version) and legacy.version>1 then return nil end
    return seed
end
function M.SameColor(a, b)
    if not a or not b then return false end
    for i = 1, 4 do if not M.Number(a[i]) or not M.Number(b[i]) or math.abs(a[i] - b[i]) > .00001 then return false end end
    return true
end

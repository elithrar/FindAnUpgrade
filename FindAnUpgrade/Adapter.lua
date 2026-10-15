local _, N = ...
local M = N.Model
local A = {}; N.Adapter = A
A.interface = 16001
function A.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and M.Readable(value) then return value end
end
function A.Supported()
    if type(GetBuildInfo) ~= "function" then return false end
    local ok, _, _, _, interface = pcall(GetBuildInfo)
    return ok and M.Number(interface) and interface == A.interface
end
function A.QuestId() return M.QuestId(A.Call(GetQuestID)) end
function A.Visible(frame)
    return frame and not A.Forbidden(frame) and A.Call(frame.IsVisible or frame.IsShown, frame) == true
end
function A.Forbidden(region)
    if not region then return true end
    if region.IsForbidden then return A.Call(region.IsForbidden, region) ~= false end
    return false
end
function A.Rect(frame)
    if not A.Visible(frame) or type(frame.GetRect) ~= "function" then return end
    local ok, x, y, w, h = pcall(frame.GetRect, frame)
    local scale = A.Call(frame.GetEffectiveScale, frame)
    if not ok or not M.Number(x) or not M.Number(y) or not M.Number(w) or not M.Number(h) or not M.Number(scale) or scale <= 0 then return end
    return { x = x*scale, y = y*scale, w = w*scale, h = h*scale }
end
function A.Cursor()
    if type(GetCursorPosition) ~= "function" then return end
    local ok, x, y = pcall(GetCursorPosition)
    if ok and M.Number(x) and M.Number(y) then return x, y end
end
function A.Over(frame)
    local r, x, y = A.Rect(frame), A.Cursor()
    return r and x and x >= r.x and x <= r.x+r.w and y >= r.y and y <= r.y+r.h or false
end
function A.Modifier(key)
    if key == "NONE" then return true end
    local fn = key == "CTRL" and IsControlKeyDown or key == "ALT" and IsAltKeyDown or IsShiftKeyDown
    return A.Call(fn) == true
end
function A.Color(region)
    if A.Forbidden(region) or type(region.GetVertexColor) ~= "function" then return nil end
    local ok, r, g, b, a = pcall(region.GetVertexColor, region)
    if not ok or not M.Number(r) or not M.Number(g) or not M.Number(b) or not M.Number(a) then return nil end
    return { r, g, b, a }
end
function A.SetColor(region, color)
    if A.Forbidden(region) or type(region.SetVertexColor) ~= "function" then return false end
    return pcall(region.SetVertexColor, region, unpack(color))
end
function A.ContrastEnabled()
    -- Respect the native accessibility background, including light/dark modes.
    return QuestTextContrast and A.Call(QuestTextContrast.IsEnabled) ~= false
end
function A.Backgrounds()
    local panel = QuestFrameDetailPanel
    if not panel or A.Forbidden(panel) then return {} end
    local result = {}
    for _, key in ipairs({ "Bg", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight", "SealMaterialBG" }) do
        local region = panel[key]
        if region and A.Visible(region) and not A.Forbidden(region) then result[#result + 1] = region end
    end
    return result
end

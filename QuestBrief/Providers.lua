local _, N = ...
local M, A = N.Model, N.Adapter
local P = {}; N.Providers = P
function P.Connect()
    local lib = LibQuestieDB
    if not M.Readable(lib) or type(lib) ~= "table" or not M.Readable(lib.flavor) or type(lib.flavor) ~= "table" or M.Text(lib.flavor.name) ~= "Forever" then return end
    if type(lib.RequireContract) ~= "function" then return end
    local ok, result = pcall(lib.RequireContract, 3)
    if ok and result ~= false and type(lib.Npc) == "table" and type(lib.Quest) == "table" then return lib end
end
function P.ForNPC(npcID)
    local lib = P.Connect(); npcID = M.QuestId(npcID)
    if not lib or not npcID then return {} end
    local starts = A.Call(lib.Npc.Get, npcID, "questStarts")
    if not M.Readable(starts) or type(starts) ~= "table" or #starts > 256 then return {} end
    local out = {}
    for _, value in ipairs(starts) do
        local id = M.QuestId(value)
        local starter = id and A.Call(lib.Quest.Get, id, "startedBy")
        local npcs = M.Readable(starter) and type(starter) == "table" and starter[1]
        if M.Readable(npcs) and type(npcs) == "table" and #npcs <= 256 then
            for _, starterID in ipairs(npcs) do
                if M.QuestId(starterID) == npcID then
                    out[#out+1] = { id = id, title = M.Text(A.Call(lib.Quest.Get, id, "name")),
                        evidence = "Possible quest - availability unconfirmed", provenance = "QuestieDB Forever contract 3; reciprocal starter association" }
                    break
                end
            end
        end
    end
    return M.Entries(out)
end

local _, N = ...
local M = N.Model
local S = { schemaVersion = 1, capacity = 20, revision = 0, readOnly = true }
N.Shortlist = S

local function copy(ids)
    local result = {}
    for index, id in ipairs(ids) do result[index] = id end
    return result
end

local function readIDs(value)
    local ids, seen, keys = {}, {}, {}
    if not M.Readable(value) or type(value) ~= "table" then return ids, false end
    local valid = true
    for key in pairs(value) do
        if M.Number(key) and key >= 1 and key == math.floor(key) then
            keys[#keys + 1] = key
        else
            valid = false
        end
    end
    table.sort(keys)
    for index, key in ipairs(keys) do
        local id = M.QuestId(value[key])
        if key ~= index or not id or seen[id] then valid = false end
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids, valid
end

function S:Load(saved)
    local db, ids, readOnly = saved, {}, false
    if saved == nil then
        db = { schemaVersion = self.schemaVersion, ids = {} }
    elseif not M.Readable(saved) or type(saved) ~= "table" then
        db = { schemaVersion = self.schemaVersion, ids = {}, recovery = saved }
    elseif not M.Readable(saved.schemaVersion)
        or (saved.schemaVersion ~= nil and saved.schemaVersion ~= self.schemaVersion) then
        -- A future or unrecognized format belongs to its writer. Do not
        -- interpret its list, normalize its fields, or write through it.
        readOnly = true
    else
        local valid
        ids, valid = readIDs(saved.ids)
        if saved.schemaVersion ~= self.schemaVersion or not valid then
            -- Keep the exact original record for recovery, including holes,
            -- duplicates and unrelated fields; the usable list is independent.
            db = { schemaVersion = self.schemaVersion, ids = copy(ids), recovery = saved }
        end
    end
    self.db, self.ids, self.lookup, self.readOnly = db, ids, {}, readOnly
    for _, id in ipairs(ids) do self.lookup[id] = true end
    self.loaded = true
    self.revision = self.revision + 1
    return db, readOnly
end

function S:IDs()
    -- Callers may sort/filter their copy without mutating the stored order.
    return copy(self.ids or {})
end

function S:Contains(value)
    local id = M.QuestId(value)
    return id ~= nil and self.lookup ~= nil and self.lookup[id] == true
end

function S:Remove(value)
    local id = M.QuestId(value)
    if not id then return false, "invalid" end
    if not self.loaded then return false, "notLoaded" end
    if self.readOnly then return false, "readOnly" end
    if not self.lookup[id] then return false, "missing" end
    for index, current in ipairs(self.ids) do
        if current == id then table.remove(self.ids, index); break end
    end
    self.lookup[id] = nil
    self.db.ids = copy(self.ids)
    self.revision = self.revision + 1
    return true, "removed"
end

function S:Toggle(value)
    local id = M.QuestId(value)
    if not id then return false, "invalid" end
    if not self.loaded then return false, "notLoaded" end
    if self.readOnly then return false, "readOnly" end
    if self.lookup[id] then return self:Remove(id) end
    -- An oversized legacy list stays readable and removable. Its existing IDs
    -- are never truncated to enforce a limit intended for new additions.
    if #self.ids >= self.capacity then return false, "capacity" end
    self.ids[#self.ids + 1] = id
    self.lookup[id] = true
    self.db.ids = copy(self.ids)
    self.revision = self.revision + 1
    return true, "added"
end

PASSED = 0
local function test(name, fn) fn(); PASSED = PASSED + 1; print("PASS " .. name) end
local function setup(saved)
    local N = {}
    assert(loadfile(ROOT .. "/FindAnUpgrade/Model.lua"))("FindAnUpgrade", N)
    assert(loadfile(ROOT .. "/FindAnUpgrade/Shortlist.lua"))("FindAnUpgrade", N)
    local db, readOnly = N.Shortlist:Load(saved)
    return N.Shortlist, db, readOnly, N
end
local function equal(ids, expected)
    assert(#ids == #expected)
    for index, id in ipairs(expected) do assert(ids[index] == id) end
end

test("fresh characters own independent schema-one ordered ID lists", function()
    local a, adb = setup(); local b, bdb = setup()
    assert(adb.schemaVersion == 1 and not a.readOnly and not b.readOnly and adb ~= bdb)
    assert(a:Toggle(9)); assert(a:Toggle(14)); equal(a:IDs(), {9, 14}); equal(b:IDs(), {})
    assert(adb.ids ~= bdb.ids and a:Contains(9) and not b:Contains(9))
end)

test("valid IDs survive reload without catalog or snapshot dependencies", function()
    local first, db = setup(); assert(first:Toggle(999999)); assert(first:Toggle(9))
    local loaded, same, readOnly = setup(db)
    assert(same == db and not readOnly and loaded:Contains(999999)); equal(loaded:IDs(), {999999, 9})
    assert(not db.items and not db.completed and not db.tooltip and not db.profile)
end)

test("list reads cannot reorder or erase the model and persistence", function()
    local s, db = setup({schemaVersion = 1, ids = {9, 14}})
    local ids = s:IDs(); ids[1] = 500; ids[2] = nil; ids[3] = 99
    equal(s:IDs(), {9, 14}); equal(db.ids, {9, 14}); assert(not s:Contains(500))
end)

test("duplicates and holes normalize stably while preserving raw recovery", function()
    local raw = {schemaVersion = 1, ids = {[1] = 14, [3] = 9, [4] = 14, [8] = 30}, note = "keep"}
    local s, db, readOnly = setup(raw)
    assert(not readOnly and db ~= raw and db.recovery == raw and raw.ids[3] == 9 and raw.ids[4] == 14)
    assert(raw.ids[2] == nil and raw.note == "keep"); equal(s:IDs(), {14, 9, 30})
    assert(s:Toggle(99)); equal(s:IDs(), {14, 9, 30, 99}); assert(raw.ids[8] == 30)
    local again, persisted = setup(db)
    assert(persisted == db and persisted.recovery == raw); equal(again:IDs(), {14, 9, 30, 99})
end)

test("malformed IDs and keys never reach the usable list or erase raw records", function()
    local raw = {schemaVersion = 1, ids = {[1] = 9, [2] = "14", [3] = -1, [4] = 1.5,
        [5] = math.huge, [6] = 0 / 0, [7] = {}, [8] = false, [9] = 30, bad = 99, [0] = 50}}
    local s, db = setup(raw)
    equal(s:IDs(), {9, 30}); assert(db.recovery == raw and raw.ids.bad == 99 and raw.ids[0] == 50)
    assert(raw.ids[2] == "14" and raw.ids[5] == math.huge and raw.ids[6] ~= raw.ids[6])
end)

test("unsupported schemas stay intact read-only without guessed list semantics", function()
    for _, version in ipairs({2, 99, "1", false, -1}) do
        local raw = {schemaVersion = version, ids = {9}, extra = {"keep"}}
        local s, same, readOnly = setup(raw); local revision = s.revision
        assert(same == raw and readOnly and s.readOnly and #s:IDs() == 0)
        local ok, reason = s:Toggle(9); assert(not ok and reason == "readOnly")
        ok, reason = s:Remove(9); assert(not ok and reason == "readOnly")
        assert(s.revision == revision and raw.ids[1] == 9 and raw.extra[1] == "keep" and raw.recovery == nil)
    end
end)

test("missing schema or list retains original recovery instead of replacing silently", function()
    local raw = {ids = {9, 14}, unknown = "keep"}; local s, db = setup(raw)
    assert(db.recovery == raw and db.schemaVersion == 1 and raw.schemaVersion == nil)
    equal(s:IDs(), {9, 14})
    raw = {schemaVersion = 1, ids = "damaged"}; s, db = setup(raw)
    assert(db.recovery == raw and raw.ids == "damaged"); equal(s:IDs(), {})
    for _, value in ipairs({false, "damaged", 12}) do
        s, db = setup(value); assert(db.recovery == value and not s.readOnly); equal(s:IDs(), {})
    end
end)

test("capacity rejects additions but removal and re-addition preserve stable order", function()
    local s, db = setup()
    for id = 1, 20 do assert(s:Toggle(id)) end
    local revision = s.revision; local ok, reason = s:Toggle(21)
    assert(not ok and reason == "capacity" and s.revision == revision and #db.ids == 20)
    ok, reason = s:Toggle(10); assert(ok and reason == "removed" and not s:Contains(10))
    assert(s:Toggle(21)); local ids = s:IDs()
    assert(#ids == 20 and ids[9] == 9 and ids[10] == 11 and ids[20] == 21)
end)

test("oversized saved lists retain every ID and allow recovery by removal", function()
    local raw = {schemaVersion = 1, ids = {}, extra = "preserve"}
    for id = 1, 23 do raw.ids[id] = id end
    local s, db = setup(raw)
    assert(db == raw and #s:IDs() == 23 and db.ids[23] == 23)
    local ok, reason = s:Toggle(24); assert(not ok and reason == "capacity")
    for id = 1, 4 do assert(s:Remove(id)) end
    assert(#s:IDs() == 19 and s:Toggle(24) and db.ids[20] == 24 and db.extra == "preserve")
end)

test("revisions change only when loaded or a list membership changes", function()
    local s = setup(); local revision = s.revision
    local ok, reason = s:Remove(9); assert(not ok and reason == "missing" and s.revision == revision)
    for _, id in ipairs({0, -1, 1.5, math.huge, "9", {}, false}) do
        ok, reason = s:Toggle(id); assert(not ok and reason == "invalid" and s.revision == revision)
    end
    assert(not s:Toggle(nil) and not s:Toggle(0 / 0) and not s:Contains(nil))
    assert(s:Toggle(9) and s.revision == revision + 1)
    assert(s:Remove(9) and s.revision == revision + 2)
    s:Load({schemaVersion = 1, ids = {14}})
    assert(s.revision == revision + 3 and s:Contains(14) and not s:Contains(9))
end)

test("appearance reset cannot erase per-character state", function()
    local s, db, _, N = setup(); assert(s:Toggle(9)); local revision = s.revision
    local profile = N.Model.Load(nil); profile = N.Model.Copy(N.Model.defaults)
    assert(profile.version == 4 and db.ids[1] == 9 and s:Contains(9) and s.revision == revision)
end)

test("restricted IDs and schema fields are rejected before interpretation", function()
    local marker = {}; issecretvalue = function(value) return value == marker or value == 14 end
    local s, db = setup({schemaVersion = 1, ids = {9, 14, marker}})
    equal(s:IDs(), {9}); assert(not s:Contains(14) and not s:Toggle(14) and db.recovery.ids[2] == 14)
    local raw = {schemaVersion = marker, ids = {9}}; local same, readOnly
    same, readOnly = s:Load(raw); assert(same == raw and readOnly and #s:IDs() == 0)
    issecretvalue = nil
end)

test("model cannot write before saved variables have loaded", function()
    local N = {}; assert(loadfile(ROOT .. "/FindAnUpgrade/Model.lua"))("FindAnUpgrade", N)
    assert(loadfile(ROOT .. "/FindAnUpgrade/Shortlist.lua"))("FindAnUpgrade", N)
    local ok, reason = N.Shortlist:Toggle(9)
    assert(not ok and reason == "notLoaded" and N.Shortlist.db == nil and #N.Shortlist:IDs() == 0)
end)

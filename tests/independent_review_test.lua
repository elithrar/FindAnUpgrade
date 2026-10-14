local W = assert(loadfile(ROOT .. "/tests/wow_mock.lua"))()
PASSED = 0
local function probe(name, fn)
    local ok, message = pcall(fn)
    assert(ok, name .. ": " .. tostring(message))
    PASSED = PASSED + 1
    print("PASS " .. name)
end

probe("combat-end event retries failed restore", function()
    W.Init(); W.Offer(92124)
    local bg = QuestFrameDetailPanel.Bg
    bg.failWrite = true; W.combat = true; W.Offer(783)
    assert(W.N.UI.owned[bg] and W.N.Core.questId == nil)
    bg.failWrite = false; W.combat = false; W.Event("PLAYER_REGEN_ENABLED")
    assert(bg.color[1] == 1 and not W.N.UI.owned[bg], "old quest still has tint after restore becomes writable")
end)

probe("combat-end event retries unreadable restore", function()
    W.Init(); W.Offer(92124)
    local bg = QuestFrameDetailPanel.Bg
    bg.colorSecret = true; W.combat = true; W.Offer(783)
    assert(W.N.UI.owned[bg] and W.N.Core.questId == nil)
    bg.colorSecret = false; W.combat = false; W.Event("PLAYER_REGEN_ENABLED")
    assert(bg.color[1] == 1 and not W.N.UI.owned[bg], "old quest still has tint after color becomes readable")
end)

probe("older new-title variant is unchanged after background material swap", function()
    W.Init(); W.Offer(98189)
    QuestFrameDetailPanel.MaterialTopLeft.shown = true
    W.Offer(286)
    assert(QuestFrameDetailPanel.Bg.color[1] == 1)
    assert(QuestFrameDetailPanel.MaterialTopLeft:GetVertexColor() == 1)
end)

probe("missing or throwing contrast API fails closed", function()
    W.Init(); QuestTextContrast.IsEnabled = nil; W.Offer(92124)
    assert(W.writes == 0)
    QuestTextContrast.IsEnabled = function() error("unavailable") end; W.Offer(92124)
    assert(W.writes == 0)
end)

probe("failed restore does not later overwrite another skin", function()
    W.Init(); W.Offer(92124)
    local bg = QuestFrameDetailPanel.Bg
    bg.failWrite = true; W.Close(); bg.failWrite = false
    bg.color = {.5,.6,.7,.8}; W.Event("QUEST_FINISHED")
    assert(bg.color[1] == .5 and not W.N.UI.owned[bg])
end)

probe("future saved opt-out is honored without changing the saved table", function()
    local saved = {version=9,enabled=false}
    W.Init({saved=saved}); W.Offer(92124)
    assert(QuestBriefDB == saved and W.N.Core.readOnly)
    assert(not W.N.Core.profile.enabled, "future schema opt-out is not reflected in active profile")
end)

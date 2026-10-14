local W = assert(loadfile(ROOT .. "/tests/wow_mock.lua"))()
PASSED = 0
local function test(name, fn) fn(); PASSED = PASSED + 1; print("PASS " .. name) end
local function tinted() return QuestFrameDetailPanel.Bg.color and not W.N.Model.SameColor(QuestFrameDetailPanel.Bg.color,{1,1,1,1}) end
local function normal() return W.N.Model.SameColor({QuestFrameDetailPanel.Bg:GetVertexColor()},{1,1,1,1}) end

test("SavedVariables initialize only at matching addon load", function()
    local saved = {version=1, enabled=false}; local N = W.Reset({saved=saved}); W.Event("ADDON_LOADED", "OtherAddon")
    assert(QuestBriefDB == saved and not N.Core.ready); W.Event("ADDON_LOADED", "QuestBrief"); assert(not N.Core.profile.enabled)
end)
test("known new native offer tints while old and unknown offers stay normal", function()
    W.Init(); W.Offer(92124); assert(tinted()); W.Offer(783); assert(normal()); W.Offer(10000000); assert(normal())
end)
test("all five mixed title groups honor exact variants", function()
    W.Init()
    for _,pair in ipairs({{286,98189},{356,99156},{921,98046},{932,98403},{422,98298}}) do
        W.Offer(pair[2]); assert(tinted()); W.Offer(pair[1]); assert(tinted() == (W.N.Model.Status(pair[1]) == "verifiedUpdated"))
    end
end)
test("secure post-hooks preserve return values and native scripts", function()
    W.Init(); local result, number = QuestInfo_Display({}, {}); assert(result == "native-return" and number == 123)
    assert(#QuestFrameDetailPanel.hooks.OnShow == 1 and W.hooks.QuestInfo_Display == 1 and W.nativeMutations == 0)
end)
test("repeated native renders never compound the tint", function()
    W.Init(); W.Offer(92124); local r = QuestFrameDetailPanel.Bg.color[1]
    for _=1,1000 do W.Offer(92124) end; assert(math.abs(QuestFrameDetailPanel.Bg.color[1] - r) < .00001 and #W.frames == 1)
end)
test("close detail panel restores original background", function() W.Init(); W.Offer(92124); W.Close(); assert(normal() and W.N.Core.questId == nil) end)
test("close parent frame restores original background", function() W.Init(); W.Offer(92124); QuestFrame:Fire("OnHide"); assert(normal()) end)
for _,event in ipairs({"QUEST_FINISHED","QUEST_GREETING","QUEST_PROGRESS","QUEST_COMPLETE","GOSSIP_SHOW","PLAYER_ENTERING_WORLD"}) do
    test(event .. " clears the offer", function() W.Init(); W.Offer(92124); W.Event(event); assert(normal() and W.N.Core.questId == nil) end)
end
test("native contrast mode is preserved", function() W.Init(); W.contrast=true; W.Offer(92124); assert(normal() and W.writes==0) end)
test("enabling contrast during an offer removes tint", function() W.Init(); W.Offer(92124); W.contrast=true; QuestInfo_Display(QUEST_TEMPLATE_DETAIL,QuestDetailScrollChildFrame); assert(normal()) end)
test("quest log and reward rerenders cannot recolor offers", function() W.Init(); W.Offer(92124); local writes=W.writes; QuestInfo_Display({},QuestDetailScrollChildFrame); QuestInfo_Display(QUEST_TEMPLATE_DETAIL,{}); assert(W.writes==writes) end)
test("native nonwhite color and alpha are preserved on reset", function()
    W.Init(); local bg=QuestFrameDetailPanel.Bg; bg.color={.8,.7,.6,.4}; W.Offer(92124); assert(bg.color[4]==.4); W.Close(); assert(W.N.Model.SameColor(bg.color,{.8,.7,.6,.4}))
end)
test("later third-party color ownership is respected", function() W.Init(); W.Offer(92124); local bg=QuestFrameDetailPanel.Bg; bg.color={.5,.6,.7,.8}; W.Close(); assert(bg.color[1]==.5 and bg.color[4]==.8) end)
test("visible native alternate material regions are tinted and restored", function()
    W.Init(); QuestFrameDetailPanel.MaterialTopLeft.shown=true; W.Offer(92124); assert(QuestFrameDetailPanel.MaterialTopLeft.color[2]<1); W.Close(); assert(QuestFrameDetailPanel.MaterialTopLeft.color[1]==1)
end)
test("forbidden textures are left alone", function() W.Init(); QuestFrameDetailPanel.Bg.forbidden=true; W.Offer(92124); assert(W.writes==0) end)
test("secret texture color is left alone", function() W.Init(); QuestFrameDetailPanel.Bg.colorSecret=true; W.Offer(92124); assert(W.writes==0) end)
test("unavailable texture setter cannot abort native offer", function() W.Init(); QuestFrameDetailPanel.Bg.failWrite=true; W.Offer(92124); assert(W.N.Core.questId==92124) end)
test("temporarily blocked restoration is retried without compounding", function()
    W.Init(); W.Offer(92124); local bg=QuestFrameDetailPanel.Bg; local before=bg.color[1]; bg.failWrite=true; W.Close()
    assert(W.N.UI.owned[bg]); W.Offer(92124); assert(bg.color[1]==before); bg.failWrite=false; W.N.Core:Reset(); assert(normal() and not next(W.N.UI.owned))
end)
test("combat recovery restores old offer after a blocked setter", function()
    W.Init(); W.Offer(92124); local bg=QuestFrameDetailPanel.Bg; bg.failWrite=true; W.Offer(783)
    assert(tinted() and W.N.Core.questId==nil and W.N.UI.owned[bg]); bg.failWrite=false
    W.Event("PLAYER_REGEN_ENABLED"); assert(normal() and not next(W.N.UI.owned))
end)
test("combat recovery restores old offer after secret color readback", function()
    W.Init(); W.Offer(92124); local bg=QuestFrameDetailPanel.Bg; bg.colorSecret=true; W.Offer(783)
    assert(W.N.Core.questId==nil and W.N.UI.owned[bg]); bg.colorSecret=false
    W.Event("PLAYER_REGEN_ENABLED"); assert(normal() and not next(W.N.UI.owned))
end)
test("unreadable and malformed quest IDs restore old tint", function()
    W.Init(); W.Offer(92124); W.Offer(W.secret); assert(normal()); W.Offer("92124"); assert(normal()); W.Offer(0); assert(normal())
end)
test("throwing quest API restores safely", function() W.Init(); W.Offer(92124); GetQuestID=function() error("unavailable") end; W.N.Core:Refresh(); assert(normal()) end)
test("disable applies immediately and persists", function() W.Init(); W.Offer(92124); SlashCmdList.QUESTBRIEF("off"); assert(normal() and not QuestBriefDB.enabled); SlashCmdList.QUESTBRIEF("on"); assert(tinted()) end)
test("future SavedVariables are preserved and cannot be edited", function()
    local saved={version=9,enabled=false,preset="future"}; W.Init({saved=saved}); W.N.Core:Change("enabled",false); W.N.Core:Defaults(); W.Offer(92124)
    assert(QuestBriefDB==saved and saved.preset=="future" and W.N.Core.readOnly and not tinted())
end)
test("unsupported interface never attaches native hooks", function() W.Init({interface=120001}); W.Offer(92124); assert(not tinted() and not next(W.hooks)) end)
test("startup in combat defers hook attachment", function()
    W.Init({combat=true}); assert(not next(W.hooks)); W.combat=false; W.Event("PLAYER_REGEN_ENABLED"); W.Offer(92124); assert(tinted())
end)
test("cosmetic reset during combat avoids protected mutations", function() W.Init(); W.Offer(92124); W.combat=true; W.Offer(783); assert(normal() and W.nativeMutations==0) end)
test("late native addon load attaches hooks once", function()
    W.Reset(); QuestFrameDetailPanel=nil; W.Event("ADDON_LOADED","QuestBrief"); assert(not W.N.Core.hooked)
    QuestFrameDetailPanel=W.Object(true); QuestFrameDetailPanel.Bg=W.Object(true); W.Event("ADDON_LOADED","Blizzard_UIPanels_Game"); assert(W.N.Core.hooked); W.Event("PLAYER_LOGIN"); assert(W.hooks.QuestInfo_Display==1)
end)
test("settings match appearance and remain lazy/cached", function()
    W.Init(); assert(#W.frames==1); SlashCmdList.QUESTBRIEF("opts"); local O=W.N.Options; assert(O.frame.template=="BackdropTemplate" and O.frame.width==540)
    O.keys.CTRL:Fire("OnClick"); assert(QuestBriefDB.modifier=="CTRL"); O.sliders.strength:SetValue(80); assert(QuestBriefDB.strength==.8)
    local count=#W.frames; SlashCmdList.QUESTBRIEF(""); SlashCmdList.QUESTBRIEF(""); assert(#W.frames==count)
end)
test("settings fall back when optional Expressway font is unavailable", function()
    W.Init(); W.missingFont="missing.ttf"; LibStub=function() return {IsValid=function() return true end,Fetch=function() return "missing.ttf" end} end
    SlashCmdList.QUESTBRIEF(""); assert(W.N.Options.texts[1].object:GetFont()==STANDARD_TEXT_FONT)
end)
test("settings fit small screens and opening in combat is deferred", function()
    W.Init(); W.combat=true; SlashCmdList.QUESTBRIEF(""); assert(not W.N.Options.frame); W.combat=false; UIParent.width=640; UIParent.height=360; SlashCmdList.QUESTBRIEF("")
    assert(W.N.Options.frame.scale<=336/426)
end)
test("native quest text font and native frame geometry are untouched", function()
    W.Init(); local path,size=QuestInfoDescriptionText:GetFont(); W.Offer(92124); assert(QuestInfoDescriptionText:GetFont()==path and W.nativeMutations==0 and not QuestInfoDescriptionText.fontWrites)
end)

local api=ROOT .. "/.work/blizzard/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua"
local file=io.open(api,"rb")
if file then file:close()
    test("actual pinned Forever detail renderer and material setter integrate", function()
        W.Reset(); assert(loadfile(api))()
        QuestFrameDetailPanel.scripts.OnShow = QuestFrameDetailPanel_OnShow
        for _,key in ipairs({"QuestFrameRewardPanel","QuestFrameProgressPanel","QuestFrameGreetingPanel","QuestFrameDeclineButton","QuestFrameCloseButton","QuestFrameAcceptButton"}) do _G[key]=W.Object() end
        QuestGetAutoAccept=function() return false end; InputUtil={IsGamepadUIEnabled=function() return false end}
        GetQuestBackgroundMaterial=function() return nil end; GetQuestPortraitGiver=function() return 0 end; QuestFrame_HideQuestPortrait=function() end
        QuestDetailScrollFrame={ScrollBar={ScrollToBegin=function() end}}; QuestInfo_HideAlphaDependentText=function() end; GetCVar=function() return "1" end
        -- Blizzard itself owns these protected visibility calls. Other scenarios
        -- keep the strict native mutation guard active for addon callbacks.
        for _,key in ipairs({"MaterialTopLeft","MaterialTopRight","MaterialBotLeft","MaterialBotRight"}) do QuestFrameDetailPanel[key].native=false end
        W.Event("ADDON_LOADED","QuestBrief"); W.Offer(92124); assert(tinted() and QuestFrameDetailPanel.Bg.atlas=="QuestBG-Parchment")
        W.Offer(783); assert(normal()); assert(QuestFrameDetailPanel.fadingProgress==1024)
    end)
end

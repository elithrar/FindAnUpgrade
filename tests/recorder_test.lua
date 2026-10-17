local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn();PASSED=PASSED+1;print("PASS "..name) end
local function setup(saved,profile)
    local N=W.Reset({observations=saved,saved=profile});W.jobs={};W.reads=0;W.rewardVisible=true;W.title="A quest";W.rewardCount=1;W.choiceCount=2
    GetBuildInfo=function()return "1.60.1","70425","2026-10-15",16001 end
    GetLocale=function()return "enUS" end;UnitName=function()return "Matt","MONOLITH" end
    W.npcGuid="Creature-0-1-2-3-12345-0000000001"
    C_QuestLog.GetTitleForQuestID=function()return W.title end
    C_QuestLog.GetQuestDifficultyLevel=function()return 24 end
    C_QuestLog.ShouldShowQuestRewards=function()return W.rewardVisible end
    GetNumQuestRewards=function()W.reads=W.reads+1;return W.rewardCount end
    GetNumQuestChoices=function()return W.choiceCount end
    GetQuestItemInfoLootType=function(_,i)return i==2 and 1 or 0 end
    GetQuestItemInfo=function(kind,i)
        W.reads=W.reads+1
        if W.missingItem then return nil,nil,nil,nil,nil,nil end
        return nil,nil,kind=="reward" and 3 or 1,2,true,kind=="reward" and 90001 or 90002,4
    end
    C_QuestOffer={GetQuestRewardCurrencyInfo=function()return {currencyID=55,totalRewardAmount=8,questRewardContextFlags=2} end}
    GetRewardXP=function()return 900 end;GetRewardMoney=function()return 0 end
    QuestFrameRewardPanel=W.Object(true)
    C_Map={GetBestMapForUnit=function()return 1429 end,GetPlayerMapPosition=function()return {GetXY=function()return .48123,.42876 end} end}
    C_Timer={NewTimer=function(delay,fn)
        local job={delay=delay,fn=fn};function job:Cancel()self.cancelled=true end
        W.jobs[#W.jobs+1]=job;return job
    end}
    W.Event("ADDON_LOADED","FindAnUpgrade");return N
end
local function pending()local count=0;for _,job in ipairs(W.jobs)do if not job.cancelled and not job.done then count=count+1 end end;return count end
local function tick()
    for _,job in ipairs(W.jobs)do
        if not job.cancelled and not job.done then job.done=true;job.fn();return end
    end
end
local function open(N,id)W.quest=id or 99999;N.Recorder:Enable(true);W.Event("QUEST_DETAIL")end
local function last(N)return N.ObservationData.db.records[#N.ObservationData.db.records]end

test("default consent registers no collector events and performs no native reward reads",function()
    local N=setup();W.quest=99999;W.Event("QUEST_DETAIL");W.Event("GOSSIP_SHOW")
    assert(not N.Recorder.active and not N.Recorder.events and W.reads==0 and pending()==0)
    assert(#FindAnUpgradeObservations.records==0 and FindAnUpgradeObservations.enabled==false)
end)
test("turning the addon off pauses recording and appearance reset never clears observations",function()
    local N=setup();open(N);N.Core:Change("enabled",false)
    assert(not N.Recorder.active and not FindAnUpgradeObservations.enabled and pending()==0)
    N.Core:Change("enabled",true);assert(not N.Recorder.active and #FindAnUpgradeObservations.records==1)
    N.Recorder:Enable(true);N.Core:Defaults()
    assert(N.Recorder.active and FindAnUpgradeObservations.enabled and #FindAnUpgradeObservations.records==1)
end)
test("global off still honors recording consent when appearance settings are read-only",function()
    local saved={version=99,enabled=true,future="preserve"};local N=setup(nil,saved);open(N);N.Options:Toggle(N.Core)
    N.Core:Slash("off")
    assert(FindAnUpgradeDB==saved and saved.future=="preserve" and saved.enabled==true)
    assert(not N.Recorder.active and not FindAnUpgradeObservations.enabled and pending()==0 and not N.Options.record:GetChecked())
end)
test("disabled addon cannot restore or restart recording without a separate opt-in after enabling",function()
    local N=setup();open(N);local saved=N.Model.Copy(FindAnUpgradeObservations)
    N=setup(saved,{enabled=false});assert(not N.Recorder.active and not FindAnUpgradeObservations.enabled)
    N.Recorder:Enable(true);assert(not N.Recorder.active and not FindAnUpgradeObservations.enabled)
    N.Options:Toggle(N.Core);assert(N.Options.record.disabled and #FindAnUpgradeObservations.records==1)
    N.Core:Change("enabled",true);assert(not N.Recorder.active)
    N.Recorder:Enable(true);assert(N.Recorder.active)
end)
test("native dialog facts precede published fallback and preserve mixed choices and quantities",function()
    local N=setup();N.Rewards.Read=function()error("published display fallback entered recorder")end;open(N,6)
    local row=last(N);assert(row.questID==6 and row.client.build==70425 and row.client.locale=="enUS")
    assert(row.source.kind=="npc" and row.source.id==12345 and row.source.role=="starter")
    assert(row.location.kind=="observer" and row.location.uiMapID==1429 and row.location.x==.4812)
    assert(row.context.faction=="Alliance" and row.context.classID==1 and row.context.raceID==1 and row.context.level==20)
    assert(row.rewards.guaranteed.slots[1].id==90001 and row.rewards.guaranteed.slots[1].quantity==3)
    assert(row.rewards.choices.choose==1 and row.rewards.choices.expected==2)
    assert(row.rewards.choices.slots[1].slot==1 and row.rewards.choices.slots[1].kind=="item")
    assert(row.rewards.choices.slots[2].slot==2 and row.rewards.choices.slots[2].kind=="currency" and row.rewards.choices.slots[2].quantity==8)
    assert(row.rewards.choices.slots[2].contextFlags==2 and row.rewards.choices.slots[1].contextFlags==4)
    assert(row.rewards.money.state=="ready" and row.rewards.money.value==0 and row.rewards.otherRewards=="unknown")
end)
test("hidden or unavailable rewards remain unknown while verified empty enumerations stay empty",function()
    local N=setup();W.rewardVisible=false;W.rewardCount=0;W.choiceCount=0;open(N)
    assert(last(N).rewards.guaranteed.state=="unknown" and W.reads==0)
    W.rewardVisible=true;tick();local row=last(N)
    assert(row.rewards.guaranteed.state=="ready" and row.rewards.guaranteed.expected==0)
    assert(row.rewards.choices.state=="ready" and row.rewards.choices.choose==0)
    assert(N.ObservationData:Export():find('"slots":[]',1,true))
    GetNumQuestRewards=function()return W.secret end;tick();assert(last(N).rewards.guaranteed.state=="unknown")
end)
test("delayed item metadata preserves holes then enriches the same native slot",function()
    local N=setup();W.missingItem=true;open(N)
    assert(last(N).rewards.guaranteed.state=="partial" and last(N).rewards.guaranteed.slots[1].state=="unknown")
    assert(last(N).rewards.guaranteed.expected==1 and pending()==1)
    W.missingItem=false;W.Event("QUEST_ITEM_UPDATE");W.Event("ITEM_DATA_LOAD_RESULT",90001,true)
    assert(pending()==1);tick();assert(last(N).rewards.guaranteed.state=="ready")
end)
test("native frame may become visible after the recorder receives QUEST_DETAIL",function()
    local N=setup();QuestFrame.shown=false;open(N)
    assert(#FindAnUpgradeObservations.records==0 and W.reads==0 and pending()==1)
    QuestFrame.shown=true;tick();assert(last(N).questID==99999 and last(N).rewards.guaranteed.state=="ready")
end)
test("unrelated addon loads leave native dialog settling intact",function()
    local N=setup();W.missingItem=true;open(N);local dialog=N.Recorder.dialog
    assert(not N.Recorder.events.events.ADDON_LOADED)
    W.Event("ADDON_LOADED","UnrelatedAddon")
    assert(N.Recorder.dialog==dialog and pending()==1)
    W.missingItem=false;tick();assert(last(N).rewards.guaranteed.state=="ready")
    W.Event("QUEST_FINISHED");assert(pending()==0)
end)
test("rapid A to B dialogs cancel old jobs including same-ID reacceptance",function()
    local N=setup();open(N,99990);local old=W.jobs[1];W.quest=99991;W.Event("QUEST_DETAIL")
    assert(old.cancelled and pending()==1);local count=#FindAnUpgradeObservations.records;old.fn()
    assert(#FindAnUpgradeObservations.records==count and last(N).questID==99991)
    local prior=N.Recorder.dialog;W.Event("QUEST_DETAIL");assert(N.Recorder.dialog~=prior and pending()==1)
    local reads=W.reads;W.Event("QUEST_FINISHED");tick();assert(W.reads==reads and pending()==0)
end)
test("NPC context is immutable and target switches never supply a giver",function()
    local N=setup();open(N);W.guid="Creature-0-1-2-3-999-0";tick()
    assert(last(N).source.id==12345)
    local count=#FindAnUpgradeObservations.records;W.npcGuid="Creature-0-1-2-3-54321-0";tick()
    assert(#FindAnUpgradeObservations.records==count and pending()==0)
    W.npcGuid=nil;W.Event("QUEST_DETAIL");assert(last(N).source.kind=="unknown")
end)
test("synchronous dialog crossover cannot attach B rewards to A",function()
    local N=setup();local original=GetQuestItemInfo
    GetQuestItemInfo=function(...)W.quest=99991;return original(...)end
    open(N,99990);assert(#FindAnUpgradeObservations.records==0 and pending()==0)
end)
test("Forever QUEST_DETAIL item payload and QUEST_ACCEPTED single ID are distinct",function()
    local N=setup();N.Recorder:Enable(true);W.quest=99999;W.Event("QUEST_DETAIL",34567)
    assert(last(N).questID==99999 and last(N).source.kind=="item" and last(N).source.id==34567)
    W.Event("QUEST_ACCEPTED",99999)
    assert(last(N).stage=="accepted" and last(N).source.kind=="item" and last(N).rewards.choices.state=="unknown" and pending()==0)
    W.Event("QUEST_ACCEPTED",88888);assert(last(N).questID==88888 and last(N).source.kind=="unknown")
end)
test("completion options do not imply chosen rewards or an actual turn-in",function()
    local N=setup();N.Recorder:Enable(true);W.quest=99999;W.Event("QUEST_COMPLETE")
    assert(last(N).stage=="completion" and last(N).source.role=="ender" and last(N).rewards.choices.expected==2)
    W.Event("QUEST_TURNED_IN",99999,123,456)
    assert(last(N).stage=="turned_in" and last(N).source.role=="ender" and last(N).rewards.choices.state=="unknown")
    assert(last(N).rewards.xp.value==123 and last(N).rewards.money.value==456)
end)
test("native lifecycle events deduplicate without deferred reward reads",function()
    local N=setup();N.Recorder:Enable(true)
    for i=1,2 do W.Event("QUEST_ACCEPTED",99999) end
    for i=1,2 do W.Event("QUEST_TURNED_IN",99999,123,456) end
    local rows=FindAnUpgradeObservations.records
    assert(#rows==2 and rows[1].stage=="accepted" and rows[2].stage=="turned_in")
    assert(rows[1].samples==2 and rows[2].samples==2 and rows[2].rewards.xp.value==123)
    assert(rows[1].rewards.choices.state=="unknown" and rows[2].rewards.choices.state=="unknown")
    assert(pending()==0 and W.reads==0)
end)
test("gossip availability records typed NPC roles and bounded exact IDs",function()
    local N=setup();N.Recorder:Enable(true)
    C_GossipInfo={GetAvailableQuests=function()return {{questID=99999},{questID=W.secret},{questID=88888}} end,
        GetActiveQuests=function()return {{questID=77777}} end}
    W.Event("GOSSIP_SHOW");assert(#FindAnUpgradeObservations.records==3)
    assert(FindAnUpgradeObservations.records[1].source.role=="starter" and last(N).source.role=="unknown")
    assert(last(N).stage=="listed_active" and last(N).rewards.guaranteed.state=="unknown")
end)
test("privacy allowlist redacts own title name before storage and excludes identity/prose",function()
    local N=setup();W.title='MATT\226\128\153s "quest"';open(N)
    local row=last(N);assert(row.titleState=="redacted" and not row.title:find("MATT",1,true))
    row.guid="Player-private";row.account="private";row.context.name="Matt";row.rewards.chat="private"
    local export=N.ObservationData:Export()
    assert(not export:find("Player-private",1,true) and not export:find("private",1,true) and not export:find("MONOLITH",1,true))
    W.title="|Hplayer:Matt|hMatt|h";W.Event("QUEST_DETAIL");assert(last(N).titleState=="unknown")
end)
test("malformed, restricted and absent native data fail closed",function()
    local N=setup();GetQuestItemInfo=function()return W.secret,nil,1,2,true,123 end
    GetQuestItemInfoLootType=nil;C_Map.GetPlayerMapPosition=function()return nil end;UnitName=function()return W.secret end
    open(N);assert(last(N).titleState=="unknown" and not last(N).location.x)
    assert(last(N).rewards.guaranteed.state=="partial" and last(N).rewards.choices.state=="partial")
end)
test("retry budget and pending job count stay bounded during event storms and stop on consent revocation",function()
    local N=setup();W.missingItem=true;open(N)
    for i=1,1000 do W.Event("QUEST_ITEM_UPDATE");W.Event("QUEST_DATA_LOAD_RESULT",99999,true) end
    assert(pending()==1);for i=1,20 do tick()end
    assert(N.Recorder.dialog.attempts==8 and pending()==0 and W.reads==24)
    W.Event("QUEST_DETAIL");N.Recorder:Enable(false);local reads=W.reads;tick()
    assert(pending()==0 and not next(N.Recorder.events.events) and W.reads==reads)
    W.Event("QUEST_DETAIL");assert(W.reads==reads and not N.Recorder.events:GetScript("OnUpdate"))
end)
test("identical encounters deduplicate while changed rewards remain separate evidence",function()
    local N=setup();open(N);W.Event("QUEST_DETAIL");assert(#FindAnUpgradeObservations.records==1 and last(N).samples==2)
    W.rewardCount=0;W.Event("QUEST_DETAIL");assert(#FindAnUpgradeObservations.records==2)
    local saved=N.Model.Copy(FindAnUpgradeObservations);N=setup(saved)
    assert(#FindAnUpgradeObservations.records==2 and N.Recorder.active)
end)
test("record and byte caps pause without deleting evidence and clear leaves consent off",function()
    local N=setup();open(N);local D=N.ObservationData;D.limit=2
    W.quest=99998;W.Event("QUEST_DETAIL");W.quest=99997;W.Event("QUEST_DETAIL")
    assert(#D.db.records==2 and D.db.dropped==1 and D.full and not N.Recorder.active and pending()==0)
    local export=D:Export();assert(#export<D.byteLimit);N.Recorder:Clear();assert(#D.db.records==0 and not D.db.enabled and not D.full)
    D.byteLimit=1100;open(N);assert(#D.db.records==0 and D.full and not N.Recorder.active)
end)
test("variant cap, future schema and corrupted saved observations cannot silently resume",function()
    local N=setup();open(N);N.ObservationData.variantLimit=1;W.rewardCount=0;W.Event("QUEST_DETAIL")
    assert(N.ObservationData.full and #FindAnUpgradeObservations.records==1)
    local saved={schema=99,enabled=true,records={{private="preserve"}}};N=setup(saved)
    assert(FindAnUpgradeObservations==saved and not N.Recorder.active and not N.ObservationData:Export())
    N.Recorder:Clear();assert(FindAnUpgradeObservations==saved)
    N=setup({schema=1,enabled=true,records={{questID=-1}}});assert(not N.Recorder.active and FindAnUpgradeObservations.dropped==1)
end)
test("unsupported event registration and missing cancellable timers fail safely",function()
    local N=setup();local create=CreateFrame
    CreateFrame=function(...)
        local f=create(...);local register=f.RegisterEvent
        f.RegisterEvent=function(self,event)if event=="QUEST_DETAIL"then error("unsupported")end;return register(self,event)end
        return f
    end
    N.Recorder:Enable(true);assert(not N.Recorder.active and not next(N.Recorder.events.events))
    N=setup();C_Timer=nil;open(N);assert(#FindAnUpgradeObservations.records==1 and pending()==0)
end)
test("options consent clear and native manual export reuse one integrated view",function()
    local N=setup();N.Options:Toggle(N.Core);local O=N.Options
    O.record:SetChecked(true);O.record:Fire("OnClick");assert(N.Recorder.active)
    W.quest=99999;W.Event("QUEST_DETAIL");O.export:Fire("OnClick")
    assert(O.exportMode and not O.scroll:IsShown() and O.exportEditor.template=="InputScrollFrameTemplate")
    assert(O.exportEditor.EditBox:GetText()==N.ObservationData:Export() and O.exportEditor.EditBox.focused)
    local frames=#W.frames;O.exportEditor.EditBox:Fire("OnEscapePressed");O.export:Fire("OnClick");assert(#W.frames==frames)
    O.frame:Hide();assert(not O.exportMode and not O.exportEditor.EditBox.focused and O.exportEditor.EditBox:GetText()=="")
    O:Toggle(N.Core);O.clear:Fire("OnClick");assert(#FindAnUpgradeObservations.records==1)
    O.clear:Fire("OnClick");assert(#FindAnUpgradeObservations.records==0 and not N.Recorder.active)
end)

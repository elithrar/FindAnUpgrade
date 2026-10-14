local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function complete(N)
    local O=N.Options
    assert(O.frame and O.frame:IsShown() and O.content:IsShown())
    assert(O.texts[1].object:GetText()=="QuestBrief" and O.status)
    assert(count(O.checks)==8 and #O.dropdowns==1 and count(O.sliders)==2 and count(O.edits)==2)
    for _,entry in ipairs(O.texts) do assert(entry.object:GetFont()) end
    assert(#UISpecialFrames==1 and UISpecialFrames[1]=="QuestBriefOptions")
end

test("bare native FontStrings do not acquire a font from the mock",function()
    W.Reset()
    local text=UIParent:CreateFontString(nil,"OVERLAY")
    assert(text:GetFont()==nil)
    local ok,err=pcall(text.SetText,text,"Uninitialized")
    assert(not ok and err:find("Font not set",1,true))
    text:SetFontObject(GameFontNormal); text:SetText("Initialized")
    assert(text:GetText()=="Initialized")
    local inherited=UIParent:CreateFontString(nil,"OVERLAY","GameTooltipText")
    inherited:SetText("Inherited"); assert(inherited:GetFont()==STANDARD_TEXT_FONT)
    assert(inherited:GetStringHeight()==12 and inherited:GetStringWidth()>0)
    inherited:SetFontObject(GameTooltipHeaderText); assert(inherited:GetStringHeight()==14)
    inherited:SetText(""); assert(inherited:GetStringHeight()==0 and inherited:GetStringWidth()==0)
end)

test("slash options constructs complete controls with native font preconditions",function()
    local N=W.Init(); local saved=QuestBriefDB
    assert(not N.Options.frame)
    SlashCmdList.QUESTBRIEF("opts"); complete(N)
    assert(QuestBriefDB==saved)
    local frames=#W.frames
    SlashCmdList.QUESTBRIEF("options"); assert(not N.Options.frame:IsShown())
    SlashCmdList.QUESTBRIEF(""); complete(N); assert(#W.frames==frames)
end)

test("first label failure leaves no blank options and retry reuses the named shell",function()
    local N=W.Init(); local saved=QuestBriefDB; local original=N.UI.Font; local failed=false
    N.UI.Font=function(self,object,size)
        if object.isFontString and not failed then failed=true; error("Transient font failure") end
        return original(self,object,size)
    end
    local ok,err=pcall(SlashCmdList.QUESTBRIEF,"opts")
    assert(not ok and err:find("Transient font failure",1,true))
    local shell=N.Options.shell
    assert(shell and not shell:IsShown() and not N.Options.frame and #UISpecialFrames==0)
    assert(#N.Options.texts==0 and not next(N.UI.fontSizes or {}))
    assert(QuestBriefDB==saved and not next(shell.events))
    SlashCmdList.QUESTBRIEF("opts"); complete(N)
    assert(N.Options.frame==shell and QuestBriefDB==saved)
    local named=0; for _,f in ipairs(W.frames) do if f.name=="QuestBriefOptions" then named=named+1 end end
    assert(named==1)
end)

test("late construction failure removes handlers and font ownership before retry",function()
    local N=W.Init(); local original=CreateFrame; local shell; local failed=false
    CreateFrame=function(kind,name,parent,template)
        local f=original(kind,name,parent,template)
        if name=="QuestBriefOptions" then
            shell=f; local register=f.RegisterEvent
            f.RegisterEvent=function(self,event)
                if event=="DISPLAY_SIZE_CHANGED" and not failed then failed=true; error("Transient event registration failure") end
                return register(self,event)
            end
        end
        return f
    end
    local ok,err=pcall(SlashCmdList.QUESTBRIEF,"opts")
    assert(not ok and err:find("Transient event registration failure",1,true))
    assert(not N.Options.frame and not shell:IsShown() and not next(shell.events))
    assert(not shell:GetScript("OnShow") and not shell:GetScript("OnEvent"))
    assert(not next(N.UI.fontSizes) and not next(N.UI.fontApplications))
    for _,f in ipairs(W.frames) do if f.parent==shell then assert(not f:IsShown()) end end
    SlashCmdList.QUESTBRIEF("opts"); complete(N)
    assert(shell.events.UI_SCALE_CHANGED and shell.events.DISPLAY_SIZE_CHANGED)
end)

test("unavailable path fonts fall back to the native font object before text",function()
    local N=W.Init(); W.missingFont=STANDARD_TEXT_FONT
    SlashCmdList.QUESTBRIEF("opts"); complete(N)
    for _,entry in ipairs(N.Options.texts) do
        assert(entry.object:GetFont()==STANDARD_TEXT_FONT)
        assert(entry.object.fontObject==GameFontNormal)
    end
end)

test("programmatic refresh preserves settings and controls bind the current profile",function()
    local N=W.Init(); SlashCmdList.QUESTBRIEF("opts"); local O=N.Options
    local saved=QuestBriefDB
    O:Refresh(); W.Event("UI_SCALE_CHANGED"); W.Event("DISPLAY_SIZE_CHANGED")
    assert(QuestBriefDB==saved and not O.refreshing)
    O.modifier.menu.entries[2].callback(); assert(N.Core.profile~=saved and N.Core.profile.modifier=="CTRL")
    O.sliders.strength:SetValue(80); assert(N.Core.profile.strength==.8)
    O.frame:Hide(); N.Core:Change("modifier","ALT"); SlashCmdList.QUESTBRIEF("opts")
    assert(O.modifier.Text:GetText()=="Alt" and O.sliders.strength.value==80)
end)

test("future settings remain read-only through the real options controls",function()
    local saved={version=99,enabled=false,future="preserve"}; local N=W.Init({saved=saved})
    SlashCmdList.QUESTBRIEF("opts"); complete(N)
    N.Options.modifier.menu.entries[3].callback(); N.Options.checks.enabled:SetChecked(true)
    N.Options.checks.enabled:Fire("OnClick"); N.Options.sliders.scale:SetValue(120)
    assert(QuestBriefDB==saved and saved.future=="preserve" and saved.enabled==false)
    assert(N.Options.status:GetText()=="Newer settings are read-only.")
    for _,control in ipairs(N.Options.controls) do assert(control.disabled) end
end)

test("options use current XPIsland dialog sections and native radio dropdown",function()
    local N=W.Init(); SlashCmdList.QUESTBRIEF("opts"); local O=N.Options
    assert(O.frame:GetWidth()==620 and O.frame:GetHeight()==398)
    assert(O.frame.backdrop.edgeFile=="Interface\\DialogFrame\\UI-DialogBox-Border" and O.frame.backdrop.edgeSize==16)
    assert(O.frame.backdrop.insets.left==4 and O.frame.backdropColor[4]==.94)
    assert(#O.sections==2 and O.sections[1].point[2]==16 and O.sections[2].point[2]==316)
    assert(O.sections[1]:GetWidth()==288 and O.sections[2]:GetWidth()==288)
    assert(O.modifier.template=="WowStyle1DropdownTemplate" and O.modifier:GetWidth()==260 and O.modifier:GetHeight()==24)
    assert(O.modifier.Text.justifyV=="MIDDLE" and O.modifier.Text.point[1]=="LEFT")
    assert(O.modifier.Text.point[4]*O.modifier.Text:GetScale()==9 and O.modifier.Text.qOptionsWidth==229)
    assert(O.modifier.menu.scrollHeight==220 and #O.modifier.menu.entries==4)
    assert(O.modifier.menu.entries[1].checked() and O.modifier.Text:GetText()=="Shift")
    for _,row in ipairs(O.modifier.menu.entries) do assert(row.fontObject==O.menuFont) end
    assert(O.reset:GetHeight()==22 and O.reset.text.point[1]=="CENTER")
    assert(O.status:GetText()=="")
end)

test("native numeric fields clamp on Enter and restore without writes on Escape",function()
    local N=W.Init(); SlashCmdList.QUESTBRIEF("opts"); local O=N.Options; local e=O.edits.scale
    assert(e.template=="InputBoxTemplate" and e:GetWidth()==58 and e:GetHeight()==22)
    assert(O.sliders.scale:GetWidth()==180 and O.sliders.scale:GetHeight()==16)
    e:SetFocus(); e:SetText("999"); e:Fire("OnEnterPressed")
    assert(N.Core.profile.scale==1.2 and e:GetText()=="120" and not e.focused)
    local saved=QuestBriefDB; e:SetFocus(); e:SetText("81"); e:Fire("OnEscapePressed")
    assert(QuestBriefDB==saved and e:GetText()=="120" and not e.focused)
    e:SetText("invalid"); e:Fire("OnEnterPressed"); assert(N.Core.profile.scale==1.2 and e:GetText()=="120")
    local strength=O.edits.strength; strength:SetText("-40"); strength:Fire("OnEnterPressed")
    assert(N.Core.profile.strength==.1 and strength:GetText()=="10")
end)

test("closing options clears native menus and numeric field focus",function()
    local N=W.Init(); SlashCmdList.QUESTBRIEF("opts"); local O=N.Options
    O.modifier.menuOpen=true; O.edits.scale:SetFocus(); O.edits.strength:SetFocus()
    O.close:Fire("OnClick")
    assert(not O.frame:IsShown() and not O.modifier.menuOpen and not O.edits.scale.focused and not O.edits.strength.focused)
    SlashCmdList.QUESTBRIEF("opts"); O.modifier.menuOpen=true; O.edits.scale:SetFocus(); O.frame:Hide()
    assert(not O.modifier.menuOpen and not O.edits.scale.focused)
end)

test("long native dropdown and checkbox text stays within allocated controls at fractional scale",function()
    local N=W.Init(); SlashCmdList.QUESTBRIEF("opts"); local O=N.Options
    UIParent.width=640; UIParent.height=360; UIParent:SetScale(.83)
    O.checks.worldmap.caption=string.rep("Long localized label ",5)
    local original=O.modifier.GenerateMenu
    O.modifier.GenerateMenu=function(self) original(self); self.Text:SetText(string.rep("Long localized modifier ",5)) end
    O:Refresh()
    assert(O.frame:GetScale()>=.3 and O.frame:GetScale()<=1)
    local text=O.modifier.Text
    assert(text:GetStringWidth()*text:GetScale()<=229)
    assert(text.point[4]*text:GetScale()==9 and text:GetHeight()*text:GetScale()==24)
    local caption=O.checks.worldmap.Text
    assert(caption:GetStringWidth()*caption:GetScale()<=250 and caption:GetHeight()*caption:GetScale()==24)
    assert(QuestBriefDB==N.Core.profile)
end)

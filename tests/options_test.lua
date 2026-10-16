local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function complete(N)
    local O=N.Options
    assert(O.frame and O.frame:IsShown() and O.content:IsShown())
    assert(O.texts[1].object:GetText()=="FindAnUpgrade" and O.status)
    assert(count(O.checks)==10 and #O.dropdowns==5 and count(O.sliders)==2 and count(O.edits)==4)
    for _,entry in ipairs(O.texts) do assert(entry.object:GetFont()) end
    assert(#UISpecialFrames==1 and UISpecialFrames[1]=="FindAnUpgradeOptions")
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
    local N=W.Init(); local saved=FindAnUpgradeDB
    assert(not N.Options.frame)
    SlashCmdList.FINDANUPGRADE("opts"); complete(N)
    assert(FindAnUpgradeDB==saved)
    local frames=#W.frames
    SlashCmdList.FINDANUPGRADE("options"); assert(not N.Options.frame:IsShown())
    SlashCmdList.FINDANUPGRADE("opts"); complete(N); assert(#W.frames==frames)
end)

test("first label failure leaves no blank options and retry reuses the named shell",function()
    local N=W.Init(); local saved=FindAnUpgradeDB; local original=N.UI.Font; local failed=false
    N.UI.Font=function(self,object,size)
        if object.isFontString and not failed then failed=true; error("Transient font failure") end
        return original(self,object,size)
    end
    local ok,err=pcall(SlashCmdList.FINDANUPGRADE,"opts")
    assert(not ok and err:find("Transient font failure",1,true))
    local shell=N.Options.shell
    assert(shell and not shell:IsShown() and not N.Options.frame and #UISpecialFrames==0)
    assert(#N.Options.texts==0 and not next(N.UI.fontSizes or {}))
    assert(FindAnUpgradeDB==saved and not next(shell.events))
    SlashCmdList.FINDANUPGRADE("opts"); complete(N)
    assert(N.Options.frame==shell and FindAnUpgradeDB==saved)
    local named=0; for _,f in ipairs(W.frames) do if f.name=="FindAnUpgradeOptions" then named=named+1 end end
    assert(named==1)
end)

test("late construction failure removes handlers and font ownership before retry",function()
    local N=W.Init(); local original=CreateFrame; local shell; local failed=false
    CreateFrame=function(kind,name,parent,template)
        local f=original(kind,name,parent,template)
        if name=="FindAnUpgradeOptions" then
            shell=f; local register=f.RegisterEvent
            f.RegisterEvent=function(self,event)
                if event=="DISPLAY_SIZE_CHANGED" and not failed then failed=true; error("Transient event registration failure") end
                return register(self,event)
            end
        end
        return f
    end
    local ok,err=pcall(SlashCmdList.FINDANUPGRADE,"opts")
    assert(not ok and err:find("Transient event registration failure",1,true))
    assert(not N.Options.frame and not shell:IsShown() and not next(shell.events))
    assert(not shell:GetScript("OnShow") and not shell:GetScript("OnEvent"))
    assert(not next(N.UI.fontSizes) and not next(N.UI.fontApplications))
    for _,f in ipairs(W.frames) do if f.parent==shell then assert(not f:IsShown()) end end
    local frames=#W.frames
    SlashCmdList.FINDANUPGRADE("opts"); complete(N)
    assert(#W.frames==frames,"construction retry leaked a scrollbar or content subtree")
    assert(shell.events.UI_SCALE_CHANGED and shell.events.DISPLAY_SIZE_CHANGED)
end)

test("repeated native scrollbar setup failures reuse the permanent slider",function()
    local clean=W.Init();clean.Options:Toggle(clean.Core);local expected=#W.frames
    local N=W.Init();local original=CreateFrame;local remaining=2;local scrollbar
    CreateFrame=function(kind,name,parent,template)
        local frame=original(kind,name,parent,template)
        if kind=="Slider" and template=="BackdropTemplate" then
            scrollbar=frame;local setThumb=frame.SetThumbTexture
            frame.SetThumbTexture=function(self,value)
                if remaining>0 then remaining=remaining-1;error("Transient native thumb failure") end
                return setThumb(self,value)
            end
        end
        return frame
    end
    for i=1,2 do
        local ok,err=pcall(SlashCmdList.FINDANUPGRADE,"opts")
        assert(not ok and err:find("Transient native thumb failure",1,true))
        assert(N.Options.bar==scrollbar and not N.Options.shell:IsShown() and not N.Options.frame)
    end
    SlashCmdList.FINDANUPGRADE("opts");complete(N)
    assert(N.Options.bar==scrollbar and #W.frames==expected)
    assert(scrollbar.thumb.texture=="Interface\\Buttons\\UI-SliderBar-Button-Vertical")
end)

test("unavailable path fonts fall back to the native font object before text",function()
    local N=W.Init(); W.missingFont=STANDARD_TEXT_FONT
    SlashCmdList.FINDANUPGRADE("opts"); complete(N)
    for _,entry in ipairs(N.Options.texts) do
        assert(entry.object:GetFont()==STANDARD_TEXT_FONT)
        assert(entry.object.fontObject==GameFontNormal)
    end
end)

test("programmatic refresh preserves settings and controls bind the current profile",function()
    local N=W.Init(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options
    local saved=FindAnUpgradeDB
    O:Refresh(); W.Event("UI_SCALE_CHANGED"); W.Event("DISPLAY_SIZE_CHANGED")
    assert(FindAnUpgradeDB==saved and not O.refreshing)
    O.modifier.menu.entries[2].callback(); assert(N.Core.profile~=saved and N.Core.profile.modifier=="CTRL")
    O.sliders.strength:SetValue(80); assert(N.Core.profile.strength==.8)
    O.frame:Hide(); N.Core:Change("modifier","ALT"); SlashCmdList.FINDANUPGRADE("opts")
    assert(O.modifier.Text:GetText()=="Alt" and O.sliders.strength.value==80)
end)

test("future settings remain read-only through the real options controls",function()
    local saved={version=99,enabled=false,future="preserve"}; local N=W.Init({saved=saved})
    SlashCmdList.FINDANUPGRADE("opts"); complete(N)
    N.Options.modifier.menu.entries[3].callback(); N.Options.checks.enabled:SetChecked(true)
    N.Options.checks.enabled:Fire("OnClick"); N.Options.sliders.scale:SetValue(120)
    assert(FindAnUpgradeDB==saved and saved.future=="preserve" and saved.enabled==false)
    assert(N.Options.status:GetText()=="Newer settings are read-only.")
    for _,control in ipairs(N.Options.controls) do assert(control.disabled==not control.navigation) end
end)

test("options use current XPIsland dialog sections and native radio dropdown",function()
    local N=W.Init(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options
    assert(O.frame:GetWidth()==620 and O.frame:GetHeight()==720)
    assert(O.frame.backdrop.edgeFile=="Interface\\DialogFrame\\UI-DialogBox-Border" and O.frame.backdrop.edgeSize==16)
    assert(O.frame.backdrop.insets.left==4 and O.frame.backdropColor[4]==.94)
    assert(#O.sections==5 and O.sections[1].point[2]==0 and O.sections[2].point[2]==292)
    assert(O.sections[1]:GetWidth()==280 and O.sections[2]:GetWidth()==280)
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
    local N=W.Init(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options; local e=O.edits.scale
    assert(e.template=="InputBoxTemplate" and e:GetWidth()==58 and e:GetHeight()==22)
    assert(O.sliders.scale:GetWidth()==180 and O.sliders.scale:GetHeight()==16)
    e:SetFocus(); e:SetText("999"); e:Fire("OnEnterPressed")
    assert(N.Core.profile.scale==1.2 and e:GetText()=="120" and not e.focused)
    local saved=FindAnUpgradeDB; e:SetFocus(); e:SetText("81"); e:Fire("OnEscapePressed")
    assert(FindAnUpgradeDB==saved and e:GetText()=="120" and not e.focused)
    e:SetText("invalid"); e:Fire("OnEnterPressed"); assert(N.Core.profile.scale==1.2 and e:GetText()=="120")
    local strength=O.edits.strength; strength:SetText("-40"); strength:Fire("OnEnterPressed")
    assert(N.Core.profile.strength==.1 and strength:GetText()=="10")
end)

test("closing options clears native menus and numeric field focus",function()
    local N=W.Init(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options
    O.modifier.menuOpen=true; O.edits.scale:SetFocus(); O.edits.strength:SetFocus()
    O.close:Fire("OnClick")
    assert(not O.frame:IsShown() and not O.modifier.menuOpen and not O.edits.scale.focused and not O.edits.strength.focused)
    SlashCmdList.FINDANUPGRADE("opts"); O.modifier.menuOpen=true; O.edits.scale:SetFocus(); O.frame:Hide()
    assert(not O.modifier.menuOpen and not O.edits.scale.focused)
end)

test("long native dropdown and checkbox text stays within allocated controls at fractional scale",function()
    local N=W.Init(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options
    UIParent.width=640; UIParent.height=360; UIParent:SetScale(.83)
    O.checks.worldmap.caption=string.rep("Long localized label ",5)
    local original=O.modifier.GenerateMenu
    O.modifier.GenerateMenu=function(self) original(self); self.Text:SetText(string.rep("Long localized modifier ",5)) end
    O:Refresh()
    assert(O.frame:GetScale()>=.3 and O.frame:GetScale()<=1)
    local text=O.modifier.Text
    assert(text:GetStringWidth()*text:GetScale()<=229)
    assert(math.abs(text.point[4]*text:GetScale()-9)<.00001 and math.abs(text:GetHeight()*text:GetScale()-24)<.00001)
    local caption=O.checks.worldmap.Text
    assert(caption:GetStringWidth()*caption:GetScale()<=240 and math.abs(caption:GetHeight()*caption:GetScale()-24)<.00001)
    assert(FindAnUpgradeDB==N.Core.profile)
end)

test("single options canvas keeps every setting together without navigation tabs",function()
    local N=W.Init();N.Options:Toggle(N.Core);local O=N.Options;local frames=#W.frames
    assert(not O.pages and not O.tabs and not O.page and not O.Page)
    assert(O.scroll.scrollChild==O.body and O.body.parent==O.scroll)
    for _,control in ipairs(O.controls) do
        assert(control.parent==O.body or control==O.reset)
        assert(not control.navigation)
    end
    assert(O.bar:GetThumbTexture().texture=="Interface\\Buttons\\UI-SliderBar-Button-Vertical")
    assert(O.maximum==0 and not O.bar:IsShown() and O.frame:GetScale()==1)
    for i=1,15 do O:Toggle(N.Core);O:Toggle(N.Core);O:Refresh() end
    assert(#W.frames==frames and O.font.menuGenerations==1)
end)

test("small-height options scroll at readable scale and keep footer outside the viewport",function()
    local N=W.Init();UIParent.width=960;UIParent.height=360;N.Options:Toggle(N.Core);local O=N.Options
    assert(O.frame:GetHeight()==336 and O.frame:GetScale()==1)
    assert(O.scroll:GetHeight()==246 and O.body:GetHeight()==630 and O.maximum==384 and O.bar:IsShown())
    assert(O.reset.parent==O.content and O.reset.point[1]=="BOTTOMLEFT" and O.reset.point[3]==16)
    local saved=FindAnUpgradeDB;O.font.menuOpen=true;O.edits.scale:SetFocus();O.edits.scale:SetText("81")
    O.scroll:Fire("OnMouseWheel",-1)
    assert(O.offset==40 and O.scroll:GetVerticalScroll()==40 and O.bar.value==40)
    assert(not O.font.menuOpen and not O.edits.scale.focused and O.edits.scale:GetText()=="100" and FindAnUpgradeDB==saved)
    O.bar:SetValue(10000);assert(O.offset==O.maximum and O.scroll:GetVerticalScroll()==384)
    O.scroll:Fire("OnMouseWheel",100);assert(O.offset==0 and O.bar.value==0)
    O:Scroll(384);O.modifier.menuOpen=true;O.edits.levelsBelow:SetFocus();O.edits.levelsBelow:SetText("99")
    UIParent.height=1080;W.Event("DISPLAY_SIZE_CHANGED")
    assert(O.frame:GetHeight()==720 and O.maximum==0 and O.offset==0 and not O.bar:IsShown())
    assert(not O.modifier.menuOpen and not O.edits.levelsBelow.focused and O.edits.levelsBelow:GetText()=="5")
    O:Scroll(0/0);O:Scroll(math.huge);assert(O.offset==0 and FindAnUpgradeDB==saved)
end)

test("scrolling and hidden refresh preserve read-only future settings and reuse controls",function()
    local saved={version=99,enabled=false,future="keep"};local N=W.Init({saved=saved})
    UIParent.height=360;N.Options:Toggle(N.Core);local O=N.Options;local frames=#W.frames
    for i=1,12 do O.scroll:Fire("OnMouseWheel",-1);O:Toggle(N.Core);O:Toggle(N.Core) end
    assert(#W.frames==frames and FindAnUpgradeDB==saved and saved.future=="keep" and O.offset==O.maximum)
    O.font.menuOpen=true;N.Core.profile.font="Arial";O:Refresh();assert(O.frame:GetScript("OnUpdate"))
    O.frame:Hide();assert(not O.frame:GetScript("OnUpdate") and not O.font.menuOpen and not O.menuWaiting)
end)

test("search-default edits validate through the model and do not persist transient search state",function()
    local N=W.Init();N.Options:Toggle(N.Core);local O=N.Options
    O.edits.levelsBelow:SetText("500");O.edits.levelsBelow:Fire("OnEnterPressed")
    assert(N.Core.profile.searchDefaults.levelsBelow==199 and O.edits.levelsBelow:GetText()=="199")
    O.edits.levelsAbove:SetText("-9");O.edits.levelsAbove:Fire("OnEnterPressed")
    assert(N.Core.profile.searchDefaults.levelsAbove==0 and N.Core.profile.searchDefaults.levelsBelow==199)
    O.checks.hideUnusable:SetChecked(false);O.checks.hideUnusable:Fire("OnClick")
    assert(not N.Core.profile.searchDefaults.hideUnusable and not FindAnUpgradeDB.query and not FindAnUpgradeDB.filter)
    local saved=FindAnUpgradeDB;O.edits.levelsBelow:SetText("20");O.edits.levelsBelow:Fire("OnEscapePressed")
    assert(FindAnUpgradeDB==saved and O.edits.levelsBelow:GetText()=="199")
    O.frame:Hide();N.Core:ChangeSearchDefault("includeDungeons",true);O:Toggle(N.Core)
    assert(O.checks.includeDungeons:GetChecked()==true and O.body:IsShown())
end)
test("font and border selections survive reload and reset restores persistent defaults",function()
    local N=W.Init();N.Options:Toggle(N.Core);local O=N.Options
    N.Core:Change("font","Arial");N.Core:Change("border","none");N.Core:ChangeSearchDefault("levelsAbove",17)
    local saved=N.Model.Copy(FindAnUpgradeDB)
    N=W.Init({saved=saved});N.Options:Toggle(N.Core);O=N.Options
    assert(O.font.Text:GetText()=="Arial" and O.border.Text:GetText()=="None" and O.edits.levelsAbove:GetText()=="17")
    O.reset:Fire("OnClick")
    assert(N.Core.profile.font=="Game tooltip" and N.Core.profile.border=="default" and N.Core.profile.searchDefaults.levelsAbove==3)
    assert(O.font.Text:GetText()=="Game tooltip (default)" and O.border.Text:GetText()=="Default")
end)
test("unchanged option refreshes preserve open native dropdown descriptions",function()
    local N=W.Init();N.Options:Toggle(N.Core);local O=N.Options;local generations=O.font.menuGenerations
    O.font.menuOpen=true
    for i=1,20 do O:Refresh();W.Event("UI_SCALE_CHANGED") end
    assert(O.font.menuOpen and O.font.menuGenerations==generations)
    N.Core:Change("font","Arial");assert(O.font.menuGenerations==generations and O.frame:GetScript("OnUpdate"))
    O.font.menuOpen=false;O.frame:Fire("OnUpdate")
    assert(O.font.menuGenerations==generations+1 and not O.frame:GetScript("OnUpdate") and O.font.Text:GetText()=="Arial")
end)

test("long Unicode font names keep role size and exact menu identity while selection abbreviates",function()
    local name=string.rep("\228\184\173",28)..string.rep("W",20)
    local N=W.Init({saved={font=name}});N.Options:Toggle(N.Core);local O=N.Options
    assert(N.Core.profile.font==name and O.font.Text:GetScale()==1 and O.font.Text:GetText():sub(-3)=="...")
    assert(O.fontMeasure:GetUnboundedStringWidth()+4<=O.font.Text.qOptionsWidth)
    local found=false
    for _,entry in ipairs(O.font.menu.entries) do if entry.value==name then assert(entry.label==name.." (unavailable)");found=true end end
    assert(found)
    local full=O.font.Text:GetText();O.font:GenerateMenu()
    assert(O.font.Text:GetText()==full and N.Core.profile.font==name)
end)

local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn(); PASSED=PASSED+1; print("PASS "..name) end
local function setup(mac)
    local N=W.Init(); local timers={}; W.meta=false; W.mac=mac==true; W.copies={}; W.nativeKeys=0
    IsMacClient=function()return W.mac end
    IsMetaKeyDown=function()return W.meta end
    CopyToClipboard=function()error("addon clipboard call")end
    C_Timer={After=function(delay,fn)assert(delay==0);timers[#timers+1]=fn end}
    local create=CreateFrame
    CreateFrame=function(kind,...)
        local f=create(kind,...)
        f.SetParent=function(self,parent)self.parent=parent end
        if kind=="EditBox" then
            f.HasFocus=function(self)return self.focused==true end
            f.HighlightText=function(self,first,last)
                self.selection={first or 0,last or #self:GetText()}
                self:Fire("OnCursorChanged",0,0,1,12)
            end
            f.scripts.OnEditFocusGained=function(self)self:HighlightText()end
            f.scripts.OnEditFocusLost=function(self)self:HighlightText(0,0)end
            f.SetFocus=function(self)
                if W.focus and W.focus~=self then W.focus:ClearFocus()end
                if not self.focused then self.focused=true; W.focus=self; self:Fire("OnEditFocusGained")end
            end
            f.ClearFocus=function(self)
                if self.focused then self.focused=false; if W.focus==self then W.focus=nil end; self:Fire("OnEditFocusLost")end
            end
            f.SetText=function(self,value)self.text=value;self:Fire("OnTextChanged",false)end
            f.scripts.OnKeyDown=function(self,key)
                W.nativeKeys=W.nativeKeys+1
                local chord=W.mac and W.meta and not W.ctrl or not W.mac and W.ctrl and not W.meta
                if key=="A" and chord and not W.alt and not W.shift then self:HighlightText()end
                if key=="C" and chord and not W.alt and not W.shift and self.selection then
                    W.copies[#W.copies+1]=self:GetText():sub(self.selection[1]+1,self.selection[2])
                end
            end
            f.scripts.OnKeyUp=function(self)assert(self:HasFocus() and self.parent:IsShown(),"native input lost focus before key-up")end
        end
        return f
    end
    if not N.Copy then assert(loadfile(ROOT.."/FindAnUpgrade/Copy.lua"))("FindAnUpgrade",N)end
    local parent=CreateFrame("Frame",nil,UIParent); parent:SetSize(476,680); parent:Show()
    local function drain()local batch=timers;timers={};for _,fn in ipairs(batch)do fn()end end
    return N.Copy,parent,drain,function()return #timers end
end
local function chord(copy,mac)
    W.ctrl=not mac;W.meta=mac==true;copy.edit:Fire("OnKeyDown","C");copy.edit:Fire("OnKeyUp","C")
end
test("Windows native copy keeps focus through key-up and closes on deferred delivery",function()
    local c,parent,drain,count=setup();assert(c:Show(parent,"https://example.test/?q=9"))
    assert(c.frame:GetWidth()==380 and c.frame:GetHeight()==90 and c.edit.template=="InputBoxTemplate")
    assert(c.label:GetText()=="Ctrl+C to copy" and c.edit:HasFocus())
    local native=c.edit:GetScript("OnKeyDown");chord(c)
    assert(W.copies[1]=="https://example.test/?q=9" and c.frame:IsShown() and c.edit:HasFocus() and count()==1)
    assert(c.edit:GetScript("OnKeyDown")==native and #c.edit.hooks.OnKeyDown==1)
    drain();assert(not c.frame:IsShown() and not c.edit:HasFocus() and not c.owner)
end)
test("Mac uses Command and ignores Windows Ctrl-only copy intent",function()
    local c,parent,drain,count=setup(true);c:Show(parent,"682")
    assert(c.label:GetText()=="Command+C to copy")
    W.ctrl=true;c.edit:Fire("OnKeyDown","C");c.edit:Fire("OnKeyUp","C");assert(count()==0 and c.frame:IsShown())
    c:Show(parent,"682");chord(c,true);assert(W.copies[1]=="682" and count()==1);drain();assert(not c.frame:IsShown())
end)
test("modifier release before C-up retains an unchanged genuine copy intent",function()
    for _,mac in ipairs({false,true})do
        local c,parent,drain,count=setup(mac);c:Show(parent,"A selected value")
        W.ctrl=not mac;W.meta=mac;c.edit:Fire("OnKeyDown","C");W.ctrl=false;W.meta=false
        c.edit:Fire("OnKeyUp","C");assert(count()==1 and c.frame:IsShown());drain();assert(not c.frame:IsShown())
    end
end)
test("wrong modifiers and absent key-down cannot dismiss",function()
    for _,variant in ipairs({"alt","shift","other-platform","no-modifier","keyup-only"})do
        local c,parent,drain,count=setup();c:Show(parent,"9");W.ctrl=true
        if variant=="alt"then W.alt=true elseif variant=="shift"then W.shift=true
        elseif variant=="other-platform"then W.ctrl=false;W.meta=true elseif variant=="no-modifier"then W.ctrl=false end
        if variant~="keyup-only"then c.edit:Fire("OnKeyDown","C")end
        c.edit:Fire("OnKeyUp","C");drain();assert(count()==0 and c.frame:IsShown(),variant)
    end
end)
test("repeated key delivery coalesces to one pending deferred dismissal",function()
    local c,parent,drain,count=setup();c:Show(parent,"9");W.ctrl=true
    for _=1,30 do c.edit:Fire("OnKeyDown","C");c.edit:Fire("OnKeyUp","C")end
    assert(count()==1 and c.frame:IsShown());drain();assert(not c.frame:IsShown())
end)
test("edits cursor selection changes focus and reuse cancel obsolete dismissal",function()
    for _,cancel in ipairs({
        function(c)c.edit:SetText("Changed")end,
        function(c)c.edit:Fire("OnCursorChanged",9,0,1,12)end,
        function(c)c.edit:Fire("OnMouseDown","LeftButton")end,
        function(c)c.edit:ClearFocus()end,
        function(c,parent)c:Show(parent,"New generation")end,
        function(c)c.edit:Fire("OnKeyDown","LEFT")end,
    })do
        local c,parent,drain=setup();c:Show(parent,"Old value");chord(c);cancel(c,parent);drain();assert(c.frame:IsShown())
    end
end)
test("partial selection copies natively then dismisses after unchanged platform copy intent",function()
    for _,mac in ipairs({false,true})do
        local c,parent,drain,count=setup(mac);c:Show(parent,"Selected text")
        c.edit:Fire("OnMouseDown","LeftButton");c.edit:HighlightText(0,8);chord(c,mac)
        assert(W.copies[1]=="Selected" and count()==1 and c.frame:IsShown());drain();assert(not c.frame:IsShown())
    end
end)
test("native select-all followed by copy preserves input and deferred dismissal",function()
    for _,mac in ipairs({false,true})do
        local c,parent,drain,count=setup(mac);c:Show(parent,"Selected text")
        c.edit:Fire("OnMouseDown","LeftButton");c.edit:HighlightText(0,8)
        W.ctrl=not mac;W.meta=mac;c.edit:Fire("OnKeyDown","A");c.edit:Fire("OnKeyUp","A");chord(c,mac)
        assert(W.copies[1]=="Selected text" and count()==1 and c.frame:IsShown());drain();assert(not c.frame:IsShown())
    end
end)
test("selection changes after C-down cancel dismissal before key-up or deferred delivery",function()
    for _,beforeKeyUp in ipairs({false,true})do
        local c,parent,drain,count=setup();c:Show(parent,"Selected text");W.ctrl=true
        c.edit:Fire("OnKeyDown","C")
        if not beforeKeyUp then c.edit:Fire("OnKeyUp","C")end
        c.edit:Fire("OnMouseDown","LeftButton");c.edit:HighlightText(0,8)
        if beforeKeyUp then c.edit:Fire("OnKeyUp","C")end
        assert(count()==(beforeKeyUp and 0 or 1));drain();assert(c.frame:IsShown())
    end
end)
test("native focus gain selects all and copy dismisses after native input",function()
    local c,parent,drain,count=setup();c:Show(parent,"Selected text")
    c.edit:Fire("OnMouseDown","LeftButton");c.edit:ClearFocus();c.edit:SetFocus()
    chord(c);assert(count()==1);drain();assert(not c.frame:IsShown())
end)
test("Enter Escape owner hide and explicit hide release focus and stale callback",function()
    for _,hide in ipairs({
        function(c)c.edit:Fire("OnEnterPressed")end,
        function(c)c.edit:Fire("OnEscapePressed")end,
        function(c,parent)parent:Hide()end,
        function(c)c:Hide()end,
    })do
        local c,parent,drain=setup();c:Show(parent,"9");chord(c);hide(c,parent)
        assert(not c.frame:IsShown() and not c.edit:HasFocus());parent:Show();c:Show(parent,"Reopened")
        drain();assert(c.frame:IsShown() and c.edit:GetText()=="Reopened")
    end
end)
test("unknown platform or missing timer keeps native copy dialog available",function()
    local c,parent,drain,count=setup();IsMacClient=nil;c:Show(parent,"9");assert(c.label:GetText()=="Select text to copy")
    chord(c);assert(count()==0 and c.frame:IsShown());drain()
    c,parent,drain,count=setup();c:Show(parent,"9");C_Timer=nil;chord(c);assert(c.frame:IsShown() and count()==0)
end)
test("copy dialog and parent hooks are reused over repeated open-close sessions",function()
    local c,parent=setup();c:Show(parent,"9");local frames=#W.frames
    for i=1,200 do c:Hide();c:Show(parent,tostring(i))end
    assert(#W.frames==frames and #parent.hooks.OnHide==1 and #c.edit.hooks.OnKeyDown==1)
    assert(#UISpecialFrames>=1 and c.edit:GetText()=="200")
end)

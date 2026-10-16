-- Independent source-derived UI fixture, deliberately separate from the broad
-- legacy mock. It resolves native local-scale anchors and inherited controls,
-- propagates effective visibility and focus events, and applies the actual
-- pinned tooltip backdrop mixin. Glyph measurements remain offline estimates.
PASSED=0
local function test(name,fn) if fn()==false then print("SKIP "..name..": pinned fixture absent");return end; PASSED=PASSED+1; print("PASS "..name) end
local function close(a,b) return math.abs(a-b)<.0001 end
local fractions={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
local function read(path)
    local f=io.open(path,"rb"); if not f then return end
    local source=f:read("*a"); f:close(); return source
end
local nativeBackdrop=read(ROOT.."/.work/current-api/Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.lua")
local nativeDropdown=read(ROOT.."/.work/current-api/Interface/AddOns/Blizzard_Menu/DropdownButton.lua")

local function fixture(config)
    local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
    local methods=getmetatable(W.Object()).__index
    local setText=methods.SetText
    function methods:SetText(value) return setText(self,value~=nil and tostring(value) or nil) end
    function methods:IsVisible()
        return self:IsShown() and (not self.parent or self.parent:IsVisible())
    end
    local function children(frame,fn)
        for _,child in ipairs(frame.referenceChildren or {}) do
            if child:IsShown() then fn(child); children(child,fn) end
        end
    end
    local oldShow,oldHide=methods.Show,methods.Hide
    function methods:Show()
        local was=self:IsVisible(); oldShow(self)
        if not was and self:IsVisible() then children(self,function(c) c:Fire("OnShow") end) end
    end
    function methods:Hide()
        local was=self:IsVisible(); oldHide(self)
        if was then children(self,function(c) c:Fire("OnHide") end) end
    end
    function methods:SetFocus()
        if W.focus and W.focus~=self then W.focus:ClearFocus() end
        self.focused=true; W.focus=self; self:Fire("OnEditFocusGained")
    end
    function methods:ClearFocus()
        local focused=self.focused; self.focused=false
        if W.focus==self then W.focus=nil end
        if focused then self:Fire("OnEditFocusLost") end
    end
    local function parent(child,owner)
        child.parent=owner
        if owner then owner.referenceChildren=owner.referenceChildren or {}; table.insert(owner.referenceChildren,child) end
    end
    local oldFontString,oldTexture=methods.CreateFontString,methods.CreateTexture
    function methods:CreateFontString(...)
        local object=oldFontString(self,...); parent(object,self); return object
    end
    function methods:CreateTexture(...)
        local object=oldTexture(self,...); object.referenceTexture=true; parent(object,self); return object
    end
    function methods:SetPoint(point,relative,relativePoint,x,y)
        self.referenceAnchors=self.referenceAnchors or {}
        if type(relative)=="number" then x,y,relative,relativePoint=relative,relativePoint,self.parent,point
        elseif relative==nil then relative,relativePoint,x,y=self.parent,point,0,0
        elseif type(relativePoint)=="number" then x,y,relativePoint=relativePoint,x,point end
        self.referenceAnchors[point]={point=point,relative=relative,relativePoint=relativePoint or point,x=x or 0,y=y or 0}
        self.point={point,relative,relativePoint or point,x or 0,y or 0}
    end
    function methods:ClearAllPoints() self.referenceAnchors=nil; self.point=nil end
    function methods:SetAllPoints(owner)
        self:ClearAllPoints(); self:SetPoint("TOPLEFT",owner or self.parent,"TOPLEFT",0,0)
        self:SetPoint("BOTTOMRIGHT",owner or self.parent,"BOTTOMRIGHT",0,0)
    end
    local rect
    local function axis(self,dimension,scale,explicit)
        local candidates={}
        for _,anchor in pairs(self.referenceAnchors or {}) do
            if anchor.relative then
                local x,y,w,h=rect(anchor.relative)
                local fraction=fractions[anchor.relativePoint][dimension]
                local position=(dimension==1 and x or y)+fraction*(dimension==1 and w or h)
                    +(dimension==1 and anchor.x or anchor.y)*scale
                candidates[#candidates+1]={fraction=fractions[anchor.point][dimension],position=position}
            end
        end
        for i=1,#candidates do for j=i+1,#candidates do
            local a,b=candidates[i],candidates[j]
            if a.fraction~=b.fraction then
                local size=(b.position-a.position)/(b.fraction-a.fraction)
                return a.position-a.fraction*size,size
            end
        end end
        local size=(explicit or 0)*scale
        if candidates[1] then return candidates[1].position-candidates[1].fraction*size,size end
        local origin=dimension==1 and self.x or self.y
        return (origin or 0)*scale,size
    end
    rect=function(self)
        local scale=self:GetEffectiveScale()
        local x,w=axis(self,1,scale,self.width); local y,h=axis(self,2,scale,self.height)
        return x,y,w,h
    end
    function methods:GetRect()
        local x,y,w,h=rect(self); local scale=self:GetEffectiveScale()
        return x/scale,y/scale,w/scale,h/scale
    end
    function methods:GetWidth() local _,_,w=self:GetRect(); return w end
    function methods:GetHeight() local _,_,_,h=self:GetRect(); return h end
    function methods:SetMinMaxValues(low,high)
        self.referenceLow,self.referenceHigh=low,high
        if self.value~=nil then self:SetValue(self.value) end
    end
    function methods:GetMinMaxValues() return self.referenceLow,self.referenceHigh end
    function methods:SetValue(value)
        local low,high=self.referenceLow,self.referenceHigh
        if low then value=math.max(low,math.min(high,value)) end
        local changed=self.value~=value; self.value=value
        if changed then self:Fire("OnValueChanged",value,false) end
    end
    function methods:SetOrientation(value) self.referenceOrientation=value end
    function methods:GetOrientation() return self.referenceOrientation end
    function methods:SetThumbTexture(value)
        if not self.thumb then self.thumb=self:CreateTexture(nil,"ARTWORK") end
        self.thumb:SetTexture(value)
    end
    function methods:SetHitRectInsets(...) self.referenceHitRect={...} end
    function methods:SetCenterColor(...) self.centerColor={...} end
    local N=W.Init(config)
    local create=CreateFrame
    CreateFrame=function(kind,name,owner,template)
        local frame=create(kind,name,owner,template); parent(frame,owner)
        if template=="UICheckButtonTemplate" then
            frame.Text:SetPoint("LEFT",frame,"RIGHT",-2,0)
        elseif template=="WowStyle1DropdownTemplate" then
            frame.Arrow=W.Object(); parent(frame.Arrow,frame); frame.Arrow:SetSize(20,20)
            frame.Arrow:SetPoint("RIGHT",frame,"RIGHT",-1,0)
            frame.Text:SetSize(0,10)
            frame.Text:SetPoint("TOPRIGHT",frame.Arrow,"LEFT",0,0)
            frame.Text:SetPoint("TOPLEFT",frame,"TOPLEFT",9,-7)
            if nativeDropdown then
                DropdownButtonMixin={}
                local body=nativeDropdown:match("(function DropdownButtonMixin:SetupMenu%(%a+%).-\nend)")
                assert(loadstring(assert(body,"Pinned dropdown SetupMenu missing")))()
                frame.SetupMenu=DropdownButtonMixin.SetupMenu
                local generate=frame.GenerateMenu
                frame.GenerateMenu=function(control)
                    local generator=control.menuGenerator
                    control.menuGenerator=function(owner,root)
                        -- Description generation registers release callbacks;
                        -- it does not open a menu or invoke its initializers' lifetime events.
                        function root:AddMenuReleasedCallback(callback)
                            self.referenceReleasedCallbacks=self.referenceReleasedCallbacks or {}
                            table.insert(self.referenceReleasedCallbacks,callback)
                        end
                        return generator(owner,root)
                    end
                    local ok,result=pcall(generate,control); control.menuGenerator=generator
                    if not ok then error(result,0) end
                    return result
                end
            end
        elseif template=="UISliderTemplate" then
            frame.referenceOrientation="HORIZONTAL"
            frame.thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            frame:SetHitRectInsets(0,0,-10,-10)
        elseif template=="TooltipBorderedFrameTemplate" and nativeBackdrop then
            -- Match each method separately so no unrelated global UI code runs.
            TooltipBackdropTemplateMixin={}
            for _,method in ipairs({"TooltipBackdropOnLoad","SetBackdropColor"}) do
                local body=nativeBackdrop:match("(function TooltipBackdropTemplateMixin:"..method.."%b()%s.-\nend)")
                assert(loadstring(assert(body,"Pinned backdrop method missing")))()
            end
            NineSliceUtil={DisableSharpening=function(slice) slice.sharpeningDisabled=true end}
            TOOLTIP_DEFAULT_BACKGROUND_COLOR={GetRGB=function() return .09,.09,.19 end}
            frame.backdropColor=nil; frame.backdropColorAlpha=.8
            Mixin(frame,TooltipBackdropTemplateMixin); frame:TooltipBackdropOnLoad()
        end
        return frame
    end
    return N,W,rect
end

test("shown child under hidden parent is not an eligible pointer target",function()
    local N,W=fixture(); local p=CreateFrame("Frame",nil,UIParent)
    p:SetSize(100,100); p:SetPoint("BOTTOMLEFT",20,20)
    local child=CreateFrame("Frame",nil,p); child:SetAllPoints()
    W.mouseX,W.mouseY=40,40; assert(child:IsShown() and N.Adapter.Over(child))
    p:Hide(); assert(child:IsShown() and not child:IsVisible() and not N.Adapter.Rect(child) and not N.Adapter.Over(child))
    p:Show(); assert(N.Adapter.Over(child))
end)

test("options parent hide and reopen propagate complete child lifecycle",function()
    local N,W=fixture(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options
    local shows,hides=0,0; O.modifier:HookScript("OnShow",function()
        shows=shows+1; assert(O.frame and O.modifier.Text:GetText()=="Shift" and O.edits.scale:GetText()=="100")
    end)
    O.modifier:HookScript("OnHide",function() hides=hides+1 end)
    O.edits.scale:SetFocus(); O.frame:Hide()
    assert(hides==1 and not O.edits.scale.focused and not O.modifier:IsVisible())
    O.frame:Show(); assert(shows==1 and O.modifier:IsVisible())
end)

test("actual intrinsic SetupMenu generates shown controls under a hidden shell",function()
    if not nativeDropdown then return false end
    local N,W=fixture(); N.Options:Create(N.Core); local O=N.Options
    assert(not O.frame:IsShown() and O.modifier:IsShown() and not O.modifier:IsVisible())
    assert(O.modifier.menuGenerations>=1 and O.modifier.Text:GetText()=="Shift",
        "native SetupMenu should populate a shown dropdown even while its shell is hidden")
    O.frame:Show(); assert(O.modifier:IsVisible() and O.modifier.Text:GetText()=="Shift")
end)

test("fractional scale resolves options native dropdown anchors inside its row",function()
    local N,W,rect=fixture(); UIParent:SetScale(.83); SlashCmdList.FINDANUPGRADE("opts")
    local O=N.Options; UIParent.width,UIParent.height=640,360; O:Refresh()
    local bx,by,bw,bh=rect(O.modifier); local tx,ty,tw,th=rect(O.modifier.Text)
    assert(close(tx-bx,9*O.modifier:GetEffectiveScale()))
    assert(ty>=by-.001 and ty+th<=by+bh+.001 and tx+tw<=bx+bw-20*O.modifier:GetEffectiveScale())
    local x,y,w,h=rect(O.content); local fx,fy,fw,fh=rect(O.frame)
    assert(close(x,fx) and close(y,fy) and close(w,fw) and close(h,fh))
end)

test("native checkbox caption geometry remains inside the Surfaces section",function()
    local N,W,rect=fixture(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options
    local x,y,w,h=rect(O.checks.launcher.Text); local sx,sy,sw,sh=rect(O.sections[4])
    assert(x>=sx and x+w<=sx+sw and y>=sy and y+h<=sy+sh)
end)

test("single options grid keeps native controls and headings within their sections",function()
    for _,height in ipairs({1080,360}) do
        local N,W,rect=fixture();UIParent.height=height;SlashCmdList.FINDANUPGRADE("opts");local O=N.Options
        local groups={
            {1,{O.font,O.border,O.sliders.scale,O.edits.scale}},
            {2,{O.checks.enabled,O.modifier,O.position,O.hint}},
            {3,{O.checks.accents,O.checks.dialogTint,O.checks.rewards,O.layout,O.sliders.strength,O.edits.strength}},
            {4,{O.checks.npc,O.checks.worldmap,O.checks.minimap,O.checks.launcher}},
            {5,{O.checks.hideUnusable,O.checks.includeDungeons,O.edits.levelsBelow,O.edits.levelsAbove}},
        }
        for _,group in ipairs(groups) do
            local sx,sy,sw,sh=rect(O.sections[group[1]])
            for _,control in ipairs(group[2]) do
                local x,y,w,h=rect(control)
                assert(x>=sx and x+w<=sx+sw and y>=sy and y+h<=sy+sh,"control crosses a single-window section edge")
            end
        end
        local fx,fy,fw,fh=rect(O.frame);local x,y,w,h=rect(O.scroll)
        local rx,ry,rw,rh=rect(O.reset);local bx,by,bw,bh=rect(O.bar)
        assert(x>=fx and x+w<=fx+fw and y>=fy and y+h<=fy+fh)
        assert(ry+rh<y and by>=y and by+bh<=y+h and bx>x+w)
        assert(O.maximum==math.max(0,600-O.scroll:GetHeight()) and O.frame:GetScale()==1)
    end
end)

test("search default rows keep nearby aligned numeric fields and consistent section gaps at every layout scale",function()
    for _,view in ipairs({{1920,1080,1},{640,360,.83},{320,240,.65},{1280,720,1.25}}) do
        local N,W,rect=fixture();UIParent.width,UIParent.height=view[1],view[2];UIParent:SetScale(view[3])
        SlashCmdList.FINDANUPGRADE("opts");local O=N.Options;local scale=O.body:GetEffectiveScale()
        local function label(value)
            for _,entry in ipairs(O.texts) do if entry.object:GetText()==value then return entry.object end end
            error("Missing options label: "..value)
        end
        for _,row in ipairs({{"Levels below",O.edits.levelsBelow},{"Levels above",O.edits.levelsAbove}}) do
            local caption=label(row[1]);local lx,ly,lw,lh=rect(caption);local x,y,w,h=rect(row[2])
            assert(close(x-lx,120*scale) and close(x-lx-lw,12*scale),"numeric field detached from its label")
            assert(close(ly+lh/2,y+h/2),"numeric field and label are not vertically centered")
            assert(caption:GetScale()==1 and row[2]:GetScale()==1,"spacing must not shrink the selected font or field")
            local _,size=caption:GetFont();assert(math.abs(size-12)<.1)
            assert(close(w,58*scale) and close(h,22*scale),"native numeric field changed size")
        end
        local _,by,_,bh=rect(O.edits.levelsBelow);local _,ay,_,ah=rect(O.edits.levelsAbove)
        local _,cy,_,ch=rect(O.checks.includeDungeons)
        assert(close(by+bh/2-ay-ah/2,28*scale) and close(cy+ch/2-by-bh/2,28*scale),"search rows lost the shared cadence")
        local _,hy,_,hh=rect(label("Applies next time search opens."))
        local _,zy,_,zh=rect(label("Starts in the current zone."))
        assert(ay-hy-hh>=10*scale and ay-hy-hh<=14*scale,"search hint separated by unnecessary blank space")
        assert(close(hy-zy,20*scale) and close(hh,zh),"search hints overlap or have inconsistent leading")
        for _,pair in ipairs({{1,3},{2,4},{4,5}}) do
            local _,uy=rect(O.sections[pair[1]]);local _,ly,_,lh=rect(O.sections[pair[2]])
            assert(close(uy-ly-lh,24*scale),"section separation is inconsistent")
        end
        local sx,sy,sw,sh=rect(O.sections[5]);local x,y,w,h=rect(O.edits.levelsAbove)
        assert(x>=sx+12*scale and x+w<=sx+sw-12*scale and y>=sy+12*scale)
        assert(zy>=sy+10*scale and zy+zh<=sy+sh)
        local _,fy,_,fh=rect(O.frame);local _,vy,_,vh=rect(O.scroll);local _,ry,_,rh=rect(O.reset)
        assert(vy>=fy and vy+vh<=fy+fh and ry+rh<vy,"content overlaps the fixed footer")
        O:Scroll(O.maximum);assert(close(O.offset+O.scroll:GetHeight(),O.body:GetHeight()),"last row cannot be reached")
    end
end)

test("native slider clamping does not let direct input escape option bounds",function()
    local N=fixture(); SlashCmdList.FINDANUPGRADE("opts"); local O=N.Options
    O.sliders.scale:SetValue(900); assert(N.Core.profile.scale==1.2 and O.edits.scale:GetText()=="120")
    O.sliders.scale:SetValue(-900); assert(N.Core.profile.scale==.8 and O.edits.scale:GetText()=="80")
end)

test("actual pinned backdrop mixin applies native center color for quest cards",function()
    if not nativeBackdrop then return false end
    local N,W=fixture(); N.Stack:Create(); local card=N.Stack:Card(1)
    assert(card.NineSlice.sharpeningDisabled and card.NineSlice.centerColor[4]==.8)
    card:SetBackdropColor(.12,.15,.19,.8)
    assert(card.NineSlice.centerColor[1]==.12 and card.NineSlice.centerColor[2]==.15)
end)

test("vertical reward scrollbars use native vertical thumb artwork",function()
    local N=fixture(); N.Stack:Create(); N.Search:Create()
    for _,bar in ipairs({N.Stack.bar,N.Search.bar}) do
        assert(bar:GetOrientation()=="VERTICAL")
        assert(bar:GetThumbTexture().texture=="Interface\\Buttons\\UI-SliderBar-Button-Vertical",
            "vertical scrollbar still stretches native horizontal thumb artwork")
    end
end)

test("private comparison headers preserve native label art and geometry",function()
    local N,W,rect=fixture()
    NORMAL_FONT_COLOR={GetRGB=function() return 1,.82,0 end}
    N.Stack:Create(); N.Stack:Tooltips()
    for _,tip in ipairs(N.Stack.tooltip.shoppingTooltips) do
        tip:SetSize(250,180); tip:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",100,100)
        local header=tip.CompareHeader; local atlas
        for _,child in ipairs(header.referenceChildren or {}) do
            if child.referenceTexture and child.atlas=="tooltip-compare-label" then atlas=child end
        end
        assert(header:GetHeight()==22 and atlas,"comparison header omitted native 22px label plate")
        assert(header:GetFrameLevel()<tip:GetFrameLevel(),"comparison header should remain beneath native tooltip art")
        local _,y,_,h=rect(header); local _,ty,_,th=rect(tip)
        assert(close(y,ty+th-tip:GetEffectiveScale()) and close(h,22*tip:GetEffectiveScale()))
        assert(header.Label.fontObject==GameTooltipText and header.Label.textColor
            and header.Label.textColor[1]==1 and header.Label.textColor[2]==.82 and header.Label.textColor[3]==0)
    end
end)

test("clamped private tooltips remain above the owned card and icon hierarchy",function()
    local N,W,rect=fixture(); N.Stack:Create(); local V=N.Stack
    -- A narrow viewport can clamp a native item tooltip across the stack.
    -- Resolve overlapping rectangles and use inherited frame levels rather
    -- than prescribing a particular numeric level or desired setter call.
    V.frame:SetSize(320,160); V.frame:ClearAllPoints(); V.frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",8,8)
    V.scroll:SetAllPoints(V.frame); V.child:SetAllPoints(V.scroll)
    local card=V:Card(1); card:SetSize(320,160); card:SetPoint("TOPLEFT",V.child,"TOPLEFT",0,0)
    local button=V:Icon(card,1); button:SetPoint("TOPLEFT",card,"TOPLEFT",8,-8)
    V:Tooltips()
    local function overlap(a,b)
        local ax,ay,aw,ah=rect(a); local bx,by,bw,bh=rect(b)
        return math.min(ax+aw,bx+bw)>math.max(ax,bx) and math.min(ay+ah,by+bh)>math.max(ay,by)
    end
    for _,tip in ipairs({V.tooltip,V.tooltip.shoppingTooltips[1],V.tooltip.shoppingTooltips[2]}) do
        tip:SetSize(280,180); tip:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",0,8)
        assert(overlap(tip,card) and overlap(tip,button))
        assert(tip:GetFrameLevel()>button:GetFrameLevel(),"native tooltip can be obscured by its owning reward button")
    end
end)

test("native focus-loss events cannot commit cancelled finder range edits",function()
    local N,W=fixture(); N.Search:Toggle(); local S=N.Search
    local lo,hi=S.filter.minimum,S.filter.maximum
    S.minimumInput:SetFocus(); S.minimumInput:SetText(tostring(lo+1)); S.minimumInput:Fire("OnEscapePressed")
    assert(S.filter.minimum==lo and S.filter.maximum==hi,"Escape committed the edit through OnEditFocusLost")
    assert(S.minimumInput:GetText()==tostring(lo) and not S.minimumInput.focused)
    S.maximumInput:SetFocus(); S.maximumInput:SetText(tostring(hi+1)); S.maximumInput:Fire("OnEscapePressed")
    assert(S.filter.minimum==lo and S.filter.maximum==hi and S.maximumInput:GetText()==tostring(hi))
end)

test("closing the finder clears focus without applying an unfinished range",function()
    local N,W=fixture(); N.Search:Toggle(); local S=N.Search
    local lo,hi=S.filter.minimum,S.filter.maximum
    S.minimumInput:SetFocus(); S.minimumInput:SetText(tostring(lo+1)); S.frame:Hide()
    assert(S.filter.minimum==lo and S.filter.maximum==hi and not S.minimumInput.focused,
        "window close committed an unfinished range through OnEditFocusLost")
end)

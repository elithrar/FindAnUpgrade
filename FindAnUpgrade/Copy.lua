local _,N=...
local M,A,U=N.Model,N.Adapter,N.UI
local C={generation=0,revision=0,parents={}}; N.Copy=C
local modifiers={LCTRL=true,RCTRL=true,CTRL=true,LMETA=true,RMETA=true,META=true,
    LALT=true,RALT=true,ALT=true,LSHIFT=true,RSHIFT=true,SHIFT=true}
local function keyName(key) return M.Text(key) and key:upper() end
function C:Cancel(changed)
    self.pending=nil
    if changed then self.revision=self.revision+1 end
end
function C:Current(intent)
    return intent and self.pending==intent and intent.generation==self.generation
        and intent.revision==self.revision
        and self.owner==intent.owner and A.Visible(self.owner) and A.Visible(self.frame)
        and A.Call(self.edit.HasFocus,self.edit)==true
        and M.Text(A.Call(self.edit.GetText,self.edit))==intent.value
end
function C:Chord()
    local ctrl,meta=A.Call(IsControlKeyDown),A.Call(IsMetaKeyDown)
    if A.Call(IsAltKeyDown)~=false or A.Call(IsShiftKeyDown)~=false then return false end
    if self.mac==true then return meta==true and ctrl==false end
    if self.mac==false then return ctrl==true and meta==false end
    return false
end
function C:KeyDown(key)
    key=keyName(key)
    if key=="C" and self:Chord() and A.Visible(self.owner)
        and A.Visible(self.frame) and A.Call(self.edit.HasFocus,self.edit)==true then
        if self.pending then return end -- A held key owns one intent/timer.
        local value=M.Text(A.Call(self.edit.GetText,self.edit))
        if value then self.pending={generation=self.generation,revision=self.revision,owner=self.owner,value=value} end
    elseif key and not modifiers[key] then self:Cancel(true) end
end
function C:KeyUp(key)
    if keyName(key)~="C" then return end
    local intent=self.pending
    if not self:Current(intent) then self:Cancel(); return end
    if intent.queued then return end
    if not C_Timer or type(C_Timer.After)~="function" then self:Cancel(); return end
    intent.queued=true
    -- Leave native input/focus untouched through key-down and key-up dispatch.
    -- A chord is intent, not an OS clipboard acknowledgement.
    C_Timer.After(0,function()
        if self:Current(intent) then self:Hide()
        elseif self.pending==intent then self:Cancel() end
    end)
end
function C:Create(parent)
    if self.frame then return end
    local f=CreateFrame("Frame","FindAnUpgradeCopy",parent,"BackdropTemplate"); self.frame=f
    f:Hide(); f:SetSize(380,90); f:SetClampedToScreen(true); f:SetFrameStrata("FULLSCREEN_DIALOG"); U:Dialog(f)
    local label=f:CreateFontString(nil,"OVERLAY","GameTooltipText"); self.label=label
    U:Font(label,12); label:SetJustifyH("LEFT"); label:SetPoint("TOPLEFT",12,-12)
    local edit=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); self.edit=edit
    edit:SetSize(350,26); edit:SetPoint("TOPLEFT",15,-42); edit:SetAutoFocus(false)
    edit:SetMaxLetters(1024); edit:SetTextInsets(8,8,0,0); edit:SetJustifyV("MIDDLE"); U:Font(edit,12)
    edit:HookScript("OnKeyDown",function(_,key) self:KeyDown(key) end)
    edit:HookScript("OnKeyUp",function(_,key) self:KeyUp(key) end)
    edit:HookScript("OnTextChanged",function() if not self.selecting then self:Cancel(true) end end)
    edit:HookScript("OnCursorChanged",function() if not self.selecting then self:Cancel(true) end end)
    edit:HookScript("OnMouseDown",function() self:Cancel(true) end)
    edit:HookScript("OnEditFocusLost",function() self:Cancel(true) end)
    edit:HookScript("OnEditFocusGained",function()
        if not self.selecting then self:Cancel(true) end
    end)
    edit:HookScript("OnEnterPressed",function() self:Hide() end)
    edit:HookScript("OnEscapePressed",function() self:Hide() end)
    f:HookScript("OnHide",function()
        self.generation=self.generation+1; self:Cancel(true); self.owner=nil; edit:ClearFocus()
    end)
    UISpecialFrames=UISpecialFrames or {}; UISpecialFrames[#UISpecialFrames+1]="FindAnUpgradeCopy"
end
function C:Show(parent,value)
    if not M.Text(value) or not parent or A.Forbidden(parent) or not A.Visible(parent) then return false end
    local width=A.Call(parent.GetWidth,parent)
    if not M.Number(width) or width<120 then return false end
    self:Hide(); self:Create(parent)
    self.generation=self.generation+1; self:Cancel(true); self.owner=parent
    self.frame:SetParent(parent); self.frame:ClearAllPoints(); self.frame:SetPoint("CENTER",parent,"CENTER",0,0)
    self.frame:SetWidth(math.min(380,width-24)); self.edit:SetWidth(self.frame:GetWidth()-30)
    U:Border(self.frame,"dialog"); U:Font(self.label,12); U:Font(self.edit,12)
    self.mac=A.Call(IsMacClient)
    self.label:SetText(self.mac==true and "Command+C to copy" or self.mac==false and "Ctrl+C to copy" or "Select text to copy")
    if not self.parents[parent] then
        self.parents[parent]=true
        parent:HookScript("OnHide",function() if self.owner==parent then self:Hide() end end)
    end
    self.frame:Show(); self.selecting=true
    self.edit:SetText(value); self.edit:SetFocus(); self.edit:HighlightText()
    self.selecting=false
    return true
end
function C:Hide()
    self.generation=self.generation+1; self:Cancel(true); self.owner=nil
    if self.frame then self.frame:Hide(); self.edit:ClearFocus() end
end

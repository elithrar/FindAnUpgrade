local _,N=...
local M,A=N.Model,N.Adapter
local L={}; N.Launcher=L
function L:Position(angle)
    local size=A.Call(Minimap.GetWidth,Minimap); if not M.Number(size) or size<=0 then return end
    local radius=size/2+6; local radians=angle*math.pi/180
    self.button:ClearAllPoints(); self.button:SetPoint("CENTER",Minimap,"CENTER",math.cos(radians)*radius,math.sin(radians)*radius)
end
function L:Stop(save)
    if not self.button then return end
    self.button:SetScript("OnUpdate",nil); self.dragging=false
    if save then
        self.suppressUntil=(A.Call(GetTime) or 0)+.25
        if self.angle and not N.Core.readOnly then N.Core:Change("launcherAngle",self.angle) end
    end
    self.angle=nil
end
function L:Create()
    if self.button or not Minimap or A.Forbidden(Minimap) then return end
    local b=CreateFrame("Button","FindAnUpgradeLauncher",Minimap); self.button=b; b:SetSize(32,32); b:SetFrameStrata("MEDIUM"); b:RegisterForClicks("LeftButtonUp"); b:RegisterForDrag("LeftButton")
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(24,24); b.icon:SetPoint("CENTER"); b.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09"); b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=b:CreateTexture(nil,"OVERLAY"); b.border:SetSize(52,52); b.border:SetPoint("TOPLEFT",-2,2); b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetScript("OnClick",function() if not self.dragging and (A.Call(GetTime) or 0)>=(self.suppressUntil or 0) then N.Search:Toggle() end end)
    b:SetScript("OnDragStart",function()
        if N.Core.readOnly then return end
        self.dragging=true
        b:SetScript("OnUpdate",function()
            local x,y=A.Cursor(); local scale=A.Call(Minimap.GetEffectiveScale,Minimap)
            local ok,cx,cy=pcall(Minimap.GetCenter,Minimap)
            if x and ok and M.Number(cx) and M.Number(cy) and M.Number(scale) and scale>0 then self.angle=math.atan2(y/scale-cy,x/scale-cx)*180/math.pi; self:Position(self.angle) end
        end)
    end)
    b:SetScript("OnDragStop",function() self:Stop(true) end)
    b:SetScript("OnHide",function() self:Stop(false); if self.tooltip then self.tooltip:Hide() end end)
    b:SetScript("OnEnter",function()
        if not self.tooltip then self.tooltip=CreateFrame("GameTooltip","FindAnUpgradeLauncherTooltip",UIParent,"SharedTooltipTemplate") end
        self.tooltip:SetOwner(b,"ANCHOR_LEFT"); self.tooltip:SetText("FindAnUpgrade"); self.tooltip:AddLine("Open quest reward search",.7,.7,.72); self.tooltip:Show()
    end)
    b:SetScript("OnLeave",function() if self.tooltip then self.tooltip:Hide() end end)
end
function L:Refresh()
    if not N.Core.ready then return end
    self:Create(); if not self.button then return end
    local profile=N.Core.profile; self:Position(profile.launcherAngle)
    self.button:SetShown(N.Core.supported and profile.enabled and profile.launcher)
end

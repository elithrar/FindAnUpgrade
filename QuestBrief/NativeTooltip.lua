local _, N = ...
local M, A = N.Model, N.Adapter
local T = {}; N.NativeTooltip = T

local function plain(value)
    if not M.Text(value) then return "" end
    return value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|cn[%w_]+:",""):gsub("|r","")
        :gsub("|H.-|h(.-)|h","%1"):gsub("|T.-|t",""):gsub("|A.-|a","")
        :gsub(",",""):lower():gsub("%s+","")
end
local function contains(lines,value)
    value=plain(value)
    if value=="" then return false end
    for _,line in ipairs(lines) do
        local candidate=plain(line)
        local first,last=candidate:find(value,1,true)
        if first and (not value:match("^%d") or first==1 or not candidate:sub(first-1,first-1):match("%d")) then return true end
    end
    return false
end
local function moneyShown(lines,value)
    -- Coin strings contain formatting textures. Comparing only stripped digits
    -- could mistake 10 silver for a quest level, count or part of an XP value.
    local function coins(text)
        return text:gsub("|T(.-)|t",function(markup)
            local path=markup:match("^[^:]+") or markup
            return "<coin:"..path:lower()..">"
        end):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("%s+","")
    end
    local expected=coins(value)
    for _,line in ipairs(lines) do
        if coins(line):find(expected,1,true) then return true end
    end
    return false
end
local function titleShown(lines,title,questieRendered)
    local expected=plain(title)
    for _,line in ipairs(lines) do
        local value=plain(line):gsub("^%[%d+[%+dpr]*%]","")
            :gsub("%(available%)$",""):gsub("%(complete%)$","")
        if value==expected then return true end
        if questieRendered and value:sub(1,#expected)==expected and value:sub(#expected+1,#expected+1):match("[%(%d]") then return true end
    end
    return false
end
local function suffix(profile,id)
    local status=profile.accents and M.Status(id)
    return status=="verifiedNew" and " |cffffb36bNew|r" or status=="verifiedUpdated" and " |cff9fdf9fModified|r" or ""
end
local function icons(group)
    local result={}
    for i,row in ipairs(group.items or {}) do
        if i>8 then result[#result+1]="+"..(#group.items-8); break end
        local texture=row.texture
        if M.Number(texture) or M.Text(texture) then
            result[#result+1]="|T"..texture..":24:24|t"..(row.quantity and row.quantity>1 and "x"..row.quantity or "")
        elseif M.Text(row.name) then result[#result+1]=row.name end
    end
    return table.concat(result," ")
end
-- Pure composition also gives tests a way to challenge coexistence without
-- pretending a mock can reproduce native tooltip rendering or mouse behavior.
function T:Lines(source,profile,existing)
    local result,dedup={},{}
    local function add(value) if M.Text(value) and not contains(dedup,value) then result[#result+1]=value end end
    for index,row in ipairs(source.rows) do
        if index>3 then add("+"..(#source.rows-3).." quests"); break end
        local title=M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,row.id)) or row.title or "Quest "..row.id
        local accent=suffix(profile,row.id)
        local sameTitle=0
        for _,other in ipairs(source.rows) do
            local otherTitle=M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,other.id)) or other.title or "Quest "..other.id
            if otherTitle==title then sameTitle=sameTitle+1 end
        end
        local knownTitle=sameTitle==1 and titleShown(existing,title,row.questieTip~=nil or row.provenance=="Questie current exact NPC tooltip registry")
        local rewardExisting=#source.rows==1 and knownTitle and existing or {}
        dedup=rewardExisting
        local first=#result+1
        local reward=profile.rewards and N.Rewards.Read(row.id)
        if reward then
            local guaranteed,choices=icons(reward.items),icons(reward.choices)
            local choiceCurrency=false
            for _,currency in ipairs(reward.currencies.items or {}) do if currency.isChoice then choiceCurrency=true end end
            if guaranteed~="" then add((choices~="" or choiceCurrency) and "Guaranteed: "..guaranteed or "Rewards: "..guaranteed) end
            if choices~="" then add("Choose one: "..choices) end
            local values={}
            if reward.money.state=="ready" and reward.money.value>0 then
                local money=N.Rewards.Money(reward.money.value)
                if money and not moneyShown(rewardExisting,money) then values[#values+1]=money..(reward.money.published and " (base)" or "") end
            end
            if reward.xp.state=="ready" and reward.xp.value>0 and not contains(rewardExisting,reward.xp.value.." XP") then
                values[#values+1]=reward.xp.value.." XP"..(reward.xp.published and " (base)" or "")
            end
            if #values>0 then add(table.concat(values,"  ")) end
            for _,currency in ipairs(reward.currencies.items or {}) do
                if currency.amount>0 then add((currency.isChoice and "Choose one: " or (choices~="" or choiceCurrency) and "Guaranteed: " or "")..currency.name.." "..currency.amount) end
            end
            for _,rep in ipairs(reward.reputation.items or {}) do
                if rep.amount~=0 then
                    local name=rep.name or "Faction "..rep.factionID
                    local amount=(rep.amount>=0 and "+" or "")..rep.amount
                    if not contains(rewardExisting,amount.." "..name) and not contains(rewardExisting,name..": "..amount) then
                        add(name..": "..amount..(rep.published and " (base)" or ""))
                    end
                end
            end
        end
        -- An existing Questie title/status is left intact. A short classification
        -- supplement is added only when that exact variant has a verified change.
        if not knownTitle or #source.rows>1 and #result>=first then
            table.insert(result,first,title..(sameTitle>1 and " (#"..row.id..")" or "")..accent)
        elseif accent~="" and not contains(existing,title..accent) then
            table.insert(result,first,"QuestBrief:"..accent)
        end
    end
    if #result>12 then
        while #result>11 do table.remove(result) end
        result[#result+1]="More rewards in the inspector."
    end
    result[#result+1]="|cffb3b3b3Release "..(profile.modifier=="CTRL" and "Ctrl" or profile.modifier=="ALT" and "Alt" or "Shift").." to inspect rewards.|r"
    return result
end
function T:Attach()
    if self.hooked or not N.Core.supported or InCombatLockdown() or A.Forbidden(GameTooltip) then return end
    GameTooltip:HookScript("OnTooltipCleared",function() self.epoch=(self.epoch or 0)+1; self.token,self.reusable=nil,nil end)
    GameTooltip:HookScript("OnHide",function() self:ClearOwned(true) end)
    self.hooked=true
end
function T:Matches(source)
    local tip=GameTooltip
    if not self.hooked or not A.Visible(tip) or A.Call(tip.IsProtected,tip)==true then return false end
    if source.npcGUID then
        if type(tip.GetUnit)~="function" then return false end
        local ok,_,unit=pcall(tip.GetUnit,tip)
        return ok and M.Text(unit)~=nil and M.Text(A.Call(UnitGUID,unit))==source.npcGUID
    end
    return source.owner~=nil and A.Call(tip.GetOwner,tip)==source.owner
end
function T:Begin()
    self.lastRect=nil
    if not self.escape then
        local f=CreateFrame("Frame","QuestBriefPreviewEscape",UIParent); self.escape=f
        f:SetSize(1,1); f:SetPoint("BOTTOMLEFT"); f:EnableMouse(false); f:Hide()
        f:SetScript("OnHide",function() if N.Hover.open and N.Hover.mode=="native" then N.Hover:Dismiss("escape") end end)
        UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"QuestBriefPreviewEscape")
    end
    self.escape:Show()
end
function T:End()
    if self.escape then self.escape:Hide() end
    self:ClearOwned()
    self.lastRect=nil
end
function T:Current(token,hidden)
    local tip=GameTooltip
    if not token or not tip or A.Forbidden(tip) or A.Call(tip.IsProtected,tip)==true or token.epoch~=self.epoch then return false end
    local visible=A.Visible(tip)
    local owner=A.Call(tip.GetOwner,tip)
    local data=A.Call(tip.GetPrimaryTooltipData or tip.GetTooltipData,tip)
    -- Native OnHide clears handler info without clearing font strings. Its
    -- already-owned public text must be cleaned before a same-owner Show.
    if hidden and not visible then
        return (owner==nil or owner==token.owner) and (data==nil or data==token.data)
            and M.Readable(tip._Rebuild) and (tip._Rebuild==nil or tip._Rebuild==token.rebuild)
    end
    local current=visible and token.owner==owner and token.data==data
    if not current or not M.Readable(tip._Rebuild) or tip._Rebuild~=token.rebuild then return false end
    for _,key in ipairs({"id","type","guid","dataInstanceID"}) do
        if type(token.data)=="table" and (not M.Readable(token.data[key]) or token.data[key]~=token.fields[key]) then return false end
    end
    return true
end
function T:ClearOwned(hidden)
    local token=self.token
    if not self:Current(token,hidden) then self.token=nil; return end
    local changed=false
    for _,entry in ipairs(token.lines or {}) do
        if not self:Current(token,hidden) then break end
        if entry.region and A.Call(entry.region.GetText,entry.region)==entry.text then
            self.reusable={region=entry.region,index=entry.index,epoch=self.epoch}
            entry.region:SetText(""); changed=true
        end
    end
    self.token=nil
    if changed and not hidden and self:Current(token) then GameTooltip:Show() end
end
function T:Try(source,profile)
    if self.mutating or not source.valid() or not source.over() or not self:Matches(source) then return false end
    local tip=GameTooltip
    local data=A.Call(tip.GetPrimaryTooltipData or tip.GetTooltipData,tip)
    local owner=A.Call(tip.GetOwner,tip)
    local token=self.token
    local current=token and token.key==source.key and self:Current(token)
    if token and not current then return false end
    if current and not self.dirty then return true end
    local count=A.Call(tip.NumLines,tip)
    if not M.Number(count) or count<1 or count>160 then return false end
    local existing,owned={},{}
    if current then
        for _,entry in ipairs(token.lines or {}) do
            if not entry.region or A.Call(entry.region.GetText,entry.region)~=entry.text then return true end
            owned[entry.region]=true
        end
    end
    for i=1,count do
        for _,side in ipairs({"Left","Right"}) do
            local region=_G["GameTooltipText"..side..i]
            if region then
                local ok,value=pcall(region.GetText,region)
                if not ok then return false end
                if not M.Readable(value) then return false end
                if not owned[region] and M.Text(value) then existing[#existing+1]=value end
            end
        end
    end
    local generation=N.Hover.generation
    local function active()
        return N.Hover.open and N.Hover.mode=="native" and N.Hover.generation==generation
            and N.Hover.source and N.Hover.source.key==source.key and source.valid() and self:Matches(source)
    end
    local ok,lines=pcall(self.Lines,self,source,profile,existing)
    if not ok or not active() or token and not self:Current(token) then return false end
    local fields={}
    if type(data)=="table" then
        for _,key in ipairs({"id","type","guid","dataInstanceID"}) do
            if not M.Readable(data[key]) then return false end
            fields[key]=data[key]
        end
    end
    if not M.Readable(tip._Rebuild) then return false end
    local previous=current and token.lines or {}
    local replacement={key=source.key,epoch=self.epoch,data=data,owner=owner,fields=fields,rebuild=tip._Rebuild,lines={}}
    self.token=replacement
    self.mutating=true
    ok=pcall(function()
        -- One multiline native row owns the entire supplement. Updating or
        -- clearing it cannot leave one intrinsic empty row per reward/quest.
        -- Existing NPC/Questie rows remain byte-for-byte untouched.
        local line=table.concat(lines,"\n")
        local entry=previous[1]
        local region,index=entry and entry.region,entry and entry.index
        local reusable=self.reusable
        if not region and reusable and reusable.epoch==self.epoch and reusable.index and reusable.index<=tip:NumLines()
            and _G["GameTooltipTextLeft"..reusable.index]==reusable.region and A.Call(reusable.region.GetText,reusable.region)=="" then
            region,index=reusable.region,reusable.index
        end
        if region then region:SetText(line)
        else
            index=tip:NumLines()+1
            tip:AddLine(line,1,1,1,true)
            -- Another addon's secure post-hook may append its own row before
            -- AddLine returns. Never adopt the resulting last foreign row.
            region=_G["GameTooltipTextLeft"..index]
        end
        if not region or A.Call(region.GetText,region)~=line then self.token=nil; return end
        replacement.lines[1]={region=region,text=line,index=index}
        if not active() or self.token~=replacement or not self:Current(replacement) then
            if self:Current(replacement,true) and region and A.Call(region.GetText,region)==line then
                self.reusable={region=region,index=index,epoch=self.epoch}; region:SetText("")
            end
            return
        end
        -- AddLine's documented resize idiom. The tooltip is already shown,
        -- public and unprotected; its owner, anchors, scripts and mouse stay native.
        tip:Show()
    end)
    self.mutating=false
    if not ok or not active() or self.token~=replacement or not self:Current(replacement) then return false end
    self.dirty=false
    self.lastRect=A.Rect(tip)
    return true
end

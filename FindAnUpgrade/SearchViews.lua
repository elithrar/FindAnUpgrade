local _,N=...
local S,M,A,U=N.Search,N.Model,N.Adapter,N.UI

function S:CreateViews()
    self.view="quests";self.views={quests={query="",offset=0},shortlist={query="",offset=0}}
    self.tabs={}
    for i,entry in ipairs({{"quests","Quests"},{"shortlist","Shortlist"}}) do
        local key=entry[1];local tab=U:Tab(CreateFrame("Button",nil,self.frame,"BackdropTemplate"),entry[2],116)
        tab:SetPoint("TOPLEFT",16+(i-1)*120,-42);tab:SetScript("OnClick",function()self:View(key)end)
        tab.activeLine:SetShown(key==self.view);self.tabs[key]=tab
    end
end
function S:CloseChain()
    if self.chainFrame then self.chainFrame:Hide() end
    self.chainOwner=nil
end
function S:View(key)
    if not self.views or not self.views[key] or key==self.view then return end
    self:CommitRange(true);self.search:ClearFocus();self:CancelRange();self:CloseMenu();self:CloseChain();self.inspector:ClearItem()
    if N.Copy then N.Copy:Hide() end
    local previous=self.views[self.view];previous.query=self.search:GetText();previous.offset=self.offset
    self.view=key;local current=self.views[key];self.offset=current.offset;self.bottomTarget=nil
    self.search:SetText(current.query);self.placeholder:SetText(key=="shortlist" and "Search shortlist" or "Quest or reward")
    if key=="quests" then self.filter.query=current.query end
    for name,tab in pairs(self.tabs) do tab.activeLine:SetShown(name==key) end
    self.heights={};self:LayoutControls();self:DataChanged()
end
function S:Save(row)
    if not row then return end
    local ok,reason=N.Shortlist:Toggle(row.id)
    if not ok then
        N.Core:Print(reason=="capacity" and "Shortlist is full (20 quests)." or "Shortlist is read-only.")
        return
    end
    self:CloseChain();self.inspector:ClearItem();self:DataChanged()
end
function S:Star(card)
    local star=CreateFrame("Button",nil,card);card.star=star;star:SetSize(24,24);star:SetPoint("TOPRIGHT",-4,-3)
    -- Blizzard uses these two atlases on one texture. Swapping the art keeps
    -- the native silhouette without a second outline over the filled state.
    star.icon=star:CreateTexture(nil,"ARTWORK");star.icon:SetSize(17,15.3);star.icon:SetPoint("CENTER")
    star:SetScript("OnClick",function()if card.row and A.Over(self.scroll) then self:Save(card.row) end end)
    star:SetScript("OnEnter",function()
        if not card.row or not A.Over(self.scroll) then return end
        self.inspector:ClearItem();star.icon:SetVertexColor(1.25,1.25,1.25)
        self.footerTooltip:SetOwner(star,"ANCHOR_LEFT");self.footerTooltip:SetText(N.Shortlist:Contains(card.row.id) and "Remove from shortlist" or "Save to shortlist");self.footerTooltip:Show()
    end)
    star:SetScript("OnLeave",function()star.icon:SetVertexColor(1,1,1);self.footerTooltip:Hide()end)
    card.chain=CreateFrame("Button",nil,card);card.chain:SetHeight(16)
    card.chain.text=card.chain:CreateFontString(nil,"OVERLAY","GameTooltipText");U:Font(card.chain.text,11);card.chain.text:SetAllPoints();card.chain.text:SetJustifyH("LEFT");card.chain.text:SetTextColor(.85,.75,.45);card.chain.text:SetText("Quest chain")
    card.chain:SetScript("OnClick",function()if card.row and A.Over(self.scroll) then self:Chain(card.row.id,card.chain) end end)
end
function S:ShortlistQuery()
    local out={};local query=(self.search:GetText() or ""):lower();local model=N.SearchModel
    model.needed,model.questNeeded={},{};local needed={};local context=N.Character:Get()
    for _,id in ipairs(N.Shortlist:IDs()) do
        local record=N.Catalog.records[id];local source=N.Providers.Source(id)
        if not record and source then
            record={id=id,title=source.title,level=source.level,items=source.items or {},source=source}
            N.Catalog.records[id]=record;N.Catalog.order[#N.Catalog.order+1]=record
        end
        -- Reuse the same context-aware metadata cache as the Quests view.
        if record then N.Catalog:Metadata(record,context.level) end
        local row={id=id,title=record and record.title or "Quest "..id,level=record and record.level,source=source,items={},missing=not source}
        local match=query=="" or row.title:lower():find(query,1,true) or tostring(id):find(query,1,true)
        for _,meta in ipairs(model.currentItems[id] or record and record.items or {}) do
            local item=model:Item(meta);row.items[#row.items+1]=item
            if item.state~="ready" and not needed[item.itemID] then needed[item.itemID]=true;model.needed[#model.needed+1]=item.itemID end
            match=match or (item.name or ""):lower():find(query,1,true) or (item.searchTypeText or ""):find(query,1,true)
        end
        if record and not record.metadataReady then model.questNeeded[#model.questNeeded+1]=id end
        local availability=N.Providers.Availability(row,context);row.availability=availability
        if availability.state~="unknown" then row.evidence=availability.label or availability.reason or "Unavailable" end
        if match then out[#out+1]=row end
    end
    return out
end
function S:Chain(id,owner)
    if self.chainOwner==owner and self.chainFrame and self.chainFrame:IsShown() then self:CloseChain();return end
    self:CloseMenu();self.inspector:ClearItem();if N.Copy then N.Copy:Hide()end
    local info=N.Chains and N.Chains:Describe(id);if not info or not info.hasDetails then return end
    if not self.chainFrame then
        local f=CreateFrame("Frame","FindAnUpgradeChain",self.frame,"BackdropTemplate");self.chainFrame=f;f:SetWidth(300);f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true);U:Dialog(f)
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetSize(22,22);close:SetPoint("TOPRIGHT",-4,-4);close:SetScript("OnClick",function()self:CloseChain()end)
        f.title=f:CreateFontString(nil,"OVERLAY","GameTooltipText");U:Font(f.title,13);f.title:SetPoint("TOPLEFT",12,-12);f.title:SetTextColor(1,.82,.2);f.title:SetText("Quest chain")
        f.scroll=CreateFrame("ScrollFrame",nil,f);f.scroll:SetPoint("TOPLEFT",12,-36);f.scroll:SetPoint("BOTTOMRIGHT",-18,12);f.scroll:EnableMouseWheel(true)
        f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetWidth(264);f.scroll:SetScrollChild(f.child)
        f.text=f.child:CreateFontString(nil,"OVERLAY","GameTooltipText");U:Font(f.text,11);f.text:SetPoint("TOPLEFT");f.text:SetWidth(264);f.text:SetJustifyH("LEFT");f.text:SetJustifyV("TOP");f.text:SetWordWrap(true)
        f.scroll:SetScript("OnMouseWheel",function(_,delta)f.bar:SetValue(math.max(0,math.min(f.maximum or 0,(f.scroll:GetVerticalScroll() or 0)-delta*30)))end)
        f.bar=U:VerticalBar(f);f.bar:SetPoint("TOPRIGHT",-3,-36);f.bar:SetPoint("BOTTOMRIGHT",-3,14);f.bar:SetValueStep(1)
        f.bar:SetScript("OnValueChanged",function(_,value)f.scroll:SetVerticalScroll(value)end)
        UISpecialFrames[#UISpecialFrames+1]="FindAnUpgradeChain"
    end
    local lines={};local labels={all="Complete all",any="Complete one",count="Complete required quests",breadcrumb="Optional",optionalPrerequisite="Optional",unlocks="Unlocks",exclusive="Alternative",supersededBy="Replaced by",requiresActive="Requires in log",untilCompleted="Before completion",startingWith="Starts with",disabledWhileActive="Unavailable while active",related="Related"}
    local statuses={completed="Completed",active="In quest log",incomplete="Incomplete",unknown="",repeatable="Repeatable"}
    local previousOwner,previousGroup
    for _,entry in ipairs(info.entries or {}) do
        local label=labels[entry.kind] or "Earlier quest";local suffix=statuses[entry.state] or ""
        local group=entry.group and info.groups[entry.group]
        local indent=string.rep("  ",math.min(8,entry.depth or 0))
        if entry.ownerID~=previousOwner then
            if entry.ownerID and entry.ownerID~=id then
                local source=N.Providers.Source(entry.ownerID)
                lines[#lines+1]=indent.."For "..(source and source.title or "Quest "..entry.ownerID).." (#"..entry.ownerID..")"
            end
            previousOwner,previousGroup=entry.ownerID,nil
        end
        if group then
            if previousGroup~=entry.group then
                local heading=group.kind=="any" and "Complete one of "..#group.ids or group.kind=="count" and "Complete "..group.count.." of "..#group.ids or "Complete all "..#group.ids
                lines[#lines+1]=indent..heading..":";previousGroup=entry.group
            end
            label="-"
        else previousGroup=nil end
        lines[#lines+1]=indent..label..(group and " " or ": ")..(entry.title or "Quest "..entry.id).." (#"..entry.id..")"..(suffix~="" and " - "..suffix or "")
    end
    if info.truncated then lines[#lines+1]="More quests in this chain." end
    if info.uncertain then lines[#lines+1]="Some requirements unverified." end
    local f=self.chainFrame;f.text:SetText(table.concat(lines,"\n"));f.text:SetHeight(0)
    local height=math.max(16,A.Call(f.text.GetStringHeight,f.text) or 16);f.text:SetHeight(height);f.child:SetHeight(height)
    f:SetHeight(math.min(320,height+48));f.maximum=math.max(0,height-(f:GetHeight()-48));f.scroll:SetVerticalScroll(0);f.bar:SetMinMaxValues(0,f.maximum);f.bar:SetValue(0);f.bar:SetShown(f.maximum>0)
    U:Border(f,"dialog");f:ClearAllPoints();f:SetPoint("TOPRIGHT",self.frame,"TOPLEFT",-6,-42);f:Show();self.chainOwner=owner
end
function S:OpenSlot(value)
    local key=(value or ""):lower():gsub("[%s_-]","");local chosen,label
    for _,entry in ipairs(N.SearchModel.slots) do
        if key==entry[1]:lower():gsub("[%s_-]","") or key==entry[2]:lower():gsub("[%s_-]","") then chosen,label=entry[1],entry[2];break end
    end
    if not chosen then N.Core:Print("/fau slot head | ring | trinket | weapon | offhand | all");return false end
    if not self:Visible() then self:Toggle() end
    if not self:Visible() then return false end
    self:View("quests");self.filter.slot=chosen;self.slot:SetDefaultText(label);self:Changed(true);return true
end

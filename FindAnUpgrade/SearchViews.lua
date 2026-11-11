local _,N=...
local S,M,A,U=N.Search,N.Model,N.Adapter,N.UI

function S:CreateViews()
    self.view="quests";self.views={quests={query="",offset=0},shortlist={query="",offset=0}}
    self.tabs={}
    for i,entry in ipairs({{"quests","Quests"},{"shortlist","Shortlist"}}) do
        local key=entry[1];local tab=U:Tab(CreateFrame("Button",nil,self.frame,"BackdropTemplate"),entry[2],116)
        tab:SetPoint("TOPLEFT",16+(i-1)*120,-42);tab:SetScript("OnClick",function()self:View(key)end)
        U:SelectTab(tab,key==self.view);self.tabs[key]=tab
    end
end
function S:View(key)
    if not self.views or not self.views[key] or key==self.view then return end
    self:CommitRange(true);self.search:ClearFocus();self:CancelRange();self:CloseMenu();self.inspector:ClearItem()
    if N.Copy then N.Copy:Hide() end
    local previous=self.views[self.view];previous.query=self.search:GetText();previous.offset=self.offset
    self.view=key;local current=self.views[key];self.offset=current.offset;self.bottomTarget=nil
    self.search:SetText(current.query);self.placeholder:SetText(key=="shortlist" and "Search shortlist" or "Quest or reward")
    if key=="quests" then self.filter.query=current.query end
    for name,tab in pairs(self.tabs) do U:SelectTab(tab,name==key) end
    self.heights={};self:LayoutControls();self:DataChanged()
end
function S:Save(row)
    if not row then return end
    local ok,reason=N.Shortlist:Toggle(row.id)
    if not ok then
        N.Core:Print(reason=="capacity" and "Shortlist is full (20 quests)." or "Shortlist is read-only.")
        return
    end
    self.inspector:ClearItem();self:DataChanged()
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
    card.chain:SetScript("OnClick",function()if card.row and A.Over(self.scroll) then self:Chain(card.row.id) end end)
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
        if match and (availability.state~="completed" or not N.Core.profile.hideCompleted) then out[#out+1]=row end
    end
    return out
end
function S:Chain(id)
    if not N.Chains or not N.Chains:HasDetails(id) then return end
    self:CloseMenu();self.inspector:ClearItem();if N.Copy then N.Copy:Hide() end
    self.chainExpanded=self.chainExpanded or {}
    self.chainExpanded[id]=not self.chainExpanded[id]
    self.bottomTarget=nil
    self:Render()
end
function S:ChainQuestVisible(id)
    for _,card in ipairs(self.cards) do
        if card.row and card:IsShown() and card.chainQuestIDs and card.chainQuestIDs[id] then return true end
    end
    return false
end
function S:ChainRecord(id)
    local source=N.Providers.Source(id);local record=N.Catalog.records[id]
    if not record and source then
        record={id=id,title=source.title,level=source.level,items=source.items or {},source=source}
        N.Catalog.records[id]=record;N.Catalog.order[#N.Catalog.order+1]=record
    end
    if record then N.Catalog:Metadata(record,N.Character:Get().level) end
    local row={id=id,title=record and record.title or "Quest "..id,level=record and record.level,source=source,items={},missing=not source}
    -- Read current reward membership before constructing the inspected row.
    N.SearchModel:Reward(row)
    for _,meta in ipairs(N.SearchModel.currentItems[id] or record and record.items or {}) do
        local item=N.SearchModel:Item(meta);row.items[#row.items+1]=item
        if item.state~="ready" then self:Enqueue("item",{item.itemID}) end
    end
    if record and not record.metadataReady then self:Enqueue("quest",{id}) end
    row.location=N.Catalog:Location(id)
    return row
end
function S:InspectChainQuest(ownerID,id)
    self:CloseMenu();self.inspector:ClearItem()
    self.chainInspect=self.chainInspect or {}
    self.chainInspect[ownerID]=self.chainInspect[ownerID]~=id and id or nil
    self.bottomTarget=nil;self:Render()
end
local chainLabels={breadcrumb="Optional lead-in",optionalPrerequisite="Optional prerequisite",unlocks="Unlocks",exclusive="Alternative quest",supersededBy="Replacement quest",requiresActive="Requires in log",untilCompleted="Before completion",startingWith="Starts with",disabledWhileActive="Unavailable while active",related="Related quest"}
local chainStatuses={completed="Completed",active="In quest log",incomplete="Incomplete",unknown="Status unknown",repeatable="Repeatable"}
function S:HideChainRows(card)
    card.chainQuestIDs=nil
    for _,row in ipairs(card.chainRows or {}) do row:Hide() end
    if card.chainInspection then card.chainInspection.row=nil;card.chainInspection:Hide() end
end
function S:ChainRows(card,y,width)
    local expanded=self.chainExpanded and self.chainExpanded[card.row.id]
    card.chain.text:SetText(expanded and "▾ Quest chain" or "▸ Quest chain")
    if not expanded then return y end
    local info=N.Chains:Steps(card.row.id);local used=0;local inspectionShown=false;card.chainQuestIDs={}
    local unique,total={},0
    for _,entry in ipairs(info.rows) do
        if not unique[entry.id] then unique[entry.id]=true;total=total+1 end
        for _,related in ipairs(entry.related) do if not unique[related.id] then unique[related.id]=true;total=total+1 end end
    end
    card.chain.text:SetText("▾ Quest chain · "..total..(info.truncated and "+" or "")..(total==1 and " quest" or " quests"))
    local function line(title,detail,depth,selected,questID)
        used=used+1;card.chainRows=card.chainRows or {}
        local row=card.chainRows[used]
        if not row then
            row=CreateFrame("Button",nil,card,"BackdropTemplate");card.chainRows[used]=row
            row:RegisterForClicks("LeftButtonUp","RightButtonUp")
            row:SetScript("OnClick",function(_,button)
                if not row.questID or not card.row or not A.Over(self.scroll) then return end
                if button=="RightButton" then self:ContextMenu(self:ChainRecord(row.questID),row)
                else self:InspectChainQuest(card.row.id,row.questID) end
            end)
            row:SetScript("OnEnter",function()
                if not row.questID or not A.Over(self.scroll) then return end
                self.inspector:ClearItem();self.footerTooltip:SetOwner(row,"ANCHOR_LEFT");self.footerTooltip:SetText("Quest #"..row.questID.."\nClick to inspect rewards. Right-click for quest actions.");self.footerTooltip:Show()
            end)
            row:SetScript("OnLeave",function()self.footerTooltip:Hide()end)
            row.connector=row:CreateTexture(nil,"ARTWORK");row.connector:SetTexture("Interface\\Buttons\\WHITE8X8");row.connector:SetVertexColor(.5,.45,.3);row.connector:SetSize(8,1);row.connector:SetPoint("TOPRIGHT",row,"TOPLEFT",0,-11)
            row.save=CreateFrame("Button",nil,row);row.save:SetSize(24,24);row.save:SetPoint("TOPRIGHT",-2,-2)
            row.save.icon=row.save:CreateTexture(nil,"ARTWORK");row.save.icon:SetSize(17,15.3);row.save.icon:SetPoint("CENTER")
            row.save:SetScript("OnClick",function()if row.questID and A.Over(self.scroll) then self:Save({id=row.questID}) end end)
            row.save:SetScript("OnEnter",function()
                if not row.questID or not A.Over(self.scroll) then return end
                self.inspector:ClearItem();self.footerTooltip:SetOwner(row.save,"ANCHOR_LEFT");self.footerTooltip:SetText(N.Shortlist:Contains(row.questID) and "Remove from shortlist" or "Save to shortlist");self.footerTooltip:Show()
            end)
            row.save:SetScript("OnLeave",function()self.footerTooltip:Hide()end)
            row.title=row:CreateFontString(nil,"OVERLAY","GameTooltipText");U:Font(row.title,11)
            row.detail=row:CreateFontString(nil,"OVERLAY","GameTooltipText");U:Font(row.detail,10)
            for _,label in ipairs({row.title,row.detail}) do label:SetJustifyH("LEFT");label:SetJustifyV("TOP");label:SetWordWrap(true) end
            row.title:SetPoint("TOPLEFT",6,-5)
        end
        row.questID=questID;row.selected=selected;row.depth=depth
        row.save:SetShown(questID~=nil);row.connector:SetShown((depth or 0)>0)
        if questID then row.save.icon:SetAtlas(N.Shortlist:Contains(questID) and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off") end
        if questID then card.chainQuestIDs[questID]=true end
        local inset=14+math.min(6,depth or 0)*12;local rowWidth=math.max(40,width-inset-8)
        row:ClearAllPoints();row:SetPoint("TOPLEFT",inset,-y);row:SetWidth(rowWidth)
        U:Border(row,"tooltip");row:SetBackdropColor(selected and .13 or .055,selected and .11 or .055,.055,.95)
        row:SetBackdropBorderColor(selected and .65 or .25,selected and .53 or .25,selected and .22 or .25,.8)
        row.title:SetTextColor(selected and 1 or .9,selected and .82 or .9,selected and .2 or .9)
        row.title:SetWidth(rowWidth-(questID and 36 or 12));row.title:SetText(title);row.title:SetHeight(0)
        local titleHeight=math.max(12,A.Call(row.title.GetStringHeight,row.title) or 12);row.title:SetHeight(titleHeight)
        row.detail:ClearAllPoints();row.detail:SetPoint("TOPLEFT",6,-(titleHeight+7));row.detail:SetWidth(rowWidth-12)
        row.detail:SetTextColor(.7,.7,.72);row.detail:SetText(detail or "");row.detail:SetHeight(0)
        local detailHeight=detail and math.max(12,A.Call(row.detail.GetStringHeight,row.detail) or 12) or 0
        row.detail:SetHeight(detailHeight);row.detail:SetShown(detail~=nil)
        local height=titleHeight+detailHeight+(detail and 12 or 10);row:SetHeight(height);row:Show();y=y+height+3
        if questID and not inspectionShown and self.chainInspect and self.chainInspect[card.row.id]==questID then
            inspectionShown=true
            local detailCard=card.chainInspection
            if not detailCard then detailCard=self:Card(nil,card);card.chainInspection=detailCard end
            detailCard.detailWidth=width-22;detailCard:ClearAllPoints();detailCard:SetPoint("TOPLEFT",14,-y)
            local detailHeight=self:Fill(detailCard,self:ChainRecord(questID));detailCard:Show();y=y+detailHeight+5
        end
    end
    for _,entry in ipairs(info.rows) do
        local title=(entry.level and "["..entry.level.."] " or "")..entry.title
        local detail=(entry.selected and "Selected · " or "")..(chainStatuses[entry.state] or "Status unknown")
        for _,requirement in ipairs(entry.requirements) do detail=detail.." · "..requirement end
        line(title,detail,entry.depth,entry.selected,entry.id)
        for _,related in ipairs(entry.related) do
            line((chainLabels[related.kind] or "Related quest")..": "..related.title,
                (chainStatuses[related.state] or "Status unknown"),entry.depth+1,false,related.id)
        end
    end
    if info.truncated then line("More quests in this chain are not shown.",nil,0,false) end
    return y+3
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

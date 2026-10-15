local _, N = ...
local M, A = N.Model, N.Adapter
local Q = { tokens=setmetatable({}, {__mode="k"}) }; N.Questie = Q
function Q:Title(id)
    local db=self.database
    local title=type(db)=="table" and M.Text(A.Call(db.QueryQuestSingle,id,"name"))
    local source=N.Providers.Source(id)
    return title or source and source.title
end
local tagIDs={[1]=true,[21]=true,[62]=true,[81]=true,[82]=true,[83]=true,[84]=true,[85]=true,[88]=true,[89]=true,[98]=true,[294]=true}
function Q:Translate(value)
    local translator=self.translator
    if not M.Readable(translator) or type(translator)~="function" and type(translator)~="table" then return end
    local ok,result=pcall(translator,value); if ok then return M.Text(result) end
end
function Q:GroupProof(id,tag)
    tag=M.Text(tag); if not tag then return end
    local left,right=self:Translate("("),self:Translate(")")
    local complete=self:Translate("Complete")
    if not left or not right or not complete then return end
    if tag==left..complete..right then return "questie-ready" end
    -- The current builder exclusively puts available/complete markers in this
    -- group. Recognize its exact localized categories; arbitrary text is unknown.
    local labels={"Available","Event","Daily PvP","PvP","Weekly Account","Daily Account","Account","Weekly","Monthly","Daily Dungeon","Daily Heroic","Daily Celestial","Daily","Repeatable","Rune","Raid"}
    for _,label in ipairs(labels) do local translated=self:Translate(label); if translated and tag==left..translated..right then return "questie-available" end end
    for _,native in ipairs({RAID,WEEKLY,DAILY}) do if M.Text(native) and tag==left..native..right then return "questie-available" end end
    local db=self.database
    if type(db)=="table" and type(db.GetQuestTagInfo)=="function" then
        local ok,tagID,name=pcall(db.GetQuestTagInfo,id)
        if ok and M.Number(tagID) and tagIDs[tagID] and M.Text(name) and tag==left..name..right then return "questie-available" end
    end
end
function Q:GroupContains(tooltip,tip,id)
    local groups=tooltip.npcAndObjectOrder
    if not M.Readable(groups) or type(groups)~="table" or not M.Readable(tip) or type(tip)~="table" or M.QuestId(tip.questId)~=id then return false end
    local count=0
    for _,group in pairs(groups) do
        if M.Readable(group) and type(group)=="table" then
            for _,entry in pairs(group) do count=count+1; if count>256 then return false end; if entry==tip then return true end end
        end
    end
    return false
end
function Q:Observe(tooltip)
    self.tokens[tooltip]=M.Readable(tooltip._Rebuild) and tooltip._Rebuild or false
end
function Q.Rows(tooltip,primaryID,primaryType)
    local rows = {}
    local quests = tooltip.questOrder
    if M.Readable(quests) and type(quests) == "table" then
        local n = 0
        for id in pairs(quests) do n=n+1; if n>256 then return {} end
            if M.QuestId(id) then rows[#rows+1] = {id=id,title=Q:Title(id),provenance="Questie rendered questOrder"} end
        end
    end
    local groups = tooltip.npcAndObjectOrder
    if M.Readable(groups) and type(groups) == "table" then
        local n = 0
        for _, group in pairs(groups) do
            if M.Readable(group) and type(group) == "table" then
                for _, tip in pairs(group) do n=n+1; if n>256 then return {} end
                    if M.Readable(tip) and type(tip)=="table" and M.QuestId(tip.questId) then
                        local proof=tip.questId==primaryID and (primaryType=="available" and "questie-available" or primaryType=="complete" and "questie-ready") or Q:GroupProof(tip.questId,tip.type)
                        rows[#rows+1]={id=tip.questId,title=Q:Title(tip.questId),availabilityProof=proof,questieTip=tip,provenance="Questie rendered npcAndObjectOrder exact questId"}
                    end
                end
            end
        end
    end
    -- Offer rows take precedence over objective grouping for a duplicate ID.
    table.sort(rows,function(a,b) if a.id==b.id then return a.availabilityProof~=nil and b.availabilityProof==nil end; return a.id<b.id end)
    return N.Providers.ResolveRows(rows)
end
function Q:Shown(icon, tooltip)
    if not icon or not tooltip or A.Forbidden(icon) or not A.Visible(icon) or not A.Visible(tooltip) or icon.hidden or icon._needsUnload or tooltip._owner ~= icon then return end
    local color=A.Color(icon.texture)
    if not color or color[4]<=0 then return end
    local token=tooltip._Rebuild
    if not M.Readable(token) or type(token)~="function" then return end
    local previous=self.tokens[tooltip];self.tokens[tooltip]=token
    -- Successful Questie renders replace _Rebuild; alpha/throttle early returns
    -- leave it unchanged. Unknown tooltips must establish a baseline first.
    if previous==nil or previous==token then return end
    local data = icon.data
    if not M.Readable(data) or type(data) ~= "table" then N.Sources:Clear(icon); return end
    local dataID = M.QuestId(data.Id)
    if not dataID then N.Sources:Clear(icon); return end
    local dataType=M.Text(data.Type)
    local rows = Q.Rows(tooltip,dataID,dataType); if #rows == 0 then N.Sources:Clear(icon); return end
    for _,row in ipairs(rows) do
        if row.availabilityProof then
            local proof,tip,id,tag=row.availabilityProof,row.questieTip,row.id,M.Text(row.questieTip and row.questieTip.type)
            row.availabilityCheck=function()
                if A.Visible(icon) and not icon.hidden and not icon._needsUnload and icon.data==data and M.QuestId(data.Id)==dataID and M.Text(data.Type)==dataType and tooltip._owner==icon and tooltip._Rebuild==token and Q:GroupContains(tooltip,tip,id) and M.Text(tip.type)==tag then return proof end
            end
        end
    end
    local primary=false;for _,row in ipairs(rows) do if row.id==dataID then primary=true;break end end
    if not primary then N.Sources:Clear(icon); return end
    local surface = icon.miniMapIcon == true and "minimap" or "worldmap"
    N.Sources:Watch(icon)
    local signature = {}; for _,row in ipairs(rows) do signature[#signature+1]=row.id end
    N.Sources:Set({ key = N.Sources:Key(icon,table.concat(signature,","),data), owner = icon, surface = surface, rows = rows,
        over = function() return A.Over(icon) end,
        valid = function() return A.Visible(icon) and not icon.hidden and not icon._needsUnload and icon.data==data and M.QuestId(data.Id)==dataID and M.Text(data.Type)==dataType and (icon.miniMapIcon==true)==(surface=="minimap") and (surface=="minimap" or A.Visible(WorldMapFrame)) end })
end
local function unitGUID(tooltip)
    if A.Forbidden(tooltip) or type(tooltip.GetUnit)~="function" then return end
    local ok,name,unit=pcall(tooltip.GetUnit,tooltip)
    if not ok or not M.Text(name) or not M.Text(unit) then return end
    return M.Text(A.Call(UnitGUID,unit)),name
end
function Q:RenderedNPCEntry(tooltip,id,kind)
    local lib,profile=self.lib,Questie and Questie.db and Questie.db.profile
    if tooltip~=GameTooltip or type(lib)~="table" or not profile then return false end
    local title=M.Text(A.Call(lib.GetColoredQuestName,lib,id,profile.enableTooltipsQuestLevel==true,true))
    local count=A.Call(tooltip.NumLines,tooltip)
    if not title or not M.Number(count) or count<1 or count>256 then return false end
    local texture=kind=="NPC" and "Interface\\Addons\\Questie\\Icons\\tooltip_available.png" or "Interface\\Addons\\Questie\\Icons\\tooltip_complete.png"
    for index=1,count do
        local line=_G["GameTooltipTextLeft"..index]
        local text=line and M.Text(A.Call(line.GetText,line))
        if text and text:find(texture,1,true) and text:sub(-#title)==title then return true end
    end
    return false
end
function Q:UnitShown(tooltip)
    local module=self.units
    local profile=Questie and Questie.db and Questie.db.profile
    if not module or not profile or profile.enableTooltips~=true or profile.showQuestsInNpcTooltip~=true or not A.Visible(tooltip) then return end
    local guid,name=unitGUID(tooltip)
    local npc=guid and M.QuestId(tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")))
    if not npc or guid~=M.Text(A.Call(UnitGUID,"mouseover")) or module.lastGametooltipUnit~=name or module.lastGametooltipType~="monster" then return end
    self.npc={guid=guid,id=npc,tooltip=tooltip}
    local source=N.Sources:NPC()
    if source and source.key==guid then
        N.Sources:Set(source)
        if N.Hover.open and N.Hover.source and N.Hover.source.key==guid then N.Hover.source=source; N.Hover:Refresh() end
    end
end
function Q.ForNPC(npcID)
    local snapshot,module=Q.npc,Q.units
    local profile=Questie and Questie.db and Questie.db.profile
    if not profile or profile.enableTooltips~=true or profile.showQuestsInNpcTooltip~=true then return {} end
    if not snapshot or snapshot.id~=npcID or not module or not A.Visible(snapshot.tooltip) or unitGUID(snapshot.tooltip)~=snapshot.guid or M.Text(A.Call(UnitGUID,"mouseover"))~=snapshot.guid then return {} end
    local registry=M.Readable(module.lookupByKey) and type(module.lookupByKey)=="table" and module.lookupByKey["m_"..npcID]
    if not M.Readable(registry) or type(registry)~="table" then return {} end
    local rows,count={},0
    for key,entry in pairs(registry) do
        count=count+1; if count>256 then return {} end
        if M.Readable(entry) and type(entry)=="table" and M.QuestId(entry.questId) and M.QuestId(entry.starterId)==npcID and M.Text(entry.name) then
            local kind=M.Text(entry.type)
            if (kind=="NPC" or kind=="Finisher") and Q:RenderedNPCEntry(snapshot.tooltip,entry.questId,kind) then
                local registryKey,currentEntry,currentID,proof=key,entry,entry.questId,kind=="NPC" and "questie-available" or "questie-ready"
                rows[#rows+1]={id=entry.questId,title=Q:Title(entry.questId),availabilityProof=proof,availabilityCheck=function()
                    local currentProfile=Questie and Questie.db and Questie.db.profile
                    local currentRegistry=M.Readable(module.lookupByKey) and type(module.lookupByKey)=="table" and module.lookupByKey["m_"..npcID]
                    if currentProfile~=profile or profile.enableTooltips~=true or profile.showQuestsInNpcTooltip~=true or Q.units~=module or Q.npc~=snapshot or currentRegistry~=registry or registry[registryKey]~=currentEntry or M.QuestId(currentEntry.questId)~=currentID or M.Text(currentEntry.type)~=kind or M.QuestId(currentEntry.starterId)~=npcID then return end
                    if A.Visible(snapshot.tooltip) and (unitGUID(snapshot.tooltip)~=snapshot.guid or not Q:RenderedNPCEntry(snapshot.tooltip,currentID,kind)) then return end
                    return proof
                end,provenance="Questie current exact NPC tooltip registry"}
            end
        end
    end
    return rows
end
function Q:Attach()
    if InCombatLockdown() or not QuestieLoader or type(QuestieLoader.ImportModule) ~= "function" then return end
    if not self.translator then self.translator=A.Call(QuestieLoader.ImportModule,QuestieLoader,"l10n") end
    if not self.database then
        local db=A.Call(QuestieLoader.ImportModule,QuestieLoader,"QuestieDB")
        if type(db)=="table" and type(db.GetQuestTagInfo)=="function" then self.database=db end
    end
    if not self.lib then
        local lib=A.Call(QuestieLoader.ImportModule,QuestieLoader,"QuestieLib")
        if type(lib)=="table" and type(lib.GetColoredQuestName)=="function" then self.lib=lib end
    end
    if not self.units then
        local units=A.Call(QuestieLoader.ImportModule,QuestieLoader,"QuestieTooltips")
        if type(units)=="table" and type(units.private)=="table" and type(units.private.AddUnitDataToTooltip)=="function" then
            hooksecurefunc(units.private,"AddUnitDataToTooltip",function(tooltip) self:UnitShown(tooltip) end)
            self.units=units
        end
    end
    if self.module then return end
    local module = A.Call(QuestieLoader.ImportModule, QuestieLoader, "MapIconTooltip")
    if type(module) ~= "table" or type(module.ShowOnTooltip) ~= "function" then return end
    if GameTooltip then self:Observe(GameTooltip) end
    -- The installed Forever Questie 12.1.0 publishes exact grouped IDs after
    -- ShowOnTooltip. No marker is created, hidden, recolored or reassigned.
    hooksecurefunc(module, "ShowOnTooltip", function(icon, tooltip) self:Shown(icon, tooltip) end)
    self.module = module
end

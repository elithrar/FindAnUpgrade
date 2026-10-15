local _, N = ...
local M,A=N.Model,N.Adapter
local C={records={},order={},cursor=1}; N.Catalog=C
function C:Begin()
    local data=N.CatalogData
    if type(data)~="table" or (data.schemaVersion~=1 and data.schemaVersion~=2) or type(data.quests)~="table" then
        self.error="Bundled reward catalogue unavailable."; self.ids,self.order=nil,{}; return false
    end
    if self.data==data then return true end
    self.data,self.ids,self.cursor,self.records,self.order=data,data.quests,1,{},{}
    self.done,self.error,self.locations=false,nil,{}
    if N.SearchModel then N.SearchModel.cache,N.SearchModel.usability,N.SearchModel.currentItems,N.SearchModel.currentStamp={},{},{},{} end
    return true
end
function C:Invalidate(id)
    if id then local row=self.records[id]; if row then row.metadataReady=nil end
    else for _,row in ipairs(self.order) do row.metadataReady=nil end end
end
function C:Metadata(row,playerLevel,force)
    playerLevel=playerLevel or N.Character:Get().level
    if not force and row.metadataReady and row.metadataPlayerLevel==playerLevel then return true,false end
    local beforeTitle,beforeLevel=row.title,row.level
    local title=M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,row.id))
    local level=A.Call(C_QuestLog and C_QuestLog.GetQuestDifficultyLevel,row.id)
    local source=row.source
    local published=source and source.confirmation=="published"
    local recordedTitle=published and M.Text(source.title) or nil
    if title then row.title=title elseif recordedTitle then row.title=recordedTitle end
    if M.Number(level) and level>=1 and level<=200 and level==math.floor(level) then row.level=level
    elseif published and M.Number(source.level) and source.level>=1 and source.level<=200 and source.level==math.floor(source.level) then row.level=source.level
    else row.level=nil end
    row.metadataReady=(title~=nil or recordedTitle~=nil) and row.level~=nil; row.metadataPlayerLevel=playerLevel
    return row.metadataReady,row.title~=beforeTitle or row.level~=beforeLevel
end
function C:Step()
    if not self.ids or self.done then return false end
    local stop=math.min(#self.ids,self.cursor+63)
    for i=self.cursor,stop do
        local source=self.ids[i]; local id=M.QuestId(source.id)
        if id and not self.records[id] and type(source.items)=="table" then
            local row={id=id,title=source.title,level=source.level,items=source.items,source=source}
            self:Metadata(row); self.records[id]=row; self.order[#self.order+1]=row
        end
    end
    self.cursor=stop+1; self.done=self.cursor>#self.ids; return true
end
function C:Locations(id)
    local faction=N.Character:Get().faction
    if self.locationFaction~=faction then self.locations={};self.locationFaction=faction end
    if self.locations[id] then return self.locations[id] end
    local source=self.records[id] and self.records[id].source; local out={}
    self.locations[id]=out
    for _,location in ipairs(source and source.locations or {}) do
        if N.Providers.LocationAllowed(location,source,{faction=faction}) then
        local name=M.Text(location.name)
        local fallback=location.npcID and "NPC "..location.npcID or location.objectID and "Object "..location.objectID or location.itemID and "Item "..location.itemID or "Quest giver"
        local row={npcID=location.npcID,objectID=location.objectID,itemID=location.itemID,name=name or fallback,nameKnown=name~=nil}
        local map=M.QuestId(location.mapID); local info=map and A.Call(C_Map and C_Map.GetMapInfo,map)
        -- Only recorded native-map coordinates on a current native zone map.
        if M.Readable(info) and type(info)=="table" and Enum and Enum.UIMapType and M.Readable(info.mapType) and info.mapType==Enum.UIMapType.Zone
            and M.Number(location.x) and M.Number(location.y) and location.x>=0 and location.x<=1 and location.y>=0 and location.y<=1 then
            row.mapID,row.x,row.y,row.zone=map,location.x,location.y,M.Text(info.name) or ("Map "..map)
            row.phase,row.mobile=location.phase or source.locationConflict,location.mobile
        end
        out[#out+1]=row
        end
    end
    return out
end
function C:Location(id)
    local rows=self:Locations(id); local current=N.Character:Get().mapID
    for _,row in ipairs(rows) do if row.mapID==current and row.x then return row,#rows end end
    return rows[1],#rows
end
function C:Category(id)
    local index=N.Data and N.Data.categoryById and N.Data.categoryById[id]
    return index and N.Data.categories and N.Data.categories[index] or nil
end
function C:QuestTag(id)
    local native=N.Character:QuestTag(id)
    if native then return native end
    return N.QuestTags and N.QuestTags[id]
end
function C:CurrentCategories(context)
    context=context or N.Character:Get()
    local categories=N.Data and N.Data.categories or {}
    if self.categorySource==categories and self.categoryRevision==context.locationRevision then return self.currentCategories,self.currentCategoryName end
    local names={}
    for _,category in ipairs(categories) do
        local area=M.QuestId(category.sourceZoneID)
        local name=area and M.Text(A.Call(C_Map and C_Map.GetAreaInfo,area))
        if name then
            local match=names[name]
            if match and match.area~=area then match.ambiguous=true
            elseif not match then names[name]={area=area,category=category.name} end
        end
    end
    self.categorySource,self.categoryRevision=categories,context.locationRevision
    self.currentCategories,self.currentCategoryName={},nil
    for index,info in ipairs(context.mapHierarchy or {}) do
        if index>8 then break end
        local name=M.Text(info.name); local match=name and names[name]
        local zone=Enum and Enum.UIMapType and Enum.UIMapType.Zone
        local dungeon=Enum and Enum.UIMapType and Enum.UIMapType.Dungeon
        if match and not match.ambiguous and M.Number(info.mapType) and (zone and info.mapType==zone or dungeon and info.mapType==dungeon) then
            self.currentCategories,self.currentCategoryName={[match.category]=true},name
            return self.currentCategories,self.currentCategoryName
        end
    end
    return self.currentCategories,self.currentCategoryName
end

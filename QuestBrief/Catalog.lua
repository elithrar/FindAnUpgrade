local _, N = ...
local M,A=N.Model,N.Adapter
local C={records={},order={},cursor=1}; N.Catalog=C
function C:Begin()
    local data=N.CatalogData
    if type(data)~="table" or data.schemaVersion~=1 or type(data.quests)~="table" then
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
function C:Metadata(row,playerLevel)
    playerLevel=playerLevel or A.Call(UnitLevel,"player")
    if row.metadataReady and row.metadataPlayerLevel==playerLevel then return true end
    local title=M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,row.id))
    local level=A.Call(C_QuestLog and C_QuestLog.GetQuestDifficultyLevel,row.id)
    if title then row.title=title end
    if M.Number(level) and level>=1 and level<=200 and level==math.floor(level) then row.level=level else row.level=nil end
    row.metadataReady=title~=nil and row.level~=nil; row.metadataPlayerLevel=playerLevel
    return row.metadataReady
end
function C:Step()
    if not self.ids or self.done then return false end
    local stop=math.min(#self.ids,self.cursor+63)
    for i=self.cursor,stop do
        local source=self.ids[i]; local id=M.QuestId(source.id)
        if id and not self.records[id] and type(source.items)=="table" and #source.items>0 then
            local row={id=id,title=source.title,level=source.level,items=source.items,source=source}
            self:Metadata(row); self.records[id]=row; self.order[#self.order+1]=row
        end
    end
    self.cursor=stop+1; self.done=self.cursor>#self.ids; return true
end
function C:Locations(id)
    if self.locations[id] then return self.locations[id] end
    local source=self.records[id] and self.records[id].source; local out={}
    self.locations[id]=out
    for _,location in ipairs(source and source.locations or {}) do
        local name=M.Text(location.name)
        local row={npcID=location.npcID,name=name or (location.npcID and "NPC "..location.npcID or "Quest giver"),nameKnown=name~=nil}
        local map=M.QuestId(location.mapID); local info=map and A.Call(C_Map and C_Map.GetMapInfo,map)
        -- Only recorded native-map coordinates on a current native zone map.
        if M.Readable(info) and type(info)=="table" and Enum and Enum.UIMapType and M.Readable(info.mapType) and info.mapType==Enum.UIMapType.Zone
            and M.Number(location.x) and M.Number(location.y) and location.x>=0 and location.x<=1 and location.y>=0 and location.y<=1 then
            row.mapID,row.x,row.y,row.zone=map,location.x,location.y,M.Text(info.name) or ("Map "..map)
            row.phase,row.mobile=location.phase or source.locationConflict,location.mobile
        end
        out[#out+1]=row
    end
    return out
end
function C:Location(id)
    local rows=self:Locations(id); local current=A.Call(C_Map and C_Map.GetBestMapForUnit,"player")
    for _,row in ipairs(rows) do if row.mapID==current and row.x then return row,#rows end end
    return rows[1],#rows
end

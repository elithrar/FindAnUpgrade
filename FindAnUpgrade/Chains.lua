local _,N=...
local M=N.Model
local C={};N.Chains=C
local function list(value)
    return M.Readable(value) and type(value)=="table" and #value<=128
end
local function source(id) return N.Providers.Source(id) end
local function facts(id) return N.Character:Quest(id) end
local function chain(row)
    return M.Readable(row.chain) and type(row.chain)=="table" and row.chain or nil
end
local function groups(row)
    local value=chain(row)
    if value and list(value.groups) then return value.groups end
    local ids=row.prerequisiteAlternatives or row.prerequisites
    if not ids then return {} end
    return {{kind=row.prerequisiteAlternatives and "any" or row.prerequisiteCount and "count" or "all",
        ids=ids,count=row.prerequisiteCount,verified=row.prerequisitesVerified==true}}
end
local function relations(row)
    local value=chain(row)
    if value and list(value.relations) then return value.relations end
    local result={}
    if list(row.exclusive) then for _,id in ipairs(row.exclusive) do result[#result+1]={id=id,kind="exclusive",verified=row.exclusiveVerified==true} end end
    return result
end
local function validGroup(group)
    if not M.Readable(group) or type(group)~="table" then return end
    if not list(group.ids) or #group.ids==0 or group.kind~="all" and group.kind~="any" and group.kind~="count" then return end
    local seen={}
    for _,id in ipairs(group.ids) do if not M.QuestId(id) or seen[id] then return end;seen[id]=true end
    local required=group.kind=="any" and 1 or group.kind=="count" and group.count or #group.ids
    if not M.Number(required) or required~=math.floor(required) or required<1 or required>#group.ids then return end
    return required
end
local function included(ids,id)
    if not list(ids) then return false end
    for _,other in ipairs(ids) do if other==id then return true end end
    return false
end
local function optional(row)
    if row.isBreadcrumb==true then return true end
    for _,relation in ipairs(relations(row)) do if relation.kind=="breadcrumb" then return true end end
    return false
end
local function completion(id,strict)
    local current=facts(id)
    if current.completed==true then return true end
    local previous=source(id)
    if not previous then return nil end
    if optional(previous) then return nil end
    local uncertain=current.completed==nil
    if not strict then
        for _,relation in ipairs(relations(previous)) do if relation.kind=="exclusive" and M.QuestId(relation.id) then
            local other=facts(relation.id)
            if relation.verified==true and other.completed==true then return true end
            if relation.verified~=true or other.completed==nil then uncertain=true end
        end end
    end
    if uncertain then return nil end
    return false
end
local function entry(id,kind,verified,depth,groupIndex,count)
    local row=source(id) or {}
    local current=facts(id)
    local key=current.active==true and "active" or current.completed==true and (current.repeatable==false and "completed" or current.repeatable==true and "repeatable" or "unknown")
        or current.completed==false and "incomplete" or "unknown"
    return {id=id,title=M.Text(row.title) or ("Quest "..id),state=key,kind=kind,verified=verified==true,depth=depth or 0,group=groupIndex,count=count}
end
function C:HasDetails(id)
    local row=source(id);if not row then return false end
    local value=chain(row)
    if value then return list(value.groups) and #value.groups>0 or list(value.relations) and #value.relations>0 or false end
    return row.prerequisites~=nil or row.prerequisiteAlternatives~=nil or row.exclusive~=nil
end
function C:State(row)
    if not row then return end
    local uncertain,requirements=false,{}
    for _,group in ipairs(groups(row)) do
        local required=validGroup(group)
        if not required then uncertain=true
        else
            local done,unknown=0,0
            for _,id in ipairs(group.ids) do
                local complete
                if id~=row.id then complete=completion(id,group.kind~="all" or included(group.noAlternates,id)) end
                if complete==true then done=done+1 elseif complete==nil then unknown=unknown+1
                else local previous=source(id);requirements[#requirements+1]={id=id,title=previous and previous.title} end
            end
            if done<required then
                if group.verified==true and done+unknown<required then
                    return {state="blocked",label="Prerequisite incomplete",authority="verified-prerequisite",reason="Prerequisite incomplete",requirements=requirements}
                end
                uncertain=true
            end
        end
    end
    for _,relation in ipairs(relations(row)) do if relation.verified==true and M.QuestId(relation.id) then
        local current=facts(relation.id)
        local final=current.completed==true and current.repeatable==false
        local blocked,reason=false
        if relation.kind=="exclusive" then blocked=current.active==true or final;reason="Other quest path chosen"
        elseif relation.kind=="supersededBy" then blocked=current.active==true or final;reason="Later quest already reached"
        elseif relation.kind=="requiresActive" then blocked=current.active==false;reason="Required quest is not active"
        elseif relation.kind=="untilCompleted" then blocked=final;reason="Quest window completed"
        elseif relation.kind=="startingWith" then blocked=current.active==false and current.completed==false;reason="Starting quest incomplete"
        elseif relation.kind=="disabledWhileActive" then blocked=current.active==true;reason="Another quest is active" end
        if blocked then return {state="blocked",label=reason,reason=reason,authority="verified-chain",requirements={{id=relation.id,title=source(relation.id) and source(relation.id).title}}} end
    end end
    if uncertain then return {state="unknown",authority="recorded-chain",requirements=requirements} end
end
function C:Describe(id)
    local result={id=id,groups={},relations={},entries={},truncated=false,hasDetails=self:HasDetails(id),uncertain=false}
    if not result.hasDetails then return result end
    local queue,seen={{id=id,depth=0}},{}
    local function onPath(current,previousID)
        while current do
            if current.id==previousID then return true end
            current=current.parent
        end
        return false
    end
    local cursor=1
    while cursor<=#queue do
        local current=queue[cursor];cursor=cursor+1
        if not seen[current.id] then
            seen[current.id]=true
            local row=source(current.id) or {}
            for _,group in ipairs(groups(row)) do
                local required=validGroup(group)
                if required then for _,previousID in ipairs(group.ids) do
                    if onPath(current,previousID) then required=nil;break end
                end end
                if not required then result.uncertain=true
                else
                    local detail={kind=group.kind,count=required,ids=group.ids,verified=group.verified==true,entries={},depth=current.depth,ownerID=current.id}
                    result.groups[#result.groups+1]=detail
                    if group.verified~=true then result.uncertain=true end
                    for _,previousID in ipairs(group.ids) do
                        if #result.entries>=32 then result.truncated=true;return result end
                        local value=entry(previousID,group.kind,group.verified,current.depth,#result.groups,required)
                        value.ownerID=current.id
                        if value.state=="unknown" then result.uncertain=true end
                        detail.entries[#detail.entries+1]=value;result.entries[#result.entries+1]=value
                        if current.depth<8 and not seen[previousID] and #queue<33 then queue[#queue+1]={id=previousID,depth=current.depth+1,parent=current}
                        elseif current.depth>=8 and self:HasDetails(previousID) then result.truncated=true end
                    end
                end
            end
            for _,relation in ipairs(relations(row)) do if M.QuestId(relation.id) and not onPath(current,relation.id) then
                if #result.entries>=32 then result.truncated=true;return result end
                local value=entry(relation.id,relation.kind,relation.verified,current.depth)
                value.ownerID=current.id
                if value.state=="unknown" then result.uncertain=true end
                result.entries[#result.entries+1]=value;result.relations[#result.relations+1]=value
                if relation.verified~=true then result.uncertain=true end
            end end
        end
    end
    return result
end
function C:Index()
    if self.data==N.CatalogData then return end
    N.Providers.Index();self.data=N.CatalogData;self.reverse={}
    for id,row in pairs(N.Providers.records or {}) do
        local function add(previousID)
            if not M.QuestId(previousID) then return end
            self.reverse[previousID]=self.reverse[previousID] or {};self.reverse[previousID][id]=true
        end
        for _,group in ipairs(groups(row)) do if list(group.ids) then for _,previousID in ipairs(group.ids) do add(previousID) end end end
        for _,relation in ipairs(relations(row)) do add(relation.id) end
    end
end
function C:Dependants(ids)
    self:Index();local result,queue={},{}
    for id in pairs(ids or {}) do if M.QuestId(id) then result[id]=true;queue[#queue+1]=id end end
    local cursor=1
    while cursor<=#queue and cursor<=10000 do
        local id=queue[cursor];cursor=cursor+1
        for dependant in pairs(self.reverse[id] or {}) do if not result[dependant] then
            result[dependant]=true;if #queue<10000 then queue[#queue+1]=dependant end
        end end
    end
    return result
end

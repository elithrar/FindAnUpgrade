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
    local key=current.active==true and "active" or current.completed==true and (current.repeatable==true and "repeatable" or "completed")
        or current.completed==false and "incomplete" or "unknown"
    return {id=id,title=M.Text(row.title) or ("Quest "..id),state=key,kind=kind,verified=verified==true,depth=depth or 0,group=groupIndex,count=count}
end
function C:HasDetails(id)
    local row=source(id);if not row then return false end
    local value=chain(row)
    if value then
        if list(value.groups) and #value.groups>0 or list(value.relations) and #value.relations>0 then return true end
    elseif row.prerequisites~=nil or row.prerequisiteAlternatives~=nil or row.exclusive~=nil then return true end
    self:Index();return self.next[id]~=nil
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
    N.Providers.Index();self.data=N.CatalogData;self.reverse={};self.next={}
    for id,row in pairs(N.Providers.records or {}) do
        local function add(previousID)
            if not M.QuestId(previousID) then return end
            self.reverse[previousID]=self.reverse[previousID] or {};self.reverse[previousID][id]=true
        end
        for _,group in ipairs(groups(row)) do if list(group.ids) then for _,previousID in ipairs(group.ids) do
            add(previousID)
            if validGroup(group) then self.next[previousID]=self.next[previousID] or {};self.next[previousID][id]=group.verified==true end
        end end end
        for _,relation in ipairs(relations(row)) do add(relation.id) end
    end
end
-- Keep progression separate from availability gates and replacement/alternate
-- relations. In particular, supersededBy alone does not establish a next step.
function C:Steps(id)
    self:Index()
    local result={rows={},uncertain=false,truncated=false}
    local nodes,edges,before,after,count={},{},{},{},0
    local function include(questID)
        if nodes[questID] then return true end
        if count>=32 then result.truncated=true;return false end
        count=count+1;nodes[questID]=true;return true
    end
    local function connect(first,last,verified)
        local seen={}
        local function reaches(current)
            if current==first then return true end
            if seen[current] then return false end
            seen[current]=true
            for nextID in pairs(edges[current] or {}) do if reaches(nextID) then return true end end
            return false
        end
        if reaches(last) then result.uncertain=true;return end
        edges[first]=edges[first] or {};edges[first][last]=true
        if not verified then result.uncertain=true end
    end
    local function sorted(set)
        local ids={};for questID in pairs(set or {}) do ids[#ids+1]=questID end;table.sort(ids);return ids
    end
    local function earlier(questID,depth,path)
        if path[questID] then result.uncertain=true;return end
        if before[questID] then return end
        before[questID]=true;path[questID]=true
        for _,group in ipairs(groups(source(questID) or {})) do
            if not validGroup(group) then result.uncertain=true
            else for _,previousID in ipairs(group.ids) do
                if depth>=8 then result.truncated=true
                elseif path[previousID] then result.uncertain=true
                elseif include(previousID) then connect(previousID,questID,group.verified==true);earlier(previousID,depth+1,path) end
            end end
        end
        path[questID]=nil
    end
    local function later(questID,depth,path)
        if after[questID] then return end
        after[questID]=true;path[questID]=true
        for _,nextID in ipairs(sorted(self.next[questID])) do
            if depth>=8 then result.truncated=true
            elseif path[nextID] or before[nextID] then result.uncertain=true
            elseif include(nextID) then connect(questID,nextID,self.next[questID][nextID]);later(nextID,depth+1,path) end
        end
        path[questID]=nil
    end
    if not M.QuestId(id) then return result end
    include(id);earlier(id,0,{})
    local ancestors={};for questID in pairs(before) do ancestors[questID]=true end
    later(id,0,{})
    -- A follow-up may also require quests outside the selected path.
    for _,questID in ipairs(sorted(nodes)) do earlier(questID,0,{}) end
    -- Topological order keeps every represented prerequisite before its quest.
    -- Only branches add indentation; long linear chains stay readable.
    local incoming,depths,emitted={},{},{}
    for first,targets in pairs(edges) do for last in pairs(targets) do incoming[last]=(incoming[last] or 0)+1 end end
    local joins={};for questID,total in pairs(incoming) do if total>1 then joins[questID]=true end end
    local order,rank={},{}
    local branched=false
    local function visit(questID)
        if rank[questID] then return end
        order[#order+1]=questID;rank[questID]=#order
        local children=sorted(edges[questID]);if #children>1 then branched=true end
        for _,child in ipairs(children) do visit(child) end
    end
    for _,questID in ipairs(sorted(nodes)) do if not incoming[questID] then visit(questID) end end
    local relatedCount=0
    for _=1,count do
        local chosen
        for _,questID in ipairs(order) do if not emitted[questID] and (incoming[questID] or 0)==0 then chosen=questID;break end end
        if not chosen then result.uncertain=true;break end
        emitted[chosen]=true
        if joins[chosen] then depths[chosen]=0 end
        local value=entry(chosen,"step",true,depths[chosen] or 0)
        local row=source(chosen) or {};value.level=row.level;value.selected=chosen==id
        value.role=chosen==id and "Selected quest" or ancestors[chosen] and "Earlier quest" or after[chosen] and "Follow-up" or "Prerequisite"
        value.requirements={};value.related={}
        for _,group in ipairs(groups(row)) do if validGroup(group) and #group.ids>1 then
            local names={};for _,previousID in ipairs(group.ids) do local previous=source(previousID);names[#names+1]=previous and previous.title or "Quest "..previousID end
            value.requirements[#value.requirements+1]=(group.kind=="any" and "Complete one of "..#group.ids or group.kind=="count" and "Complete "..group.count.." of "..#group.ids or "Complete all "..#group.ids)..": "..table.concat(names,", ")
        end end
        for _,relation in ipairs(relations(row)) do if M.QuestId(relation.id) and relation.id~=chosen then
            local progression=relation.kind=="supersededBy" and edges[chosen] and edges[chosen][relation.id]
            if not progression then
                if relatedCount>=32 then result.truncated=true
                else
                    relatedCount=relatedCount+1
                    value.related[#value.related+1]=entry(relation.id,relation.kind,relation.verified)
                    if relation.verified~=true then result.uncertain=true end
                end
            end
        end end
        result.rows[#result.rows+1]=value
        local targets=edges[chosen] or {}
        for nextID in pairs(targets) do
            incoming[nextID]=incoming[nextID]-1
            depths[nextID]=math.max(depths[nextID] or 0,math.min(6,(depths[chosen] or 0)+(branched and 1 or 0)))
        end
    end
    return result
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

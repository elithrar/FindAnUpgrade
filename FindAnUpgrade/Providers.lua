local _, N = ...
local M, A = N.Model, N.Adapter
local P = {}; N.Providers = P
function P.Context()
    return N.Character:Get()
end
local function facts(id)
    return N.Character:Quest(id)
end
function P.Index()
    local data=N.CatalogData
    if P.data==data then return end
    P.data,P.records,P.starters=data,{},{}
    if not M.Readable(data) or type(data)~="table" or not M.Readable(data.quests) or type(data.quests)~="table" or #data.quests>10000 then return end
    for _,source in ipairs(data.quests) do
        if M.Readable(source) and type(source)=="table" and M.QuestId(source.id) then
            P.records[source.id]=source
            for _,location in ipairs(source.locations or {}) do
                local npc=M.QuestId(location.npcID)
                if npc then P.starters[npc]=P.starters[npc] or {}; P.starters[npc][#P.starters[npc]+1]=source.id end
            end
        end
    end
end
function P.Source(id)
    P.Index(); return P.records and P.records[id]
end
local function state(key,label,authority,reason,requirements)
    return {state=key,label=label,authority=authority,reason=reason,requirements=requirements}
end
local function contains(list,value)
    if not M.Readable(list) or type(list)~="table" or #list==0 or #list>128 then return nil end
    for _,entry in ipairs(list) do if not M.Readable(entry) then return nil end; if entry==value then return true end end
    return false
end
local function starterIdentity(location)
    if not M.Readable(location) or type(location)~="table" then return end
    local id=M.QuestId(location.npcID); if id then return "npcID",id end
    id=M.QuestId(location.objectID); if id then return "objectID",id end
    id=M.QuestId(location.itemID); if id then return "itemID",id end
end
function P.LocationAllowed(location,source,context)
    local kind,id=starterIdentity(location); if not kind then return false end
    local faction=M.Text(location.faction)
    if faction then return faction==context.faction end
    -- An unqualified duplicate is missing information, not a neutral starter.
    -- Explicit qualifiers for this exact typed entity must still be respected.
    local qualified=false
    for _,other in ipairs(source and source.locations or {}) do
        local otherFaction=M.Text(other.faction)
        if M.QuestId(other[kind])==id and otherFaction then
            qualified=true; if otherFaction==context.faction then return true end
        end
    end
    return not qualified
end
function P.StartPath(row,context)
    local source=row.source or P.Source(row.id)
    local npc=M.QuestId(row.npcID); local known=false
    for _,location in ipairs(source and source.locations or {}) do
        local kind,id=starterIdentity(location)
        if kind and (not npc or kind=="npcID" and id==npc) then
            known=true
            if P.LocationAllowed(location,source,context) then return true,true end
        end
    end
    return false,known
end
local function offeredState(proof,active)
    if proof=="native-map-available" then return state("available","Available","native-map") end
    if proof=="questie-available" then return state("available","Available","questie-rendered") end
    if proof=="questie-ready" and active~=false then return state("ready","Ready to turn in","questie-rendered") end
end
function P.Availability(row,context)
    local id=M.QuestId(row.id); if not id then return state("unknown") end
    local current=facts(id)
    local active=current.active
    if active==true then
        if N.QuestState then A.Call(N.QuestState.Track,N.QuestState,id) end
        return current.complete==true and state("ready","Ready to turn in","native-log") or state("active","In quest log","native-log")
    end
    local proof=row.availabilityProof
    if row.availabilityCheck then proof=A.Call(row.availabilityCheck) end
    if not proof and not row.availabilityCheck then
        if row.npcID then proof=N.Character:Proof(id,row.npcID)
        elseif context and context.nativeOffers then proof=context.nativeOffers[id]
        else proof=N.Character:Proof(id,row.npcID) end
    end
    if proof=="native-active" or proof=="native-ready" then
        return proof=="native-ready" and state("ready","Ready to turn in","native-gossip") or state("active","In quest log","native-gossip")
    end
    if current.disabled==true then return state("blocked",nil,"native-session","Quest disabled for this session") end
    if proof=="native-available" then return state("available","Available","native-gossip") end
    local complete,repeatable=current.completed,current.repeatable
    if complete==true and repeatable~=true then return state("completed","Completed","native-history") end
    -- A fresh native log or gossip offer describes this player's actual quest.
    -- A map line or optional marker is less specific and must pass constraints.
    context=context or P.Context()
    local source=row.source or P.Source(id) or {}
    if source.eligibilityConflict then return state("blocked",nil,"recorded-conflict","Recorded eligibility is contradictory") end
    if source.faction and context.faction and source.faction~=context.faction then return state("blocked",nil,"recorded-constraint","Other faction") end
    local starter,knownStarter=P.StartPath({id=id,source=source,npcID=row.npcID},context)
    if knownStarter and not starter then return state("blocked",nil,"recorded-constraint","Other faction starter") end
    for _,pair in ipairs({{source.classTokens,context.classToken,"Other class"},{source.classes,context.classID,"Other class"},{source.races,context.raceID,"Other race"}}) do
        if pair[2] and contains(pair[1],pair[2])==false then return state("blocked",nil,"recorded-constraint",pair[3]) end
    end
    local minimum
    if M.Number(context.level) then
        if M.Number(source.maximum) and source.maximum>0 and context.level>source.maximum then return state("blocked",nil,"recorded-constraint","Above recorded maximum level") end
        if M.Number(source.minimum) and context.level<source.minimum then
            minimum=state("blocked","Recorded minimum level "..source.minimum,"recorded-level","Below recorded minimum level")
        end
    end
    local chain=P.ChainState(source)
    if chain and chain.state=="blocked" then return chain end
    return minimum or offeredState(proof,active) or chain or state("unknown",complete==true and repeatable==true and "Repeatable" or nil,complete==true and "native-history" or nil)
end
function P.ChainState(source)
    local group,single=source.prerequisites,source.prerequisiteAlternatives
    local list=single or group
    if list~=nil and (not M.Readable(list) or type(list)~="table" or #list>128) then
        return state("unknown","Chain requirements unavailable","recorded-chain")
    end
    if M.Readable(list) and type(list)=="table" and #list>0 and #list<=128 then
        local done,unknown,missing,seen=0,0,{},{}
        for _,previousID in ipairs(list) do
            previousID=M.QuestId(previousID)
            if not previousID or seen[previousID] then return state("unknown","Chain requirements unavailable","recorded-chain") end
            seen[previousID]=true
            local previous=previousID and P.Source(previousID)
            local completed=previousID and facts(previousID).completed
            -- A breadcrumb or an unverified alternate link cannot be a hard gate.
            if completed==true then done=done+1
            elseif not previousID or completed==nil then unknown=unknown+1
            else
                local alternatives=previous and previous.exclusive
                local alternate=false
                if previous and previous.exclusiveVerified==true and M.Readable(alternatives) and type(alternatives)=="table" and #alternatives<=128 then
                    for _,other in ipairs(alternatives) do if M.QuestId(other) and facts(other).completed==true then alternate=true end end
                end
                if alternate then done=done+1
                elseif previous and previous.isBreadcrumb==true then unknown=unknown+1
                else missing[#missing+1]={id=previousID,title=previous and previous.title} end
            end
        end
        local required=single and 1 or source.prerequisiteCount or #list
        if not M.Number(required) or required~=math.floor(required) or required<1 or required>#list then
            return state("unknown","Chain requirements unavailable","recorded-chain")
        end
        if done<required then
            local names={}
            for i=1,math.min(2,#missing) do names[#names+1]=missing[i].title or ("Quest "..missing[i].id) end
            if #missing>2 then names[#names+1]="+"..(#missing-2) end
            if source.prerequisitesVerified==true and done+unknown<required then
                return state("blocked","Requires "..table.concat(names,", "),"verified-prerequisite","Prerequisite incomplete",missing)
            end
            return state("unknown",#names>0 and "Quest chain: "..table.concat(names,", ") or "Chain requirements unavailable","recorded-chain","Recorded links may include breadcrumbs or alternate paths",missing)
        end
    end
end

function P.RequiresNativeProof(source)
    return source and (source.confirmation and source.confirmation~="published" or source.questKind=="hidden-trigger") or false
end
function P.HasNativeProof(availability)
    local authority,state=availability.authority,availability.state
    return (authority=="native-log" or authority=="native-gossip" or authority=="native-map")
        and (state=="active" or state=="ready" or state=="available")
end
function P.Resolve(row,context)
    row.availability=P.Availability(row,context); row.evidence=row.availability.label
    -- A recorded starter or optional marker cannot establish that an old
    -- candidate or hidden tracker is obtainable in the current client.
    if P.RequiresNativeProof(row.source or P.Source(row.id)) and not P.HasNativeProof(row.availability) then return false end
    return row.availability.state~="blocked" and row.availability.state~="completed"
end
function P.ResolveRows(rows)
    local out,context={},P.Context()
    for _,row in ipairs(M.Entries(rows)) do if P.Resolve(row,context) then out[#out+1]=row end end
    return out
end
function P.Connect()
    local lib = LibQuestieDB
    if not M.Readable(lib) or type(lib) ~= "table" or not M.Readable(lib.flavor) or type(lib.flavor) ~= "table" or M.Text(lib.flavor.name) ~= "Forever" then return end
    if type(lib.RequireContract) ~= "function" then return end
    local ok, result = pcall(lib.RequireContract, 3)
    if ok and result ~= false and type(lib.Npc) == "table" and type(lib.Quest) == "table" then return lib end
end
function P.ForNPC(npcID)
    local lib = P.Connect(); npcID = M.QuestId(npcID)
    if not npcID then return {} end
    P.Index()
    local out,faction={},P.Context().faction
    for _,id in ipairs(P.starters and P.starters[npcID] or {}) do
        local source=P.records[id]
        local allowed=false
        for _,location in ipairs(source.locations or {}) do
            if location.npcID==npcID and P.LocationAllowed(location,source,{faction=faction}) then allowed=true;break end
        end
        if allowed then out[#out+1]={id=id,title=source.title,source=source,npcID=npcID,provenance="Bundled Forever exact NPC starter association"} end
    end
    if N.Questie and N.Questie.ForNPC then
        for _,row in ipairs(N.Questie.ForNPC(npcID)) do row.npcID=npcID;table.insert(out,1,row) end
    end
    if not lib then return P.ResolveRows(out) end
    local starts = A.Call(lib.Npc.Get, npcID, "questStarts")
    if not M.Readable(starts) or type(starts) ~= "table" or #starts > 256 then return P.ResolveRows(out) end
    for _, value in ipairs(starts) do
        local id = M.QuestId(value)
        local starter = id and A.Call(lib.Quest.Get, id, "startedBy")
        local npcs = M.Readable(starter) and type(starter) == "table" and starter[1]
        if M.Readable(npcs) and type(npcs) == "table" and #npcs <= 256 then
            for _, starterID in ipairs(npcs) do
                if M.QuestId(starterID) == npcID then
                    out[#out+1] = { id = id, npcID=npcID, title = M.Text(A.Call(lib.Quest.Get, id, "name")),
                        provenance = "QuestieDB Forever contract 3; reciprocal starter association" }
                    break
                end
            end
        end
    end
    return P.ResolveRows(out)
end

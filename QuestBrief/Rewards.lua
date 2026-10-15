local _, N = ...
local M, A = N.Model, N.Adapter
local R = {}; N.Rewards = R
function R.RecordedItem(meta)
    local row={itemID=meta.itemID,name=meta.name,quantity=meta.quantity,group=meta.group,kind="catalog",state="pending",catalog=true}
    local getter=C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getter)=="function" and A.Call(C_Item and C_Item.IsItemDataCachedByID,meta.itemID)==true then
        local ok,name,link,quality,level,minimum,itemType,subType,stack,slot,texture=pcall(getter,meta.itemID)
        if ok and M.Text(name) and M.Text(link) and M.Number(quality) and (M.Text(texture) or M.Number(texture)) then
            row.name,row.link,row.quality,row.texture,row.state=name,link,quality,texture,"ready"
        end
    end
    if not row.texture then
        local ok,id,itemType,subType,slot,texture=pcall(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,meta.itemID)
        if ok then row.texture=M.Text(texture) or M.Number(texture) and texture or nil end
    end
    return row
end
function R.Recorded(id,out)
    local source=N.Providers and N.Providers.Source(id)
    if not source or not source.itemState then return out end
    -- Live readiness owns its entire item set, including confirmed empty and
    -- class-filtered/ambiguous choices. Published fallback has no native ordinal.
    if out.state=="pending" and (source.itemState=="published" or source.itemState=="published-empty") then
        out.items,out.choices={state="published",items={}},{state="published",items={}}
        out.recordedGroups=true
        for _,meta in ipairs(source.items or {}) do
            local group=meta.group=="guaranteed" and out.items or meta.group=="choice" and out.choices
            if group then group.items[#group.items+1]=R.RecordedItem(meta) end
        end
    end
    local values=source.rewardValues or {}
    for _,key in ipairs({"xp","money"}) do
        if out[key].state~="ready" and M.Number(values[key]) and values[key]>=0 then out[key]={state="ready",value=values[key],published=true} end
    end
    out.reputation.items=out.reputation.items or {}
    for _,entry in ipairs(values.reputation or {}) do
        if M.Text(entry.name) and M.Number(entry.amount) then
            local matched=false
            for _,native in ipairs(out.reputation.items) do
                local faction=A.Call(C_Reputation and C_Reputation.GetFactionDataByID,native.factionID)
                local name=M.Readable(faction) and type(faction)=="table" and M.Text(faction.name) or M.Text(A.Call(GetFactionInfoByID,native.factionID))
                if entry.factionID and entry.factionID==native.factionID or name and name==entry.name then matched=true;break end
            end
            -- The native API is partial. An unrelated major faction cannot
            -- erase separately published ordinary-faction reputation.
            if not matched then out.reputation.items[#out.reputation.items+1]={name=entry.name,factionID=entry.factionID,amount=entry.amount,published=true} end
        end
    end
    return out
end
function R.Money(value)
    if not M.Number(value) or value<=0 or value~=math.floor(value) then return nil end
    local native=M.Text(A.Call(C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString,value,12))
    if native then return native end
    local gold,silver,copper=math.floor(value/10000),math.floor(value/100)%100,value%100
    local parts={}
    if gold>0 then parts[#parts+1]=gold.."g" end
    if silver>0 then parts[#parts+1]=silver.."s" end
    if copper>0 then parts[#parts+1]=copper.."c" end
    return table.concat(parts," ")
end
local function field(fn,id)
    if type(fn) ~= "function" then return { state="unavailable" } end
    local ok,value=pcall(fn,id)
    return ok and M.Field(value) or { state="unavailable" }
end
local function count(value)
    if M.Number(value) and value >= 0 and value <= 128 and value == math.floor(value) then return value end
end
local function metadata(getter,index,id,row)
    local ok,name,texture,quantity,quality,usable,itemID=false
    if type(getter)=="function" then ok,name,texture,quantity,quality,usable,itemID=pcall(getter,index,id) end
    if ok and M.Text(name) and M.Number(quantity) and quantity>=1 and quantity==math.floor(quantity) and M.Number(quality) and quality>=0 and quality<=8 and quality==math.floor(quality) and M.QuestId(itemID) and (M.Text(texture) or M.Number(texture)) then
        row.name,row.texture,row.quantity,row.quality,row.itemID,row.state=name,texture,quantity,quality,itemID,"ready"
        row.usable=M.Readable(usable) and type(usable)=="boolean" and usable or nil
        if M.Readable(usable) and usable==false then row.usable=false end
        return true
    end
end
local function readItems(id, kind)
    local value
    if kind == "choice" then value=A.Call(GetNumQuestLogChoices,id,true) else value=A.Call(GetNumQuestLogRewards,id) end
    local number = count(value)
    if not number then return { state = "unavailable", items = {}, currencies = {} } end
    local out = { state = "ready", items = {}, currencies = {} }
    local getter = kind == "choice" and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
    local nativeIDs, nativeOccurrences, nativeComplete = {}, {}, true
    if kind=="choice" then
        local itemCount=count(A.Call(GetNumQuestLogChoices,id,false))
        if itemCount then
            for index=1,itemCount do
                local data=A.Call(C_TooltipInfo and C_TooltipInfo.GetQuestLogItem,kind,index,id)
                local nativeID=M.Readable(data) and type(data)=="table" and M.QuestId(data.id)
                local itemType=M.Readable(data) and type(data)=="table" and M.Readable(data.type) and Enum and Enum.TooltipDataType and data.type==Enum.TooltipDataType.Item
                if nativeID and itemType then nativeIDs[index]=nativeID;nativeOccurrences[nativeID]=(nativeOccurrences[nativeID] or 0)+1 else nativeComplete=false end
            end
        else nativeComplete=false end
    end
    local itemIndex, ordinalKnown=0,true
    for exposedIndex = 1, number do
        local currency, currencyOK = nil, true
        if kind == "choice" then
            local currencyGetter=C_QuestLog and C_QuestLog.GetQuestRewardCurrencyInfo
            if type(currencyGetter)=="function" then currencyOK,currency=pcall(currencyGetter,id,exposedIndex,true) else currencyOK=false end
        end
        if kind == "choice" and currencyOK and M.Readable(currency) and type(currency)=="table" and M.QuestId(currency.currencyID) and M.Text(currency.name) and M.Number(currency.totalRewardAmount) then
            out.currencies[#out.currencies+1]={name=currency.name,amount=currency.totalRewardAmount,isChoice=true}
        elseif kind == "choice" and (not currencyOK or not M.Readable(currency) or currency~=nil) then
            out.state="unavailable" -- Do not mislabel an unresolved currency slot as an item.
            ordinalKnown=false
        else
        if ordinalKnown then
        itemIndex=itemIndex+1
        -- Native quest-info uses mixed loot indices to read choices, then item-
        -- only indices for GetQuestLogItem. Preserve both; never collapse gaps.
        local row = { questID = id, kind = kind, index = itemIndex, exposedIndex=exposedIndex, state = "pending" }
        metadata(getter,exposedIndex,id,row)
        if kind=="choice" then
            local nativeID=nativeIDs[itemIndex]
            local itemType=nativeID~=nil
            local fallback={}
            local fallbackMatches=nativeID and itemType and metadata(getter,itemIndex,id,fallback) and fallback.itemID==nativeID
            -- A duplicate ID cannot disambiguate missing metadata at a shifted
            -- slot. Suppress it until explicit-ID overload semantics are proved.
            local ambiguous=exposedIndex~=itemIndex and (not nativeComplete or nativeID and (nativeOccurrences[nativeID] or 0)>1)
            if fallbackMatches and row.itemID==nativeID then
                for _,key in ipairs({"name","texture","quantity","quality"}) do if row[key]~=fallback[key] then ambiguous=true end end
            end
            if ambiguous or not nativeID or not itemType or row.itemID~=nativeID then
                if not ambiguous and fallbackMatches then
                    for key,value in pairs(fallback) do row[key]=value end
                else
                    row.name,row.texture,row.quantity,row.quality,row.itemID=nil,nil,nil,nil,nil
                    row.state=nativeID and "unavailable" or "pending"
                end
            end
        end
        if row.state~="ready" then out.state=row.state end
        out.items[#out.items+1] = row
        else out.state="unavailable" end
        end
    end
    return out
end
function R.Read(id)
    id = M.QuestId(id)
    local out = { id = id, items = { state = "unavailable", items = {} }, choices = { state = "unavailable", items = {} },
        money = { state = "unavailable" }, xp = { state = "unavailable" }, reputation = { state = "unavailable" }, currencies = { state = "unavailable", items = {} } }
    if not id then return out end
    if A.Call(HaveQuestRewardData, id) ~= true then out.state = "pending"; return R.Recorded(id,out) end
    out.state = "ready"
    out.items, out.choices = readItems(id, "reward"), readItems(id, "choice")
    out.money = field(GetQuestLogRewardMoney,id)
    out.xp = field(GetQuestLogRewardXP,id)
    local rows = A.Call(C_QuestLog and C_QuestLog.GetQuestRewardCurrencies, id)
    if M.Readable(rows) and type(rows) == "table" and #rows <= 128 then
        out.currencies.state = "ready"
        for _, row in ipairs(rows) do
            if M.Readable(row) and type(row) == "table" and M.QuestId(row.currencyID) and M.Text(row.name) and M.Number(row.totalRewardAmount) then
                out.currencies.items[#out.currencies.items+1] = { name = row.name, amount = row.totalRewardAmount, isChoice = false }
            else out.currencies.state = "unavailable" end
        end
    end
    for _,currency in ipairs(out.choices.currencies or {}) do out.currencies.items[#out.currencies.items+1]=currency end
    -- This API is explicitly limited to major factions. An empty result cannot
    -- establish the absence of ordinary Classic faction reputation.
    local reputation=A.Call(C_QuestLog and C_QuestLog.GetQuestLogMajorFactionReputationRewards,id)
    if M.Readable(reputation) and type(reputation)=="table" and #reputation<=128 then
        out.reputation.items={}
        for _,row in ipairs(reputation) do
            if M.Readable(row) and type(row)=="table" and M.QuestId(row.factionID) and M.Number(row.rewardAmount) then
                out.reputation.items[#out.reputation.items+1]={factionID=row.factionID,amount=row.rewardAmount}
            end
        end
    end
    return R.Recorded(id,out)
end
function R.Request(id, requested, withRewards)
    if requested[id] then return end
    requested[id] = true
    if not M.Text(A.Call(C_QuestLog and C_QuestLog.GetTitleForQuestID,id)) then A.Call(C_QuestLog and C_QuestLog.RequestLoadQuestByID, id) end
    if withRewards and A.Call(HaveQuestRewardData,id) ~= true then A.Call(C_TaskQuest and C_TaskQuest.RequestPreloadRewardData,id) end
    local source=withRewards and N.Providers and N.Providers.Source(id)
    for _,item in ipairs(source and source.items or {}) do
        local key="item:"..item.itemID
        if not requested[key] and A.Call(C_Item and C_Item.IsItemDataCachedByID,item.itemID)~=true then
            requested[key]=true; A.Call(C_Item and C_Item.RequestLoadItemDataByID,item.itemID)
        end
    end
end

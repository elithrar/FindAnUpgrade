local _, N = ...
local D = {schema=1, limit=250, byteLimit=262144, variantLimit=12}; N.ObservationData=D
local M=N.Model

function D.Integer(value,low,high)
    return M.Number(value) and value==math.floor(value) and value>=low and value<=high and value or nil
end
local function text(value,limit)
    return M.Readable(value) and type(value)=="string" and #value>0 and #value<=limit
        and not value:find("[%z\1-\31\127|]") and value or nil
end
local function object(value) return M.Readable(value) and type(value)=="table" and value or {} end
local function one(value,values) return M.Readable(value) and type(value)=="string" and values[value] and value or nil end
local states={ready=true,unknown=true,partial=true}
local function field(value)
    value=object(value)
    local number=one(value.state,states)=="ready" and D.Integer(value.value,0,2147483647)
    return number and {state="ready",value=number} or {state="unknown"}
end
local function group(value,choice)
    value=object(value)
    local expected=D.Integer(value.expected,0,32)
    local state=one(value.state,states)
    if not expected or not state or state=="unknown" then return {state="unknown",slots={}} end
    local result={expected=expected,slots={},state="ready"}
    if choice then result.choose=expected>0 and 1 or 0 end
    local slots=object(value.slots)
    for i=1,expected do
        local raw=object(slots[i]);local slot={slot=i,state="unknown"}
        local kind=one(raw.kind,{item=true,currency=choice})
        local id=D.Integer(raw.id,1,2147483647);local quantity=D.Integer(raw.quantity,1,2147483647)
        if D.Integer(raw.slot,1,32)==i and one(raw.state,states)=="ready" and kind and id and quantity then
            slot={slot=i,state="ready",kind=kind,id=id,quantity=quantity}
            slot.contextFlags=D.Integer(raw.contextFlags,0,2147483647)
        else result.state="partial" end
        result.slots[i]=slot
    end
    return result
end
function D.Record(raw)
    raw=object(raw)
    local id=D.Integer(raw.questID,1,2147483647)
    local stage=one(raw.stage,{listed=true,listed_active=true,offered=true,progress=true,completion=true,accepted=true,turned_in=true})
    local client=object(raw.client);local build=D.Integer(client.build,1,2147483647)
    local version=text(client.version,32);local locale=text(client.locale,8)
    if not id or not stage or not build or not version or not locale or D.Integer(client.interface,16001,16001)~=16001 then return end
    if not version:match("^%d+%.%d+%.%d+$") or not locale:match("^[a-z][a-z][A-Z][A-Z]$") then return end
    local row={questID=id,stage=stage,client={version=version,build=build,interface=16001,locale=locale},
        titleState="unknown",context={},source={kind="unknown",role="unknown"},location={kind="observer"},questLevel=field(raw.questLevel)}
    local title=text(raw.title,256)
    local titleState=one(raw.titleState,{ready=true,redacted=true})
    if title and titleState then row.title=title;row.titleState=titleState end
    local context=object(raw.context)
    row.context.faction=one(context.faction,{Alliance=true,Horde=true,Neutral=true})
    row.context.classID=D.Integer(context.classID,1,64);row.context.raceID=D.Integer(context.raceID,1,256)
    row.context.level=D.Integer(context.level,1,200)
    local source=object(raw.source);local sourceID=D.Integer(source.id,1,2147483647)
    local kind=one(source.kind,{npc=true,item=true,object=true})
    local role=one(source.role,{starter=true,ender=true,unknown=true})
    if sourceID and kind and role then row.source={kind=kind,id=sourceID,role=role} end
    local location=object(raw.location)
    row.location.uiMapID=D.Integer(location.uiMapID,1,2147483647)
    if row.location.uiMapID and M.Number(location.x) and M.Number(location.y) and location.x>=0 and location.x<=1 and location.y>=0 and location.y<=1 then
        row.location.x=location.x;row.location.y=location.y
    end
    local rewards=object(raw.rewards)
    row.rewards={scope="dialog-items-and-choice-currencies",otherRewards="unknown",
        guaranteed=group(rewards.guaranteed,false),choices=group(rewards.choices,true),xp=field(rewards.xp),money=field(rewards.money)}
    return row
end

-- Only the small allowlisted model above reaches this encoder. Empty records
-- and slot collections must remain arrays, including explicitly empty rewards.
local function quote(value)
    return '"'..value:gsub('[%z\1-\31\\"]',function(c)
        if c=='"' or c=='\\' then return '\\'..c end
        return string.format("\\u%04x",c:byte())
    end)..'"'
end
local function encode(value,key)
    if type(value)=="string" then return quote(value) end
    if type(value)=="number" then return string.format("%.17g",value) end
    local parts={}
    if key=="records" or key=="slots" then
        for _,item in ipairs(value) do parts[#parts+1]=encode(item) end
        return "["..table.concat(parts,",").."]"
    end
    local keys={};for name in pairs(value) do keys[#keys+1]=name end;table.sort(keys)
    for _,name in ipairs(keys) do parts[#parts+1]=quote(name)..":"..encode(value[name],name) end
    return "{"..table.concat(parts,",").."}"
end
D.Encode=encode
function D:Initialize(saved)
    self.readOnly=nil;self.index={};self.variants={};self.bytes=1024
    if M.Readable(saved) and type(saved)=="table" and M.Number(saved.schema) and saved.schema>self.schema then
        self.readOnly=true;self.db={schema=self.schema,enabled=false,dropped=0,records={}};return saved
    end
    saved=object(saved)
    self.db={schema=self.schema,enabled=saved.schema==self.schema and saved.enabled==true,dropped=D.Integer(saved.dropped,0,1000000) or 0,records={}}
    local rows=object(saved.records)
    for i=1,self.limit+1 do
        if rows[i]==nil then break end
        local row=D.Record(rows[i])
        if row then self:Add(row,D.Integer(object(rows[i]).samples,1,1000000) or 1,true)
        else self.db.dropped=math.min(1000000,self.db.dropped+1);self.db.enabled=false end
    end
    return self.db
end
function D:Add(raw,samples,restoring)
    if self.readOnly then return false end
    local row=D.Record(raw);if not row then return false end
    local signature=encode(row);local existing=self.index[signature]
    if existing then existing.samples=math.min(1000000,existing.samples+(samples or 1));return true end
    local key=row.questID..":"..row.stage
    if #self.db.records>=self.limit or self.bytes+#signature+128>self.byteLimit or (self.variants[key] or 0)>=self.variantLimit then
        self.db.dropped=math.min(1000000,self.db.dropped+1);self.db.enabled=false;self.full=true;return false
    end
    row.samples=samples or 1;self.db.records[#self.db.records+1]=row;self.index[signature]=row
    self.variants[key]=(self.variants[key] or 0)+1;self.bytes=self.bytes+#signature+128
    if not restoring then self.changed=true end
    return true
end
function D:Export()
    if self.readOnly then return end
    local rows={}
    for _,raw in ipairs(self.db.records) do
        local row=D.Record(raw)
        if row then row.samples=D.Integer(raw.samples,1,1000000) or 1;rows[#rows+1]=row end
    end
    return encode({format="FindAnUpgrade.quest-observations",schema=self.schema,addonVersion=N.Core.version,dropped=self.db.dropped,records=rows})
end

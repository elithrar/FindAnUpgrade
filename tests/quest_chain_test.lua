local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn) fn();PASSED=PASSED+1;print("PASS "..name) end
local function setup()
    local N=W.Init();W.done,W.active,W.repeatable={},{},{}
    N.CatalogData={quests={}}
    for id=1,50 do N.CatalogData.quests[id]={id=id,title="Quest "..id,confirmation="published",chain={groups={},relations={}}} end
    N.Character.Quest=function(_,id) return {completed=W.done[id],active=W.active[id],repeatable=W.repeatable[id]} end
    local row=N.CatalogData.quests[1]
    return N,row
end
local function group(row,kind,ids,count,verified)
    row.chain.groups={{kind=kind,ids=ids,count=count,verified=verified~=false}}
end
local function relation(row,kind,id,verified)
    row.chain.relations[#row.chain.relations+1]={kind=kind,id=id,verified=verified~=false}
end
test("all any and count use exact completion and unknown does not reject",function()
    local N,row=setup();group(row,"all",{2,3});W.done[2]=true
    assert(N.Chains:State(row).state=="unknown")
    W.done[3]=false;assert(N.Chains:State(row).state=="blocked")
    group(row,"any",{2,3});assert(N.Chains:State(row)==nil)
    group(row,"count",{2,3,4},2);W.done[4]=true;assert(N.Chains:State(row)==nil)
    W.done[4]=false;assert(N.Chains:State(row).state=="blocked")
end)
test("unverified missing links have no per-row uncertainty prose and never hard-gate",function()
    local N,row=setup();group(row,"all",{2},nil,false);W.done[2]=false
    local state=N.Chains:State(row);assert(state.state=="unknown" and state.label==nil and state.requirements[1].id==2)
    local detail=N.Chains:Describe(1);assert(detail.hasDetails and detail.uncertain and detail.entries[1].kind=="all")
end)
test("malformed duplicate unknown thresholds cannot establish rejection",function()
    local N,row=setup();W.done[2]=false
    for _,ids in ipairs({{2,2},{"2"},{2,W.secret}}) do group(row,"all",ids);assert(N.Chains:State(row).state=="unknown") end
    group(row,"count",{2},2);assert(N.Chains:State(row).state=="unknown")
end)
test("optional breadcrumbs never become mandatory prerequisite failures",function()
    local N,row=setup();group(row,"all",{2});W.done[2]=false
    relation(N.CatalogData.quests[2],"breadcrumb",1,false)
    assert(N.Chains:State(row).state=="unknown")
end)
test("verified alternate satisfies group while literal group member skips substitution",function()
    local N,row=setup();group(row,"all",{2});W.done[2]=false;W.done[3]=true
    relation(N.CatalogData.quests[2],"exclusive",3)
    assert(N.Chains:State(row)==nil)
    row.chain.groups[1].noAlternates={2};assert(N.Chains:State(row).state=="blocked")
end)
test("unverified alternate creates uncertainty rather than false hard failure",function()
    local N,row=setup();group(row,"all",{2});W.done[2]=false;W.done[3]=false
    relation(N.CatalogData.quests[2],"exclusive",3,false)
    assert(N.Chains:State(row).state=="unknown")
end)
test("single alternatives require a listed completion and do not borrow exclusive paths",function()
    local N,row=setup();group(row,"any",{2});W.done[2]=false;W.done[3]=true
    relation(N.CatalogData.quests[2],"exclusive",3)
    assert(N.Chains:State(row).state=="blocked")
    group(row,"all",{2});assert(N.Chains:State(row)==nil)
end)
test("exclusive and superseding completion require known nonrepeatability",function()
    for _,kind in ipairs({"exclusive","supersededBy","untilCompleted"}) do
        local N,row=setup();relation(row,kind,2);W.done[2]=true
        assert(N.Chains:State(row)==nil)
        W.repeatable[2]=true;assert(N.Chains:State(row)==nil)
        W.repeatable[2]=false;assert(N.Chains:State(row).state=="blocked")
    end
end)
test("active-only until and starting relations are distinct",function()
    local N,row=setup();relation(row,"requiresActive",2);W.active[2]=false
    assert(N.Chains:State(row).state=="blocked")
    row.chain.relations={};relation(row,"startingWith",2);W.done[2]=false
    assert(N.Chains:State(row).state=="blocked")
    W.active[2]=true;assert(N.Chains:State(row)==nil)
    row.chain.relations={};relation(row,"disabledWhileActive",2);assert(N.Chains:State(row).state=="blocked")
end)
test("native current active and gossip offer override every static chain gate",function()
    local N,row=setup();group(row,"all",{2});W.done[2]=false;W.active[1]=true
    assert(N.Providers.Availability({id=1,source=row}).state=="active")
    W.active[1]=false;assert(N.Providers.Availability({id=1,source=row,availabilityProof="native-available"}).state=="available")
end)
test("completed history is marked done even when repeatability is unknown",function()
    local N,row=setup();W.done[1]=true
    assert(N.Providers.Availability({id=1,source=row}).state=="completed")
    W.repeatable[1]=false;assert(N.Providers.Availability({id=1,source=row}).state=="completed")
end)
test("detail traversal bounds cycles depth and total flat rows",function()
    local N,row=setup();group(row,"all",{2});group(N.CatalogData.quests[2],"any",{1})
    relation(N.CatalogData.quests[2],"supersededBy",1)
    local d=N.Chains:Describe(1);assert(#d.entries==1 and not d.truncated and d.uncertain)
    assert(d.groups[1].ownerID==1 and d.entries[1].ownerID==1 and d.entries[1].id==2)
    for id=1,49 do group(N.CatalogData.quests[id],"all",{id+1}) end
    d=N.Chains:Describe(1);assert(#d.entries==9 and d.truncated)
    row.chain.groups={};for id=2,50 do relation(row,"related",id,false) end
    d=N.Chains:Describe(1);assert(#d.entries==32 and d.truncated)
end)
test("shared prerequisites retain sibling owner lineage without ancestor return rows",function()
    local N,row=setup();group(row,"all",{2,3});group(N.CatalogData.quests[2],"all",{4});group(N.CatalogData.quests[3],"all",{4})
    local d=N.Chains:Describe(1);assert(#d.entries==4)
    assert(d.entries[3].id==4 and d.entries[3].ownerID==2 and d.entries[4].id==4 and d.entries[4].ownerID==3)
end)
test("actual Temple of the Moon optional breadcrumb is not also displayed as mandatory",function()
    local N=W.Init();local d=N.Chains:Describe(2519);local optional=false
    for _,value in ipairs(d.entries) do
        assert(not(value.id==98391 and (value.kind=="all" or value.kind=="any" or value.kind=="count")))
        if value.id==98391 and value.kind=="optionalPrerequisite" then optional=true end
        assert(value.id~=2519)
    end
    assert(optional)
end)
test("reverse dependency index reaches transitive chains cycles and relation owners once",function()
    local N,row=setup();group(row,"all",{2});group(N.CatalogData.quests[2],"all",{3});group(N.CatalogData.quests[3],"all",{1})
    relation(N.CatalogData.quests[4],"exclusive",3)
    local d=N.Chains:Dependants({[3]=true});assert(d[1] and d[2] and d[3] and d[4] and not d[5])
    local reverse=N.Chains.reverse;N.Chains:Dependants({[3]=true});assert(reverse==N.Chains.reverse)
    N.CatalogData={quests={{id=9,chain={groups={{kind="any",ids={8}}},relations={}}}}}
    d=N.Chains:Dependants({[8]=true});assert(d[9] and not d[1] and reverse~=N.Chains.reverse)
end)

test("Ormer's Revenge shows all three stages from first middle and final quest",function()
    local N=W.Init()
    for _,id in ipairs({294,295,296}) do
        local d=N.Chains:Steps(id);assert(#d.rows==3 and d.uncertain and not d.truncated)
        for i,row in ipairs(d.rows) do
            assert(row.id==293+i and row.selected==(row.id==id) and #row.related==0)
            assert(row.level==({24,27,29})[i])
        end
    end
end)
test("reverse prerequisites reveal a chain on its first quest without outgoing relations",function()
    local N=setup();group(N.CatalogData.quests[2],"all",{1});group(N.CatalogData.quests[3],"all",{2})
    assert(N.Chains:HasDetails(1))
    local d=N.Chains:Steps(1);assert(#d.rows==3 and d.rows[1].selected and d.rows[3].role=="Follow-up")
    assert(N.Chains:Steps(3).rows[1].role=="Earlier quest")
end)
test("chain branches preserve group meaning and shared prerequisites appear once",function()
    local N,row=setup();group(row,"any",{2,3});group(N.CatalogData.quests[2],"all",{4});group(N.CatalogData.quests[3],"all",{4})
    W.done[4]=true;W.repeatable[4]=false;W.active[2]=true
    local d=N.Chains:Steps(1);assert(#d.rows==4 and d.rows[1].id==4 and d.rows[1].state=="completed")
    assert(d.rows[2].id==2 and d.rows[2].state=="active" and d.rows[2].depth==1 and d.rows[3].depth==1)
    assert(d.rows[4].id==1 and d.rows[4].requirements[1]=="Complete one of 2: Quest 2, Quest 3" and d.rows[4].depth==0)
end)
test("replacement and exclusive relations alone never become progression steps",function()
    local N,row=setup();relation(row,"supersededBy",2);relation(row,"exclusive",3)
    local d=N.Chains:Steps(1);assert(#d.rows==1 and #d.rows[1].related==2)
    assert(d.rows[1].related[1].kind=="supersededBy" and d.rows[1].related[2].kind=="exclusive")
end)
test("follow-ups retain additional prerequisites and cycles remain bounded",function()
    local N=setup();group(N.CatalogData.quests[2],"all",{1,3});group(N.CatalogData.quests[3],"all",{4})
    local d=N.Chains:Steps(1);assert(#d.rows==4 and d.rows[1].id==1 and d.rows[2].id==4 and d.rows[3].id==3 and d.rows[4].id==2)
    group(N.CatalogData.quests[4],"all",{2})
    d=N.Chains:Steps(1);assert(#d.rows==4 and d.uncertain)
end)
test("step traversal limits deep and wide chains with explicit truncation",function()
    local N,row=setup();for id=1,49 do group(N.CatalogData.quests[id],"all",{id+1}) end
    local d=N.Chains:Steps(1);assert(#d.rows==9 and d.truncated)
    group(row,"all",{});for id=2,50 do group(N.CatalogData.quests[id],"all",{1}) end
    N.Chains.data=nil;d=N.Chains:Steps(1);assert(#d.rows==32 and d.truncated)
end)

test("forked paths remain contiguous and retain parent child indentation",function()
    local N=setup()
    for _,edge in ipairs({{1,2},{1,3},{2,4},{3,5}}) do group(N.CatalogData.quests[edge[2]],"all",{edge[1]}) end
    local rows=N.Chains:Steps(1).rows
    local ids,depths={1,2,4,3,5},{0,1,2,1,2}
    for i,row in ipairs(rows) do assert(row.id==ids[i] and row.depth==depths[i]) end
end)

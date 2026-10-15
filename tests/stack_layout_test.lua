local W=assert(loadfile(ROOT.."/tests/wow_mock.lua"))()
PASSED=0
local function test(name,fn)fn();PASSED=PASSED+1;print("PASS "..name)end
local function show(rows,config)
    local N=W.Init(config);W.shift=true;GameTooltip=nil;C_QuestLog.IsOnQuest=function()return true end
    N.CatalogData={schemaVersion=2,quests={}} -- Native-only layout fixtures; published cards have their own suite.
    if config and config.screenWidth then UIParent.width=config.screenWidth;UIParent.height=config.screenHeight end
    local f=W.Object();f.x=690;f.y=690;f.width=30;f.height=30;f.related={}
    for _,row in ipairs(rows)do f.related[row.id]={} end
    f.GetRelatedQuests=function(self)return self.related end
    N.Sources:Pin(f,nil,rows);assert(N.Hover.open)
    return N,f
end
test("short stack is content-sized without an outer backdrop or count row",function()
    local N=show({{id=9},{id=14}})
    assert(not N.Stack.frame.backdrop and not N.Stack.header:IsShown() and not N.Stack.bar:IsShown())
    assert(N.Stack.frame:GetHeight()==N.Stack.contentHeight and N.Stack.frame:GetHeight()<160)
    for _,c in ipairs(N.Stack.cards)do assert(c.template=="TooltipBorderedFrameTemplate" and c.title.fontObject==GameTooltipHeaderText and c.summary.fontObject==GameTooltipText)end
end)
test("empty and unverified reward fields allocate no rows or placeholders",function()
    local N=show({{id=9}});C_QuestLog.IsOnQuest=nil
    GetQuestLogRewardMoney=function()end;GetQuestLogRewardXP=function()return 0 end
    N.Stack:Refresh();local c=N.Stack.cards[1]
    assert(not c.evidence:IsShown() and not c.status:IsShown() and not c.summary:IsShown() and c:GetHeight()<=38)
    assert(not c.groups.items and not c.groups.choices)
end)
test("guaranteed-only item icons have no empty label and choices stay distinct",function()
    local N=show({{id=9}});W.items={{"A",100,2,2,true,123}}
    N.Stack:Refresh();local c=N.Stack.cards[1]
    assert(not c.groups.items.label:IsShown() and c.icons[1]:GetWidth()==24 and c.icons[1].border.color[2]==1)
    W.choices={{"B",101,1,3,true,124}};N.Stack:Refresh()
    assert(c.groups.items.label:GetText()=="Guaranteed" and c.groups.choices.label:GetText()=="Choose one")
    assert(c.icons[1].row.kind=="reward" and c.icons[2].row.kind=="choice")
end)
test("money uses current native namespace and stays inline with XP",function()
    local N=show({{id=9}});local seen
    C_CurrencyInfo.GetCoinTextureString=function(value,size)seen={value,size};return "NATIVE_COINS" end
    N.Stack:Refresh();assert(seen[1]==12345 and seen[2]==12 and N.Stack.cards[1].summary:GetText()=="NATIVE_COINS  450 XP")
    C_CurrencyInfo=nil;assert(N.Rewards.Money(10101)=="1g 1s 1c" and not N.Rewards.Money(0) and not N.Rewards.Money(-1))
end)
test("native border persists while exact primary classifications tint only fill",function()
    local N=show({{id=2},{id=9},{id=98189}})
    assert(N.Stack.cards[1].backdropColor[1]==.09 and N.Stack.cards[2].backdropColor[2]>.09 and N.Stack.cards[3].backdropColor[1]>.09)
    for _,c in ipairs(N.Stack.cards)do assert(c.border[1]==.6 and not c.status:IsShown())end
end)
test("long stacks use a bounded viewport and clamp scroll at both ends",function()
    local rows={};for id=1,12 do rows[#rows+1]={id=id}end
    local N=show(rows);assert(N.Stack.maximum>0 and N.Stack.header:IsShown() and N.Stack.bar:IsShown())
    assert(N.Stack.frame:GetHeight()<=320 and N.Stack.scroll:GetWidth()==N.Stack.frame:GetWidth()-16)
    N.Stack:Scroll(10000);assert(N.Stack.offset==N.Stack.maximum)
    N.Stack:Scroll(-10000);assert(N.Stack.offset==0)
end)
test("pending rewards add one temporary line and timeout removes reserved space",function()
    local N=show({{id=9}});W.rewardReady=false;N.Stack:Refresh()
    local c=N.Stack.cards[1];assert(c.summary:GetText()=="Loading rewards…" and N.Hover.pending)
    N.Hover.timedOut=true;N.Stack:Refresh();assert(not c.summary:IsShown() and not N.Hover.pending)
end)
test("refresh filters newly completed rows and closes an empty stack",function()
    local N=show({{id=9}});C_QuestLog.IsOnQuest=function()return false end
    C_QuestLog.IsQuestFlaggedCompleted=function()return true end;C_QuestLog.IsRepeatableQuest=function()return false end
    W.Event("QUEST_REMOVED",9)
    N.Stack:Refresh();assert(not N.Hover.open and not N.Stack.frame:IsShown())
end)
test("scaled placement is clamped and remains frozen after cursor changes",function()
    local N=show({{id=9}},{saved={scale=1.2},screenWidth=360,screenHeight=240})
    N.Stack.screenWidth,N.Stack.screenHeight=360,240;N.Stack.anchorX,N.Stack.anchorY=358,239;N.Stack:Refresh()
    local point=N.Stack.frame.point;local scale=N.Stack.frame:GetScale();local left,bottom=point[4]*scale,point[5]*scale
    assert(left>=8 and bottom>=8 and left+N.Stack.frame:GetWidth()*scale<=360-8)
    assert(bottom+N.Stack.frame:GetHeight()*scale<=240-8)
    W.mouseX,W.mouseY=100,100;N.Stack:Refresh();assert(N.Stack.frame.point[4]==point[4] and N.Stack.frame.point[5]==point[5])
end)
test("native tooltip bridge permits slow transit and rejects owner or geometry changes",function()
    local N=show({{id=9}});N.Hover:Dismiss();N.Hover.blocked=nil
    GameTooltip=W.Object();GameTooltip.x=685;GameTooltip.y=620;GameTooltip.width=280;GameTooltip.height=100;GameTooltip.owner=W.Object();local data={id=54,type=1,guid="npc54"};GameTooltip.GetPrimaryTooltipData=function()return data end
    local f=W.Object();f.x=690;f.y=690;f.width=30;f.height=30;f.questID=9;f.GetQuestID=function()return 9 end
    W.mouseX,W.mouseY=700,700;N.Sources:Pin(f,9)
    W.mouseX=850;N.Hover:Tick(1);N.Hover:Tick(2);assert(N.Hover.open and N.Stack:NativeTransit())
    data.id=55;assert(not N.Stack:NativeTransit());data.id=54
    GameTooltip.owner=W.Object();assert(not N.Stack:NativeTransit())
    GameTooltip.owner=N.Stack.nativeOwner;GameTooltip.x=686;assert(not N.Stack:NativeTransit())
    GameTooltip.x=685;GameTooltip.shown=false;assert(not N.Stack:NativeTransit())
end)
test("native item tooltip aligns to its icon while remaining beside stack",function()
    local N=show({{id=9}});W.items={{"A",100,1,2,true,123}};N.Stack:Refresh()
    local b=N.Stack.cards[1].icons[1];N.Stack.frame.x=730;N.Stack.frame.y=400
    N.Stack.scroll.x=736;N.Stack.scroll.y=690;b.x=750;b.y=690;b.width=28;b.height=28;W.mouseX=760;W.mouseY=700
    b:Fire("OnEnter");assert(N.Stack.item and N.Stack.tooltip.point[2]==b and N.Stack.tooltip.point[5]==0)
    assert(N.Stack.tooltip.point[3]=="TOPRIGHT")
end)
test("Questie native hide allows bounded slow opening transit then consumes the bridge",function()
    local N=show({{id=9}},{screenWidth=900,screenHeight=700});N.Hover:Dismiss();N.Hover.blocked=nil
    GameTooltip=W.Object();GameTooltip.x=10;GameTooltip.y=540;GameTooltip.width=350;GameTooltip.height=100
    W.mouseX,W.mouseY=14,600
    local f=W.Object();f.x=5;f.y=590;f.width=20;f.height=20;f.questID=9;f.GetQuestID=function()return 9 end
    N.Sources:Pin(f,9);assert(N.Stack.placement.left==372)
    GameTooltip:Hide();GameTooltip._Rebuild=nil;W.mouseX=100;N.Hover:Tick(.1);N.Hover:Tick(.8);assert(N.Hover.open)
    N.Stack.frame.x=372;N.Stack.frame.y=580;W.mouseX=380;N.Hover:Tick(.9);assert(N.Stack.openingTransitConsumed)
    W.mouseX=100;N.Hover:Tick(1);N.Hover:Tick(1.21);assert(not N.Hover.open)
end)
test("opening bridge cannot retain the stack indefinitely after icon leave",function()
    local N=show({{id=9}});N.Stack.nativeRect={};N.Stack.placement={left=1066,bottom=640,width=320,height=60}
    N.Stack.anchorX,N.Stack.anchorY,N.Stack.parentScale=700,680,1
    W.mouseX,W.mouseY=850,680;N.Hover:Tick(.1);N.Hover:Tick(.8);assert(N.Hover.open)
    N.Hover:Tick(1.4);N.Hover:Tick(1.61);assert(not N.Hover.open)
end)
test("item row transit survives a slow cross-card route and expires when stalled",function()
    local N=show({{id=9}});W.items={{"A",100,1,2,true,123}};N.Stack:Refresh()
    local b=N.Stack.cards[1].icons[1];N.Stack.frame.x=730;N.Stack.frame.y=660
    N.Stack.scroll.x=730;N.Stack.scroll.y=660;b.x=738;b.y=680;b.width=28;b.height=28;W.mouseX,W.mouseY=750,694
    b:Fire("OnEnter");local t=N.Stack.tooltip;t.x=1056;t.y=640;t.width=280;t.height=80
    W.mouseX=900;N.Stack:ItemTransit(.1);N.Stack:ItemTransit(.8);assert(N.Stack.item)
    N.Stack:ItemTransit(1.4);N.Stack:ItemTransit(1.61);assert(not N.Stack.item)
end)
test("guaranteed currencies remain explicit beside choice item rewards",function()
    local N=show({{id=9}});W.choices={{"Choice",100,1,2,true,123}}
    C_QuestLog.GetQuestRewardCurrencies=function()return {{currencyID=10,name="Token",totalRewardAmount=3}}end
    N.Stack:Refresh();assert(N.Stack.cards[1].summary:GetText():find("Guaranteed: Token 3",1,true))
end)
test("related native tooltip update floods cannot restart an item transit deadline",function()
    local N=show({{id=9}});W.items={{"A",100,1,2,true,123}};N.Stack:Refresh()
    local b=N.Stack.cards[1].icons[1];N.Stack.frame.x=730;N.Stack.frame.y=660
    N.Stack.scroll.x=730;N.Stack.scroll.y=660;b.x=738;b.y=680;b.width=28;b.height=28;W.mouseX,W.mouseY=750,694
    b:Fire("OnEnter");local t=N.Stack.tooltip;t.x=1056;t.y=640;t.width=280;t.height=80
    W.mouseX=900;N.Stack:ItemTransit(.1)
    for i=1,6 do W.time=i*.2;local item=N.Stack.item;N.Stack:Inspect(item.button,item.row,true);N.Stack:ItemTransit(W.time);assert(N.Stack.item.bridgeAt==.1)end
    N.Stack:ItemTransit(1.4);N.Stack:ItemTransit(1.61);assert(not N.Stack.item)
end)

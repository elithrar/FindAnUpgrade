"""Render shipped Stack layout with real substitute glyph metrics; no WoW pixel claim."""
from pathlib import Path
import sys, re, json, math
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.work/pydeps'))
from lupa.lua51 import LuaRuntime
from PIL import Image,ImageDraw,ImageFont
FONT=Path('C:/Windows/Fonts/georgia.ttf')
FONT_BOLD=Path('C:/Windows/Fonts/georgiab.ttf')
OUT=ROOT/'dist/hover-layout-fixture.png'
def plain(value):
    value=re.sub(r'\|c[0-9a-fA-F]{8}|\|r','',value or '')
    value=re.sub(r'\|T.*?\|t','●',value)
    return value
fonts={}
def font_for(obj):
    values=obj.GetFont(obj)
    size=max(1,round(values[1] or 12))
    header=obj.template=='GameTooltipHeaderText'
    key=(size,header)
    if key not in fonts:fonts[key]=ImageFont.truetype(str(FONT_BOLD if header else FONT),size)
    return fonts[key]
def lines_for(obj):
    font=font_for(obj);width=max(1,obj.GetWidth(obj));out=[]
    for line in plain(obj.GetText(obj)).split('\n'):
        if obj.wordWrap is False:out.append(line);continue
        current=''
        for word in line.split(' '):
            candidate=(current+' '+word).strip()
            if current and font.getlength(candidate)>width:out.append(current);current=word
            else:current=candidate
        out.append(current)
    return out if plain(obj.GetText(obj)) else []
def measure_height(obj):
    font=font_for(obj);a,d=font.getmetrics();return len(lines_for(obj))*(a+d)
def measure_width(obj):
    font=font_for(obj);return max([font.getlength(x) for x in plain(obj.GetText(obj)).split('\n')] or [0])
image=Image.new('RGB',(1080,610),(34,39,46));draw=ImageDraw.Draw(image)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
draw.text((18,15),'OFFLINE LAYOUT FIXTURE — shipped Lua; Georgia substitute; approximate border and icon art',(235,236,238),font=small)
draw.text((18,36),'This is geometry evidence, not a screenshot or native rendering verification.',(181,190,204),font=small)
report={'nativeRenderingVerified':False,'fontSubstitute':str(FONT),'borderArt':'approximation of native template','scenarios':[]}
for i,(name,ids,items,choices) in enumerate([
    ('NPC · two money/XP quests',[9,14],[],[]),
    ('Marker · guaranteed + choose one',[98189],[['Boots',100,1,2,True,123]],[['Sword',101,1,3,True,124],['Staff',102,1,2,True,125]]),
    ('Long stack · bounded scrolling',list(range(1,9)),[['Reward',100,1,2,True,123]],[])]):
    lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().ROOT=str(ROOT).replace('\\','/')
    W=lua.execute((ROOT/'tests/wow_mock.lua').read_text());N=W.Init();lua.globals().W=W;lua.globals().N=N
    methods=lua.eval('function(w)return getmetatable(w.Object()).__index end')(W)
    methods.GetStringHeight=measure_height;methods.GetStringWidth=measure_width
    W.items=lua.table_from([lua.table_from(x) for x in items]);W.choices=lua.table_from([lua.table_from(x) for x in choices]);W.shift=True
    lua.execute('C_QuestLog.IsOnQuest=function()return true end;C_QuestLog.GetTitleForQuestID=function(id)local t={[9]="Selling Fish",[14]="Murloc Poachers",[98189]="Alther’s Mill"};return t[id] or "Quest "..id end;C_CurrencyInfo.GetCoinTextureString=function()return "12s 50c" end')
    source=lua.table_from({'rows':lua.table_from([lua.table_from({'id':x}) for x in ids]),'surface':'worldmap','valid':lua.eval('function()return true end'),'over':lua.eval('function()return true end'),'key':lua.table()})
    N.Hover.Consider(N.Hover,source)
    V=N.Stack;x=18+i*354;y=95
    draw.text((x,70),name,(235,236,238),font=small)
    layer=Image.new('RGBA',(320,math.ceil(V.frame.GetHeight(V.frame))),(0,0,0,0));ld=ImageDraw.Draw(layer)
    head=18 if V.maximum>0 else 0
    if head:ld.text((8,0),plain(V.header.text),(220,223,225),font=font_for(V.header))
    measured=[]
    for k in range(1,len(ids)+1):
        c=V.cards[k];cy=round(-c.point[3]+head);h=math.ceil(c.GetHeight(c))
        if cy>=layer.height:break
        width=round(c.GetWidth(c));rgb=tuple(round(c.backdropColor[j]*255) for j in (1,2,3))
        ld.rounded_rectangle((0,cy,width-1,cy+h-1),radius=5,fill=rgb+(238,),outline=(163,168,183,255),width=2)
        def text_obj(obj,ox=0,oy=cy):
            if not obj.shown:return
            pt=obj.point
            if pt is None:return
            tx,ty=ox+pt[2],oy-pt[3]
            f=font_for(obj);a,d=f.getmetrics()
            for n,line in enumerate(lines_for(obj)):ld.text((round(tx),round(ty)+n*(a+d)),line,font=f,fill=(235,236,239))
        for field in ('title','evidence','summary'):text_obj(c[field])
        for _,g in c.groups.items():text_obj(g.label)
        for _,icon in c.icons.items():
            if not icon.shown:continue
            px,py=round(icon.point[2]),round(cy-icon.point[3]);color=tuple(round(icon.border.color[j]*255) for j in (1,2,3))
            ld.rectangle((px,py,px+27,py+27),fill=(69,74,90),outline=color,width=2)
            ld.line((px+6,py+22,px+21,py+6),fill=(170,177,185),width=2)
        measured.append({'id':c.questID,'height':h,'width':width,'top':cy})
        assert h>=28
    if V.maximum>0:ld.rectangle((308,22,317,layer.height-1),fill=(64,66,76));ld.rectangle((309,24,316,45),fill=(183,185,194))
    image.paste(layer,(x,y),layer)
    report['scenarios'].append({'name':name,'frameWidth':V.frame.GetWidth(V.frame),'frameHeight':V.frame.GetHeight(V.frame),'contentHeight':V.contentHeight,'maximumScroll':V.maximum,'visibleCards':measured})
image.save(OUT)
(ROOT/'dist/hover-layout-fixture.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))

"""Reconstruct the current shipped sidebar from executed Lua, never a game capture.

Private client artwork/fonts and downloaded icon fixtures live only in .work.
The JSON receipt records the exact inputs and every approximation. This utility
is a visual review aid; it is not part of the installed addon or a rendering test.
"""

import argparse
import hashlib
import json
import re
from pathlib import Path

from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]

SCALE = 4
ASSETS = ROOT / ".work/mock-reconstruction-assets"
WORK = ROOT / ".work/mock-renderer"
OUT = ROOT / "dist"


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def plain(value):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", str(value or ""))


def measure_text(value, font):
    return sum(
        12 * SCALE if token.startswith("|T") else font.getlength(token)
        for token in re.split(r"(\|T.*?\|t)", value)
        if token
    )


def lua_value(lua, value):
    if isinstance(value, dict):
        return lua.table_from({k: lua_value(lua, v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([lua_value(lua, v) for v in value])
    return value


def build_scene(fixture, font_path, number_path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = ROOT.as_posix()
    W = lua.execute((ROOT / "tests/wow_mock.lua").read_text(encoding="utf-8"))
    N = W.Init()
    lua.globals().W, lua.globals().N = W, N
    methods = lua.eval("function(w)return getmetatable(w.Object()).__index end")(W)
    fonts = {}

    def font(obj):
        _, size, *_ = obj.GetFont(obj)
        size = size or 12
        numeric = (
            obj.template == "NumberFontNormalSmall"
            or obj.fontObject == lua.globals().NumberFontNormalSmall
        )
        key = (round(size * SCALE), bool(numeric))
        if key not in fonts:
            fonts[key] = ImageFont.truetype(
                str(number_path if numeric else font_path), max(1, key[0])
            )
        return fonts[key]

    def lines(obj):
        f = font(obj)
        width = max(1, obj.GetWidth(obj)) * SCALE
        result = []
        for line in plain(obj.GetText(obj)).split("\n"):
            if obj.wordWrap is False:
                result.append(line)
                continue
            current = ""
            for word in line.split(" "):
                candidate = (current + " " + word).strip()
                if current and measure_text(candidate, f) > width:
                    result.append(current)
                    current = word
                else:
                    current = candidate
            result.append(current)
        return result if plain(obj.GetText(obj)) else []

    def width(obj):
        return max(
            [
                measure_text(x, font(obj)) / SCALE
                for x in plain(obj.GetText(obj)).split("\n")
            ]
            or [0]
        )

    def height(obj):
        _, size, *_ = obj.GetFont(obj)
        return len(lines(obj)) * (size or 12)

    # Adapter.Call deliberately accepts Lua functions only. Wrapping Python
    # callbacks preserves that production guard while supplying real glyph
    # metrics, rather than silently triggering the fixture's fallback sizes.
    lua.globals().mockWidth, lua.globals().mockHeight = width, height
    methods.GetStringWidth = lua.eval("function(self)return mockWidth(self)end")
    methods.GetUnboundedStringWidth = methods.GetStringWidth
    methods.GetStringHeight = lua.eval("function(self)return mockHeight(self)end")
    lua.globals().fontFace = str(font_path)
    lua.execute(
        'GameTooltipText.font={fontFace,12,""};N.UI.fontState=nil;N.CatalogData={schemaVersion=1,quests={}};W.guid="Player-1";C_SpecializationInfo={GetActiveSpecGroup=function()return 1 end};N.Character:Mark("identity");N.Search:Toggle();W.time=.3;N.Search:Tick()'
    )
    S = N.Search
    data = lua_value(lua, fixture)
    lua.globals().fixture = data
    lua.execute("""
        local S=N.Search
        S.search:ClearFocus()
        S.filter.minimum,S.filter.maximum=fixture.minimum,fixture.maximum
        S.minimumInput:SetText(tostring(fixture.minimum));S.maximumInput:SetText(tostring(fixture.maximum))
        S.filter.scope=fixture.scope or "SAME_ZONE"
        S.scope:SetDefaultText(S.filter.scope=="SAME_ZONE" and "Same zone" or "Level range")
        S.slot:SetDefaultText("All rewards")
        S.usable:SetChecked(true);S.dungeons:SetChecked(false)
        C_CurrencyInfo.GetCoinTextureString=function(value)
            local gold=math.floor(value/10000);local silver=math.floor(value/100)%100;local copper=value%100;local parts={}
            if gold>0 then parts[#parts+1]=gold.."|Tgold:12|t"end
            if silver>0 then parts[#parts+1]=silver.."|Tsilver:12|t"end
            if copper>0 then parts[#parts+1]=copper.."|Tcopper:12|t"end
            return table.concat(parts," ")
        end
        local rewards={}
        N.Catalog.locationFaction=N.Character:Get().faction
        for _,row in ipairs(fixture.rows)do
            N.Catalog.records[row.id]={id=row.id,source=row.source or row}
            N.Catalog.locations[row.id]=row.locations or {}
            rewards[row.id]=row.reward
        end
        N.SearchModel.Reward=function(_,row)return rewards[row.id],{},false end
        S.results=fixture.rows
        S.count:SetText(fixture.count.."\\n"..#fixture.rows.." not rated")
        S:LayoutControls()
        -- The engine attaches the scroll child at its viewport origin. The
        -- lightweight test fixture does not model that implicit attachment.
        S.child:SetPoint("TOPLEFT",S.scroll,"TOPLEFT",0,0)
        S:LayoutResults();S:Scroll(0)
        S.empty:Hide()
    """)
    return lua, W, N, S, font, lines


class Painter:
    def __init__(self, scene, manifest):
        self.lua, self.W, self.N, self.S, self.font, self.lines = scene
        self.manifest = manifest
        self.image = Image.new("RGBA", (2200, 3040), (27, 29, 32, 255))
        self.draw = ImageDraw.Draw(self.image)
        self.origin = (148, 156)
        self.bounds = self.W.Bounds(self.S.frame)
        self.art_used, self.approximations = {}, []

    def rect(self, obj):
        x, y, w, h = self.W.Bounds(obj)
        px, py, _, ph = self.bounds
        return (
            (x - px) * SCALE + self.origin[0],
            (py + ph - y - h) * SCALE + self.origin[1],
            w * SCALE,
            h * SCALE,
        )

    def box(self, obj):
        x, y, w, h = self.rect(obj)
        return (round(x), round(y), round(x + w), round(y + h))

    def asset(self, key):
        entry = self.manifest.get("assets", self.manifest).get(key)
        if not entry:
            return None
        path = Path(entry["path"] if isinstance(entry, dict) else entry)
        if not path.is_absolute():
            path = ASSETS / path
        if not path.is_file():
            return None
        self.art_used[key] = {"path": str(path), "sha256": digest(path)}
        return Image.open(path).convert("RGBA")

    def paste(self, art, rect, color=None):
        if art is None:
            return
        x, y, w, h = rect
        art = art.resize((max(1, round(w)), max(1, round(h))), Image.Resampling.LANCZOS)
        if color:
            channels = art.split()
            art = Image.merge(
                "RGBA",
                tuple(
                    channels[i].point(lambda v, c=color[i]: round(v * c))
                    for i in range(3)
                )
                + (channels[3],),
            )
        self.image.alpha_composite(art, (round(x), round(y)))

    def nine(self, art, rect, edge=8, color=None):
        if art is None:
            return False
        x, y, w, h = rect
        # WoW Backdrop edge files contain eight square tiles: the four edges,
        # then top-left, top-right, bottom-left and bottom-right corners.
        unit = art.height
        if art.width != unit * 8:
            self.paste(art, rect, color)
            return True
        e = edge * SCALE
        left, right, top, bottom, tl, tr, bl, br = [
            art.crop((i * unit, 0, (i + 1) * unit, unit)) for i in range(8)
        ]
        top = top.transpose(Image.Transpose.ROTATE_270)
        bottom = bottom.transpose(Image.Transpose.ROTATE_90)
        for tile, r in [
            (left, (x, y + e, e, h - 2 * e)),
            (right, (x + w - e, y + e, e, h - 2 * e)),
            (top, (x + e, y, w - 2 * e, e)),
            (bottom, (x + e, y + h - e, w - 2 * e, e)),
            (tl, (x, y, e, e)),
            (tr, (x + w - e, y, e, e)),
            (bl, (x, y + h - e, e, e)),
            (br, (x + w - e, y + h - e, e, e)),
        ]:
            self.paste(tile, r, color)
        return True

    def fill(self, rect, color):
        x, y, w, h = rect
        self.draw.rectangle(
            (round(x), round(y), round(x + w - 1), round(y + h - 1)), fill=color
        )

    def text(self, obj):
        if obj.shown is False or not plain(obj.GetText(obj)):
            return
        x, y, w, h = self.rect(obj)
        f = self.font(obj)
        color = tuple(
            round((obj.textColor[i] if obj.textColor else 0.93) * 255)
            for i in (1, 2, 3)
        ) + (255,)
        lines = self.lines(obj)
        _, size, *_ = obj.GetFont(obj)
        line_h = (size or 12) * SCALE
        if obj.justifyV == "MIDDLE":
            y += (h - len(lines) * line_h) / 2
        elif obj.justifyV == "BOTTOM":
            y += h - len(lines) * line_h
        for i, line in enumerate(lines):
            tx = x
            tw = measure_text(line, f)
            if obj.justifyH == "RIGHT":
                tx += w - tw
            elif obj.justifyH == "CENTER":
                tx += (w - tw) / 2
            # Native number strings have outline; ordinary owned text inherits
            # tooltip typography, with no added web-style weight or shadow.
            numeric = obj.template == "NumberFontNormalSmall"
            for token in re.split(r"(\|T.*?\|t)", line):
                if not token:
                    continue
                if token.startswith("|T"):
                    name = token[2:].split(":")[0]
                    art = self.asset("coin_" + name)
                    if art:
                        self.paste(art, (tx, y + i * line_h, 12 * SCALE, 12 * SCALE))
                    else:
                        self.draw.ellipse(
                            (
                                tx + 2 * SCALE,
                                y + i * line_h + 2 * SCALE,
                                tx + 10 * SCALE,
                                y + i * line_h + 10 * SCALE,
                            ),
                            fill=(190, 190, 185),
                        )
                        self.approximations.append("coin " + name + " native artwork")
                    tx += 12 * SCALE
                else:
                    self.draw.text(
                        (round(tx), round(y + i * line_h)),
                        token,
                        font=f,
                        fill=color,
                        anchor="lt",
                        stroke_width=3 if numeric else 0,
                        stroke_fill=(0, 0, 0, 255),
                    )
                    tx += f.getlength(token)

    def input(self, obj):
        rect = self.rect(obj)
        x, y, w, h = rect
        left = self.asset("input_left")
        middle = self.asset("input_middle")
        right = self.asset("input_right")
        if left and middle and right:
            self.paste(left, (x - 5 * SCALE, y, 8 * SCALE, h))
            self.paste(middle, (x + 3 * SCALE, y, w - 6 * SCALE, h))
            self.paste(right, (x + w - 3 * SCALE, y, 8 * SCALE, h))
        else:
            self.fill(rect, (8, 8, 8, 255))
            self.draw.rounded_rectangle(
                (x, y, x + w, y + h),
                radius=4 * SCALE,
                outline=(108, 99, 80, 255),
                width=2 * SCALE,
            )
            self.approximations.append("InputBoxTemplate border geometry")
        if obj.GetText(obj):
            f = self.font(obj)
            value = obj.GetText(obj)
            self.draw.text(
                (x + 8 * SCALE, y + (h - 12 * SCALE) / 2),
                value,
                font=f,
                fill=(237, 240, 247, 255),
                anchor="lt",
            )

    def dropdown(self, obj):
        r = self.rect(obj)
        x, y, w, h = r
        art = self.asset("dropdown")
        if art:
            # Captured native 3-part art has fixed end caps; preserve those.
            cap = min(14 * SCALE, w / 3)
            aw, ah = art.size
            cut = min(28, aw // 3)
            self.paste(art.crop((0, 0, cut, ah)), (x, y, cap, h))
            self.paste(art.crop((cut, 0, aw - cut, ah)), (x + cap, y, w - 2 * cap, h))
            self.paste(art.crop((aw - cut, 0, aw, ah)), (x + w - cap, y, cap, h))
        else:
            self.fill(r, (12, 11, 8, 255))
            self.draw.rounded_rectangle(
                (x, y, x + w, y + h),
                radius=3 * SCALE,
                outline=(107, 93, 59, 255),
                width=2 * SCALE,
            )
            self.draw.rectangle(
                (
                    x + w - 25 * SCALE,
                    y + 3 * SCALE,
                    x + w - 3 * SCALE,
                    y + h - 3 * SCALE,
                ),
                outline=(125, 117, 91),
                width=SCALE,
            )
            self.draw.polygon(
                [
                    (x + w - 22 * SCALE, y + 10 * SCALE),
                    (x + w - 6 * SCALE, y + 10 * SCALE),
                    (x + w - 14 * SCALE, y + 19 * SCALE),
                ],
                fill=(255, 207, 0),
            )
            self.approximations.append("WowStyle1DropdownTemplate border/arrow")
        obj.Text.SetText(obj.Text, obj.defaultText or "")
        self.text(obj.Text)

    def checkbox(self, obj):
        key = "check_checked" if obj.checked else "check_empty"
        art = self.asset(key)
        if art:
            self.paste(art, self.rect(obj))
        else:
            x, y, w, h = self.rect(obj)
            self.draw.rectangle(
                (x + 4 * SCALE, y + 4 * SCALE, x + w - 4 * SCALE, y + h - 4 * SCALE),
                fill=(5, 5, 5),
                outline=(129, 126, 106),
                width=SCALE,
            )
            if obj.checked:
                self.draw.line(
                    [
                        (x + 5 * SCALE, y + 12 * SCALE),
                        (x + 10 * SCALE, y + 17 * SCALE),
                        (x + 22 * SCALE, y + 4 * SCALE),
                    ],
                    fill=(255, 219, 0),
                    width=3 * SCALE,
                )
            self.approximations.append("UICheckButtonTemplate artwork")
        # Native inherited checkbox labels use NORMAL_FONT_COLOR.
        obj.Text.textColor = self.lua.table_from([1, 0.82, 0])
        self.text(obj.Text)

    def panel(self):
        S = self.S
        self.fill(self.rect(S.frame), (12, 12, 13, 255))
        if not self.nine(
            self.asset("dialog_border"), self.rect(S.frame), 16, (0.65, 0.65, 0.65)
        ):
            x, y, w, h = self.rect(S.frame)
            self.draw.rectangle(
                (x, y, x + w, y + h), outline=(92, 92, 91), width=3 * SCALE
            )
            self.draw.rectangle(
                (x + 4 * SCALE, y + 4 * SCALE, x + w - 4 * SCALE, y + h - 4 * SCALE),
                outline=(35, 35, 34),
                width=SCALE,
            )
            self.approximations.append("UI-DialogBox-Border")
        self.text(S.title)
        for obj in (S.search, S.minimumInput, S.maximumInput):
            self.input(obj)
        self.text(S.placeholder)
        self.text(S.levelLabel)
        self.text(S.rangeSeparator)
        self.dropdown(S.slot)
        self.dropdown(S.scope)
        self.checkbox(S.usable)
        self.checkbox(S.dungeons)
        self.text(S.count)
        for key, obj in (("close", S.close), ("cog", S.options), ("sort", S.sort)):
            art = self.asset(key)
            if art:
                r = self.rect(obj)
                if key == "cog":
                    r = (r[0] + 3 * SCALE, r[1] + 3 * SCALE, 20 * SCALE, 20 * SCALE)
                self.paste(art, r)
            elif key == "cog":
                x, y, w, h = self.rect(obj)
                self.draw.text(
                    (x + w / 2, y + h / 2),
                    "⚙",
                    font=ImageFont.truetype(
                        "C:/Windows/Fonts/seguisym.ttf", 20 * SCALE
                    ),
                    fill=(180, 180, 178),
                    anchor="mm",
                )
                self.approximations.append("GEAR_64GREY texture")
            else:
                x, y, w, h = self.rect(obj)
                self.draw.rectangle(
                    (
                        x + 2 * SCALE,
                        y + 2 * SCALE,
                        x + w - 2 * SCALE,
                        y + h - 2 * SCALE,
                    ),
                    fill=(92, 12, 9),
                    outline=(177, 140, 64),
                    width=2 * SCALE,
                )
                if key == "sort":
                    self.draw.line(
                        (x + 10 * SCALE, y + 7 * SCALE, x + 10 * SCALE, y + 19 * SCALE),
                        fill=(255, 216, 0),
                        width=2 * SCALE,
                    )
                    self.draw.polygon(
                        [
                            (x + 6 * SCALE, y + 10 * SCALE),
                            (x + 10 * SCALE, y + 5 * SCALE),
                            (x + 14 * SCALE, y + 10 * SCALE),
                        ],
                        fill=(255, 216, 0),
                    )
                    self.draw.line(
                        (x + 18 * SCALE, y + 7 * SCALE, x + 18 * SCALE, y + 19 * SCALE),
                        fill=(255, 216, 0),
                        width=2 * SCALE,
                    )
                    self.draw.polygon(
                        [
                            (x + 14 * SCALE, y + 16 * SCALE),
                            (x + 18 * SCALE, y + 21 * SCALE),
                            (x + 22 * SCALE, y + 16 * SCALE),
                        ],
                        fill=(255, 216, 0),
                    )
                else:
                    f = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 18 * SCALE)
                    self.draw.text(
                        (x + w / 2, y + h / 2),
                        "×",
                        font=f,
                        fill=(255, 214, 0),
                        anchor="mm",
                    )
                self.approximations.append(key + " native button artwork")
        viewport = self.rect(S.scroll)
        saved = self.image
        cards = Image.new("RGBA", self.image.size, (0, 0, 0, 0))
        self.image = cards
        self.draw = ImageDraw.Draw(cards)
        geometry = []
        for _, card in S.cards.items():
            if not card.row or card.shown is False:
                continue
            r = self.rect(card)
            x, y, w, h = r
            c = tuple(round(card.backdropColor[j] * 255) for j in (1, 2, 3)) + (255,)
            self.fill(r, c)
            if not self.nine(self.asset("tooltip_border"), r, 10, (0.5, 0.5, 0.5)):
                self.draw.rounded_rectangle(
                    (x, y, x + w, y + h),
                    radius=3 * SCALE,
                    outline=(83, 83, 83),
                    width=SCALE,
                )
                self.approximations.append("UI-Tooltip-Border")
            for name in ("title", "tag", "location", "evidence"):
                self.text(card[name])
            if card.giver.shown:
                self.text(card.giver.text)
            for _, label in card.footer.items():
                self.text(label)
            for _, icon in card.icons.items():
                if icon.shown is False or not icon.row:
                    continue
                art = self.asset("item_" + str(icon.row.itemID))
                if art:
                    self.paste(art, self.rect(icon))
                else:
                    self.fill(self.rect(icon), (63, 58, 50, 255))
                    self.approximations.append("missing item " + str(icon.row.itemID))
                color = tuple(icon.border.color[j] for j in (1, 2, 3))
                border = self.asset("icon_border")
                if border:
                    self.paste(border, self.rect(icon), color)
                else:
                    bx, by, bw, bh = self.rect(icon)
                    self.draw.rectangle(
                        (bx, by, bx + bw, by + bh),
                        outline=tuple(round(v * 255) for v in color),
                        width=SCALE,
                    )
                    self.approximations.append("WhiteIconFrame rarity border")
                self.text(icon.level)
                self.text(icon.count)
                self.text(icon.group)
            if card.more.shown:
                self.text(card.more.text)
            geometry.append(
                {
                    "questID": card.row.id,
                    "rectLogical": [
                        (r[0] - self.origin[0]) / SCALE,
                        (r[1] - self.origin[1]) / SCALE,
                        r[2] / SCALE,
                        r[3] / SCALE,
                    ],
                    "title": card.title.text,
                }
            )
        vx, vy, vw, vh = map(round, viewport)
        clipped = cards.crop((vx, vy, vx + vw, vy + vh))
        saved.alpha_composite(clipped, (vx, vy))
        self.image = saved
        self.draw = ImageDraw.Draw(saved)
        if S.bar.shown:
            r = self.rect(S.bar)
            x, y, w, h = r
            self.fill(r, (8, 8, 8))
            self.draw.rounded_rectangle(
                (x, y, x + w, y + h),
                radius=5 * SCALE,
                outline=(74, 74, 72),
                width=SCALE,
            )
            thumb = self.asset("scroll_thumb")
            if thumb:
                self.paste(thumb, (x, y, w, 22 * SCALE))
            else:
                self.draw.rounded_rectangle(
                    (x + 2 * SCALE, y + 2 * SCALE, x + w - 2 * SCALE, y + 22 * SCALE),
                    radius=2 * SCALE,
                    fill=(111, 108, 100),
                )
        self.paste(self.asset("resize"), self.rect(S.resize))
        return geometry

    def label(self):
        f = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 32)
        self.draw.text(
            (148, 80),
            "Code-driven reconstruction · not an in-game capture",
            font=f,
            fill=(184, 188, 193),
            anchor="lt",
        )
        self.draw.text(
            (148, 2928),
            "476 × 680 logical UI units · rendered at 4×",
            font=f,
            fill=(141, 146, 152),
            anchor="lt",
        )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--fixture", type=Path, default=ASSETS / "fixture.json")
    ap.add_argument("--manifest", type=Path, default=ASSETS / "manifest.json")
    ap.add_argument("--name", default="FindAnUpgrade-current-sidebar-reconstruction-v2")
    ap.add_argument(
        "--sort-menu-only",
        action="store_true",
        help="Overlay the executed current menu description on the frozen first PNG",
    )
    args = ap.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(exist_ok=True)
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    manifest = (
        json.loads(args.manifest.read_text(encoding="utf-8"))
        if args.manifest.exists()
        else {}
    )
    font = Path(manifest.get("font", ASSETS / "fonts/Expressway.TTF"))
    number = Path(manifest.get("numberFont", "C:/Windows/Fonts/arial.ttf"))
    scene = build_scene(fixture, font, number)
    p = Painter(scene, manifest)
    if args.sort_menu_only:
        frozen = OUT / "FindAnUpgrade-current-sidebar-4x.png"
        p.image = Image.open(frozen).convert("RGBA")
        p.draw = ImageDraw.Draw(p.image)
        menu = scene[3].sort.GenerateMenu(scene[3].sort)
        title_font = ImageFont.truetype(str(font), 11 * SCALE)
        radio_font = ImageFont.truetype(str(font), 12 * SCALE)
        titles = [value for _, value in menu.titles.items()]
        entries = [entry for _, entry in menu.entries.items()]
        width = max(title_font.getlength(value) for value in titles) + 32 * SCALE
        height = (20 + len(titles) * 17 + len(entries) * 23) * SCALE
        bx, by, bw, bh = p.rect(scene[3].sort)
        x, y = bx + bw - width, by + bh + 3 * SCALE
        p.fill((x, y, width, height), (10, 10, 12, 255))
        p.nine(p.asset("tooltip_border"), (x, y, width, height), 10, (0.72, 0.67, 0.52))
        cursor = y + 10 * SCALE
        for index, label in enumerate(titles):
            p.draw.text(
                (x + 16 * SCALE, cursor),
                label,
                font=title_font,
                fill=(255, 209, 51) if index < 2 else (177, 177, 182),
                anchor="lt",
            )
            cursor += 17 * SCALE
        for entry in entries:
            cy = cursor + 6 * SCALE
            p.draw.ellipse(
                (x + 16 * SCALE, cy - 4 * SCALE, x + 24 * SCALE, cy + 4 * SCALE),
                fill=(12, 12, 12),
                outline=(137, 130, 103),
                width=SCALE,
            )
            if entry.checked():
                p.draw.ellipse(
                    (x + 18 * SCALE, cy - 2 * SCALE, x + 22 * SCALE, cy + 2 * SCALE),
                    fill=(255, 208, 0),
                )
            p.draw.text(
                (x + 32 * SCALE, cursor),
                entry.label,
                font=radio_font,
                fill=(238, 240, 247),
                anchor="lt",
            )
            cursor += 23 * SCALE
        destination = OUT / "FindAnUpgrade-current-sidebar-sort-menu-4x.png"
        p.image.convert("RGB").save(destination)
        receipt = {
            "artifact": "Code-driven reconstruction, not an in-game capture",
            "nativeRenderingVerified": False,
            "basePNG": {"path": str(frozen), "sha256": digest(frozen)},
            "currentSearchLua": digest(ROOT / "FindAnUpgrade/Search.lua"),
            "menuTitles": titles,
            "menuEntries": [
                {"label": e.label, "checked": bool(e.checked())} for e in entries
            ],
            "approximations": [
                "Native menu layout, radio artwork and placement are reconstructed from the current executed description; native rendering remains unverified."
            ],
            "png": {"path": str(destination), "sha256": digest(destination)},
        }
        destination.with_suffix(".json").write_text(
            json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
        )
        print(json.dumps(receipt, indent=2))
        return
    geometry = p.panel()
    p.label()
    destination = OUT / (args.name + ".png")
    p.image.convert("RGB").save(destination)
    evidence = {
        "artifact": "Code-driven reconstruction, not an in-game capture",
        "nativeRenderingVerified": False,
        "scale": SCALE,
        "canvasPixels": p.image.size,
        "panelLogical": [476, 680],
        "font": {"path": str(font), "sha256": digest(font)},
        "numberFont": {"path": str(number), "sha256": digest(number)},
        "shippedSource": {
            f: digest(ROOT / "FindAnUpgrade" / f)
            for f in ["Search.lua", "UI.lua", "Model.lua"]
        },
        "fixture": {"path": str(args.fixture), "sha256": digest(args.fixture)},
        "assetsUsed": p.art_used,
        "approximations": sorted(set(p.approximations)),
        "rows": geometry,
        "png": {"path": str(destination), "sha256": digest(destination)},
    }
    destination.with_suffix(".json").write_text(
        json.dumps(evidence, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "png": str(destination),
                "rows": len(geometry),
                "approximations": evidence["approximations"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()

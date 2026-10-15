"""Parse public Forever HTML without executing embedded website JavaScript."""
from html.parser import HTMLParser
import hashlib
import json
import re


_UNSIGNED_DISPLAY_INTEGER = r"(?:0|[1-9]\d*|[1-9]\d{0,2}(?:,\d{3})+)"
_VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}


def primary_reward_values(row):
    """Copy only explicitly encoded primary base amounts, never absent zeros.

    The exact quest/environment binding belongs to the caller. Primary JSON
    omits fields it does not publish; in particular, no reprewards key is not
    evidence of a complete empty reputation list. Native client multipliers
    and costs are separate from these nonnegative base XP/money rewards.
    """
    out = {}
    for key in ("xp", "money"):
        if key in row:
            value = row[key]
            if type(value) is not int or not 0 <= value < 2**53:
                raise ValueError("Invalid explicit primary reward "+key)
            out[key] = value
    if "reprewards" in row:
        if not isinstance(row["reprewards"], list) or len(row["reprewards"]) > 128:
            raise ValueError("Invalid explicit primary reputation list")
        rewards, factions = [], set()
        for entry in row["reprewards"]:
            if not isinstance(entry, list) or len(entry) != 2:
                raise ValueError("Invalid explicit primary reputation pair")
            faction, amount = entry
            if type(faction) is not int or not 0 < faction < 2**31 or type(amount) is not int or not -2**31 < amount < 2**31 or faction in factions:
                raise ValueError("Invalid or duplicate explicit primary reputation")
            factions.add(faction)
            rewards.append({"factionID": faction, "amount": amount})
        out["reputation"] = rewards
    return out


def reward_amount_line(text):
    """Parse one labelled Forever reward line; unrelated content stays absent.

    A displayed zero is retained. No blank or absent line supplies a default.
    Malformed explicit amount syntax fails staging instead of silently
    discarding a field or concatenating its digits into a different value.
    """
    integer = _UNSIGNED_DISPLAY_INTEGER
    match = re.fullmatch("("+integer+r") experience", text)
    if match:
        value = int(match[1].replace(",", ""))
        if value >= 2**53:
            raise ValueError("Explicit XP amount exceeds exact numeric range")
        return "xp", value
    match = re.fullmatch(r"([+-]"+integer+r"|0) reputation with (\S(?:.*\S)?)", text)
    if match:
        value = int(match[1].replace(",", ""))
        if not -2**31 < value < 2**31:
            raise ValueError("Explicit reputation amount exceeds supported range")
        return "reputation", {"name": match[2], "amount": value}
    # Coins may be split over child spans and therefore have no separating
    # spaces. Unit labels, a unique descending unit order, and complete input
    # consumption establish copper units; bare numbers remain unknown.
    coin_integer = r"-?"+integer
    coins = list(re.finditer("("+coin_integer+r")\s*([gsc])", text))
    if coins and re.sub("("+coin_integer+r")\s*([gsc])|\s", "", text) == "":
        units = [coin[2] for coin in coins]
        if len(set(units)) != len(units) or units != sorted(units, key="gsc".index):
            raise ValueError("Ambiguous explicit money unit order")
        signs = {coin[1].startswith("-") for coin in coins}
        if len(signs) != 1:
            raise ValueError("Mixed reward and cost money units")
        value = sum(int(coin[1].replace(",", ""))*{"g": 10000, "s": 100, "c": 1}[coin[2]] for coin in coins)
        if abs(value) >= 2**53:
            raise ValueError("Explicit money amount exceeds exact numeric range")
        return ("moneyCost", -value) if True in signs else ("money", value)
    if text.endswith(" experience") or " reputation with" in text or re.fullmatch(r"[\d,\s+.-]*[gsc][\d,gsc\s+.-]*", text):
        raise ValueError("Unsupported explicit reward amount: "+text)
    return None


class Node:
    def __init__(self, tag="", attrs=(), parent=None):
        self.tag, self.attrs, self.parent, self.children = tag, dict(attrs), parent, []
        self.closed = tag in _VOID_TAGS
        self.malformed = False

    def text(self):
        return "".join(c if isinstance(c, str) else c.text() for c in self.children)

    def all(self, tag=None):
        for child in self.children:
            if isinstance(child, Node):
                if tag is None or child.tag == tag:
                    yield child
                yield from child.all(tag)

    def has_class(self, name):
        return name in self.attrs.get("class", "").split()


class Parser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root, self.stack = Node(), []
        self.stack.append(self.root)

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.stack[-1])
        self.stack[-1].children.append(node)
        if tag not in _VOID_TAGS:
            self.stack.append(node)

    def handle_endtag(self, tag):
        for i in range(len(self.stack)-1, 0, -1):
            if self.stack[i].tag == tag:
                # HTMLParser permits a closing ancestor to abandon still-open
                # children. Retain that fact: browser-style recovery cannot
                # establish that a source reward list was complete.
                self.stack[i].closed = True
                self.stack[i].malformed = self.stack[i].malformed or i != len(self.stack)-1
                self.stack = self.stack[:i]
                return
        if tag not in _VOID_TAGS:
            self.stack[-1].malformed = True

    def handle_data(self, value):
        self.stack[-1].children.append(value)


def document(html):
    parser = Parser()
    parser.feed(re.sub(r"<script\b[^>]*>.*?</script>", "", html, flags=re.S | re.I))
    return parser.root


def quest_index(html):
    root = document(html)
    result = next((re.fullmatch(r"([\d,]+)\s*results", node.text().strip()) for node in root.all("span") if re.fullmatch(r"([\d,]+)\s*results", node.text().strip())), None)
    if not result:
        raise ValueError("Public index result count missing")
    ids = set()
    for anchor in root.all("a"):
        match = re.fullmatch(r"/quests/(\d+)", anchor.attrs.get("href", ""))
        # The all-record index also lists explicitly unconfirmed Classic-only
        # IDs. Discovery retains them; detail parsing must prove Forever data.
        if match and anchor.attrs.get("data-wowhead") in ("quest="+match[1]+"&domain=forever", "quest="+match[1]+"&domain=classic"):
            ids.add(int(match[1]))
    if not ids:
        raise ValueError("Public index contains no exact Forever quest links")
    return int(result[1].replace(",", "")), sorted(ids)


def quest_index_titles(html):
    out = {}
    for anchor in document(html).all("a"):
        match = re.fullmatch(r"/quests/(\d+)", anchor.attrs.get("href", ""))
        if match:
            title = next((node.text() for node in anchor.all("div") if node.has_class("font-semibold")), None)
            if title:
                out[int(match[1])] = title
    return out


def quest_index_fingerprints(html):
    """Hash each displayed exact row, excluding unrelated scripts/page chrome."""
    def tree(node):
        if isinstance(node, str): return node.strip()
        return [node.tag, sorted(node.attrs.items()), [tree(child) for child in node.children]]
    out = {}
    for anchor in document(html).all("a"):
        match = re.fullmatch(r"/quests/([1-9]\d*)", anchor.attrs.get("href", ""))
        if match and anchor.attrs.get("data-wowhead") in ("quest="+match[1]+"&domain=forever", "quest="+match[1]+"&domain=classic"):
            out[int(match[1])] = hashlib.sha256(json.dumps(tree(anchor), ensure_ascii=False, sort_keys=True).encode()).hexdigest()
    return out


def quest_detail(html, quest_id):
    """Read the explicitly labelled Forever column, never its Classic sibling.

    Empty means the source's complete item list is empty. Absent XP/money/rep
    display remains unknown: omission is not a verified zero-valued award.
    """
    if "</html>" not in html.lower():
        return {"id": quest_id, "items": [], "itemState": "unknown", "confirmation": "unconfirmed", "fieldStates": {name: "unknown" for name in ("xp", "money", "reputation", "currencies", "givers", "coordinates")}, "reason": "Incomplete public HTML document"}
    root = document(html)
    labels = [node for node in root.all("div") if node.has_class("label") and node.text() == "Forever"]
    panels = [node for label in labels for node in label.parent.children if isinstance(node, Node) and node.has_class("wow-tt")]
    out = {"id": quest_id, "items": [], "itemState": "unknown", "confirmation": "unconfirmed", "fieldStates": {name: "unknown" for name in ("xp", "money", "reputation", "currencies", "givers", "coordinates")}}
    exact = any(anchor.attrs.get("href") == "https://www.wowhead.com/forever/quest="+str(quest_id) for anchor in root.all("a"))
    if len(panels) != 1:
        out["reason"] = "Missing or ambiguous Forever panel"
        return out
    panel = panels[0]
    if not panel.closed or panel.malformed or any(not node.closed or node.malformed for node in panel.all()):
        raise ValueError("Malformed Forever reward panel: "+str(quest_id))
    if not exact or "Not in Forever" in panel.text() or "not yet confirmed" in panel.text().lower():
        out["reason"] = "Source does not confirm an exact Forever record"
        return out
    blocks = [node for node in panel.children if isinstance(node, Node)]
    if not blocks or not blocks[0].has_class("font-semibold"):
        raise ValueError("Forever record title missing: "+str(quest_id))
    out["title"] = blocks[0].text().strip()
    out["confirmation"] = "published"
    slots = {"guaranteed": 0, "choice": 0}
    reputation = []
    for block in blocks[1:]:
        value = block.text().strip()
        match = re.fullmatch(r"Level (-?\d+)", value)
        if match:
            out["level"] = int(match[1])
            continue
        match = re.fullmatch(r"Requires Level (\d+)", value)
        if match:
            out["minimum"] = int(match[1])
            continue
        if value in ("Alliance", "Horde", "Both"):
            out["faction"] = value
            continue
        children = [node for node in block.children if isinstance(node, Node)]
        heading = children[0].text().strip() if children else ""
        anchors = [node for node in block.all("a") if re.fullmatch(r"/items/\d+", node.attrs.get("href", ""))]
        if anchors:
            group = {"You will receive:": "guaranteed", "You will also receive:": "guaranteed", "You will be able to choose one of these rewards:": "choice"}.get(heading)
            if not group:
                # The separate change-summary section is not a reward list.
                if heading == "Changes in Forever":
                    continue
                raise ValueError("Unsupported Forever item block: "+str(quest_id)+" "+heading)
            for anchor in anchors:
                item_id = int(anchor.attrs["href"].split("/")[-1])
                if anchor.attrs.get("data-wowhead") != "item="+str(item_id)+"&domain=forever":
                    raise ValueError("Item environment does not match Forever")
                spans = [node for node in anchor.children if isinstance(node, Node) and node.tag == "span"]
                if not spans:
                    raise ValueError("Item identification label missing")
                name, suffix = spans[0].text().strip(), "".join(node.text() for node in spans[1:]).strip()
                amount = re.fullmatch(r"[\u00d7x]\s*(\d+)", suffix) if suffix else None
                if suffix and not amount:
                    raise ValueError("Unsupported item quantity: "+suffix)
                quantity = int(amount[1]) if amount else 1  # A displayed unstacked item, not a missing record.
                if quantity < 1:
                    raise ValueError("Invalid reward quantity")
                # Published slots can repeat the same item even within a group
                # (9324/9331 list Burning Blossom x20 and x10). Keep both facts;
                # neither silently sum quantities nor collapse an occurrence.
                slots[group] += 1
                out["items"].append({"itemID": item_id, "name": name, "quantity": quantity, "group": group, "slot": slots[group]})
        if heading == "You will also receive:":
            for line in children[1:]:
                text = line.text().strip()
                amount = reward_amount_line(text)
                if not amount:
                    continue
                key, value = amount
                if key == "reputation":
                    # Keep the displayed slots, including repeated names. The
                    # source does not explain their effective award. Neither
                    # sum nor deduplicate these separate source observations.
                    reputation.append(value)
                else:
                    if key in out:
                        raise ValueError("Duplicate explicit reward amount: "+str(quest_id)+" "+key)
                    out[key] = value
                    if key in out["fieldStates"]:
                        out["fieldStates"][key] = "published"
    if reputation:
        out["reputation"] = reputation
        out["fieldStates"]["reputation"] = "published"
    out["itemState"] = "published" if out["items"] else "published-empty"
    return out

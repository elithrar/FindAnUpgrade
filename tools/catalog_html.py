"""Parse public Forever HTML without executing embedded website JavaScript."""
from html.parser import HTMLParser
import re


class Node:
    def __init__(self, tag="", attrs=(), parent=None):
        self.tag, self.attrs, self.parent, self.children = tag, dict(attrs), parent, []

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
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            self.stack.append(node)

    def handle_endtag(self, tag):
        for i in range(len(self.stack)-1, 0, -1):
            if self.stack[i].tag == tag:
                self.stack = self.stack[:i]
                return

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
                match = re.fullmatch(r"([\d,]+) experience", text)
                if match:
                    out["xp"] = int(match[1].replace(",", ""))
                    out["fieldStates"]["xp"] = "published"
                    continue
                match = re.fullmatch(r"([+-][\d,]+) reputation with (.+)", text)
                if match:
                    reputation.append({"name": match[2], "amount": int(match[1].replace(",", ""))})
                    continue
                coins = re.findall(r"(\d+)\s*([gsc])", text)
                if coins and re.sub(r"\d+\s*[gsc]|\s", "", text) == "":
                    out["money"] = sum(int(count)*{"g": 10000, "s": 100, "c": 1}[unit] for count, unit in coins)
                    out["fieldStates"]["money"] = "published"
    if reputation:
        out["reputation"] = reputation
        out["fieldStates"]["reputation"] = "published"
    out["itemState"] = "published" if out["items"] else "published-empty"
    return out

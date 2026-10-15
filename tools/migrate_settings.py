"""Copy only this addon's old SavedVariables data, without evaluating Lua."""
from pathlib import Path
import argparse
import hashlib
import math
import os
import re

MAX_BYTES = 4 * 1024 * 1024
TOKEN = re.compile(r'''[ \t\r\n\f\v]+|--[^\r\n]*|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|(?:-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)|[A-Za-z_][A-Za-z_0-9]*|[{}\[\]=,;]''')
NUMBER = re.compile(r'-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\Z')
RESERVED = set('and break do else elseif end false for function if in local nil not or repeat return then true until while'.split())


def quoted(token):
    index = 1
    while index < len(token) - 1:
        char = token[index]
        if char in '\r\n\0':
            raise ValueError('Literal control characters are not saved strings')
        if char == '\\':
            index += 1
            char = token[index]
            if char.isascii() and char.isdigit():
                match = re.match(r'[0-9]{1,3}', token[index:])
                if int(match[0]) > 255:
                    raise ValueError('Invalid Lua byte escape')
                index += len(match[0]) - 1
            elif char not in 'abfnrtv\\\"\'':
                raise ValueError('Unsupported Lua string escape')
        index += 1


def validate_data(raw):
    """Accept one finite, bounded data table assignment; reject executable Lua."""
    if len(raw) > MAX_BYTES:
        raise ValueError("Saved settings exceed the migration limit")
    text = raw.decode('utf-8-sig')
    tokens = []
    position = 0
    for match in TOKEN.finditer(text):
        if match.start() != position:
            raise ValueError("Settings contain unsupported Lua syntax")
        position = match.end()
        token = match.group()
        if token.isspace() or token.startswith('--'):
            if token.startswith('--['):
                raise ValueError("Long Lua comments are not SavedVariables data")
            continue
        if NUMBER.fullmatch(token) and not math.isfinite(float(token)):
            raise ValueError("Settings numbers must be finite")
        if token.startswith(('"', "'")):
            quoted(token)
        tokens.append(token)
        if len(tokens) > 100000:
            raise ValueError("Saved settings contain too many values")
    if position != len(text):
        raise ValueError("Settings contain unsupported Lua syntax")
    cursor = 0

    def take(expected=None):
        nonlocal cursor
        if cursor >= len(tokens) or expected is not None and tokens[cursor] != expected:
            raise ValueError("Settings are not a data table")
        token = tokens[cursor]
        cursor += 1
        return token

    def value(depth=0):
        if depth > 32:
            raise ValueError("Settings table is too deeply nested")
        token = take()
        if token == '{':
            while cursor < len(tokens) and tokens[cursor] != '}':
                if tokens[cursor] == '[':
                    take('[')
                    key = take()
                    if not (key.startswith(('"', "'")) or NUMBER.fullmatch(key)):
                        raise ValueError("Unsupported settings key")
                    take(']'); take('='); value(depth + 1)
                elif cursor + 1 < len(tokens) and tokens[cursor + 1] == '=':
                    key = take()
                    if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', key) or key in RESERVED:
                        raise ValueError("Unsupported settings key")
                    take('='); value(depth + 1)
                else:
                    value(depth + 1)
                if cursor < len(tokens) and tokens[cursor] in (',', ';'):
                    take()
                elif cursor >= len(tokens) or tokens[cursor] != '}':
                    raise ValueError("Missing settings separator")
            take('}')
        elif not (token in ('true', 'false', 'nil') or token.startswith(('"', "'")) or NUMBER.fullmatch(token)):
            raise ValueError("Executable settings expressions are not accepted")

    take('QuestBriefDB'); take('=')
    if cursor >= len(tokens) or tokens[cursor] != '{':
        raise ValueError("Expected QuestBrief settings table")
    value()
    if cursor < len(tokens) and tokens[cursor] == ';':
        take(';')
    if cursor != len(tokens):
        raise ValueError("Only the QuestBrief settings assignment is accepted")
    return hashlib.sha256(raw).hexdigest()


def read_data(path):
    with Path(path).open('rb') as source:
        raw = source.read(MAX_BYTES + 1)
    validate_data(raw)
    return raw


def copy_settings(source, target, expected_sha):
    source, target = Path(source).resolve(), Path(target).resolve()
    if source.name != 'QuestBrief.lua' or target.name != 'FindAnUpgrade.lua' or source.parent != target.parent:
        raise ValueError("Migration must use the two owned files in the same SavedVariables directory")
    raw = read_data(source)
    digest = validate_data(raw)
    if digest != expected_sha:
        raise ValueError("Saved settings changed after the reviewed snapshot")
    # Exclusive creation preserves any existing new-name settings, even empty ones.
    created = False
    identity = None
    try:
        with target.open('xb') as output:
            created = True
            identity = os.fstat(output.fileno())
            output.write(raw)
        if target.read_bytes() != raw:
            raise ValueError("Copied settings failed byte verification")
    except Exception:
        if created and identity is not None and target.exists() and target.stat().st_ino == identity.st_ino:
            target.unlink()
        raise
    return {'source': str(source), 'target': str(target), 'bytes': len(raw), 'sha256': digest}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--target', required=True, type=Path)
    parser.add_argument('--expect-sha', required=True)
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    import json
    if args.check_only:
        if validate_data(read_data(args.source)) != args.expect_sha:
            raise ValueError('Saved settings changed after the reviewed snapshot')
    else:
        print(json.dumps(copy_settings(args.source, args.target, args.expect_sha), indent=2))

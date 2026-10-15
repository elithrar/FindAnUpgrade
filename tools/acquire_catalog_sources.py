"""Acquire pinned public ATT inputs with byte/Git-blob receipts and warm reuse.

No credentials, upstream Lua execution, harvesters or runtime installation.
"""
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen
import argparse, hashlib, json
from import_catalog import PIN, PREFIX

REPO = "ATTWoWAddon/AllTheThings"
AGENT = "FindAnUpgrade-source-sync/1 (public pinned factual inputs)"


def fetch(url):
    with urlopen(Request(url, headers={"User-Agent":AGENT,"Accept":"application/vnd.github+json"}),timeout=45) as response:
        if response.url.split('/')[2] not in ('api.github.com','raw.githubusercontent.com'):
            raise ValueError("Unexpected source redirect")
        return response.read()


def subtree(path, revision):
    parent, name = path.rsplit('/',1)
    listing = json.loads(fetch("https://api.github.com/repos/"+REPO+"/contents/"+quote(parent,safe='/')+"?ref="+revision))
    selected = [row for row in listing if row['name']==name and row['type']=='dir']
    if len(selected)!=1: raise ValueError("Source directory identity missing: "+path)
    tree = json.loads(fetch("https://api.github.com/repos/"+REPO+"/git/trees/"+selected[0]['sha']+"?recursive=1"))
    if tree.get('truncated') or 'tree' not in tree: raise ValueError("Incomplete upstream tree: "+path)
    return [{**row,'path':path+'/'+row['path']} for row in tree['tree'] if row['type']=='blob']


def receipt(path, raw, blob=None):
    actual = hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
    if blob and actual!=blob: raise ValueError("Upstream Git blob mismatch: "+path)
    return {'path':path,'gitBlob':actual,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'url':'https://github.com/'+REPO+'/blob/'+PIN+'/'+quote(path,safe='/')}


def acquire(destination, selected):
    old = {}
    manifest=destination/'ACQUISITION.json'
    if manifest.exists():
        previous=json.loads(manifest.read_bytes())
        if previous['commit']!=PIN: raise ValueError("Cache belongs to a different source pin; use a separate cache directory")
        old={row['path']:row for row in previous['files']}
    rows=[];downloaded=0
    for source in sorted(selected,key=lambda row:row['path']):
        relative=Path(source['path'])
        target=(destination/relative).resolve()
        if not target.is_relative_to(destination.resolve()): raise ValueError("Source path escaped cache")
        raw=target.read_bytes() if target.is_file() else None
        expected=source.get('sha') or old.get(source['path'],{}).get('gitBlob')
        if raw is None or not expected or hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()!=expected:
            raw=fetch('https://raw.githubusercontent.com/'+REPO+'/'+PIN+'/'+quote(source['path'],safe='/'))
            target.parent.mkdir(parents=True,exist_ok=True)
            verified=receipt(source['path'],raw,expected)
            target.write_bytes(raw);downloaded+=1
        else: verified=receipt(source['path'],raw,expected)
        rows.append(verified)
    destination.mkdir(parents=True,exist_ok=True)
    manifest.write_bytes((json.dumps({'repository':REPO,'commit':PIN,'purpose':'Read-only pinned source inputs; raw files excluded from distributions','files':rows},indent=2)+'\n').encode())
    return {'files':len(rows),'downloaded':downloaded,'reused':len(rows)-downloaded}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source-root',type=Path,default=Path('.work/catalog-cache/att-source'))
    parser.add_argument('--compiled-root',type=Path,default=Path('.work/catalog-cache/att-generated'))
    parser.add_argument('--revision',default=PIN)
    parser.add_argument('--plan-only',action='store_true')
    args=parser.parse_args()
    if args.revision!=PIN: raise ValueError("A new ATT revision requires reviewed parser/build contracts and a pin update")
    authored_tree=subtree(PREFIX.rstrip('/'),PIN)
    compiled_tree=subtree('db/Camelot',PIN)
    authored=[row for row in authored_tree if row['path'].endswith('.lua') or row['path'].endswith('forever.config')]
    support=['LICENSE','.contrib/.db/shared/constants/raceIDs.lua','.contrib/.db/shared/constants/classIDs.lua','.contrib/.db/shared/constants/lvl.lua','.contrib/.db/shared/functions/Shortcuts.lua','.contrib/.db/shared/.config/root.config','.contrib/.db/shared/.main.lua','.contrib/.db/build - forever.bat','.contrib/.db/standard/.config/retail/retail.config','src/Classes/Quests.lua','src/Classes/base.lua','src/base.lua']
    authored.extend({'path':path} for path in support)
    compiled=[row for row in compiled_tree if row['path'].endswith('.lua') or row['path'].endswith('Database.xml')]
    compiled.extend({'path':path} for path in ('LICENSE','.contrib/.db/forever/.config/forever.config','.contrib/.db/shared/.config/root.config','.contrib/.db/build - forever.bat','.contrib/.db/standard/.config/retail/retail.config'))
    if args.plan_only:
        print(json.dumps({'revision':PIN,'authoringPaths':[row['path'] for row in authored],'compiledPaths':[row['path'] for row in compiled]},indent=2));return
    print(json.dumps({'revision':PIN,'authoring':acquire(args.source_root,authored),'compiled':acquire(args.compiled_root,compiled)},indent=2))


if __name__=='__main__': main()

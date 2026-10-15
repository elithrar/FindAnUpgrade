"""Acquisition trust boundaries, incremental reuse, ownership and safe apply."""
from pathlib import Path
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError
from unittest import mock
import hashlib
import contextlib
import io
import json
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
import acquire_catalog_sources as acquire
import collect_catalog_sources as collect
import sync_catalog as sync
from import_catalog import tokenize,bounds,literal
from import_complete_catalog import compiled_quest_variants,compiled_locations,compiled_ids,source_bytes
from complete_catalog import enrich_locations


class Response:
    def __init__(self,raw,url=collect.ORIGIN+"/quests/9",headers=None):self.raw,self.url,self.headers=raw,url,headers or {}
    def __enter__(self):return self
    def __exit__(self,*args):pass
    def read(self):return self.raw


class SyncTests(unittest.TestCase):
    def setUp(self):
        (ROOT/".work").mkdir(exist_ok=True)
        self.tmp=tempfile.TemporaryDirectory(dir=ROOT/".work");self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)

    def collector(self,**kwargs):
        with mock.patch.object(collect,"urlopen",return_value=Response(b'User-agent: *\nAllow: /\nDisallow: /api/\n')):
            collector=collect.Collector(self.root,**kwargs)
        collector.delay=0
        return collector

    def seed(self,age=0):
        body=b'<html>exact source</html>';now=datetime.now(timezone.utc)-timedelta(hours=age)
        row={"key":9,"url":collect.ORIGIN+"/quests/9","file":"quests/9.html","sha256":hashlib.sha256(body).hexdigest(),"bytes":len(body),"checkedAt":now.isoformat(),"etag":"v1"}
        (self.root/"quests").mkdir();(self.root/"quests/9.html").write_bytes(body)
        collect.save(self.root/".receipts/quests/9.json",row)
        return body,row

    def test_warm_reuse_does_not_extend_freshness_and_tampering_fails(self):
        body,row=self.seed();collector=self.collector()
        with mock.patch.object(collect,"urlopen") as network:
            self.assertEqual(collector.get(9,row["url"],"quests"),body);network.assert_not_called()
        self.assertEqual(collector.rows['9']['checkedAt'],row['checkedAt'])
        (self.root/row['file']).write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,"hash changed"):collector.get(9,row['url'],'quests')

    def test_expired_conditional_304_requires_verified_cached_body(self):
        body,row=self.seed(age=25);collector=self.collector()
        error=HTTPError(row['url'],304,'Not Modified',{'ETag':'v1'},None)
        with mock.patch.object(collect,'urlopen',side_effect=error) as network:
            self.assertEqual(collector.get(9,row['url'],'quests'),body)
            self.assertEqual(network.call_args.args[0].get_header('If-none-match'),'v1')
        self.assertGreater(collector.rows['9']['checkedAt'],row['checkedAt'])

    def test_changed_index_row_refreshes_a_warm_detail(self):
        _,row=self.seed();collector=self.collector(refresh_keys=[9])
        with mock.patch.object(collect,'urlopen',return_value=Response(b'<html>new body</html>')) as network:
            self.assertEqual(collector.get(9,row['url'],'quests'),b'<html>new body</html>');network.assert_called_once()

    def test_interrupted_refresh_does_not_clear_pending_changed_details(self):
        state={'title':'Old','detail':b'old detail'};requests=[]
        def fetch(request,timeout):
            url=request.full_url;requests.append(url)
            if url.endswith('/robots.txt'):return Response(b'User-agent: *\nAllow: /\n',url)
            if '/quests?' in url:
                return Response(('<html><span>1 results</span><a href="/quests/9" data-wowhead="quest=9&amp;domain=forever"><div class="font-semibold">'+state['title']+'</div></a></html>').encode(),url)
            return Response(state['detail'],url)
        def command(mode):
            with mock.patch.object(sys,'argv',['collect','--source-root',str(self.root),'--mode',mode]+(['--refresh'] if mode=='index' else [])),contextlib.redirect_stdout(io.StringIO()):collect.main()
        with mock.patch.object(collect,'urlopen',side_effect=fetch):
            command('index');command('quests')
            state.update(title='New',detail=b'new detail');command('index')
            command('index');requests.clear();command('quests')
        self.assertEqual((self.root/'quests/9.html').read_bytes(),b'new detail')
        self.assertIn(collect.ORIGIN+'/quests/9',requests)
        self.assertEqual(json.loads((self.root/'index-manifest.json').read_bytes())['changedIDs'],[])

    def test_route_key_and_policy_boundaries_fail_without_requests(self):
        collector=self.collector()
        with mock.patch.object(collect,'urlopen') as network:
            for key,url in (('../9',collect.ORIGIN+'/quests/9'),(9,collect.ORIGIN+'/api/quests'),(9,'https://example.com/quests/9')):
                with self.assertRaises(ValueError):collector.get(key,url,'quests')
            network.assert_not_called()

    def test_challenge_and_rate_restrictions_stop_collection(self):
        collector=self.collector()
        with mock.patch.object(collect,'urlopen',return_value=Response(b'Just a moment...')):
            with self.assertRaisesRegex(ValueError,'challenge'):collector.get(9,collect.ORIGIN+'/quests/9','quests')
        self.assertTrue(collector.stop)
        with mock.patch.object(collect,'urlopen') as network:
            with self.assertRaises(RuntimeError):collector.get(10,collect.ORIGIN+'/quests/10','quests')
            network.assert_not_called()

    def test_source_acquirer_rejects_partial_tree_and_wrong_git_blob(self):
        with mock.patch.object(acquire,'fetch',side_effect=[b'[{"name":"child","type":"dir","sha":"x"}]',b'{"truncated":true,"tree":[]}']):
            with self.assertRaisesRegex(ValueError,'Incomplete'):acquire.subtree('parent/child',acquire.PIN)
        with mock.patch.object(acquire,'fetch',return_value=b'wrong bytes'):
            with self.assertRaisesRegex(ValueError,'blob mismatch'):acquire.acquire(self.root,[{'path':'file.lua','sha':'0'*40}])
        self.assertFalse((self.root/'file.lua').exists())

    def test_literal_quest_values_cannot_be_prefixes_of_expressions(self):
        for text in ('q(9,{qgs={11}} and {qgs={22}})','q(9,_.ResolveQuestData({aqd={qgs={11}} and unknown(),hqd={qgs={22}}}))','q(9,_.ResolveQuestData({aqd={qgs={11}},hqd={qgs={22}}}).other)'):
            tokens=tokenize(text);self.assertEqual(compiled_quest_variants(tokens,bounds(tokens),0),[])

    def test_resolver_branch_overrides_and_false_inherits_without_union(self):
        tokens=tokenize('q(9,_.ResolveQuestData({qgs={99},c={4},aqd={qgs={11}},hqd={qgs=false}}))');ends=bounds(tokens)
        result=[(faction,literal(tokens,ends,props['qgs']),literal(tokens,ends,props['c'])) for props,faction in compiled_quest_variants(tokens,ends,0)]
        self.assertEqual(result,[('Alliance',[11],[4]),('Horde',[99],[4])])

    def test_hidden_tracker_calls_with_and_without_metadata_keep_exact_identities(self):
        path='db/Camelot/Categories/HiddenQuestTriggers.lua';raw=b'hqt(9,{qgs={11}});hqt(10)'
        target=self.root/path;target.parent.mkdir(parents=True);target.write_bytes(raw)
        (self.root/'ACQUISITION.json').write_text(json.dumps({'commit':acquire.PIN,'files':[{'path':path,'sha256':hashlib.sha256(raw).hexdigest()}]}))
        compiled=compiled_ids(self.root)
        self.assertEqual(compiled['questIDs'],[9,10]);self.assertEqual(compiled['hiddenTriggerIDs'],[9,10])
        self.assertEqual(compiled['metadata'],[])

    def test_multiple_starters_do_not_receive_unowned_coordinates(self):
        text='q(9,{qgs={11,22},coords={[1411]={{20,30},{40,50}}}})';tokens=tokenize(text);ends=bounds(tokens)
        props,_=compiled_quest_variants(tokens,ends,0)[0]
        locations,diagnostics=compiled_locations(tokens,ends,props,[text])
        self.assertEqual(locations,[{'npcID':11},{'npcID':22}]);self.assertTrue(diagnostics)

    def test_faction_qualification_preserves_names_and_other_faction_starter(self):
        row={'id':9,'locations':[{'npcID':11,'name':'Known'}]}
        enrich_locations(row,{'locations':[{'npcID':11,'faction':'Alliance'},{'npcID':11,'faction':'Horde'}]},[])
        self.assertEqual(row['locations'],[{'npcID':11,'name':'Known','faction':'Alliance'},{'npcID':11,'name':'Known','faction':'Horde'}])
        row={'id':9,'locations':[{'npcID':11,'faction':'Alliance'}]}
        enrich_locations(row,{'locations':[{'npcID':22,'faction':'Horde'}]},[])
        self.assertEqual(len(row['locations']),2)

    def test_staged_apply_rejects_missing_files_or_concurrent_edits(self):
        stage=self.root/'stage';stage.mkdir()
        for name in sync.OUTPUTS:
            target=self.root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b'original')
        baseline={name:sync.sha(self.root/name) for name in sync.OUTPUTS}
        with self.assertRaisesRegex(ValueError,'Missing validated'):sync.apply_candidate(self.root,stage,baseline)
        self.assertTrue(all((self.root/name).read_bytes()==b'original' for name in sync.OUTPUTS))
        (self.root/sync.OUTPUTS[0]).write_bytes(b'concurrent')
        with self.assertRaisesRegex(ValueError,'Concurrent'):sync.apply_candidate(self.root,stage,baseline)

    def test_apply_rolls_back_a_partial_replace(self):
        stage=self.root/'stage';stage.mkdir()
        for name in sync.OUTPUTS:
            for root,raw in ((self.root,b'original'),(stage,b'candidate')):
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        baseline={name:sync.sha(self.root/name) for name in sync.OUTPUTS}
        original=Path.replace;calls=[]
        def replace(path,target):
            calls.append(target)
            if len(calls)==2:raise OSError('simulated apply failure')
            return original(path,target)
        with mock.patch.object(Path,'replace',replace):
            with self.assertRaisesRegex(OSError,'simulated'):sync.apply_candidate(self.root,stage,baseline)
        self.assertTrue(all((self.root/name).read_bytes()==b'original' for name in sync.OUTPUTS))
        self.assertEqual(list(self.root.rglob('*.sync-*')),[])

    def test_receipt_cannot_read_outside_the_acquisition_root(self):
        with self.assertRaisesRegex(ValueError,'outside cache'):source_bytes(self.root,{'file':'../private.html'})


if __name__=='__main__':unittest.main()

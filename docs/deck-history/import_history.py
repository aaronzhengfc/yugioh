#!/usr/bin/env python3
"""Import the sourced event index and available recipes into the bundled database.
Default is validation only; --apply makes a timestamped backup before a transaction.
"""
import argparse, collections, datetime, json, pathlib, shutil, sqlite3
ROOT = pathlib.Path(__file__).resolve().parent
DEFAULT_DB = ROOT.parents[1] / 'yugioh/cards.cdb'

def build(con):
    index = json.loads((ROOT / 'events-index.json').read_text())
    sample = json.loads((ROOT / 'wcs2016-sample.json').read_text())
    samples = {d['id']: d for d in sample['decks']}
    sources = {s['id']: s['url'] for s in sample['sources']}
    intros = json.loads((ROOT / 'sources/strategy-introductions.json').read_text())
    cards = {str(r[0]): r for r in con.execute('SELECT id,cnName,enName,type,cnDesc FROM newpro')}
    metadata = {r[0]: r[1] for r in con.execute("SELECT deckCode,sourceUrl FROM newdeck_metadata WHERE deckFormat='worldchampionship'")}
    events, entries, recipes = [], [], []
    rank_names = {'1st':'冠军','2nd':'亚军','3rd':'季军','4th':'第四名','3-4th':'并列四强'}
    for e in index['events']:
        events.append((e['id'], e['year'], e['status'], e['source_url'], e['verification'] if 'verification' in e else 'official_cancellation'))
        for n, r in enumerate(e['results'], 1):
            did = f"{e['id']}-{n}"
            recipe = []
            status = 'missing'
            recipe_source = ''
            analysis = []
            analysis_kind = 'type_overview'
            intro = intros.get(r.get('strategy_name_source'), '这个类型的具体构筑和打法仍待核对，目前先保留参赛记录。')
            analysis.append({'title':'卡组怎么运作', 'text':intro})
            if n == 1:
                recipe = [(str(cid), int(typ), int(q)) for cid,typ,q in con.execute("SELECT cardId,type,number FROM newdeck WHERE deckFormat='worldchampionship' AND deckCode=? ORDER BY type,cardId", (str(e['year']),))]
                status = 'partial' if e['year'] == 2005 else 'archived'
                recipe_source = metadata.get(str(e['year']), '')
            s = samples.get(r.get('sample_deck_id'))
            if s:
                recipe = [(c['card_password'],t,c['quantity']) for section,t in [('main',0),('side',1),('extra',2)] for c in s['sections'][section]]
                status = 'verified_transcription'
                recipe_source = sources[s['source_ids'][0]]
                a = s['analysis']
                analysis = [{'title':'构筑定位','text':a['overview']}] + [{'title':x['title'],'text':x['text']} for x in a['construction_reasons']] + [{'title':'基本打法','text':a['win_plan']},{'title':'短板与取舍','text':a['limitations']}]
                analysis_kind = 'recipe_editorial'
            elif recipe:
                main = [(cid,q) for cid,t,q in recipe if t == 0]
                counts = collections.Counter()
                for cid,q in main:
                    typ = cards[cid][3] or ''
                    counts['魔法' if 'Spell' in typ else '陷阱' if 'Trap' in typ else '怪兽'] += q
                mix = '、'.join(f'{k} {counts[k]} 张' for k in ['怪兽','魔法','陷阱'])
                repeated = sorted(main,key=lambda x:(-x[1],int(x[0])))[:5]
                names = '、'.join(f'{cards[cid][1] or cards[cid][2]} ×{q}' for cid,q in repeated)
                analysis.append({'title':'这份配方的配比','text':f'主卡共 {sum(q for _,q in main)} 张：{mix}。投入较多的卡包括：{names}。多份投入提高抽到这些卡的机会，也占用了其他备选卡的位置；具体选择原因未找到选手自述。'})
                analysis_kind = 'recipe_observation'
            if status == 'missing':
                analysis.append({'title':'选手配方待补充','text':'已收录名次与卡组类型，尚未完成这位选手的卡牌清单核对。上方为类型层面的玩法介绍，不能据此推断他使用了哪些卡或投入数量。'})
            if status == 'partial':
                analysis.append({'title':'配方缺项','text':'现有 2005 年冠军档案未收录副卡组；这里的副卡数量不代表选手没有使用副卡。'})
            for order,(cid,typ,q) in enumerate(recipe):
                assert cid in cards, (did,cid)
                assert typ in (0,1,2) and q > 0
                recipes.append((did,cid,typ,q,order))
            entries.append((did,e['id'],n,r['placement'],rank_names[r['placement']],r['player'],r.get('country_region_zh') or r.get('country_region_source') or '地区待考证',r.get('strategy_name_zh') or '卡组类型待考证',r.get('strategy_name_source') or '',status,recipe_source,analysis_kind,json.dumps(analysis,ensure_ascii=False)))
    assert len(events)==24 and len(entries)==83
    assert len({x[0] for x in recipes})==23
    return events,entries,recipes

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--apply',action='store_true'); ap.add_argument('--database',type=pathlib.Path,default=DEFAULT_DB); args=ap.parse_args()
    con=sqlite3.connect(args.database.as_uri()+'?mode=ro',uri=True)
    events,entries,recipes=build(con); con.close()
    if args.apply:
        backup=pathlib.Path('/tmp') / ('yugioh-before-history-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'.cdb')
        shutil.copy2(args.database,backup)
        con=sqlite3.connect(args.database)
        with con:
            con.execute('CREATE TABLE IF NOT EXISTS history_event (id TEXT PRIMARY KEY, year INTEGER NOT NULL UNIQUE, status TEXT NOT NULL, sourceUrl TEXT NOT NULL, verification TEXT NOT NULL)')
            con.execute('CREATE TABLE IF NOT EXISTS history_deck (id TEXT PRIMARY KEY,eventId TEXT NOT NULL,sortOrder INTEGER NOT NULL,placement TEXT NOT NULL,placementLabel TEXT NOT NULL,player TEXT NOT NULL,region TEXT NOT NULL,strategy TEXT NOT NULL,strategyOriginal TEXT NOT NULL,recipeStatus TEXT NOT NULL,recipeSourceUrl TEXT NOT NULL,analysisKind TEXT NOT NULL,analysisJson TEXT NOT NULL)')
            con.execute('CREATE TABLE IF NOT EXISTS history_card (deckId TEXT NOT NULL,cardId TEXT NOT NULL,section INTEGER NOT NULL,quantity INTEGER NOT NULL,sortOrder INTEGER NOT NULL,PRIMARY KEY(deckId,cardId,section))')
            # Only replace this curated dataset, preserving unrelated tables and future event sets.
            for eid,*_ in events:
                con.execute('DELETE FROM history_card WHERE deckId IN (SELECT id FROM history_deck WHERE eventId=?)',(eid,))
                con.execute('DELETE FROM history_deck WHERE eventId=?',(eid,))
            con.executemany('INSERT OR REPLACE INTO history_event VALUES (?,?,?,?,?)',events)
            con.executemany('INSERT INTO history_deck VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',entries)
            con.executemany('INSERT INTO history_card VALUES (?,?,?,?,?)',recipes)
        assert con.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
        con.close(); print('Backup:',backup)
    print(json.dumps({'events':len(events),'entries':len(entries),'recipes':len({x[0] for x in recipes}),'card_rows':len(recipes),'missing_recipes':sum(x[9]=='missing' for x in entries)},ensure_ascii=False))
if __name__=='__main__': main()

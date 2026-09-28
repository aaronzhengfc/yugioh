#!/usr/bin/env python3
"""Build a read-only historical deck sample from transcribed source quantities."""
import collections
import hashlib
import json
import pathlib
import sqlite3

ROOT = pathlib.Path(__file__).resolve().parent
DB = ROOT.parents[1] / 'yugioh/cards.cdb'
PREFERRED_LOCAL_IDS = {'Cyber Dragon Infinity': 10443957,
                       'Ghost Reaper & Winter Cherries': 62015408,
                       'Odd-Eyes Pendulum Dragon': 16178681}

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def main():
    before = hashlib.sha256(DB.read_bytes()).hexdigest()
    con = sqlite3.connect(DB.as_uri() + '?mode=ro', uri=True)
    con.row_factory = sqlite3.Row
    by_name = collections.defaultdict(list)
    for row in con.execute('SELECT id,enName,cnName,miscInfo FROM newpro'):
        by_name[row['enName']].append(dict(row))
    raw = json.loads((ROOT / 'sources/wcs2016-podium.json').read_text())
    editorial = json.loads((ROOT / 'sources/wcs2016-analysis.json').read_text())
    people = [('Hiyama Shunsuke', '檜山俊輔', '日本', 'blue-eyes', '青眼'),
              ('Erik Godwin Christensen', None, '美国', 'blue-eyes', '青眼'),
              ('Kajihara Soichiro', '梶原壮一朗', '日本', 'majespecter', '威风妖怪')]
    cards, decks, sources = {}, [], []
    for source, person in zip(raw, people):
        rank = source['rank']
        sid = f'neuron-wcs2016-{rank}'
        sources.append({'id': sid, 'url': source['url'], 'retrieved_at': source['retrieved_at'],
                        'kind': 'official_database_deck_page',
                        'locator': 'WCS2016 一般の部; overview Main / Extra / Side tables',
                        'notes': '页面当前禁限提示不是2016年的规则；只提取原配方卡名和数量。'})
        deck = {'id': f'wcs2016-{rank}', 'event_id': 'wcs2016', 'placement': str(rank),
                'player': {'name': person[0], 'name_ja': person[1], 'country_region_zh': person[2]},
                'strategy_id': person[3], 'strategy_name_zh': person[4],
                'sections': {}, 'counts': source['counts'], 'source_ids': [sid],
                'recipe_status': 'complete_source_transcription',
                'historical_legality_status': 'not_independently_checked',
                'analysis': editorial[str(rank)]}
        for section, entries in source['sections'].items():
            output = []
            for item in entries:
                matches = by_name[item['name_en']]
                method = 'exact_unique_enName_in_local_newpro'
                if len(matches) != 1:
                    cids = {m.get('konami_id') for row in matches for m in json.loads(row['miscInfo'] or '[]')}
                    preferred = PREFERRED_LOCAL_IDS.get(item['name_en'])
                    if not matches or len(cids) != 1 or None in cids or preferred not in {r['id'] for r in matches}:
                        raise ValueError(f"Ambiguous/missing exact name: {item['name_en']}")
                    row = next(r for r in matches if r['id'] == preferred)
                    method = 'explicit_local_id_selection_same_name_and_konami_id'
                else:
                    row = matches[0]
                password = str(row['id'])
                cid = next((m.get('konami_id') for m in json.loads(row['miscInfo'] or '[]') if m.get('konami_id')), None)
                cards[password] = {'password': password, 'name_en': row['enName'], 'name_zh': row['cnName'],
                                   'konami_id': cid, 'name_zh_source': 'local_newpro',
                                   'alternate_local_ids': [str(r['id']) for r in matches if r['id'] != row['id']],
                                   'official_card_url': (f'https://www.db.yugioh-card.com/yugiohdb/card_search.action?ope=2&cid={cid}&request_locale=ja' if cid else None)}
                output.append({'card_password': password, 'quantity': item['quantity'],
                               'source_name_en': item['name_en'], 'mapping_method': method})
            assert sum(x['quantity'] for x in output) == source['counts'][section]
            deck['sections'][section] = output
        decks.append(deck)
        lines = [f'# Derived from KONAMI WCS2016 place {rank}; canonical local passwords', '#main']
        for section, marker in [('main', None), ('extra', '#extra'), ('side', '!side')]:
            if marker: lines.append(marker)
            for item in deck['sections'][section]: lines.extend([item['card_password']] * item['quantity'])
        out = ROOT / 'ydk' / f'wcs2016-{rank}.ydk'
        out.parent.mkdir(exist_ok=True)
        out.write_text('\n'.join(lines) + '\n')
        deck['ydk'] = {'path': f'ydk/{out.name}', 'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
                       'kind': 'generated_from_transcription_not_original_download'}
    differences = []
    for section in ['main', 'extra', 'side']:
        a, b = [{x['card_password']: x['quantity'] for x in d['sections'][section]} for d in decks[:2]]
        for password in sorted(a.keys() | b.keys(), key=int):
            if a.get(password, 0) != b.get(password, 0):
                differences.append({'section': section, 'card_password': password,
                                    'champion_count': a.get(password, 0), 'runner_up_count': b.get(password, 0)})
    event = {'id': 'wcs2016', 'name': 'Yu-Gi-Oh! World Championship 2016', 'year': 2016,
             'format': 'WCS', 'division': '一般组／实体卡',
             'rules_status': 'event_specific_rules_not_fully_archived',
             'rules_note': '世界赛历史配方；不等同于当年的普通OCG环境，也不代表现在合法。',
             'source_url': 'https://roadoftheking.com/yu-gi-oh-world-championship-2016/'}
    data = {'schema_version': 'historical-deck-sample-1', 'collected_at': '2026-09-28', 'generated_at': '2026-09-29',
            'scope': '2016世界赛冠亚季军完整配方及编辑分析样例；不是历年卡组全集。',
            'events': [event], 'sources': sources, 'cards': list(cards.values()), 'decks': decks,
            'comparisons': [{'deck_ids': ['wcs2016-1', 'wcs2016-2'], 'differences': differences}]}
    save(ROOT / 'wcs2016-sample.json', data)
    # Match the already-imported champion against the new primary-source transcription.
    prior = collections.Counter()
    for cid, kind, n in con.execute("SELECT cardId,type,number FROM newdeck WHERE deckFormat='worldchampionship' AND deckCode='2016'"):
        prior[({'0': 'main', '1': 'side', '2': 'extra'}[str(kind)], str(cid))] += int(n)
    current = collections.Counter({(section, item['card_password']): item['quantity']
                                   for section, entries in decks[0]['sections'].items() for item in entries})
    con.close()
    assert hashlib.sha256(DB.read_bytes()).hexdigest() == before, 'Database was modified'
    report = {'checked_at': '2026-09-29', 'deck_counts': [d['counts'] for d in decks],
              'unique_cards': len(cards), 'unresolved_cards': [],
              'quantities_preserved': True, 'database_unchanged': True,
              'champion_matches_existing_database': prior == current,
              'champion_differences': [{'section': k[0], 'card_password': k[1], 'existing': prior[k], 'official_source': current[k]}
                                       for k in sorted(prior.keys() | current.keys()) if prior[k] != current[k]],
              'limits': ['逐项名称、数量及本地映射核对；未独立审计2016禁限表。', '玩法解释是编辑分析，未标记为选手原话或实战测试。']}
    save(ROOT / 'validation.json', report)
    render(data)
    print(json.dumps(report, ensure_ascii=False))

def render(data):
    cards = {c['password']: c for c in data['cards']}
    def name(password):
        c = cards[password]
        return c['name_zh'] or c['name_en']
    lines = ['# 2016 世界赛：同样是青眼，为什么组得不一样？', '',
             '这是一份可用于 App 内容的实际样例：三份官方数据库配方，加上独立标注的编辑分析。', '',
             '**环境：2016 世界赛一般组／实体卡。以下不是当前推荐配方，也不是普通 OCG 禁限表下的配方。**', '',
             '| 名次 | 选手 | 卡组 | 主卡／额外／副卡 |', '|---|---|---|---|']
    for d in data['decks']:
        lines.append(f"| {d['placement']} | {d['player']['name_ja'] or d['player']['name']} | {d['strategy_name_zh']} | {d['counts']['main']}／{d['counts']['extra']}／{d['counts']['side']} |")
    for d in data['decks']:
        a = d['analysis']
        lines += ['', f"## 第 {d['placement']} 名 · {d['strategy_name_zh']}", '', a['overview'], '', '**为什么这样组（编辑分析）**', '']
        for reason in a['construction_reasons']:
            lines += [f"- **{reason['title']}**：{reason['text']}"]
        lines += ['', '**怎么赢**：' + a['win_plan'], '', '**需要注意**：' + a['limitations'], '',
                  f"[原始配方]({data['sources'][int(d['placement'])-1]['url']}) · [下载 YDK]({d['ydk']['path']})", '',
                  '<details><summary>查看完整配方</summary>', '']
        for section, label in [('main', '主卡组'), ('extra', '额外卡组'), ('side', '副卡组')]:
            lines += [f"### {label} · {d['counts'][section]} 张", '', '| 卡牌 | 数量 |', '|---|---:|']
            for item in d['sections'][section]:
                lines.append(f"| {name(item['card_password'])} | {item['quantity']} |")
            lines.append('')
        lines += ['</details>', '']
    lines += ['## 冠亚军的实际用卡差异', '', '数量来自配方，搭配解释见上方。不同组法的名次不能直接证明哪张卡更强。', '', '| 位置 | 卡牌 | 冠军 | 亚军 |', '|---|---|---:|---:|']
    for diff in data['comparisons'][0]['differences']:
        lines.append(f"| {dict(main='主卡',extra='额外',side='副卡')[diff['section']]} | {name(diff['card_password'])} | {diff['champion_count']} | {diff['runner_up_count']} |")
    lines += ['', '## 数据边界', '',
              '- 三份配方的卡名和数量来自官方数据库页面；页面上当前的禁限提示没有用来删改历史配方。',
              '- 中文卡名沿用 App 的数据库。YDK 由核对后的配方生成；不是选手上传的原始文件。',
              '- 玩法说明是结合配方与效果做的编辑分析，尚未收录选手亲述，也未完成历史裁定审计。',
              '- 历年赛事来源见 events-index.json；配方收录状态分别记录，不能把找到比赛成绩等同于找到完整卡组。', '']
    (ROOT / 'SAMPLE.md').write_text('\n'.join(lines))

if __name__ == '__main__': main()

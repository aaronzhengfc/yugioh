#!/usr/bin/env python3
"""Verify the persisted app dataset against the reproducible importer inputs."""
import sqlite3
from import_history import DEFAULT_DB, build

def main():
    con = sqlite3.connect(DEFAULT_DB.as_uri() + '?mode=ro', uri=True)
    events, decks, cards = build(con)
    for table, expected in [('history_event', events), ('history_deck', decks), ('history_card', cards)]:
        actual = con.execute('SELECT * FROM ' + table).fetchall()
        assert set(actual) == set(expected), table
    assert con.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert not con.execute('SELECT h.cardId FROM history_card h LEFT JOIN newpro p ON h.cardId=p.id WHERE p.id IS NULL').fetchall()
    assert not con.execute("SELECT d.id FROM history_deck d JOIN history_card c ON c.deckId=d.id WHERE recipeStatus='missing'").fetchall()
    assert con.execute("SELECT year FROM history_event WHERE status='not_held' ORDER BY year").fetchall() == [(2020,), (2021,), (2022,)]
    assert not con.execute("SELECT id FROM history_deck WHERE region IN ('Taiwan','Chinese Taipei','中华台北')").fetchall()
    for rank, counts in [(1, {0:42, 1:15, 2:15}), (2, {0:40, 1:15, 2:15}), (3, {0:41, 1:15, 2:15})]:
        assert dict(con.execute('SELECT section,SUM(quantity) FROM history_card WHERE deckId=? GROUP BY section', (f'wcs2016-{rank}',))) == counts
    print('PASS: persisted data matches sources; all card IDs resolve; counts, omissions, cancellation years and region names verified.')

if __name__ == '__main__': main()

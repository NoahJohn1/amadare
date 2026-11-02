import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const context = {};
vm.runInNewContext(readFileSync(new URL('../../QuickActions/lookup-search.js', import.meta.url), 'utf8'), context);
const { matchNotes } = context;

const notes = [
  { noteId: 1, texts: ['日記', 'diary', 'にっき'] },
  { noteId: 2, texts: ['天気', 'weather', 'てんき'] },
];
const fieldTexts = n => n.texts;
const ids = q => Array.from(matchNotes(notes, q, fieldTexts), n => n.noteId);

test('an empty query returns every note', () => assert.deepEqual(ids(''), [1, 2]));
test('matches Japanese in any field', () => assert.deepEqual(ids('てん'), [2]));
test('matches English regardless of case', () => assert.deepEqual(ids('DIA'), [1]));
test('matches the middle of a field', () => assert.deepEqual(ids('eat'), [2]));
test('returns nothing when nothing matches', () => assert.deepEqual(ids('猫'), []));

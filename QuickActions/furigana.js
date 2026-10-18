// Source: Amadare repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Furigana in Anki's format ("未[み]来[らい] 食[た]べ 物[もの]", shown with {{furigana:Furigana}}), built from a word and its kana reading.
// The reading is lined up against the kana in the word, then each kanji run is split so every kanji gets its own
// reading, using the kanji reading list (kanji-readings.txt, from KANJIDIC2). Runs that can't be split that way
// (今日[きょう], 大人[おとな]) keep one reading over the run; if the kana don't line up, the whole word gets the reading.
// Shared by add-to-anki.js and lookup.html; plain text in, plain text out. Call setKanjiReadings() first.
// Amadare's Sources/AmadareCore/Furigana.swift does the same; keep the two in step.

const KANJI_RUN = /[㐀-䶿一-鿿豈-﫿々〆ヵヶ]+/g;
let kanjiReadings = {};

// Takes the contents of kanji-readings.txt.
function setKanjiReadings(text) {
  kanjiReadings = {};
  for (const line of text.split('\n')) {
    if (!line || line[0] === '#') continue;
    const [kanji, ...readings] = line.split(' ');
    kanjiReadings[kanji] = readings;
  }
}

function toHiragana(s) {
  return s.replace(/[ァ-ヶ]/g, c => String.fromCharCode(c.charCodeAt(0) - 0x60));
}

const VOICED = { か: 'が', き: 'ぎ', く: 'ぐ', け: 'げ', こ: 'ご', さ: 'ざ', し: 'じ', す: 'ず', せ: 'ぜ', そ: 'ぞ',
  た: 'だ', ち: 'ぢじ', つ: 'づず', て: 'で', と: 'ど', は: 'ばぱ', ひ: 'びぴ', ふ: 'ぶぷ', へ: 'べぺ', ほ: 'ぼぽ' };

// The ways a kanji's reading can be written inside a compound: as is, voiced when it isn't first (時々 → ときどき),
// or ending in っ before another kanji (学校 → がっこう).
function readingForms(reading, first, last) {
  const forms = [reading];
  if (!first) for (const v of VOICED[reading[0]] || '') forms.push(v + reading.slice(1));
  if (!last) for (const f of forms.slice()) if (/[つくちき]$/.test(f) && f.length > 1) forms.push(f.slice(0, -1) + 'っ');
  return forms;
}

// One reading per kanji, or null if the run's reading can't be split exactly.
function splitRun(run, reading) {
  const chars = [...run];
  const pieces = [];
  const walk = (i, at) => {
    if (i === chars.length) return at === reading.length;
    const kanji = chars[i] === '々' && i > 0 ? chars[i - 1] : chars[i];
    for (const r of kanjiReadings[kanji] || []) {
      for (const form of readingForms(r, i === 0, i === chars.length - 1)) {
        if (!reading.startsWith(form, at)) continue;
        pieces[i] = form;
        if (walk(i + 1, at + form.length)) return true;
      }
    }
    return false;
  };
  return chars.length > 1 && walk(0, 0) ? chars.map((c, i) => c + '[' + pieces[i] + ']').join('') : null;
}

function furigana(word, reading) {
  word = word.trim();
  // Only the first reading if several are listed ("にっき, にき").
  reading = toHiragana(reading.split(/[,、;；/／]/)[0].replace(/\s+/g, ''));
  if (!word || !reading) return '';
  const parts = [];
  let last = 0;
  word.replace(KANJI_RUN, (run, at) => {
    if (at > last) parts.push({ kana: word.slice(last, at) });
    parts.push({ kanji: run });
    last = at + run.length;
  });
  if (last < word.length) parts.push({ kana: word.slice(last) });
  if (!parts.some(p => p.kanji)) return word;

  const escape = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = parts.map(p => p.kanji ? '(.+?)' : escape(toHiragana(p.kana).replace(/\s+/g, ''))).join('');
  const m = reading.match(new RegExp('^' + pattern + '$'));
  if (!m) return word + '[' + reading + ']';
  let i = 1;
  // A space before each kanji run (except at the start) marks where its base text begins; Anki hides it.
  return parts.map((p, n) => {
    if (!p.kanji) return p.kana;
    const r = m[i++];
    return (n ? ' ' : '') + (splitRun(p.kanji, r) || p.kanji + '[' + r + ']');
  }).join('');
}

// Anki furigana text → <ruby> HTML for display. Expects plain text (escape it first if it may contain markup).
function furiganaToRuby(text) {
  return text.replace(/ ?([^\s\[\]]+?)\[([^\]]*)\]/g, '<ruby>$1<rt>$2</rt></ruby>');
}

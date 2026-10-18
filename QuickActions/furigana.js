// Source: Ankani repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Furigana in Anki's format ("食[た]べ 物[もの]", shown with {{furigana:Furigana}}), built from a word and its kana reading.
// The reading is lined up against the kana in the word, so each kanji run gets its own reading;
// consecutive kanji share one reading (未来[みらい]). If they can't be lined up, the whole word gets the reading.
// Shared by add-to-anki.js and lookup.html; plain text in, plain text out.

const KANJI_RUN = /[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff々〆ヵヶ]+/g;

function toHiragana(s) {
  return s.replace(/[\u30a1-\u30f6]/g, c => String.fromCharCode(c.charCodeAt(0) - 0x60));
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
  return parts.map((p, n) => p.kanji ? (n ? ' ' : '') + p.kanji + '[' + m[i++] + ']' : p.kana).join('');
}

// Anki furigana text → <ruby> HTML for display. Expects plain text (escape it first if it may contain markup).
function furiganaToRuby(text) {
  return text.replace(/ ?([^\s\[\]]+)\[([^\]]*)\]/g, '<ruby>$1<rt>$2</rt></ruby>');
}

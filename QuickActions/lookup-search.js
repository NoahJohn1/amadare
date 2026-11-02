// Source: Amadare repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Searches the local snapshot of notes. Used by lookup.html; kept apart from the page so it can be tested.

// The notes with a field containing the query, ignoring case. fieldTexts(note) gives its fields as lowercase plain text.
function matchNotes(notes, query, fieldTexts) {
  const q = query.toLowerCase();
  if (!q) return notes;
  return notes.filter(n => fieldTexts(n).some(text => text.includes(q)));
}

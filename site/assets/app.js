'use strict';
(() => {
  const search = document.querySelector('#help-search');
  if (!search) return;
  const kind = document.querySelector('#help-kind');
  const cards = [...document.querySelectorAll('.help-card')];
  const count = document.querySelector('#help-count');
  const empty = document.querySelector('#help-empty');
  function filter() {
    const raw = search.value.trim().toLocaleLowerCase();
    const query = raw.replace(/^(source|target)_/, '');
    let shown = 0;
    for (const card of cards) {
      const text = card.textContent.toLocaleLowerCase();
      const matches = (!raw || text.includes(raw) || (card.dataset.kind === 'message' && card.dataset.code === query)) && (kind.value === 'all' || kind.value === card.dataset.kind);
      card.hidden = !matches;
      if (matches) shown += 1;
    }
    count.textContent = `${shown} ${shown === 1 ? 'entry' : 'entries'}`;
    empty.hidden = shown > 0;
  }
  search.addEventListener('input', filter);
  kind.addEventListener('change', filter);
  document.querySelector('#help-clear').addEventListener('click', () => {
    search.value = ''; kind.value = 'all'; filter(); search.focus();
  });
  filter();
})();

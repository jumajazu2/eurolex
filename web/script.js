// --- Account/Passkey Panel Logic ---
const openAccountPanelBtn = document.getElementById('openAccountPanel');
const accountPanel = document.getElementById('accountPanel');
const closeAccountPanelBtn = document.getElementById('closeAccountPanel');
const accountForm = document.getElementById('accountForm');
const accountEmailInput = document.getElementById('accountEmail');
const accountPasskeyInput = document.getElementById('accountPasskey');
const accountStatusBar = document.getElementById('accountStatusBar');
const accountStatusText = document.getElementById('accountStatusText');

function showAccountPanel() {
  accountPanel.style.display = 'block';
  if (openAccountPanelBtn) openAccountPanelBtn.style.display = 'none';
  // Pre-fill fields from localStorage
  accountEmailInput.value = localStorage.getItem('lt_email') || '';
  accountPasskeyInput.value = localStorage.getItem('lt_passkey') || '';
}
function hideAccountPanel() {
  accountPanel.style.display = 'none';
  updateAccountStatusBar();
}
if (openAccountPanelBtn) openAccountPanelBtn.addEventListener('click', showAccountPanel);
if (closeAccountPanelBtn) closeAccountPanelBtn.addEventListener('click', hideAccountPanel);

function updateAccountStatusBar() {
  const email = localStorage.getItem('lt_email');
  const passkey = localStorage.getItem('lt_passkey');
  if (email && passkey) {
    accountStatusBar.style.display = 'flex';
    if (openAccountPanelBtn) openAccountPanelBtn.style.display = 'none';
    accountStatusText.textContent = `Signed in as ${email}`;
  } else {
    accountStatusBar.style.display = 'none';
    if (openAccountPanelBtn) openAccountPanelBtn.style.display = 'flex';
  }
}

// Load from localStorage on page load
document.addEventListener('DOMContentLoaded', () => {
  updateAccountStatusBar();
});

// Save on submit
if (accountForm) {
  accountForm.addEventListener('submit', function(e) {
    e.preventDefault();
    const email = accountEmailInput.value.trim();
    const passkey = accountPasskeyInput.value.trim();
    if (email && passkey) {
      localStorage.setItem('lt_email', email);
      localStorage.setItem('lt_passkey', passkey);
      apiKey = passkey;
      hideAccountPanel();
    }
  });
}
/* LegisTracerEU Website Functionality */

// OpenSearch configuration
const OPENSEARCH_URL = 'https://search.pts-translation.sk';
const DEFAULT_INDEX = '_all';
let apiKey = 'trial';
let userIP = 'N/A';
let userFingerprint = 'N/A';
let searchCount = 0;

// Newsletter config (email destination and optional backend endpoint)
const NEWSLETTER_TO = 'juraj.kuban.sk@gmail.com';
// If you add a serverless endpoint (e.g., Formspree/Netlify Function), set it here.
// Example: const NEWSLETTER_ENDPOINT = 'https://formspree.io/f/xxxxxx';
const NEWSLETTER_ENDPOINT = '';

document.addEventListener('DOMContentLoaded', () => {
  const yearEl = document.getElementById('year');
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // Initialize user info
  initializeUserInfo();

  // Mobile nav toggle
  const navToggle = document.getElementById('navToggle');
  const navMenu = document.getElementById('navMenu');
  if (navToggle && navMenu) {
    navToggle.addEventListener('click', () => {
      const expanded = navToggle.getAttribute('aria-expanded') === 'true';
      navToggle.setAttribute('aria-expanded', String(!expanded));
    });
  }

  // Search hint pills (hero section)
  document.querySelectorAll('.hint-pill').forEach(pill => {
    pill.addEventListener('click', () => {
      const q = pill.getAttribute('data-query');
      const input = document.getElementById('heroSearch');
      if (input && q) {
        input.value = q;
        input.focus();
      }
    });
  });

  // Hero search form
  const heroForm = document.getElementById('heroSearchForm');
  if (heroForm) {
    heroForm.addEventListener('submit', e => {
      e.preventDefault();
      const query = new FormData(heroForm).get('q')?.toString().trim();
      if (!query) return;
      
      // Redirect to search page with query
      window.location.href = `search.html?q=${encodeURIComponent(query)}`;
    });
  }

  // Demo search functionality
  setupDemoSearch();

  // Handle URL search parameter for search page
  handleURLSearchParam();

  // Newsletter form
  const newsletterForm = document.getElementById('newsletterForm');
  if (newsletterForm) {
    newsletterForm.addEventListener('submit', async e => {
      e.preventDefault();
      const email = newsletterForm.querySelector('input[type="email"]')?.value;
      if (!email) return;
      try {
        const subject = 'Newsletter signup for LegisTracerEU';
        const body = `Please add me to the newsletter.\n\nEmail: ${email}`;

        // Always open the user's email client with a prefilled message
        window.location.href = `mailto:${encodeURIComponent(NEWSLETTER_TO)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;

        // If an endpoint is configured, also submit in the background without blocking or alerting
        if (NEWSLETTER_ENDPOINT) {
          try {
            fetch(NEWSLETTER_ENDPOINT, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ email }),
              keepalive: true
            });
          } catch (bgErr) {
            console.warn('Background newsletter submission failed:', bgErr);
          }
        }
      } catch (err) {
        alert('Could not submit your request. Please try again later.');
        console.error('Newsletter submission failed:', err);
      } finally {
        newsletterForm.reset();
      }
    });
  }

  // Cookie notice functionality
  initializeCookieNotice();

  // Handle direct links to FAQ items
  handleFAQLinks();
});

function setupDemoSearch() {
  const demoInput = document.getElementById('demoSearch');
  const resultsDiv = document.getElementById('results');
  const quotaInfoDiv = document.getElementById('quotaInfo');

  if (!demoInput || !resultsDiv || !quotaInfoDiv) return;

  // Search button event listeners
  const searchBtn1 = document.getElementById('searchBtn1');
  const searchBtn2 = document.getElementById('searchBtn2');
  const searchBtn3 = document.getElementById('searchBtn3');
  const clearBtn = document.getElementById('clearBtn');

  if (searchBtn1) searchBtn1.addEventListener('click', () => doSearch("phraseBoost"));
  if (searchBtn2) searchBtn2.addEventListener('click', () => doSearch("multiFuzzy"));
  if (searchBtn3) searchBtn3.addEventListener('click', () => doSearch("combined"));
  if (clearBtn) {
    clearBtn.addEventListener('click', () => {
      demoInput.value = '';
      resultsDiv.innerHTML = '';
      updateQuotaDisplay();
    });
  }

  // Enter key search
  demoInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') doSearch("phraseBoost");
  });

  updateQuotaDisplay();
}

async function doSearch(mode) {
  const demoInput = document.getElementById('demoSearch');
  const resultsDiv = document.getElementById('results');
  
  if (!demoInput || !resultsDiv) return;

  // Check if email is set, if not prompt user for trial access
  let localEmail = localStorage.getItem('lt_email');
  if (!localEmail || !localEmail.trim() || !localEmail.includes('@')) {
    localEmail = prompt('Please enter your email address to use the trial search (7 searches per day):');
    if (!localEmail || !localEmail.trim() || !localEmail.includes('@')) {
      resultsDiv.innerHTML = '<div class="search-error">Valid email address is required for trial access.</div>';
      return;
    }
    // Save email and set trial passkey
    localStorage.setItem('lt_email', localEmail.trim());
    localStorage.setItem('lt_passkey', 'trial');
    updateAccountStatusBar();
  }

  const q = demoInput.value.trim();

  // Prepare client context
  const clientContext = {
    ip: userIP,
    fingerprint: userFingerprint,
    timestamp: new Date().toISOString(),
  };

  if (q) {
    searchCount++;
    updateQuotaDisplay();
  }

  // Get selected source and target languages from dropdowns
  const sourceLang = document.getElementById('sourceLang')?.value || 'en';
  const targetLang = document.getElementById('targetLang')?.value || 'sk';

  // Compose field names
  const sourceField = sourceLang + '_text';
  const targetField = targetLang + '_text';

  let body;
  if (!q) {
    body = { size: 50, query: { match_all: {} } };
  } else if (mode === "phraseBoost") {
    body = {
      query: {
        bool: {
          must: [
            { match_phrase: { [sourceField]: { query: q, slop: 2, boost: 1.5 } } },
            { term: { paragraphsNotMatched: false } }
          ]
        }
      },
      size: 50
    };
  } else if (mode === "multiFuzzy") {
    body = {
      query: {
        bool: {
          must: [
            {
              multi_match: {
                query: q,
                fields: [sourceField, targetField],
                fuzziness: 1,
                minimum_should_match: "80%"
              }
            },
            { term: { paragraphsNotMatched: false } }
          ]
        }
      },
      size: 50
    };
  } else if (mode === "combined") {
    body = {
      query: {
        bool: {
          should: [
            { match_phrase: { [sourceField]: { query: q, slop: 2, boost: 3.0 } } },
            { match: { [sourceField]: { query: q, fuzziness: 1, operator: "and", boost: 1.0 } } },
            { match_phrase: { [targetField]: { query: q, slop: 2, boost: 3.0 } } },
            { match: { [targetField]: { query: q, fuzziness: 1, operator: "and", boost: 1.0 } } }
          ],
          minimum_should_match: 1
        }
      },
      size: 25
    };
  }

  // Add deduplication if checked
  const deduplicate = document.getElementById('deduplicateToggle')?.checked;
  if (deduplicate && q) {
    body.collapse = { "field": "dir_id.keyword" };
  }

  resultsDiv.innerHTML = '<p class="search-loading">Searching EU legislation...</p>';

  try {
    // Always get latest passkey from localStorage for x-api-key
    let localPasskey = localStorage.getItem('lt_passkey');
    if (!localPasskey || !localPasskey.trim()) localPasskey = 'trial';
    const localEmail = localStorage.getItem('lt_email');
    // Use wildcard for all indices
    const indexPattern = '*';
    const url = `${OPENSEARCH_URL}/${indexPattern}/_search`;
    const headers = {
      'Content-Type': 'application/json',
      'x-client-context': JSON.stringify(clientContext),
      'x-api-key': localPasskey,
      'x-email': localEmail || ''
    };
    const resp = await fetch(url, { 
      method: 'POST', 
      headers, 
      body: JSON.stringify(body) 
    });

    if (resp.status === 429) {
      const errorData = await resp.json();
      showQuotaExceeded(errorData.error);
      return;
    }

    if (!resp.ok) {
      throw new Error(`HTTP error! status: ${resp.status}`);
    }

    const data = await resp.json();
    renderResults(data, q);
  } catch (err) {
    resultsDiv.innerHTML = `<div class="search-error">Error: ${escapeHtml(String(err))}</div>`;
  }
}

function renderResults(data, query) {
  const resultsDiv = document.getElementById('results');
  if (!resultsDiv) return;

  const hits = (data.hits?.hits || []).filter(h => {
    const src = h._source || {};
    if (src.class === "NotMatch") return false;
    if (src.paragraphsNotMatched !== false) return false;
    return true;
  });

  if (hits.length === 0) {
    resultsDiv.innerHTML = '<p class="no-results">No results found</p>';
    return;
  }

  // Get selected source and target languages from dropdowns
  const sourceLang = document.getElementById('sourceLang')?.value || 'en';
  const targetLang = document.getElementById('targetLang')?.value || 'sk';

  const fieldMap = {
    [sourceLang + '_text']: sourceLang === 'en' ? 'English' : (sourceLang === 'sk' ? 'Slovak' : sourceLang),
    [targetLang + '_text']: targetLang === 'en' ? 'English' : (targetLang === 'sk' ? 'Slovak' : targetLang),
    "celex": "EUR-lex URL"
  };

  const fields = Object.keys(fieldMap);
  const headers = Object.values(fieldMap);

  let html = '<div class="results-table"><table><thead><tr>' + 
    headers.map((h, i) => {
      if (i === 0 || i === 1) return `<th style="min-width:340px;max-width:900px;">${h}</th>`;
      if (i === 2) return `<th style="min-width:80px;max-width:120px;">${h}</th>`;
      return `<th>${h}</th>`;
    }).join('') + 
    '</tr></thead><tbody>';

  for (const h of hits) {
    const src = h._source || {};
    html += '<tr>' + fields.map(f => {
      if (f === "celex") {
        const val = String(src[f] || '').trim();
        if (!val) return '<td></td>';
        const uriParam = val.match(/^CELEX:/i) ? val : 'CELEX:' + val;
        const url = 'https://eur-lex.europa.eu/legal-content/' + encodeURIComponent(sourceLang) + '-' + encodeURIComponent(targetLang) + '/TXT/?fromTab=ALL&from=SK&uri=' + 
          encodeURIComponent(uriParam);
        const display = val.replace(/^CELEX:/i, '');
        return `<td><a href="${url}" target="_blank" rel="noopener noreferrer">${escapeHtml(display)}</a></td>`;
      }

      const cellText = pretty(src[f]);
      const shouldHighlight = document.getElementById('highlightToggle')?.checked;
      return `<td>${shouldHighlight ? highlight(cellText, query) : escapeHtml(cellText)}</td>`;
    }).join('') + '</tr>';
  }

  html += '</tbody></table></div>';
  resultsDiv.innerHTML = html;
}

function showQuotaExceeded(errorMessage) {
  const resultsDiv = document.getElementById('results');
  if (!resultsDiv) return;

  const quotaHtml = `
    <div class="quota-exceeded">
      <h3>Daily Limit Reached</h3>
      <p>${escapeHtml(errorMessage)}</p>
      <p>To continue searching and access advanced features:</p>
      <div class="quota-actions">
        <a href="index.html#pricing" class="btn primary">View Pricing</a>
        <a href="https://www.pts-translation.sk/#pricing" class="btn outline" target="_blank" rel="noopener noreferrer">Get Subscription</a>
      </div>
    </div>
  `;
  resultsDiv.innerHTML = quotaHtml;
}

function updateQuotaDisplay() {
  const quotaInfoDiv = document.getElementById('quotaInfo');
  if (!quotaInfoDiv) return;

  let pk = localStorage.getItem('lt_passkey');
  if (!pk || !pk.trim() || pk.trim() === 'trial') {
    quotaInfoDiv.textContent = `Trial usage: ${searchCount} / 7 searches today`;
    quotaInfoDiv.className = searchCount >= 7 ? 'quota-display warning' : 'quota-display';
  } else {
    quotaInfoDiv.textContent = `Searches used: ${searchCount} (Subscription active)`;
    quotaInfoDiv.className = 'quota-display';
  }
}

async function initializeUserInfo() {
  userFingerprint = generateFingerprint();
  
  try {
    const response = await fetch('https://api.ipify.org?format=json');
    const data = await response.json();
    userIP = data.ip;
  } catch (e) {
    console.error('Could not fetch IP address.', e);
  }
}

function generateFingerprint() {
  const components = [
    navigator.userAgent,
    navigator.language,
    screen.width,
    screen.height,
    new Date().getTimezoneOffset()
  ];
  const joined = components.join('###');
  let hash = 0;
  for (let i = 0; i < joined.length; i++) {
    const char = joined.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0;
  }
  return 'fp_' + String(Math.abs(hash));
}

function pretty(v) {
  if (v === null || v === undefined) return '';
  if (typeof v === 'object') return JSON.stringify(v);
  return String(v);
}

function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function escapeRegExp(str) {
  return String(str).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function highlight(text, term) {
  if (!term || !text) return escapeHtml(text || '');

  const searchWords = String(term).split(/\s+/).filter(Boolean).map(word => {
    const escaped = escapeRegExp(word);
    return /^\w+$/.test(word) ? `\\b${escaped}\\b` : escaped;
  });

  if (searchWords.length === 0) return escapeHtml(text);
  const regex = new RegExp(`(${searchWords.join('|')})`, 'gi');

  const highlightedText = text.replace(regex, '<mark>$1</mark>');
  return escapeHtml(highlightedText).replace(/&lt;mark&gt;/g, '<mark>').replace(/&lt;\/mark&gt;/g, '</mark>');
}

function handleURLSearchParam() {
  const urlParams = new URLSearchParams(window.location.search);
  const searchQuery = urlParams.get('q');
  
  if (searchQuery) {
    const demoInput = document.getElementById('demoSearch');
    if (demoInput) {
      demoInput.value = searchQuery;
      // Auto-run search after a brief delay
      setTimeout(() => doSearch("phraseBoost"), 500);
    }
  }
}

// Cookie Notice Functions
function initializeCookieNotice() {
  const cookieNotice = document.getElementById('cookieNotice');
  const acceptBtn = document.getElementById('acceptCookies');
  
  if (!cookieNotice || !acceptBtn) return;

  // Check if user has already accepted cookies
  if (localStorage.getItem('cookiesAccepted') === 'true') {
    return; // Don't show notice if already accepted
  }

  // Show notice after a brief delay
  setTimeout(() => {
    cookieNotice.classList.add('show');
  }, 1000);

  // Handle accept button click
  acceptBtn.addEventListener('click', () => {
    acceptCookies();
  });
}

function acceptCookies() {
  const cookieNotice = document.getElementById('cookieNotice');
  
  // Store acceptance in localStorage
  localStorage.setItem('cookiesAccepted', 'true');
  
  // Hide the notice
  if (cookieNotice) {
    cookieNotice.classList.remove('show');
    
    // Remove from DOM after animation
    setTimeout(() => {
      cookieNotice.remove();
    }, 300);
  }
}

// Handle FAQ Links - Auto-open specific FAQ items
function handleFAQLinks() {
  // Intentionally do NOT auto-open FAQ items on initial load.
  // Requirement: The first FAQ (data sources) should stay closed unless the user
  // actively clicks either its own summary or the "Data Sources" nav link.

  document.addEventListener('click', (e) => {
    const link = e.target.closest('a');
    if (!link) return;

    const href = link.getAttribute('href');
    if (!href || !href.startsWith('#')) return;

    // Only act on in-page anchors that point to a FAQ item id (we look for 'faq' in id)
    if (href.includes('faq')) {
      const targetId = href.substring(1);
      const targetElement = document.getElementById(targetId);
      if (targetElement && targetElement.classList.contains('faq-item')) {
        // Open the targeted FAQ item
        setTimeout(() => {
          targetElement.open = true;
          targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }, 50);
      }
    }
  });
}

const http = require('http');
const https = require('https');
const path = require('path');
const express = require('express');
const { createProxyMiddleware, responseInterceptor } = require('http-proxy-middleware');
// Note: We do not use a global body parser to avoid interfering with proxy streaming.
// For custom routes (like /search) we attach `express.json()` at the route level.
const cors = require('cors');
const fs = require('fs/promises'); // For writing to the log file
const morgan = require('morgan'); // Import morgan for logging

// Try to load nodemailer (optional dependency for email support)
let nodemailer = null;
try {
  nodemailer = require('nodemailer');
} catch (err) {
  console.warn('⚠️  nodemailer not installed - support endpoint email forwarding disabled');
  console.warn('   Install with: npm install nodemailer');
}

const app = express();
app.set('trust proxy', true);


// Inline fallback API keys if external config is missing
const VALID_API_KEYS = ['1234', '7239', 'trial'];

// Load API keys from external JSON file (lib/api-keys.json)
// Structure:
// {
//   "keys": [
//     { "key": "7239", "email": "juraj@example.com", "allowPrefixes": ["eu_7239_"], "dailyQuota": 100000 }
//   ]
// }
let API_KEY_REGISTRY = new Map(); // key -> { email, allowPrefixes, dailyQuota }
(function loadApiKeysFromFile() {
    try {
        const cfg = require(path.join(__dirname, 'api-keys.json'));
        if (cfg && Array.isArray(cfg.keys)) {
            API_KEY_REGISTRY = new Map(cfg.keys.map(k => [k.key, k]));
            console.log(`Loaded ${API_KEY_REGISTRY.size} API keys from api-keys.json`);
        } else {
            console.warn('api-keys.json missing "keys" array; using inline VALID_API_KEYS');
        }
    } catch (e) {
        console.warn('api-keys.json not found or invalid; using inline VALID_API_KEYS');
    }
})();

// --- START: CORS Configuration ---
const allowedOrigins = [
    'https://www.pts-translation.sk',
    'https://search.pts-translation.sk',

    'http://localhost:8080' // For local testing
];

const corsOptions = {


    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin || allowedOrigins.indexOf(origin) !== -1) {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'x-api-key', 'x-client-context', 'x-email'],
};

// --- START: Middleware Chain ---
// The order of middleware is very important.

// 1. Apply CORS middleware.
// This will handle pre-flight OPTIONS requests for all routes and also add
// CORS headers to all subsequent responses.
app.use(cors(corsOptions));

// 2. Log the request. With 'trust proxy' enabled, this will show the real IP.
app.use(morgan('combined'));

// 3. Add security headers.
app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'no-store');
    next();
});

// 4. Extract API key and attach it to the request object for later use.
app.use((req, res, next) => {
    req.apiKey = req.headers['x-api-key'];
    next();
});


// --- Manual endpoint to dump API_KEY_REGISTRY and usage counters to a file ---
app.get('/dump-api-keys', async (req, res) => {
    try {
        // Convert API key registry to array for serialization
        const apiKeys = Array.from(API_KEY_REGISTRY.entries());

        // Enhance usageCounters: for each IP, try to find the most recent email used from any key type
        const usageCounters = Array.from(ipRequestCounts.entries()).map(([key, value]) => {
            // Prefer the email property if present
            let email = value.email || null;
            // If not present, try to infer as before
            if (!email && /^\d+\.\d+\.\d+\.\d+$/.test(key)) {
                for (const [ekey, evalue] of ipRequestCounts.entries()) {
                    if (ekey.startsWith('trial:') && evalue.date === value.date) {
                        const ipKey = `trial-ip:${key}`;
                        if (ipRequestCounts.has(ipKey) && ipRequestCounts.get(ipKey).date === value.date) {
                            email = ekey.slice(6); // Remove 'trial:'
                            break;
                        }
                    }
                }
                if (!email) {
                    for (const [ekey, evalue] of ipRequestCounts.entries()) {
                        if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(ekey) && evalue.date === value.date) {
                            const regEntry = apiKeys.find(([k, v]) => v.email && v.email.toLowerCase() === ekey.toLowerCase());
                            if (regEntry) {
                                email = ekey;
                                break;
                            }
                        }
                    }
                }
            }
            return [key, { ...value, email }];
        });

        const dump = {
            apiKeys,
            usageCounters
        };
        const json = JSON.stringify(dump, null, 2);
        const filePath = 'api_key_registry_dump.json';
        await fs.writeFile(filePath, json, 'utf8');
        res.status(200).json({
            message: `API_KEY_REGISTRY and usage counters dumped to ${filePath}`,
            apiKeyCount: apiKeys.length,
            usageCounterCount: usageCounters.length
        });
    } catch (err) {
        console.error('Failed to dump API_KEY_REGISTRY and usage counters:', err);
        res.status(500).json({ error: 'Failed to dump API_KEY_REGISTRY and usage counters', details: err.message });
    }
});

app.get('/reset-rate-limit', (req, res) => {
    // Only allow from localhost, resets all rate limits for all IPs 
    const clientIp = req.ip;
    const isLocalhost = clientIp === '127.0.0.1' || 
                       clientIp === '::1' || 
                       clientIp === '::ffff:127.0.0.1' ||
                       clientIp === 'localhost';
    
    if (!isLocalhost) {
        console.warn(`Rate limit reset attempt denied from non-localhost IP: ${clientIp}`);
        return res.status(403).send('Rate limit reset can only be performed from localhost');
    }
    
    ipRequestCounts.clear();
    console.log('All rate limit counters have been reset.');
    res.status(200).send('All rate limit counters have been reset.');
});
// 5. Rate Limiting Middleware
// Store IP addresses and their request counts in memory.
// For a production environment with multiple server instances,
// a shared store like Redis would be more appropriate.
const ipRequestCounts = new Map();

// Track unique emails
const uniqueEmails = new Set();
const emailsFilePath = 'unique_emails.log';

// Load existing emails from file at startup
(async function loadUniqueEmails() {
    try {
        const content = await fs.readFile(emailsFilePath, 'utf8');
        content.split('\n').forEach(email => {
            const trimmed = email.trim();
            if (trimmed) uniqueEmails.add(trimmed);
        });
        console.log(`Loaded ${uniqueEmails.size} unique emails from ${emailsFilePath}`);
    } catch (err) {
        if (err.code !== 'ENOENT') {
            console.error('Error loading unique emails:', err);
        }
    }
})();

/**
 * Asynchronously adds a new email to the unique emails file.
 * Only adds if the email hasn't been seen before.
 * @param {string} email The email address to track.
 */
async function trackUniqueEmail(email) {
    if (!email || typeof email !== 'string' || !email.includes('@')) return;
    
    const normalizedEmail = email.toLowerCase().trim();
    if (uniqueEmails.has(normalizedEmail)) return;
    
    uniqueEmails.add(normalizedEmail);
    try {
        const timestamp = new Date().toISOString();
        await fs.appendFile(emailsFilePath, `${timestamp} | ${normalizedEmail}\n`);
    } catch (err) {
        console.error('Error writing unique email:', err);
    }
}

// --- Support Request Rate Limiting ---
// Track support requests per IP to prevent spam
// Key: IP address, Value: { count, lastReset }
const supportRequestLimits = new Map();
const SUPPORT_REQUESTS_PER_DAY = 5; // Max 5 support requests per IP per day

// --- Email Configuration for Support Forwarding ---
// Configure these via environment variables:
// SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SUPPORT_EMAIL_TO
let emailTransporter = null;
if (nodemailer) {
    try {
        const smtpHost = process.env.SMTP_HOST || 'smtp.gmail.com';
        const smtpPort = parseInt(process.env.SMTP_PORT || '587');
        const smtpUser = process.env.SMTP_USER;
        const smtpPass = process.env.SMTP_PASS;
        const supportEmailTo = process.env.SUPPORT_EMAIL_TO;

        if (smtpUser && smtpPass && supportEmailTo) {
            emailTransporter = nodemailer.createTransport({
                host: smtpHost,
                port: smtpPort,
                secure: smtpPort === 465, // true for 465, false for other ports
                auth: {
                    user: smtpUser,
                    pass: smtpPass,
                },
            });
            console.log(`Email transporter configured: ${smtpUser} -> ${supportEmailTo}`);
        } else {
            console.warn('Email environment variables not set (SMTP_USER, SMTP_PASS, SUPPORT_EMAIL_TO). Support email forwarding disabled.');
        }
    } catch (e) {
        console.error('Failed to configure email transporter:', e);
    }
}

/**
 * Asynchronously appends a log entry for IP quota usage.
 * This is a non-blocking operation.
 * @param {string} logMessage The message to write to the log.
 */
async function writeToAccessLog(logMessage) {
    const logFilePath = 'ip_access.log';
    const timestamp = new Date().toISOString();
    const logEntry = `${timestamp}: ${logMessage}\n`;

    try {
        await fs.appendFile(logFilePath, logEntry);
    } catch (err) {
        console.error('Error writing to access log:', err);
    }
}

app.use((req, res, next) => {
    // Skip quota checking for indices list refreshes - these are unlimited
    if (req.path === '/_cat/indices' && req.method === 'GET') {
        return next();
    }

    // Determine the rate limit based on the API key for this specific request.
    const reg = API_KEY_REGISTRY.get(req.apiKey);
    const isTrialKey = req.apiKey === 'trial';
    // Always use hardcoded quota for trial key, ignore registry value
    const maxRequests = isTrialKey ? 7 : (reg && Number.isInteger(reg.dailyQuota) ? reg.dailyQuota : 1000);

    const clientIp = req.ip;
    const clientEmail = req.headers['x-email'];
    const today = new Date().toISOString().slice(0, 10); // Get date in YYYY-MM-DD format

    // For trial keys, require email and track quota by BOTH email AND IP
    if (isTrialKey) {
        if (!clientEmail || typeof clientEmail !== 'string' || !clientEmail.includes('@')) {
            console.log(`Trial access rejected: missing or invalid email from IP: ${clientIp}`);
            return res.status(400).json({
                error: 'Trial access requires a valid email address in x-email header'
            });
        }

        const emailKey = `trial:${clientEmail.toLowerCase().trim()}`;
        const ipKey = `trial-ip:${clientIp}`;

        // Track unique email
        trackUniqueEmail(clientEmail);

        // Check email-based quota
        let emailData = ipRequestCounts.get(emailKey);
        if (!emailData || emailData.date !== today) {
            emailData = { count: 0, date: today };
        }
        emailData.count += 1;
        ipRequestCounts.set(emailKey, emailData);

        // Check IP-based quota (to prevent abuse with fake emails)
        let ipData = ipRequestCounts.get(ipKey);
        if (!ipData || ipData.date !== today) {
            ipData = { count: 0, date: today };
        }
        ipData.count += 1;
        // Store email in IP data for trial keys
        ipData.email = clientEmail;
        ipRequestCounts.set(ipKey, ipData);

        // Add quota info to request for downstream logging
        req.quotaInfo = {
            quotaType: 'trial',
            email: clientEmail,
            ip: clientIp,
            emailUsed: emailData.count,
            ipUsed: ipData.count,
            max: maxRequests
        };

        const logMessage = `Trial: ${clientEmail}, IP: ${clientIp}, Email Quota: ${emailData.count}/${maxRequests}, IP Quota: ${ipData.count}/${maxRequests}`;
        console.log(logMessage);
        writeToAccessLog(logMessage);

        // Block if EITHER email OR IP exceeds quota
        if (emailData.count > maxRequests) {
            const exceededMessage = `RATE LIMIT EXCEEDED (email) for ${logMessage}`;
            console.log(exceededMessage);
            writeToAccessLog(exceededMessage);
            return res.status(429).json({
                error: 'Too Many Requests: You have exceeded the daily query limit for this email address.'
            });
        }

        if (ipData.count > maxRequests) {
            const exceededMessage = `RATE LIMIT EXCEEDED (IP) for ${logMessage}`;
            console.log(exceededMessage);
            writeToAccessLog(exceededMessage);
            return res.status(429).json({
                error: 'Too Many Requests: You have exceeded the daily query limit from this IP address.'
            });
        }
    } else {
        // Regular keys: track by IP only
        let usageData = ipRequestCounts.get(clientIp);

        if (!usageData || usageData.date !== today) {
            usageData = { count: 0, date: today };
        }


        usageData.count += 1;
        // Get email from header or registry
        const email = clientEmail || (reg && reg.email) || 'no-email';
        // Store email in IP data for subscription keys
        usageData.email = email;
        ipRequestCounts.set(clientIp, usageData);

        // Track unique email if present
        if (email !== 'no-email') {
            trackUniqueEmail(email);
        }

        req.quotaInfo = {
            quotaType: 'subscription',
            email,
            ip: clientIp,
            used: usageData.count,
            max: maxRequests
        };

        const timestamp = new Date().toISOString();
        const logMessage = `IP: ${clientIp}, Email: ${email}, Quota Used: ${usageData.count}/${maxRequests}, apikey: ${req.apiKey}`;
        console.log(`${timestamp} QUOTA: ${logMessage}`);
        writeToAccessLog(logMessage);

        if (usageData.count > maxRequests) {
            const exceededMessage = `RATE LIMIT EXCEEDED for ${logMessage}`;
            console.log(exceededMessage);
            writeToAccessLog(exceededMessage);
            return res.status(429).json({
                error: 'Too Many Requests: You have exceeded the daily query limit.'
            });
        }
    }

    next();
});

// --- START: Test-only endpoint to reset rate limits ---
// This endpoint is for development/testing and should be removed or
// secured in a production environment.


// 4. Log incoming request details
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    const requestId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    req.requestId = requestId;
    
    console.log(`\n${'='.repeat(80)}`);
    console.log(`${timestamp} REQUEST START [${requestId}]`);
    console.log(`${req.method} ${req.path}`);
    console.log(`IP: ${req.ip} | API Key: ${req.apiKey || 'none'} | Email: ${req.headers['x-email'] || 'none'}`);
    if (req.quotaInfo) {
        if (req.quotaInfo.quotaType === 'trial') {
            console.log(`Quota (trial): Email ${req.quotaInfo.email} ${req.quotaInfo.emailUsed}/${req.quotaInfo.max}, IP ${req.quotaInfo.ip} ${req.quotaInfo.ipUsed}/${req.quotaInfo.max}`);
        } else {
            console.log(`Quota (subscription): IP ${req.quotaInfo.ip} ${req.quotaInfo.used}/${req.quotaInfo.max}`);
        }
    }
    console.log(`User-Agent: ${req.headers['user-agent'] || 'unknown'}`);
    if (req.headers['x-device-id']) {
        console.log(`Device-ID: ${req.headers['x-device-id']}`);
    }
    console.log(`${'='.repeat(80)}`);
    
    // Capture response end
    const originalEnd = res.end;
    res.end = function(...args) {
        const endTime = new Date().toISOString();
        console.log(`${endTime} REQUEST END [${requestId}] - Status: ${res.statusCode}`);
        console.log(`${'='.repeat(80)}\n`);
        originalEnd.apply(res, args);
    };
    
    next();
});

// 6. NOW, validate the API key after logging and CORS have been handled.
app.use((req, res, next) => {
    // Skip authentication for public endpoints
    const publicEndpoints = ['/version', '/reset-rate-limit', '/support'];
    if (publicEndpoints.includes(req.path)) {
        return next();
    }
    
    // Prefer external registry; fallback to inline VALID_API_KEYS
    const hasKey = API_KEY_REGISTRY.size > 0
        ? API_KEY_REGISTRY.has(req.apiKey)
        : VALID_API_KEYS.includes(req.apiKey);
    if (!req.apiKey || !hasKey) {
        console.log(`Unauthorized access attempt with key: ${req.apiKey} from IP: ${req.ip}`);
        return res.status(401).json({ error: 'Unauthorized: invalid API key' });
    }

    // Optional email check: if registry specifies email, require match with header
    const rec = API_KEY_REGISTRY.get(req.apiKey);
    const headerEmail = req.headers['x-email'];
    if (rec && rec.email && headerEmail && String(rec.email).toLowerCase() !== String(headerEmail).toLowerCase()) {
        console.log(`Email mismatch for API key ${req.apiKey}: expected ${rec.email}, got ${headerEmail}`);
        return res.status(403).json({ error: 'Forbidden: email does not match key owner' });
    }
    next();
});

// Create a custom agent to force IPv4 resolution for localhost.
// This is a common fix for Node.js v17+ DNS resolution behavior.
const ipv4Agent = new http.Agent({ family: 4 });

// ------------------------------
// Search API (client-facing)
// ------------------------------
// We replace the broad proxy with a narrow, validated API for search.
// The legacy proxy remains only for admin paths further below.

/**
 * Validate an OpenSearch index name against standard rules
 * - lowercase letters, digits, '.', '-', '_'
 * - cannot start with '-', '_', '+'
 * - cannot be '.' or '..'
 * - max length 255
 */
function isValidIndexName(name) {
    if (typeof name !== 'string') return false;
    if (name.length === 0 || name.length > 255) return false;
    if (name === '.' || name === '..') return false;
    if (/^[\-\_\+]/.test(name)) return false;
    if (!/^[a-z0-9._-]+$/.test(name)) return false;
    return true;
}

/**
 * Build an OpenSearch query body from client payload.
 * 
 * Pattern 1: Phrase search on lang1 only (slop: 2, boost: 1.5)
 *            - Used by: _startSearch (Phrase button)
 * 
 * Pattern 2: Multi-match with fuzziness across all langs + paragraphsNotMatched filter
 *            - Used by: _startSearch2 (Multi button)
 * 
 * Pattern 3: Phrase + fuzzy match on all langs with boosting
 *            - Used by: _startSearch3 (Multi+ button)
 * 
 * Pattern 4: Intervals query with ordered tokens
 *            - Used by: _startIntervalsTest (A/B button)
 * 
 * Pattern 5: Phrase search across ALL indices with wildcard fields
 *            - Used by: _startSearchPhraseAll (All button)
 * 
 * Pattern 6: Auto-lookup from Trados (currently same as Pattern 2, can be customized)
 *            - Used by: _httpUpdate (Trados auto-lookup integration)
 */
function buildQuery({ term, langs = [], pattern = 1, size = 50, existsLangs = [] }) {
    // Build exists clauses for displayed languages (like _existsClausesForDisplayedLangs)
    const existsClauses = existsLangs
        .filter(l => l && typeof l === 'string')
        .map(l => ({ exists: { field: `${l.toLowerCase()}_text` } }));
    
    const [lang1, lang2, lang3] = langs.map(l => l ? l.toLowerCase() : null);

    // Pattern 1: Phrase search on lang1 only
    if (pattern === 1) {
        return {
            query: {
                bool: {
                    must: [
                        ...existsClauses,
                        {
                            match_phrase: {
                                [`${lang1}_text`]: {
                                    query: term,
                                    slop: 2,
                                    boost: 1.5
                                }
                            }
                        }
                    ]
                }
            },
            size
        };
    }

    // Pattern 2: Multi-match with fuzziness + paragraphsNotMatched filter
    if (pattern === 2) {
        const fields = langs.filter(Boolean).map(l => `${l.toLowerCase()}_text`);
        return {
            query: {
                bool: {
                    must: [
                        ...existsClauses,
                        {
                            multi_match: {
                                query: term,
                                fields,
                                fuzziness: "AUTO",
                                minimum_should_match: "80%"
                            }
                        },
                        { term: { paragraphsNotMatched: false } }
                    ]
                }
            },
            size,
            highlight: {
                fields: Object.fromEntries(fields.map(f => [f, {}]))
            }
        };
    }

    // Pattern 3: Phrase + fuzzy match on all langs with boosting
    if (pattern === 3) {
        const should = [];
        langs.filter(Boolean).forEach(l => {
            const field = `${l.toLowerCase()}_text`;
            should.push({
                match_phrase: {
                    [field]: { query: term, slop: 2, boost: 3.0 }
                }
            });
            should.push({
                match: {
                    [field]: { query: term, fuzziness: "AUTO", operator: "and", boost: 1.0 }
                }
            });
        });
        return {
            query: {
                bool: {
                    must: existsClauses,
                    should,
                    minimum_should_match: 1
                }
            },
            size
        };
    }

    // Pattern 4: Intervals query with ordered tokens
    if (pattern === 4) {
        const tokens = term.split(/\s+/).filter(t => t.length > 2).slice(0, 4);
        const should = [];
        langs.filter(Boolean).forEach(l => {
            const field = `${l.toLowerCase()}_text`;
            should.push({
                intervals: {
                    [field]: {
                        all_of: {
                            ordered: true,
                            intervals: tokens.map(t => ({ match: { query: t } })),
                            max_gaps: 3
                        }
                    }
                }
            });
        });
        return {
            query: {
                bool: { should, minimum_should_match: 1 }
            },
            size
        };
    }

    // Pattern 5: Phrase search across ALL with wildcard fields
    if (pattern === 5) {
        return {
            query: {
                bool: {
                    must: [
                        ...existsClauses,
                        {
                            multi_match: {
                                type: "phrase",
                                query: term,
                                slop: 10,
                                fields: ["*_text"],
                                auto_generate_synonyms_phrase_query: false,
                                lenient: true
                            }
                        }
                    ]
                }
            },
            size,
            highlight: {
                require_field_match: false,
                fields: { "*_text": {} }
            }
        };
    }

    // Pattern 6: Auto-lookup from Trados (combine match_phrase with high boost and multi_match for better ranking)
    if (pattern === 6) {
        const lang1 = langs[0] ? langs[0].toLowerCase() : null;
        const fields = lang1 ? [`${lang1}_text`] : [];
        return {
            query: {
                bool: {
                    must: [
                        ...existsClauses,
                        { term: { paragraphsNotMatched: false } }
                    ],
                    should: [
                        lang1 ? {
                            match_phrase: {
                                [`${lang1}_text`]: {
                                    query: term,
                                    slop: 5,
                                    boost: 5.0
                                }
                            }
                        } : null,
                        {
                            multi_match: {
                                query: term,
                                fields,
                                fuzziness: "AUTO"
                            }
                        }
                    ].filter(Boolean)
                }
            },
            size
        };
    }

    // Pattern 7: IATE terminology search
    // Searches IATE database with fuzzy matching, requires all working language fields to exist
    if (pattern === 7) {
        const fields = langs.filter(Boolean).map(l => `${l.toLowerCase()}_text`);
        return {
            query: {
                bool: {
                    must: [
                        ...existsClauses,
                        {
                            multi_match: {
                                query: term,
                                fields,
                                fuzziness: "AUTO"
                            }
                        }
                    ]
                }
            },
            size
        };
    }

    // Default fallback: simple match
    return {
        query: { match: { [`${lang1}_text`]: term } },
        size
    };
}

/**
 * Execute an OpenSearch _search request using Node's http module.
 * We reuse the same connection details as the proxy (localhost:9200, basic auth).
 */
/**
 * Execute an OpenSearch search across one or more indices.
 * Supports single index names, comma-separated lists, or wildcard patterns.
 * The path must remain safe; we only allow characters [a-z0-9._-*,]
 */
async function executeSearch(indexParam, body) {
    return new Promise((resolve, reject) => {
        const postData = Buffer.from(JSON.stringify(body));
        const authHeader = 'Basic ' + Buffer.from('admin:admin').toString('base64');

        // Build a safe index path segment
        let indexPath = '';
        if (Array.isArray(indexParam)) {
            indexPath = indexParam.join(',');
        } else if (typeof indexParam === 'string') {
            indexPath = indexParam;
        } else {
            return reject(new Error('Invalid index parameter'));
        }
        if (!/^[a-z0-9._\-*,]+$/.test(indexPath)) {
            return reject(new Error('Unsafe index path'));
        }

        const req = http.request({
            host: '127.0.0.1',
            port: 9200,
            method: 'POST',
            // Do not encode wildcard/comma; OS expects raw characters here.
            path: `/${indexPath}/_search`,
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': postData.length,
                'Authorization': authHeader,
            },
            agent: ipv4Agent,
        }, (res) => {
            let data = '';
            res.on('data', chunk => { data += chunk; });
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    resolve({ statusCode: res.statusCode, body: parsed });
                } catch (e) {
                    // Return raw text if JSON parsing fails
                    resolve({ statusCode: res.statusCode, body: data });
                }
            });
        });

        req.on('error', reject);
        req.write(postData);
        req.end();
    });
}

// ------------------------------
// Secure Search Endpoint (parameters only)
// ------------------------------
// The app sends only search parameters; the query is built server-side.
// POST /search
// Body: { index, term, langs, pattern, size?, existsLangs? }
//
// Patterns:
//   1 = Phrase search on lang1 (Phrase button)
//   2 = Multi-match with fuzziness (Multi button)
//   3 = Phrase + fuzzy with boosting (Multi+ button)
//   4 = Intervals ordered tokens (A/B button)
//   5 = Phrase search ALL indices (All button)
//
app.post('/search', express.json({ limit: '1mb' }), async (req, res) => {
    try {
        const { index, term, langs, pattern, size, existsLangs } = req.body || {};

        // Validate required fields
        if (!term || typeof term !== 'string' || term.trim().length === 0) {
            return res.status(400).json({ error: 'Invalid `term`' });
        }
        if (!Array.isArray(langs) || langs.length === 0) {
            return res.status(400).json({ error: 'Invalid `langs` array' });
        }

        // Determine index to search
        let indexParam;
        if (index === '*' || !index) {
            // Search all indices
            indexParam = '*';
        } else if (typeof index === 'string') {
            if (!isValidIndexName(index)) {
                return res.status(400).json({ error: 'Invalid `index` name' });
            }
            indexParam = index;
        } else {
            return res.status(400).json({ error: 'Invalid `index`' });
        }

        // Build query server-side from parameters
        const body = buildQuery({
            term,
            langs,
            pattern: pattern || 1,
            size: Math.min(size || 50, 100),  // Cap at 100
            existsLangs: existsLangs || langs  // Default to all langs if not specified
        });
        
        const langsStr = langs.join(',');
        const timestamp = new Date().toISOString();
        console.log(`${timestamp} REQUEST: search, index=${indexParam}, pattern=${pattern || 1}, langs=[${langsStr}]`);
        const result = await executeSearch(indexParam, body);
        
        // Log result count
        const hitCount = result.body?.hits?.total?.value || result.body?.hits?.hits?.length || 0;
        console.log(`${timestamp} RESPONSE: search returned ${hitCount} results`);
        
        res.status(result.statusCode || 200).json(result.body);
    } catch (err) {
        console.error('Search route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Secure Context Retrieval Endpoint (parameter-based)
// ------------------------------
// POST /context
// Body: { index, celex?, filename?, sequenceId, window, langs }
// Returns surrounding segments for context display
// 
// SECURITY: Client sends only parameters, server constructs query
app.post('/context', express.json({ limit: '1mb' }), async (req, res) => {
    try {
        const { index, celex, filename, sequenceId, window, langs } = req.body || {};

        // Validate required fields
        if (!index || typeof index !== 'string' || !isValidIndexName(index)) {
            return res.status(400).json({ error: 'Invalid `index`' });
        }
        if (!Number.isInteger(sequenceId)) {
            return res.status(400).json({ error: 'Invalid `sequenceId` (must be integer)' });
        }
        if (!Number.isInteger(window) || window < 0) {
            return res.status(400).json({ error: 'Invalid `window` (must be non-negative integer)' });
        }
        if (!Array.isArray(langs) || langs.length === 0) {
            return res.status(400).json({ error: 'Invalid `langs` array' });
        }

        // Must have either celex or filename
        if ((!celex || celex === '') && (!filename || filename === '')) {
            return res.status(400).json({ error: 'Must provide either `celex` or `filename`' });
        }

        // Build document identifier query server-side
        let documentIdentifier;
        if (celex && celex.toString().trim() !== '') {
            // Match by celex
            documentIdentifier = {
                bool: {
                    should: [
                        { term: { celex: celex } },
                        { term: { 'celex.keyword': celex } }
                    ],
                    minimum_should_match: 1
                }
            };
        } else {
            // Match by filename
            documentIdentifier = {
                bool: {
                    should: [
                        { term: { filename: filename } },
                        { term: { 'filename.keyword': filename } }
                    ],
                    minimum_should_match: 1
                }
            };
        }

        // Calculate range
        const center = sequenceId;
        let gte = center - window;
        if (gte < 0) gte = 0;
        const lte = center + window;

        // Build query server-side
        const query = {
            query: {
                bool: {
                    must: [
                        documentIdentifier,
                        {
                            range: {
                                sequence_id: { gte, lte }
                            }
                        }
                    ]
                }
            },
            sort: [
                { sequence_id: { order: 'asc' } }
            ],
            size: 50
        };

        const timestamp = new Date().toISOString();
        console.log(`${timestamp} REQUEST: context, index=${index}, celex=${celex || 'none'}, filename=${filename || 'none'}, seq=${sequenceId}, window=${window}`);
        
        const result = await executeSearch(index, query);
        
        // Log result count
        const hitCount = result.body?.hits?.total?.value || result.body?.hits?.hits?.length || 0;
        console.log(`${timestamp} RESPONSE: context returned ${hitCount} segments`);
        
        res.status(result.statusCode || 200).json(result.body);
    } catch (err) {
        console.error('Context route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Secure Upload Endpoint (parameter-based)
// ------------------------------
// POST /upload
// Client sends: { "index": "eu_7239_0132b", "documents": [{celex: "...", en_text: "...", sk_text: "..."}, ...] }
// Server constructs bulk NDJSON (only "index" operations allowed - no delete/update)
// 
// SECURITY IMPROVEMENTS over /:index/_bulk:
// - Client cannot control operation type (always "index", never delete/update)
// - Server validates index access (allowPrefixes check)
// - Server blocks dangerous fields (script, runtime_mappings)
// - Server constructs all bulk operations, client only sends documents
app.post('/upload', express.json({ limit: '50mb' }), async (req, res) => {
    try {
        const { index, documents } = req.body;
        
        // Validate index name
        if (!index || typeof index !== 'string' || !isValidIndexName(index)) {
            return res.status(400).json({ error: 'Invalid or missing `index` name' });
        }
        
        // Validate documents array
        if (!Array.isArray(documents) || documents.length === 0) {
            return res.status(400).json({ error: 'Invalid or missing `documents` array' });
        }
        
        // SECURITY: Check if user has access to this index
        const reg = API_KEY_REGISTRY.get(req.apiKey);
        const isAdmin = reg && reg.email && reg.email.toLowerCase() === 'juraj.kuban.sk@gmail.com';
        
        if (!isAdmin) {
            // Non-admin users can only upload to indices matching their allowPrefixes
            const allowPrefixes = reg?.allowPrefixes || [`eu_${req.apiKey}_`];
            const hasAccess = allowPrefixes.some(prefix => index.startsWith(prefix));
            
            if (!hasAccess) {
                console.log(`BLOCKED: User ${req.apiKey} attempted to upload to index: ${index}`);
                return res.status(403).json({ 
                    error: 'Access denied. You can only upload to your own indices.',
                    allowedPrefixes: allowPrefixes 
                });
            }
        }
        
        // SECURITY: Validate document structure (prevent script injection)
        for (let i = 0; i < documents.length; i++) {
            const doc = documents[i];
            if (typeof doc !== 'object' || doc === null) {
                return res.status(400).json({ 
                    error: `Invalid document at index ${i}. Must be an object.` 
                });
            }
            // Block dangerous fields
            if (doc.script || doc._script || doc.runtime_mappings) {
                return res.status(403).json({ 
                    error: `Document at index ${i} contains forbidden fields (script)` 
                });
            }
        }
        
        // BUILD BULK NDJSON: Server constructs the bulk operations
        // Each document becomes: {"index": {"_index": "..."}} \n {document} \n
        const bulkLines = [];
        for (const doc of documents) {
            // Action line: only "index" operation (not delete/update)
            bulkLines.push(JSON.stringify({ index: { _index: index } }));
            // Document line
            bulkLines.push(JSON.stringify(doc));
        }
        const ndjsonBody = bulkLines.join('\n') + '\n';
        
        const timestamp = new Date().toISOString();
        console.log(`${timestamp} REQUEST: upload, index=${index}, docs=${documents.length}, IP=${req.ip}`);
        
        // Send to OpenSearch
        const authHeader = 'Basic ' + Buffer.from('admin:admin').toString('base64');
        const postData = Buffer.from(ndjsonBody, 'utf8');
        
        const proxyReq = http.request({
            host: '127.0.0.1',
            port: 9200,
            method: 'POST',
            path: '/_bulk',
            headers: {
                'Content-Type': 'application/x-ndjson',
                'Content-Length': postData.length,
                'Authorization': authHeader,
            },
            agent: ipv4Agent,
        }, (proxyRes) => {
            let data = '';
            proxyRes.on('data', chunk => { data += chunk; });
            proxyRes.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    const ts = new Date().toISOString();
                    const hasErrors = parsed.errors === true;
                    const itemCount = parsed.items ? parsed.items.length : 0;
                    console.log(`${ts} RESPONSE: upload ${hasErrors ? 'with errors' : 'OK'}, processed ${itemCount} items`);
                    res.status(proxyRes.statusCode || 200).json(parsed);
                } catch (e) {
                    res.status(proxyRes.statusCode || 200).send(data);
                }
            });
        });
        
        proxyReq.on('error', (err) => {
            console.error('Upload proxy error:', err);
            res.status(502).json({ error: 'Bad Gateway' });
        });
        proxyReq.write(postData);
        proxyReq.end();
        
    } catch (err) {
        console.error('Upload route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Fetch Update Info (client-friendly)
// ------------------------------
// Proxies the public update JSON through this server so the Flutter app only
// needs to trust your domain. Requires a valid API key like other routes.
// GET /fetch/update-info
// Response: JSON from https://www.pts-translation.sk/updateInfoUrl.json
app.get('/fetch/update-info', async (req, res) => {
    const sourceUrl = 'https://www.pts-translation.sk/updateInfoUrl.json';
    try {
        https.get(sourceUrl, { agent: undefined }, (resp) => {
            let data = '';
            resp.on('data', (chunk) => { data += chunk; });
            resp.on('end', () => {
                // Try to return parsed JSON, fallback to raw text
                try {
                    const json = JSON.parse(data);
                    res.status(200).json(json);
                } catch (_) {
                    res.status(200).send(data);
                }
            });
        }).on('error', (err) => {
            console.error('Update info fetch error:', err);
            res.status(502).json({ error: 'Bad Gateway: failed to fetch update info' });
        });
    } catch (e) {
        console.error('Update info route error:', e);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Version Endpoint
// ------------------------------
// Returns the current app version directly without external fetch.
// GET /version
app.get('/version', (req, res) => {
    res.status(200).json({
        version: '0.9.7',  // Update this value when releasing new versions
        minVersion: '0.9.6',
        updateUrl: 'https://apps.microsoft.com/detail/9nknvgxjfsw5'
    });
});

// ------------------------------
// List Indices Endpoint
// ------------------------------
// GET /_cat/indices?h=index or ?h=index,store.size,docs.count
// Returns filtered list of indices based on user's API key
app.get('/_cat/indices', async (req, res) => {
    try {
        const timestamp = new Date().toISOString();
        console.log(`${timestamp} REQUEST: list-indices, IP=${req.ip}, apikey=${req.apiKey}`);
        
        // Check if user is admin (has access to all indices)
        const reg = API_KEY_REGISTRY.get(req.apiKey);
        const isAdmin = reg && reg.email && reg.email.toLowerCase() === 'juraj.kuban.sk@gmail.com';
        
        // Parse query parameter 'h' for headers/columns
        const headers = req.query.h || 'index';
        const columns = headers.split(',').map(h => h.trim());
        
        // Query OpenSearch for index information
        const authHeader = 'Basic ' + Buffer.from('admin:admin').toString('base64');
        const osPath = `/_cat/indices?h=${headers}&format=json`;
        
        const osReq = http.request({
            host: '127.0.0.1',
            port: 9200,
            method: 'GET',
            path: osPath,
            headers: {
                'Authorization': authHeader,
            },
            agent: ipv4Agent,
        }, (osRes) => {
            let data = '';
            osRes.on('data', chunk => { data += chunk; });
            osRes.on('end', () => {
                try {
                    const indices = JSON.parse(data);
                    
                    // Filter indices based on user access
                    let filtered;
                    if (isAdmin) {
                        // Admin sees all indices except system indices
                        filtered = indices.filter(idx => 
                            !idx.index.startsWith('.') && 
                            !idx.index.startsWith('top_queries')
                        );
                    } else if (req.apiKey === 'trial') {
                        // Trial users see no indices
                        filtered = [];
                    } else {
                        // Regular users see only their own indices (eu_{apiKey}_*)
                        const prefix = `eu_${req.apiKey}_`;
                        filtered = indices.filter(idx => idx.index.startsWith(prefix));
                    }
                    
                    // Format response based on requested columns
                    if (columns.length === 1 && columns[0] === 'index') {
                        // Simple format: one index name per line
                        const result = filtered.map(idx => idx.index).join('\n');
                        res.status(200).type('text/plain').send(result);
                    } else {
                        // Multi-column format: space-separated values
                        const lines = filtered.map(idx => {
                            return columns.map(col => {
                                if (col === 'index') return idx.index;
                                if (col === 'store.size') return idx['store.size'] || '0b';
                                if (col === 'docs.count') return idx['docs.count'] || '0';
                                return idx[col] || '';
                            }).join(' ');
                        });
                        res.status(200).type('text/plain').send(lines.join('\n'));
                    }
                } catch (e) {
                    console.error('Error parsing indices response:', e);
                    res.status(500).json({ error: 'Error parsing indices' });
                }
            });
        });
        
        osReq.on('error', (err) => {
            console.error('Error fetching indices:', err);
            res.status(502).json({ error: 'Bad Gateway' });
        });
        osReq.end();
    } catch (err) {
        console.error('List indices error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Shared handler for search/bulk operations
// ------------------------------
async function handleSearchOrBulk(req, res, targetPath) {
    const contentType = req.headers['content-type'] || '';
    
    // SECURITY: Only allow _search and _bulk - block delete/update operations
    const isSearch = targetPath.endsWith('/_search');
    const isBulk = targetPath.endsWith('/_bulk');
    
    if (!isSearch && !isBulk) {
        console.log(`BLOCKED: Attempted operation: ${targetPath} from ${req.ip}`);
        return res.status(403).json({ error: 'Only _search and _bulk operations are allowed' });
    }
    
    // Log request type
    const requestType = isSearch ? 'search' : 'bulk';
    const timestamp = new Date().toISOString();
    console.log(`${timestamp} REQUEST: ${requestType}, path=${targetPath}, IP=${req.ip}`);
    
    // Basic path validation - allow index names, wildcards, and allowed endpoints
    if (!/^[a-z0-9._\-*,\/]+$/.test(targetPath)) {
        return res.status(400).json({ error: 'Invalid path' });
    }
    
    let postData = req.body;
    
    // SECURITY: For bulk operations, validate index access
    if (isBulk) {
        try {
            const ndjsonBody = req.body.toString('utf8');
            const lines = ndjsonBody.trim().split('\n');
            
            // Get user's allowed prefixes
            const reg = API_KEY_REGISTRY.get(req.apiKey);
            const isAdmin = reg && reg.email && reg.email.toLowerCase() === 'juraj.kuban.sk@gmail.com';
            
            if (!isAdmin) {
                const allowPrefixes = reg?.allowPrefixes || [`eu_${req.apiKey}_`];
                
                // Parse NDJSON and check each action line
                for (let i = 0; i < lines.length; i += 2) {
                    if (!lines[i]) continue;
                    
                    try {
                        const action = JSON.parse(lines[i]);
                        const operation = Object.keys(action)[0]; // 'index', 'create', 'update', 'delete'
                        
                        // Block dangerous operations
                        if (operation === 'delete' || operation === 'update') {
                            console.log(`BLOCKED: User ${req.apiKey} attempted ${operation} operation`);
                            return res.status(403).json({ 
                                error: `Operation '${operation}' not allowed. Only 'index' operations permitted.` 
                            });
                        }
                        
                        const indexName = action[operation]?._index;
                        if (indexName && typeof indexName === 'string') {
                            // Check if user has access to this index
                            const hasAccess = allowPrefixes.some(prefix => indexName.startsWith(prefix));
                            if (!hasAccess) {
                                console.log(`BLOCKED: User ${req.apiKey} attempted to write to index: ${indexName}`);
                                return res.status(403).json({ 
                                    error: `Access denied to index '${indexName}'. Allowed prefixes: ${allowPrefixes.join(', ')}` 
                                });
                            }
                        }
                        
                        // Optional: Check document for dangerous fields (if there's a document line)
                        if (i + 1 < lines.length && lines[i + 1]) {
                            try {
                                const doc = JSON.parse(lines[i + 1]);
                                if (doc.script || doc._script || doc.runtime_mappings) {
                                    console.log(`BLOCKED: Document contains forbidden fields from ${req.ip}`);
                                    return res.status(403).json({ 
                                        error: 'Document contains forbidden fields (script, runtime_mappings)' 
                                    });
                                }
                            } catch (e) {
                                // Skip if document line is not valid JSON
                            }
                        }
                    } catch (e) {
                        // Skip malformed lines
                    }
                }
            }
        } catch (e) {
            console.error('Error parsing bulk request:', e);
            return res.status(400).json({ error: 'Invalid bulk request format' });
        }
    }
    
    // For search: apply security restrictions (parse JSON to inspect)
    if (isSearch && contentType.includes('application/json')) {
        try {
            let body = JSON.parse(req.body.toString());
            // SECURITY: Block dangerous query types
            if (body.script || body.runtime_mappings) {
                return res.status(403).json({ error: 'Script queries not allowed' });
            }
            // SECURITY: Limit result size to prevent data dumps
            if (!body.size || body.size > 100) {
                body.size = 100;
            }
            postData = Buffer.from(JSON.stringify(body));
        } catch (e) {
            return res.status(400).json({ error: 'Invalid JSON' });
        }
    }
    
    const authHeader = 'Basic ' + Buffer.from('admin:admin').toString('base64');
    const outContentType = isBulk ? (contentType || 'application/x-ndjson') : 'application/json';
    
    const proxyReq = http.request({
        host: '127.0.0.1',
        port: 9200,
        method: 'POST',
        path: `/${targetPath}`,
        headers: {
            'Content-Type': outContentType,
            'Content-Length': postData.length,
            'Authorization': authHeader,
        },
        agent: ipv4Agent,
    }, (proxyRes) => {
        let data = '';
        proxyRes.on('data', chunk => { data += chunk; });
        proxyRes.on('end', () => {
            try {
                const parsed = JSON.parse(data);
                // Log result count for search operations
                if (isSearch) {
                    const hitCount = parsed?.hits?.total?.value || parsed?.hits?.hits?.length || 0;
                    const ts = new Date().toISOString();
                    console.log(`${ts} RESPONSE: ${requestType} returned ${hitCount} results`);
                }
                res.status(proxyRes.statusCode || 200).json(parsed);
            } catch (e) {
                res.status(proxyRes.statusCode || 200).send(data);
            }
        });
    });
    
    proxyReq.on('error', (err) => {
        console.error('Proxy request error:', err);
        res.status(502).json({ error: 'Bad Gateway' });
    });
    proxyReq.write(postData);
    proxyReq.end();
}

// ------------------------------
// Backward-compatible routes (no /proxy prefix)
// ------------------------------
// POST /:index/_search - for search queries
// POST /:index/_bulk - for bulk uploads
// These match the original OpenSearch URL format
app.post('/:index/_search', express.raw({ limit: '5mb', type: '*/*' }), async (req, res) => {
    try {
        const targetPath = `${req.params.index}/_search`;
        await handleSearchOrBulk(req, res, targetPath);
    } catch (err) {
        console.error('Search route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/:index/_bulk', express.raw({ limit: '50mb', type: '*/*' }), async (req, res) => {
    try {
        const targetPath = `${req.params.index}/_bulk`;
        await handleSearchOrBulk(req, res, targetPath);
    } catch (err) {
        console.error('Bulk route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Delete Index (for authenticated users)
// ------------------------------
// DELETE /:index
app.delete('/:index', async (req, res) => {
    try {
        const index = req.params.index;
        
        // Validate index name
        if (!isValidIndexName(index)) {
            return res.status(400).json({ error: 'Invalid index name' });
        }
        
        // Check if user is admin
        const reg = API_KEY_REGISTRY.get(req.apiKey);
        const isAdmin = reg && reg.email && reg.email.toLowerCase() === 'juraj.kuban.sk@gmail.com';
        
        console.log(`DELETE AUTH: apiKey=${req.apiKey}, regEmail=${reg?.email}, isAdmin=${isAdmin}, index=${index}`);
        
        // SECURITY: Only allow users to delete their own indices (with their API key prefix)
        // Admin can delete any index
        if (!isAdmin && !index.startsWith(`eu_${req.apiKey}_`)) {
            console.log(`BLOCKED: User ${req.apiKey} attempted to delete index: ${index}`);
            return res.status(403).json({ error: 'You can only delete your own indices' });
        }
        
        const timestamp = new Date().toISOString();
        console.log(`${timestamp} REQUEST: delete, index=${index}, apikey=${req.apiKey}, IP=${req.ip}`);
        
        const authHeader = 'Basic ' + Buffer.from('admin:admin').toString('base64');
        
        const deleteReq = http.request({
            host: '127.0.0.1',
            port: 9200,
            method: 'DELETE',
            path: `/${index}`,
            headers: {
                'Authorization': authHeader,
            },
            agent: ipv4Agent,
        }, (proxyRes) => {
            let data = '';
            proxyRes.on('data', chunk => { data += chunk; });
            proxyRes.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    console.log(`Index ${index} deleted: ${JSON.stringify(parsed)}`);
                    res.status(proxyRes.statusCode || 200).json(parsed);
                } catch (e) {
                    res.status(proxyRes.statusCode || 200).send(data);
                }
            });
        });
        
        deleteReq.on('error', (err) => {
            console.error('Delete index error:', err);
            res.status(502).json({ error: 'Bad Gateway' });
        });
        deleteReq.end();
    } catch (err) {
        console.error('Delete route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Proxy routes (alternative with /proxy prefix) - if needed in future
// ------------------------------
// Specific routes for proxy prefix (app doesn't use these currently)
app.post('/proxy/:index/_search', express.raw({ limit: '5mb', type: '*/*' }), async (req, res) => {
    try {
        const targetPath = `${req.params.index}/_search`;
        await handleSearchOrBulk(req, res, targetPath);
    } catch (err) {
        console.error('Proxy search route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.post('/proxy/:index/_bulk', express.raw({ limit: '50mb', type: '*/*' }), async (req, res) => {
    try {
        const targetPath = `${req.params.index}/_bulk`;
        await handleSearchOrBulk(req, res, targetPath);
    } catch (err) {
        console.error('Proxy bulk route error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// ------------------------------
// Support/Error Reporting Endpoint
// ------------------------------
// POST /support - Submit support request from app
// Body: { email: string, subject: string, message: string, apiKey?: string }
app.post('/support', express.json({ limit: '1mb' }), async (req, res) => {
    const requestId = `SUP-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const timestamp = new Date().toISOString();
    const clientIp = req.ip;

    try {
        // Rate limiting for support requests (per IP)
        const today = new Date().toISOString().split('T')[0];
        const limitKey = clientIp;
        const limitEntry = supportRequestLimits.get(limitKey);

        if (limitEntry) {
            if (limitEntry.lastReset !== today) {
                // Reset daily limit
                limitEntry.count = 0;
                limitEntry.lastReset = today;
            }
            if (limitEntry.count >= SUPPORT_REQUESTS_PER_DAY) {
                console.log(`[${timestamp}] ${requestId} - Support request rate limit exceeded for IP: ${clientIp}`);
                return res.status(429).json({ 
                    error: 'Rate limit exceeded', 
                    message: `Maximum ${SUPPORT_REQUESTS_PER_DAY} support requests per day allowed.` 
                });
            }
            limitEntry.count++;
        } else {
            supportRequestLimits.set(limitKey, { count: 1, lastReset: today });
        }

        // Validate required fields
        const { email, subject, message, apiKey } = req.body;
        if (!email || !subject || !message) {
            return res.status(400).json({ 
                error: 'Missing required fields', 
                message: 'email, subject, and message are required' 
            });
        }

        // Basic email validation
        if (!email.includes('@')) {
            return res.status(400).json({ 
                error: 'Invalid email format' 
            });
        }

        // Sanitize inputs (limit length)
        const sanitizedEmail = email.substring(0, 100);
        const sanitizedSubject = subject.substring(0, 200);
        const sanitizedMessage = message.substring(0, 5000);

        // Log support request to file
        const logEntry = {
            requestId,
            timestamp,
            ip: clientIp,
            email: sanitizedEmail,
            subject: sanitizedSubject,
            message: sanitizedMessage,
            apiKey: apiKey || 'none'
        };

        const logLine = `\n${'='.repeat(80)}\n` +
            `[${timestamp}] Support Request ${requestId}\n` +
            `IP: ${clientIp}\n` +
            `Email: ${sanitizedEmail}\n` +
            `API Key: ${apiKey || 'none'}\n` +
            `Subject: ${sanitizedSubject}\n` +
            `Message:\n${sanitizedMessage}\n` +
            `${'='.repeat(80)}\n`;

        // Write to support_requests.log (async, non-blocking)
        fs.appendFile(path.join(__dirname, 'logs', 'support_requests.log'), logLine)
            .catch(err => console.error('Failed to write support request log:', err));

        console.log(`[${timestamp}] ${requestId} - Support request received from ${sanitizedEmail}`);

        // Forward to email if configured
        if (emailTransporter && process.env.SUPPORT_EMAIL_TO) {
            try {
                const mailOptions = {
                    from: process.env.SMTP_USER,
                    to: process.env.SUPPORT_EMAIL_TO,
                    subject: `[Support] ${sanitizedSubject}`,
                    text: `Support Request ${requestId}\n` +
                          `Timestamp: ${timestamp}\n` +
                          `IP: ${clientIp}\n` +
                          `User Email: ${sanitizedEmail}\n` +
                          `API Key: ${apiKey || 'none'}\n\n` +
                          `Subject: ${sanitizedSubject}\n\n` +
                          `Message:\n${sanitizedMessage}`,
                    replyTo: sanitizedEmail // Allow direct reply to user
                };

                // Send email asynchronously (don't wait)
                emailTransporter.sendMail(mailOptions)
                    .then(info => {
                        console.log(`[${timestamp}] ${requestId} - Email sent: ${info.messageId}`);
                    })
                    .catch(err => {
                        console.error(`[${timestamp}] ${requestId} - Failed to send email:`, err);
                    });

                res.status(200).json({ 
                    success: true, 
                    message: 'Support request received and will be forwarded',
                    requestId 
                });
            } catch (err) {
                console.error(`[${timestamp}] ${requestId} - Email error:`, err);
                res.status(200).json({ 
                    success: true, 
                    message: 'Support request received and logged',
                    requestId,
                    note: 'Email forwarding failed but request was logged'
                });
            }
        } else {
            // Email not configured, just log
            res.status(200).json({ 
                success: true, 
                message: 'Support request received and logged',
                requestId 
            });
        }
    } catch (err) {
        console.error(`[${timestamp}] ${requestId} - Support endpoint error:`, err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// ------------------------------
// Admin Proxy (DISABLED for security)
// ------------------------------
// The admin proxy has been disabled to prevent unauthorized access to
// OpenSearch admin endpoints. If you need admin access, use SSH tunnel
// or access OpenSearch directly from the server.
app.use('/admin', (req, res) => {
    console.log(`BLOCKED admin access attempt: ${req.method} ${req.path} from ${req.ip}`);
    res.status(403).json({ error: 'Admin access disabled' });
});
// --- END: Middleware Chain ---

// Start the single HTTP server on port 3000
http.createServer(app).listen(3000, () => {
    console.log('HTTP proxy running on port 3000');
});

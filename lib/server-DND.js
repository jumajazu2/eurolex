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
app.options('/', cors(corsOptions));
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


app.get('/reset-rate-limit', (req, res) => {
    const ipToReset = req.query.ip;
    if (ipToReset) {
        ipRequestCounts.delete(ipToReset);
        console.log(`Rate limit counter reset for specific IP: ${ipToReset}`);
        return res.status(200).send(`Rate limit counter reset for IP: ${ipToReset}`);
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
    // Determine the rate limit based on the API key for this specific request.
    const reg = API_KEY_REGISTRY.get(req.apiKey);
    const isTrialKey = req.apiKey === 'trial';
    const maxRequests = reg && Number.isInteger(reg.dailyQuota)
        ? reg.dailyQuota
        : (isTrialKey ? 1000 : 100000);

    const clientIp = req.ip;
    const today = new Date().toISOString().slice(0, 10); // Get date in YYYY-MM-DD format

    let ipData = ipRequestCounts.get(clientIp);

    // If it's a new day for this IP, or the IP is new, reset the count.
    if (!ipData || ipData.date !== today) {
        ipData = { count: 0, date: today };
    }

    ipData.count += 1;
    ipRequestCounts.set(clientIp, ipData);

    const logMessage = `IP: ${clientIp}, Quota Used: ${ipData.count}/${maxRequests}, apikey: ${req.apiKey}`;
    console.log(logMessage);
    writeToAccessLog(logMessage); // Write to the persistent log file

    if (ipData.count > maxRequests) {
        const exceededMessage = `RATE LIMIT EXCEEDED for ${logMessage}`;
        console.log(exceededMessage);
        writeToAccessLog(exceededMessage);
        return res.status(429).json({
            error: 'Too Many Requests: You have exceeded the daily query limit.'
        });
    }

    next();
});

// --- START: Test-only endpoint to reset rate limits ---
// This endpoint is for development/testing and should be removed or
// secured in a production environment.


// 4. Log incoming headers to debug x-client-context.
app.use((req, res, next) => {
    // Log all headers to see exactly what is being received.
    console.log('--- INCOMING HEADERS ---');
    console.log(req.headers);
    console.log('--- END INCOMING HEADERS ---');

    const clientContext = req.headers['x-client-context'];
    if (clientContext) {
        console.log(`SUCCESS: Found x-client-context header: ${clientContext}`);
    }
    next();
});

// 6. NOW, validate the API key after logging and CORS have been handled.
app.use((req, res, next) => {
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
 * We support both the earlier `{ term, langs, type, options }` and
 * the minimal payload using a numeric `pattern` that maps to type/options.
 *
 * Pattern mapping (suggested defaults; can be adjusted):
 * 1 => text (should across langs)
 * 2 => phrase (slop: 2)
 * 3 => intervals (ordered; maxGaps: 1)
 * 4 => celex (exact)
 * 5 => text with paragraphsNotMatched: false filter
 */
function buildQuery({ term, langs = [], type = 'text', options = {}, pattern }) {
    const size = Number.isInteger(options.size) ? options.size : 10;
    const must = [];
    const filter = [];
    const should = [];

    // Optional filter used in analyser-based flows
    if (options.paragraphsNotMatchedFalse) {
        must.push({ term: { paragraphsNotMatched: false } });
    }

    // Language field names follow the pattern `${lang}_text`.
    const langFields = Array.isArray(langs) ? langs.map(l => `${l}_text`) : [];

    // Require existence of selected language fields if requested
    if (options.requireLangFields && langFields.length > 0) {
        langFields.forEach(f => filter.push({ exists: { field: f } }));
    }

    // If pattern provided, map it to type/options defaults
    if (Number.isInteger(pattern)) {
        switch (pattern) {
            case 2:
                type = 'phrase';
                options.slop = Number.isInteger(options.slop) ? options.slop : 2;
                break;
            case 3:
                type = 'intervals';
                options.maxGaps = Number.isInteger(options.maxGaps) ? options.maxGaps : 1;
                break;
            case 4:
                type = 'celex';
                break;
            case 5:
                type = 'text';
                options.paragraphsNotMatchedFalse = true;
                break;
            case 1:
            default:
                type = 'text';
        }
    }

    // Query construction by type
    if (type === 'celex') {
        // Exact match on celex keyword field
        must.push({ term: { celex: term } });
    } else if (type === 'phrase') {
        const slop = Number.isInteger(options.slop) ? options.slop : 0;
        langFields.forEach(field => {
            should.push({ match_phrase: { [field]: { query: term, slop } } });
        });
    } else if (type === 'intervals') {
        const maxGaps = Number.isInteger(options.maxGaps) ? options.maxGaps : 0;
        langFields.forEach(field => {
            // Basic intervals example using ordered tokens split by space
            // For more control, provide tokens via options.tokens
            const tokens = Array.isArray(options.tokens) && options.tokens.length > 0
                ? options.tokens
                : String(term).split(/\s+/).filter(Boolean);
            const orderedIntervals = {
                intervals: {
                    [field]: {
                        ordered: {
                            max_gaps: maxGaps,
                            // Map each token to a simple match interval
                            // More advanced patterns can be added as needed
                            // (e.g., gaps, non-overlapping constraints)
                            sub_sequences: tokens.map(t => ({
                                match: { query: t }
                            }))
                        }
                    }
                }
            };
            should.push(orderedIntervals);
        });
    } else {
        // Default full-text: bool.should across language fields
        langFields.forEach(field => {
            should.push({ match: { [field]: { query: term } } });
        });
    }

    const body = {
        size,
        query: {
            bool: {
                must: must.length ? must : undefined,
                filter: filter.length ? filter : undefined,
                should: should.length ? should : undefined,
                minimum_should_match: should.length ? 1 : undefined,
            }
        },
        // Highlight selected language fields for UI display
        highlight: langFields.length ? { fields: Object.fromEntries(langFields.map(f => [f, {}])) } : undefined,
    };

    return body;
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

// Route-level JSON parser to avoid interfering with proxy streaming
app.post('/search', express.json({ limit: '1mb' }), async (req, res) => {
    try {
        // Minimal payload expected from Flutter:
        // { email, passkey, index: string|'*', term: string, langs: string[], pattern: number }
        const { email, passkey, index, term, langs, pattern } = req.body || {};

        // Basic validation
        if (!passkey || typeof passkey !== 'string') {
            return res.status(400).json({ error: 'Invalid `passkey`' });
        }
        if (!term || typeof term !== 'string' || term.trim().length === 0) {
            return res.status(400).json({ error: 'Invalid `term`' });
        }
        if (!Array.isArray(langs) || langs.some(l => typeof l !== 'string')) {
            return res.status(400).json({ error: 'Invalid `langs` array' });
        }
        if (pattern !== undefined && !Number.isInteger(pattern)) {
            return res.status(400).json({ error: 'Invalid `pattern`' });
        }

        // Derive allowed index prefixes: prefer registry, fallback to pattern from passkey
        const registryEntry = API_KEY_REGISTRY.get(req.apiKey);
        const allowedPrefixes = (registryEntry && Array.isArray(registryEntry.allowPrefixes) && registryEntry.allowPrefixes.length > 0)
            ? registryEntry.allowPrefixes
            : [`eu_${passkey}_`];

        // Ensure header key equals body passkey to prevent cross-key usage
        if (req.apiKey !== passkey) {
            return res.status(403).json({ error: 'Forbidden: passkey mismatch with header key' });
        }

        // Resolve index selection: specific name or all (`*` => expand to prefix+`*`)
        let indexParam;
        if (index === '*') {
            // Search across all indices matching any allowed prefix
            // If multiple prefixes, you can join with comma (e.g., p1*,p2*)
            indexParam = allowedPrefixes.length === 1
                ? `${allowedPrefixes[0]}*`
                : allowedPrefixes.map(p => `${p}*`).join(',');
        } else if (typeof index === 'string') {
            if (!isValidIndexName(index)) {
                return res.status(400).json({ error: 'Invalid `index` name' });
            }
            const startsWithAllowed = allowedPrefixes.some(p => index.startsWith(p));
            if (!startsWithAllowed) {
                return res.status(403).json({ error: 'Index not permitted for this passkey' });
            }
            indexParam = index;
        } else {
            return res.status(400).json({ error: 'Missing or invalid `index`' });
        }

        // Optional: log email for analytics/debugging
        if (email && typeof email === 'string') {
            console.log(`Search requested by email: ${email}`);
        }

        const body = buildQuery({ term, langs, pattern });
        const result = await executeSearch(indexParam, body);
        res.status(result.statusCode || 200).json(result.body);
    } catch (err) {
        console.error('Search route error:', err);
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
// Legacy Proxy (admin-only)
// ------------------------------
// Keep the old proxy but restrict to admin paths. Adjust the path list
// as needed (e.g., '/_cat', '/_cluster', '/_snapshot', '/_ilm').
// Here we mount under '/admin' so only requests to /admin/* are proxied.
app.use('/admin', createProxyMiddleware({
    target: 'http://127.0.0.1:9200',
    changeOrigin: true,
    auth: 'admin:admin',
    agent: ipv4Agent,
    logLevel: 'debug',
    selfHandleResponse: true,
    on: {
        proxyRes: responseInterceptor(async (responseBuffer, proxyRes, req, res) => {
            console.log('--- RESPONSE FROM OPENSEARCH (admin proxy) ---');
            const responseString = responseBuffer.toString('utf8');
            const truncatedResponse = responseString.substring(0, 300);
            console.log(truncatedResponse + (responseString.length > 300 ? '...' : ''));
            console.log('--- END OF RESPONSE ---');
            return responseBuffer;
        }),
    },
}));
// --- END: Middleware Chain ---

// Start the single HTTP server on port 3000
http.createServer(app).listen(3000, () => {
    console.log('HTTP proxy running on port 3000');
});

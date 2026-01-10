const http = require('http');
const express = require('express');
const { createProxyMiddleware, responseInterceptor } = require('http-proxy-middleware');
// bodyParser is not needed as the proxy will stream the body directly.
const cors = require('cors');
const fs = require('fs/promises'); // For writing to the log file
const morgan = require('morgan'); // Import morgan for logging

const app = express();
app.set('trust proxy', true);


const VALID_API_KEYS = ['1234', '7239', 'trial']; // Example valid API keys

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
    const isTrialKey = req.apiKey === 'trial';
    const maxRequests = isTrialKey ? 1000 : 100000;

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
    if (!req.apiKey || !VALID_API_KEYS.includes(req.apiKey)) {
        console.log(`Unauthorized access attempt with key: ${req.apiKey} from IP: ${req.ip}`);
        return res.status(401).json({ error: 'Unauthorized: invalid API key' });
    }
    next();
});

// Create a custom agent to force IPv4 resolution for localhost.
// This is a common fix for Node.js v17+ DNS resolution behavior.
const ipv4Agent = new http.Agent({ family: 4 });

// 7. Finally, proxy authorized requests to OpenSearch.
app.use('/', createProxyMiddleware({
    target: 'http://127.0.0.1:9200',
    changeOrigin: true,
    auth: 'admin:admin',
    // Use the custom agent to prevent connection timeouts.
    agent: ipv4Agent,
    logLevel: 'debug',
    selfHandleResponse: true, // Required for response interception
    on: {
        proxyRes: responseInterceptor(async (responseBuffer, proxyRes, req, res) => {
            // Log the response from OpenSearch for debugging
            console.log('--- RESPONSE FROM OPENSEARCH ---');
            // Limiting the output to the first 300 characters for brevity.
            const responseString = responseBuffer.toString('utf8');
            const truncatedResponse = responseString.substring(0, 300);
            console.log(truncatedResponse + (responseString.length > 300 ? '...' : ''));
            console.log('--- END OF RESPONSE ---');

            // Return the original buffer to be sent to the client
            return responseBuffer;
        }),
    },
}));
// --- END: Middleware Chain ---

// Start the single HTTP server on port 3000
http.createServer(app).listen(3000, () => {
    console.log('HTTP proxy running on port 3000');
});

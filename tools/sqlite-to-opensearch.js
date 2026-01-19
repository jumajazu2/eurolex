/**
 * SQLite to OpenSearch Import Script
 * 
 * Install dependencies:
 *   npm install sqlite3
 * 
 * Usage:
 *   node tools/sqlite-to-opensearch.js
 */

const sqlite3 = require('sqlite3').verbose();
const http = require('http');

// ==================== CONFIGURATION ====================
const CONFIG = {
    // SQLite database
    sqliteDbPath: './your-database.db',
    sqliteTable: 'your_table_name',
    
    // OpenSearch
    opensearchHost: 'localhost',
    opensearchPort: 9200,
    opensearchIndex: 'eu_yourkey_yourindex', // Change to your index name
    
    // If using your server-DND.js proxy instead of direct OpenSearch:
    useProxy: false, // Set to true to use your proxy server
    proxyHost: 'localhost',
    proxyPort: 3000,
    apiKey: 'your-api-key', // Required if useProxy = true
    email: 'your-email@example.com', // Required if useProxy = true
    
    // Batch settings
    batchSize: 1000, // Number of records per bulk request
};

// ==================== METADATA FUNCTION ====================
/**
 * Add custom metadata to each record from SQLite
 * Modify this function to add your custom fields
 */
function addMetadata(record) {
    return {
        ...record, // Original fields from SQLite
        
        // Add your custom metadata here:
        importedAt: new Date().toISOString(),
        source: 'sqlite_import',
        version: '1.0',
        // Add more fields as needed
    };
}

// ==================== BULK UPLOAD ====================
function sendBulkToOpenSearch(bulkBody, indexName) {
    return new Promise((resolve, reject) => {
        const target = CONFIG.useProxy 
            ? { host: CONFIG.proxyHost, port: CONFIG.proxyPort, path: '/opensearch/_bulk' }
            : { host: CONFIG.opensearchHost, port: CONFIG.opensearchPort, path: '/_bulk' };
        
        const headers = {
            'Content-Type': 'application/x-ndjson',
        };
        
        // Add authentication headers
        if (CONFIG.useProxy) {
            headers['x-api-key'] = CONFIG.apiKey;
            headers['x-email'] = CONFIG.email;
        } else {
            // Direct OpenSearch: use Basic Auth
            const auth = Buffer.from('admin:admin').toString('base64');
            headers['Authorization'] = `Basic ${auth}`;
        }
        
        const options = {
            ...target,
            method: 'POST',
            headers,
        };
        
        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    const result = JSON.parse(data);
                    if (result.errors) {
                        console.error('Bulk request had errors:', JSON.stringify(result.items.slice(0, 3), null, 2));
                    }
                    resolve(result);
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                }
            });
        });
        
        req.on('error', reject);
        req.write(bulkBody);
        req.end();
    });
}

// ==================== MAIN IMPORT FUNCTION ====================
async function importFromSqlite() {
    console.log('Starting SQLite to OpenSearch import...\n');
    console.log('Configuration:');
    console.log(`  SQLite: ${CONFIG.sqliteDbPath} (table: ${CONFIG.sqliteTable})`);
    console.log(`  Target: ${CONFIG.useProxy ? 'Proxy Server' : 'Direct OpenSearch'}`);
    console.log(`  Index: ${CONFIG.opensearchIndex}`);
    console.log(`  Batch size: ${CONFIG.batchSize}\n`);
    
    const db = new sqlite3.Database(CONFIG.sqliteDbPath, sqlite3.OPEN_READONLY, (err) => {
        if (err) {
            console.error('Failed to connect to SQLite database:', err);
            process.exit(1);
        }
    });
    
    // Get total count
    const totalCount = await new Promise((resolve, reject) => {
        db.get(`SELECT COUNT(*) as count FROM ${CONFIG.sqliteTable}`, (err, row) => {
            if (err) reject(err);
            else resolve(row.count);
        });
    });
    
    console.log(`Found ${totalCount} records to import\n`);
    
    let batch = [];
    let processedCount = 0;
    let successCount = 0;
    let errorCount = 0;
    
    return new Promise((resolve, reject) => {
        db.each(
            `SELECT * FROM ${CONFIG.sqliteTable}`,
            async (err, row) => {
                if (err) {
                    console.error('Error reading row:', err);
                    errorCount++;
                    return;
                }
                
                // Add metadata to the record
                const enrichedRecord = addMetadata(row);
                
                // Add to batch
                batch.push(enrichedRecord);
                
                // Send batch when it reaches batchSize
                if (batch.length >= CONFIG.batchSize) {
                    const currentBatch = [...batch];
                    batch = [];
                    
                    try {
                        // Build bulk request body (NDJSON format)
                        const bulkBody = currentBatch.map(doc => {
                            // Use a unique ID if available, or let OpenSearch generate one
                            const action = doc.id 
                                ? JSON.stringify({ index: { _index: CONFIG.opensearchIndex, _id: doc.id } })
                                : JSON.stringify({ index: { _index: CONFIG.opensearchIndex } });
                            const source = JSON.stringify(doc);
                            return `${action}\n${source}`;
                        }).join('\n') + '\n';
                        
                        const result = await sendBulkToOpenSearch(bulkBody, CONFIG.opensearchIndex);
                        successCount += currentBatch.length;
                        processedCount += currentBatch.length;
                        
                        if (result.errors) {
                            const failedCount = result.items.filter(item => item.index.error).length;
                            errorCount += failedCount;
                            successCount -= failedCount;
                        }
                        
                        console.log(`Progress: ${processedCount}/${totalCount} (${Math.round(processedCount/totalCount*100)}%) - Success: ${successCount}, Errors: ${errorCount}`);
                    } catch (error) {
                        console.error('Bulk upload failed:', error.message);
                        errorCount += currentBatch.length;
                        processedCount += currentBatch.length;
                    }
                }
            },
            async (err, count) => {
                if (err) {
                    reject(err);
                    return;
                }
                
                // Send remaining records
                if (batch.length > 0) {
                    try {
                        const bulkBody = batch.map(doc => {
                            const action = doc.id 
                                ? JSON.stringify({ index: { _index: CONFIG.opensearchIndex, _id: doc.id } })
                                : JSON.stringify({ index: { _index: CONFIG.opensearchIndex } });
                            const source = JSON.stringify(doc);
                            return `${action}\n${source}`;
                        }).join('\n') + '\n';
                        
                        const result = await sendBulkToOpenSearch(bulkBody, CONFIG.opensearchIndex);
                        successCount += batch.length;
                        processedCount += batch.length;
                        
                        if (result.errors) {
                            const failedCount = result.items.filter(item => item.index.error).length;
                            errorCount += failedCount;
                            successCount -= failedCount;
                        }
                        
                        console.log(`Progress: ${processedCount}/${totalCount} (100%) - Success: ${successCount}, Errors: ${errorCount}`);
                    } catch (error) {
                        console.error('Final bulk upload failed:', error.message);
                        errorCount += batch.length;
                        processedCount += batch.length;
                    }
                }
                
                db.close();
                console.log('\n✅ Import completed!');
                console.log(`Total: ${totalCount}, Success: ${successCount}, Errors: ${errorCount}`);
                resolve();
            }
        );
    });
}

// ==================== RUN ====================
importFromSqlite()
    .then(() => process.exit(0))
    .catch(err => {
        console.error('Import failed:', err);
        process.exit(1);
    });

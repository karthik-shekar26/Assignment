const AWS = require('aws-sdk');
const mysql = require('mysql2/promise');

const secretsManager = new AWS.SecretsManager();

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    try {
        // Get database credentials from Secrets Manager
        const secretName = `${process.env.ENVIRONMENT}/rds/credentials`;
        const secretData = await secretsManager.getSecretValue({ SecretId: secretName }).promise();
        const credentials = JSON.parse(secretData.SecretString);
        
        console.log('Retrieved credentials from Secrets Manager');
        console.log('RDS Endpoint:', credentials.host);
        console.log('Database:', credentials.dbname);
        console.log('Username:', credentials.username);
        console.log('Port:', credentials.port);
        
        // Create database connection
        const connection = await mysql.createConnection({
            host: credentials.host,
            user: credentials.username,
            password: credentials.password,
            database: credentials.dbname,
            port: credentials.port,
            connectTimeout: 10000,
            acquireTimeout: 10000,
            timeout: 10000
        });
        
        console.log('✅ SUCCESS: Connected to RDS database!');
        
        // Create test table if it doesn't exist
        await connection.execute(`
            CREATE TABLE IF NOT EXISTS test_items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        `);
        
        console.log('✅ SUCCESS: Test table created/verified');
        
        // Insert a test item
        const testItem = {
            name: `Test Item ${Date.now()}`,
            description: `This is a test item created at ${new Date().toISOString()}`
        };
        
        const [insertResult] = await connection.execute(
            'INSERT INTO test_items (name, description) VALUES (?, ?)',
            [testItem.name, testItem.description]
        );
        
        console.log('✅ SUCCESS: Test item inserted successfully');
        console.log('Inserted ID:', insertResult.insertId);
        
        // Retrieve the inserted item
        const [rows] = await connection.execute(
            'SELECT * FROM test_items WHERE id = ?',
            [insertResult.insertId]
        );
        
        // Get total count
        const [countResult] = await connection.execute('SELECT COUNT(*) as total FROM test_items');
        
        // Get all items for demonstration
        const [allItems] = await connection.execute('SELECT * FROM test_items ORDER BY created_at DESC LIMIT 5');
        
        await connection.end();
        console.log('✅ SUCCESS: Database connection closed');
        
        const response = {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                message: 'Successfully connected to RDS and performed database operations!',
                timestamp: new Date().toISOString(),
                environment: process.env.ENVIRONMENT || 'dev',
                databaseOperations: {
                    connection: 'successful',
                    tableCreation: 'successful',
                    insert: 'successful',
                    select: 'successful'
                },
                insertedItem: rows[0],
                totalItems: countResult[0].total,
                recentItems: allItems,
                credentials: {
                    host: credentials.host,
                    database: credentials.dbname,
                    username: credentials.username,
                    port: credentials.port
                },
                event: event
            })
        };
        
        return response;
        
    } catch (error) {
        console.error('❌ ERROR:', error);
        
        const response = {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                message: 'Error connecting to RDS or performing database operations',
                error: error.message,
                timestamp: new Date().toISOString(),
                environment: process.env.ENVIRONMENT || 'dev',
                troubleshooting: [
                    'Check if RDS instance is running',
                    'Verify security group allows Lambda access on port 3306',
                    'Ensure Secrets Manager has correct credentials',
                    'Check VPC and subnet configuration',
                    'Verify Lambda has mysql2 layer attached',
                    'Check Lambda execution role permissions'
                ]
            })
        };
        
        return response;
    }
}; 
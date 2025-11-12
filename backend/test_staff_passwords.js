import mysql from 'mysql2';
import bcrypt from 'bcrypt';

const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'rentify'
});

db.connect(async (err) => {
    if (err) {
        console.error('Error connecting to the database:', err);
        process.exit(1);
    }
    console.log('Connected to the database.\n');

    // Test common passwords
    const testPasswords = ['password', '123456', 'staff123', 'robert', 'andrea'];
    
    db.query('SELECT staff_id, username, password_hash FROM staff', async (err, results) => {
        if (err) {
            console.error('Error querying staff table:', err);
            db.end();
            return;
        }

        for (const staff of results) {
            console.log(`\nTesting passwords for: ${staff.username}`);
            console.log('=====================================');
            
            for (const testPass of testPasswords) {
                try {
                    const isMatch = await bcrypt.compare(testPass, staff.password_hash);
                    if (isMatch) {
                        console.log(`✅ MATCH! Password is: "${testPass}"`);
                    }
                } catch (e) {
                    // Not a bcrypt hash, try direct comparison
                    if (staff.password_hash === testPass) {
                        console.log(`✅ MATCH! Password is: "${testPass}" (plain text)`);
                    }
                }
            }
        }
        
        console.log('\n\nTo login, use:');
        results.forEach(staff => {
            console.log(`Username: ${staff.username} (case-sensitive!)`);
        });
        
        db.end();
    });
});

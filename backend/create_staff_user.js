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
    console.log('Connected to the database.');

    try {
        // Hash the password
        const password_hash = await bcrypt.hash('staff123', 10);

        // Check if staff user already exists
        db.query(
            'SELECT user_id FROM users WHERE username = ?',
            ['staff'],
            (err, results) => {
                if (err) {
                    console.error('Error checking for existing staff user:', err);
                    db.end();
                    return;
                }

                if (results.length > 0) {
                    console.log('Staff user already exists with user_id:', results[0].user_id);
                    db.end();
                    return;
                }

                // Insert staff user
                db.query(
                    'INSERT INTO users (username, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, ?)',
                    ['staff', 'staff@rentify.com', password_hash, 'Staff Member', 'staff'],
                    (err, result) => {
                        if (err) {
                            console.error('Error creating staff user:', err);
                        } else {
                            console.log('✅ Staff user created successfully!');
                            console.log('   Username: staff');
                            console.log('   Password: staff123');
                            console.log('   User ID:', result.insertId);
                        }
                        db.end();
                    }
                );
            }
        );
    } catch (error) {
        console.error('Error:', error);
        db.end();
    }
});

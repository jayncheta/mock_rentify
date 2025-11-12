import mysql from 'mysql2';

const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'rentify'
});

db.connect((err) => {
    if (err) {
        console.error('Error connecting to the database:', err);
        process.exit(1);
    }
    console.log('Connected to the database.\n');

    // Check staff table
    db.query('SELECT staff_id, username, full_name, email, role, password_hash FROM staff', (err, results) => {
        if (err) {
            console.error('Error querying staff table:', err);
        } else {
            console.log('Staff users in database:');
            console.log('========================');
            results.forEach(staff => {
                console.log(`ID: ${staff.staff_id}`);
                console.log(`Username: ${staff.username}`);
                console.log(`Full Name: ${staff.full_name}`);
                console.log(`Email: ${staff.email}`);
                console.log(`Role: ${staff.role}`);
                console.log(`Password Hash: ${staff.password_hash ? (staff.password_hash.substring(0, 20) + '...') : 'NULL'}`);
                console.log('------------------------');
            });
            console.log(`Total staff users: ${results.length}\n`);
        }
        db.end();
    });
});

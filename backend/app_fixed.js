import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import mysql from 'mysql2';

const app = express();
app.use(cors());
app.use(bodyParser.json());

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
    } else {
        console.log('Connected to the database.');
    }
});

// Endpoint: List all items
app.get('/items', (req, res) => {
    const includeDisabled = req.query.includeDisabled === 'true';
    const query = includeDisabled 
        ? 'SELECT * FROM items' 
        : 'SELECT * FROM items WHERE availability_status = "Available"';
    
    db.query(query, (err, results) => {
        if (err) {
            console.error('Error fetching items:', err);
            return res.status(500).json({ error: err });
        }
        console.log(`Fetched ${results.length} items from database`);
        res.json(results);
    });
});

// Endpoint: Create a borrow request
app.post('/borrow-request', (req, res) => {
    const { item_id, borrower_id, lender_id, borrower_reason } = req.body;
    db.query(
        'INSERT INTO borrow_requests (item_id, borrower_id, lender_id, borrower_reason) VALUES (?, ?, ?, ?)',
        [item_id, borrower_id, lender_id, borrower_reason || ''],
        (err, result) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true, request_id: result.insertId });
        }
    );
});

// Endpoint: Get user info by ID
app.get('/users/:id', (req, res) => {
    db.query(
        'SELECT user_id, username, full_name, email, role FROM users WHERE user_id = ?',
        [req.params.id],
        (err, results) => {
            if (err) return res.status(500).json({ error: err });
            if (results.length === 0) {
                return res.status(404).json({ error: 'User not found' });
            }
            res.json(results[0]);
        }
    );
});

// Endpoint: Basic login
app.post('/login', (req, res) => {
    const { username, password } = req.body;
    console.log('Login attempt:', { username, password }); // Debug log
    
    db.query(
        'SELECT user_id, username, full_name, email, role, password_hash FROM users WHERE username = ?',
        [username],
        (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: err });
            }
            
            console.log('Query results:', results); // Debug log
            
            if (results.length === 0) {
                console.log('User not found');
                return res.status(403).json({ error: 'Invalid login' });
            }
            
            const user = results[0];
            
            // Check password - handles both plain text and hashed passwords
            if (user.password_hash === password || user.password_hash === null && password === '') {
                console.log('Login successful for user:', user.username);
                // Remove password_hash from response
                delete user.password_hash;
                res.json(user);
            } else {
                console.log('Password mismatch');
                return res.status(403).json({ error: 'Invalid login' });
            }
        }
    );
});

// Endpoint: User registration/signup
app.post('/signup', (req, res) => {
    const { username, email, password, full_name } = req.body;
    console.log('Signup attempt:', { username, email, full_name }); // Debug log
    
    // Validate required fields
    if (!username || !password || !email) {
        return res.status(400).json({ error: 'Username, email, and password are required' });
    }
    
    // Check if username already exists
    db.query(
        'SELECT user_id FROM users WHERE username = ? OR email = ?',
        [username, email],
        (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: err });
            }
            
            if (results.length > 0) {
                console.log('Username or email already exists');
                return res.status(409).json({ error: 'Username or email already exists' });
            }
            
            // Insert new user
            db.query(
                'INSERT INTO users (username, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, ?)',
                [username, email, password, full_name || username, 'User'],
                (err, result) => {
                    if (err) {
                        console.error('Error creating user:', err);
                        return res.status(500).json({ error: err });
                    }
                    
                    console.log('User created successfully:', username);
                    res.json({ 
                        success: true, 
                        user_id: result.insertId,
                        username: username,
                        email: email,
                        full_name: full_name || username,
                        role: 'User'
                    });
                }
            );
        }
    );
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Accessible at http://172.25.7.206:${PORT}`);
});


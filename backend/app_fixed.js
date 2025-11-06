import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import mysql from 'mysql2';
import bcrypt from 'bcrypt';

const app = express();
app.use(cors());
app.use(bodyParser.json());

// -------- DATABASE CONNECTION --------
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
    console.log('Connected to the database.');
});

// -------- GET ALL ITEMS --------
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
        res.json(results);
    });
});

// -------- CREATE BORROW REQUEST --------
app.post('/borrow-request', (req, res) => {
    const { item_id, borrower_id, lender_id, borrower_reason } = req.body;
    if (!item_id || !borrower_id || !lender_id) {
        return res.status(400).json({ error: "Missing required fields." });
    }
    db.query(
        'INSERT INTO borrow_requests (item_id, borrower_id, lender_id, borrower_reason) VALUES (?, ?, ?, ?)',
        [item_id, borrower_id, lender_id, borrower_reason || ''],
        (err, result) => {
            if (err) {
                console.error('Error inserting borrow_request:', err);
                return res.status(500).json({ error: err });
            }
            res.json({ success: true, request_id: result.insertId });
        }
    );
});

// -------- GET ALL BORROW REQUESTS --------
// Your Flutter app should use this endpoint!
app.get('/borrow-requests', (req, res) => {
    // Fix the JOINs and column names to match your actual MySQL schema
    db.query(`
        SELECT 
            br.request_id,
            br.item_id,
            br.borrower_id,
            br.lender_id,
            br.staff_processed_return_id,
            br.status,
            br.borrower_reason,
            br.lender_response,
            i.item_name,
            i.description AS item_description,
            i.availability_status
        FROM borrow_requests br
        LEFT JOIN items i ON br.item_id = i.item_id
        ORDER BY br.request_id DESC
    `, (err, results) => {
        if (err) {
            console.error('Error fetching borrow requests:', err);
            return res.status(500).json({ error: err });
        }
        res.json(results);
    });
});

// -------- GET BORROW REQUESTS FOR USER --------
app.get('/users/:userId/borrow-requests', (req, res) => {
    const { userId } = req.params;
    const { status } = req.query;

    let query = `
        SELECT 
            br.request_id,
            br.item_id,
            br.borrower_id,
            br.lender_id,
            br.status,
            br.borrower_reason,
            br.lender_response,
            br.staff_processed_return_id,
            i.item_name,
            i.description AS item_description,
            i.availability_status
        FROM borrow_requests br
        LEFT JOIN items i ON br.item_id = i.item_id
        WHERE br.borrower_id = ?
    `;
    const params = [userId];
    if (status) {
        query += ' AND br.status = ?';
        params.push(status);
    }
    query += ' ORDER BY br.request_id DESC';

    db.query(query, params, (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ error: err });
        }
        res.json(results);
    });
});

// Cancel/update borrow request status
app.patch('/borrow-requests/:requestId', (req, res) => {
    const { requestId } = req.params;
    const { status } = req.body;
    
    if (!status) {
        return res.status(400).json({ error: 'Status is required' });
    }
    
    console.log(`🔄 Updating borrow request ${requestId} to status: ${status}`);
    
    db.query(
        'UPDATE borrow_requests SET status = ? WHERE request_id = ?',
        [status, requestId],
        (err, result) => {
            if (err) {
                console.error('Error updating borrow request:', err);
                return res.status(500).json({ error: err });
            }
            if (result.affectedRows === 0) {
                return res.status(404).json({ error: 'Borrow request not found' });
            }
            console.log(`✅ Borrow request ${requestId} updated to ${status}`);
            res.json({ success: true, updated: result.affectedRows });
        }
    );
});

// -------- GET USER INFO --------
app.get('/users/:id', (req, res) => {
    db.query(
        'SELECT user_id, username, full_name, email, role FROM users WHERE user_id = ?',
        [req.params.id],
        (err, results) => {
            if (err) return res.status(500).json({ error: err });
            if (results.length === 0) return res.status(404).json({ error: 'User not found' });
            res.json(results[0]);
        }
    );
});

// -------- AUTH: LOGIN --------
app.post('/login', (req, res) => {
    const { username, password } = req.body;
    db.query(
        'SELECT user_id, username, full_name, email, role, password_hash FROM users WHERE username = ?',
        [username],
        async (err, results) => {
            if (err) return res.status(500).json({ error: err });
            if (results.length === 0) return res.status(403).json({ error: 'Invalid login' });
            const user = results[0];
            const isBcryptHash = user.password_hash?.startsWith('$2');
            let isPasswordValid = false;
            if (isBcryptHash)
                isPasswordValid = await bcrypt.compare(password, user.password_hash);
            else
                isPasswordValid = user.password_hash === password;
            // Auto-upgrade password_hash to bcrypt if they log in with their existing password
            if (!isBcryptHash && isPasswordValid) {
                const hashedPassword = await bcrypt.hash(password, 10);
                db.query(
                    'UPDATE users SET password_hash = ? WHERE user_id = ?',
                    [hashedPassword, user.user_id],
                    () => {}
                );
            }
            if (isPasswordValid) {
                delete user.password_hash;
                user.id = user.user_id;
                res.json(user);
            } else {
                return res.status(403).json({ error: 'Invalid login' });
            }
        }
    );
});

// -------- AUTH: SIGNUP --------
app.post('/signup', async (req, res) => {
    const { username, email, password, full_name } = req.body;
    if (!username || !password || !email) {
        return res.status(400).json({ error: 'Username, email, and password are required' });
    }
    db.query(
        'SELECT user_id FROM users WHERE username = ? OR email = ?',
        [username, email],
        async (err, results) => {
            if (err) return res.status(500).json({ error: err });
            if (results.length > 0)
                return res.status(409).json({ error: 'Username or email already exists' });
            try {
                const password_hash = await bcrypt.hash(password, 10);
                db.query(
                    'INSERT INTO users (username, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, ?)',
                    [username, email, password_hash, full_name || username, 'User'],
                    (err, result) => {
                        if (err) return res.status(500).json({ error: err });
                        res.json({
                            success: true,
                            id: result.insertId,
                            user_id: result.insertId,
                            username,
                            email,
                            full_name: full_name || username,
                            role: 'User'
                        });
                    }
                );
            } catch (err) {
                return res.status(500).json({ error: 'Password hashing failed.' });
            }
        }
    );
});

// -------- FAVORITES --------
app.get('/users/:userId/favorites', (req, res) => {
    db.query(
        'SELECT item_id FROM user_favorites WHERE user_id = ?',
        [req.params.userId],
        (err, results) => {
            if (err) return res.status(500).json({ error: err });
            const itemIds = results.map(row => row.item_id.toString());
            res.json({ favorites: itemIds });
        }
    );
});

app.post('/users/:userId/favorites', (req, res) => {
    db.query(
        'INSERT INTO user_favorites (user_id, item_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE user_id=user_id',
        [req.params.userId, req.body.item_id],
        (err) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true });
        }
    );
});

app.delete('/users/:userId/favorites/:itemId', (req, res) => {
    db.query(
        'DELETE FROM user_favorites WHERE user_id = ? AND item_id = ?',
        [req.params.userId, req.params.itemId],
        (err) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true });
        }
    );
});

// -------- START SERVER --------
const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Accessible at http://10.2.8.30:${PORT}`);
});
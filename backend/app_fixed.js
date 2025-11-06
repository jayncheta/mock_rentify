import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import mysql from 'mysql2';
import bcrypt from 'bcrypt';

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
    }
    console.log('Connected to the database.');
});

// Get all items
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

// Create borrow request (history logging)
app.post('/borrow-request', (req, res) => {
    const { 
        item_id, 
        borrower_id, 
        lender_id, 
        borrower_reason,
        borrow_date,
        return_date
    } = req.body;
    
    console.log('📝 Creating borrow request:', { item_id, borrower_id, lender_id, borrow_date, return_date });
    
    db.beginTransaction((err) => {
        if (err) {
            console.error('Transaction error:', err);
            return res.status(500).json({ error: err });
        }
        
        db.query(
            'INSERT INTO borrow_requests (item_id, borrower_id, lender_id, borrower_reason) VALUES (?, ?, ?, ?)',
            [item_id, borrower_id, lender_id, borrower_reason || ''],
            (err, result) => {
                if (err) {
                    return db.rollback(() => {
                        console.error('Error inserting borrow_request:', err);
                        res.status(500).json({ error: err });
                    });
                }
                
                const requestId = result.insertId;
                console.log('✅ Borrow request created:', requestId);
                
                // Insert into history table
                db.query(
                    'INSERT INTO history (user_id, item_id, borrow_date, return_date, status, borrower_reason) VALUES (?, ?, ?, ?, ?, ?)',
                    [borrower_id, item_id, borrow_date, return_date, 'Pending', borrower_reason || ''],
                    (err, historyResult) => {
                        if (err) {
                            return db.rollback(() => {
                                console.error('Error inserting history:', err);
                                res.status(500).json({ error: err });
                            });
                        }
                        
                        db.commit((err) => {
                            if (err) {
                                return db.rollback(() => {
                                    console.error('Commit error:', err);
                                    res.status(500).json({ error: err });
                                });
                            }
                            
                            console.log('✅ History entry created:', historyResult.insertId);
                            res.json({ 
                                success: true, 
                                request_id: requestId,
                                history_id: historyResult.insertId
                            });
                        });
                    }
                );
            }
        );
    });
});

// Get user info by ID
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

// User login with bcrypt
app.post('/login', (req, res) => {
    const { username, password } = req.body;
    console.log('Login attempt:', { username });

    db.query(
        'SELECT user_id, username, full_name, email, role, password_hash FROM users WHERE username = ?',
        [username],
        async (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: err });
            }

            if (results.length === 0) {
                console.log('User not found');
                return res.status(403).json({ error: 'Invalid login' });
            }

            const user = results[0];

            try {
                // Check if password is bcrypt hashed (starts with $2b$ or $2a$)
                const isBcryptHash = user.password_hash && user.password_hash.startsWith('$2');
                
                let isPasswordValid = false;
                
                if (isBcryptHash) {
                    // Use bcrypt compare for hashed passwords
                    isPasswordValid = await bcrypt.compare(password, user.password_hash);
                } else {
                    // Direct comparison for plain text passwords (legacy)
                    isPasswordValid = (user.password_hash === password);
                    
                    // If login successful with plain text, update to hashed password
                    if (isPasswordValid) {
                        console.log('⚠️ Plain text password detected, upgrading to bcrypt...');
                        const hashedPassword = await bcrypt.hash(password, 10);
                        db.query(
                            'UPDATE users SET password_hash = ? WHERE user_id = ?',
                            [hashedPassword, user.user_id],
                            (updateErr) => {
                                if (updateErr) {
                                    console.error('Failed to update password hash:', updateErr);
                                } else {
                                    console.log('✅ Password upgraded to bcrypt for user:', user.username);
                                }
                            }
                        );
                    }
                }

                if (isPasswordValid) {
                    console.log('Login successful for user:', user.username);
                    delete user.password_hash;
                    res.json(user);
                } else {
                    console.log('Password mismatch');
                    return res.status(403).json({ error: 'Invalid login' });
                }
            } catch (compareErr) {
                console.error('Error comparing password:', compareErr);
                return res.status(500).json({ error: 'Password check failed' });
            }
        }
    );
});

// User signup with bcrypt
app.post('/signup', async (req, res) => {
    const { username, email, password, full_name } = req.body;
    console.log('Signup attempt:', { username, email, full_name });

    if (!username || !password || !email) {
        return res.status(400).json({ error: 'Username, email, and password are required' });
    }

    db.query(
        'SELECT user_id FROM users WHERE username = ? OR email = ?',
        [username, email],
        async (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: err });
            }

            if (results.length > 0) {
                console.log('Username or email already exists');
                return res.status(409).json({ error: 'Username or email already exists' });
            }

            console.log('✨ ABOUT TO HASH PASSWORD - THIS LINE SHOULD ALWAYS SHOW');

            // Hash the password before storing
            try {
                console.log('🔐 Hashing password...');
                const password_hash = await bcrypt.hash(password, 10);
                console.log('✅ Password hashed successfully:', password_hash.substring(0, 20) + '...');
                
                db.query(
                    'INSERT INTO users (username, email, password_hash, full_name, role) VALUES (?, ?, ?, ?, ?)',
                    [username, email, password_hash, full_name || username, 'User'],
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
            } catch (hashErr) {
                console.error('Hashing error:', hashErr);
                return res.status(500).json({ error: 'Password hashing failed.' });
            }
        }
    );
});

// Get user's favorite item IDs
app.get('/users/:userId/favorites', (req, res) => {
    const { userId } = req.params;
    console.log(`Fetching favorites for user: ${userId}`);

    db.query(
        'SELECT item_id FROM user_favorites WHERE user_id = ?',
        [userId],
        (err, results) => {
            if (err) {
                console.error('Error fetching favorites:', err);
                return res.status(500).json({ error: err });
            }
            console.log(`Found ${results.length} favorites for user ${userId}`);
            const itemIds = results.map(row => row.item_id.toString());
            res.json({ favorites: itemIds });
        }
    );
});

// Add item to favorites
app.post('/users/:userId/favorites', (req, res) => {
    const { userId } = req.params;
    const { item_id } = req.body;

    db.query(
        'INSERT INTO user_favorites (user_id, item_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE user_id=user_id',
        [userId, item_id],
        (err) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true });
        }
    );
});

// Remove item from favorites
app.delete('/users/:userId/favorites/:itemId', (req, res) => {
    const { userId, itemId } = req.params;

    db.query(
        'DELETE FROM user_favorites WHERE user_id = ? AND item_id = ?',
        [userId, itemId],
        (err) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true });
        }
    );
});

// ============ HISTORY TABLE API ENDPOINTS ============

// Get all history entries with user and item details
app.get('/history', (req, res) => {
    const { status, user_id } = req.query;
    
    let query = `
        SELECT 
            h.*,
            u.username,
            u.full_name,
            u.email,
            i.item_name,
            i.item_type,
            i.brand
        FROM history h
        LEFT JOIN users u ON h.user_id = u.user_id
        LEFT JOIN items i ON h.item_id = i.item_id
    `;
    
    const conditions = [];
    const params = [];
    
    if (status) {
        conditions.push('h.status = ?');
        params.push(status);
    }
    
    if (user_id) {
        conditions.push('h.user_id = ?');
        params.push(user_id);
    }
    
    if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
    }
    
    query += ' ORDER BY h.created_at DESC';
    
    console.log('📜 Fetching history entries...');
    
    db.query(query, params, (err, results) => {
        if (err) {
            console.error('Error fetching history:', err);
            return res.status(500).json({ error: err });
        }
        console.log(`✅ Found ${results.length} history entries`);
        res.json(results);
    });
});

// Get specific user's borrow history
app.get('/history/user/:userId', (req, res) => {
    const { userId } = req.params;
    const { status } = req.query;
    
    let query = `
        SELECT 
            h.*,
            i.item_name,
            i.item_type,
            i.brand,
            i.image_path
        FROM history h
        LEFT JOIN items i ON h.item_id = i.item_id
        WHERE h.user_id = ?
    `;
    
    const params = [userId];
    
    if (status) {
        query += ' AND h.status = ?';
        params.push(status);
    }
    
    query += ' ORDER BY h.created_at DESC';
    
    console.log(`📜 Fetching history for user ${userId}`);
    
    db.query(query, params, (err, results) => {
        if (err) {
            console.error('Error fetching user history:', err);
            return res.status(500).json({ error: err });
        }
        console.log(`✅ Found ${results.length} history entries for user ${userId}`);
        res.json(results);
    });
});

// Get specific history entry by ID
app.get('/history/:historyId', (req, res) => {
    const { historyId } = req.params;
    
    const query = `
        SELECT 
            h.*,
            u.username,
            u.full_name,
            u.email,
            i.item_name,
            i.item_type,
            i.brand,
            i.image_path
        FROM history h
        LEFT JOIN users u ON h.user_id = u.user_id
        LEFT JOIN items i ON h.item_id = i.item_id
        WHERE h.history_id = ?
    `;
    
    db.query(query, [historyId], (err, results) => {
        if (err) {
            console.error('Error fetching history entry:', err);
            return res.status(500).json({ error: err });
        }
        if (results.length === 0) {
            return res.status(404).json({ error: 'History entry not found' });
        }
        console.log(`✅ Found history entry: ${historyId}`);
        res.json(results[0]);
    });
});

// Update history entry (status, return_date, lender_response, is_late_flagged)
app.put('/history/:historyId', (req, res) => {
    const { historyId } = req.params;
    const { status, return_date, lender_response, is_late_flagged } = req.body;
    
    const updates = [];
    const params = [];
    
    if (status) {
        updates.push('status = ?');
        params.push(status);
    }
    
    if (return_date !== undefined) {
        updates.push('return_date = ?');
        params.push(return_date);
    }
    
    if (lender_response !== undefined) {
        updates.push('lender_response = ?');
        params.push(lender_response);
    }
    
    if (is_late_flagged !== undefined) {
        updates.push('is_late_flagged = ?');
        params.push(is_late_flagged);
    }
    
    if (updates.length === 0) {
        return res.status(400).json({ error: 'No fields to update' });
    }
    
    params.push(historyId);
    const query = `UPDATE history SET ${updates.join(', ')} WHERE history_id = ?`;
    
    console.log(`🔄 Updating history entry ${historyId}:`, { status, return_date, lender_response, is_late_flagged });
    
    db.query(query, params, (err, result) => {
        if (err) {
            console.error('Error updating history:', err);
            return res.status(500).json({ error: err });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ error: 'History entry not found' });
        }
        console.log(`✅ History entry ${historyId} updated successfully`);
        res.json({ success: true, updated: result.affectedRows });
    });
});

// Update only status (quick endpoint)
app.patch('/history/:historyId/status', (req, res) => {
    const { historyId } = req.params;
    const { status } = req.body;
    
    if (!status) {
        return res.status(400).json({ error: 'Status is required' });
    }
    
    console.log(`🔄 Updating status for history ${historyId} to: ${status}`);
    
    db.query(
        'UPDATE history SET status = ? WHERE history_id = ?',
        [status, historyId],
        (err, result) => {
            if (err) {
                console.error('Error updating status:', err);
                return res.status(500).json({ error: err });
            }
            if (result.affectedRows === 0) {
                return res.status(404).json({ error: 'History entry not found' });
            }
            console.log(`✅ Status updated for history ${historyId}`);
            res.json({ success: true, updated: result.affectedRows });
        }
    );
});

// Update lender response
app.patch('/history/:historyId/response', (req, res) => {
    const { historyId } = req.params;
    const { lender_response } = req.body;
    
    if (!lender_response) {
        return res.status(400).json({ error: 'Lender response is required' });
    }
    
    console.log(`💬 Adding lender response for history ${historyId}`);
    
    db.query(
        'UPDATE history SET lender_response = ? WHERE history_id = ?',
        [lender_response, historyId],
        (err, result) => {
            if (err) {
                console.error('Error updating lender response:', err);
                return res.status(500).json({ error: err });
            }
            if (result.affectedRows === 0) {
                return res.status(404).json({ error: 'History entry not found' });
            }
            console.log(`✅ Lender response added for history ${historyId}`);
            res.json({ success: true, updated: result.affectedRows });
        }
    );
});

// Delete history entry (if needed)
app.delete('/history/:historyId', (req, res) => {
    const { historyId } = req.params;
    
    console.log(`🗑️ Deleting history entry ${historyId}`);
    
    db.query(
        'DELETE FROM history WHERE history_id = ?',
        [historyId],
        (err, result) => {
            if (err) {
                console.error('Error deleting history:', err);
                return res.status(500).json({ error: err });
            }
            if (result.affectedRows === 0) {
                return res.status(404).json({ error: 'History entry not found' });
            }
            console.log(`✅ History entry ${historyId} deleted`);
            res.json({ success: true, deleted: result.affectedRows });
        }
    );
});

// Get history by item_id (to see who borrowed an item)
app.get('/history/item/:itemId', (req, res) => {
    const { itemId } = req.params;
    const { status } = req.query;
    
    let query = `
        SELECT 
            h.*,
            u.username,
            u.full_name,
            u.email
        FROM history h
        LEFT JOIN users u ON h.user_id = u.user_id
        WHERE h.item_id = ?
    `;
    
    const params = [itemId];
    
    if (status) {
        query += ' AND h.status = ?';
        params.push(status);
    }
    
    query += ' ORDER BY h.created_at DESC';
    
    console.log(`📜 Fetching history for item ${itemId}`);
    
    db.query(query, params, (err, results) => {
        if (err) {
            console.error('Error fetching item history:', err);
            return res.status(500).json({ error: err });
        }
        console.log(`✅ Found ${results.length} history entries for item ${itemId}`);
        res.json(results);
    });
});

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Accessible at http://172.25.4.100:${PORT}`);
});
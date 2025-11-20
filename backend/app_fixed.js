import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import mysql from 'mysql2';
import bcrypt from 'bcrypt';

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Serve images from the 'images' folder as static files
app.use('/images', express.static('images'));

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
    const baseCondition = includeDisabled ? '1=1' : 'i.availability_status = "Available"';
    const sql = `SELECT i.*, l.full_name AS lender_name \n               FROM items i \n               LEFT JOIN lender l ON i.lender_id = l.lender_id \n               WHERE ${baseCondition} \n               ORDER BY i.item_id DESC`;
    db.query(sql, (err, results) => {
        if (err) {
            console.error('Error fetching items:', err);
            return res.status(500).json({ error: err });
        }
        res.json(results);
    });
});

// -------- CREATE BORROW REQUEST (validates item availability) --------
app.post('/borrow-request', (req, res) => {
    const { item_id, borrower_id, lender_id, borrower_reason, borrow_date, return_date } = req.body;
    if (!item_id || !borrower_id || !lender_id) {
        return res.status(400).json({ error: 'Missing required fields.' });
    }

    // Check item availability before allowing borrow
    db.query('SELECT availability_status FROM items WHERE item_id = ?', [item_id], (err, rows) => {
        if (err) {
            console.error('Error checking item availability:', err);
            return res.status(500).json({ error: 'Database error.' });
        }
        if (!rows || rows.length === 0) {
            return res.status(404).json({ error: 'Item not found.' });
        }
        const status = (rows[0].availability_status || '').toString().toLowerCase();
        // Treat anything not exactly 'available' as blocked (e.g. Disabled, Unavailable)
        if (status !== 'available') {
            return res.status(400).json({ error: 'Item is not available for borrowing.' });
        }

        // Proceed to insert borrow request now that item is confirmed available
        db.query(
            'INSERT INTO borrow_requests (item_id, borrower_id, lender_id, borrower_reason, borrow_date, return_date) VALUES (?, ?, ?, ?, ?, ?)',
            [item_id, borrower_id, lender_id, borrower_reason || '', borrow_date || null, return_date || null],
            (err2, result) => {
                if (err2) {
                    console.error('Error inserting borrow_request:', err2);
                    return res.status(500).json({ error: 'Failed to create borrow request.' });
                }
                res.json({ success: true, request_id: result.insertId });
            }
        );
    });
});

// -------- GET ALL BORROW REQUESTS (includes lender name) --------
app.get('/borrow-requests', (req, res) => {
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
            br.borrow_date,
            br.return_date,
            i.item_name,
            i.description AS item_description,
            i.availability_status,
            i.image_url,
            u.full_name AS borrower_name,
            l.full_name AS lender_name
        FROM borrow_requests br
        LEFT JOIN items i ON br.item_id = i.item_id
        LEFT JOIN users u ON br.borrower_id = u.user_id
        LEFT JOIN lender l ON br.lender_id = l.lender_id
        ORDER BY br.request_id DESC
    `, (err, results) => {
        if (err) {
            console.error('Error fetching borrow requests:', err);
            return res.status(500).json({ error: err });
        }
        res.json(results);
    });
});

// -------- GET SINGLE BORROW REQUEST --------
app.get('/borrow-requests/:requestId', (req, res) => {
    const { requestId } = req.params;
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
            br.borrow_date,
            br.return_date,
            i.item_name,
            i.description AS item_description,
            i.availability_status,
            i.image_url,
            u.full_name AS borrower_name,
            l.full_name AS lender_name
        FROM borrow_requests br
        LEFT JOIN items i ON br.item_id = i.item_id
        LEFT JOIN users u ON br.borrower_id = u.user_id
        LEFT JOIN lender l ON br.lender_id = l.lender_id
        WHERE br.request_id = ?
        LIMIT 1
    `, [requestId], (err, results) => {
        if (err) {
            console.error('Error fetching single borrow request:', err);
            return res.status(500).json({ error: 'Database error.' });
        }
        if (!results || results.length === 0) {
            return res.status(404).json({ error: 'Borrow request not found.' });
        }
        res.json(results[0]);
    });
});

// Get borrow requests for a specific user (includes lender name)
app.get('/users/:userId/borrow-requests', (req, res) => {
    const { userId } = req.params;
    
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
            br.borrow_date,
            br.return_date,
            i.item_name,
            i.description AS item_description,
            i.availability_status,
            i.image_url,
            l.full_name AS lender_name
        FROM borrow_requests br
        LEFT JOIN items i ON br.item_id = i.item_id
        LEFT JOIN lender l ON br.lender_id = l.lender_id
        WHERE br.borrower_id = ?
        ORDER BY br.request_id DESC
    `, [userId], (err, results) => {
        if (err) {
            console.error('Error fetching user borrow requests:', err);
            return res.status(500).json({ error: err });
        }
        res.json(results);
    });
});

// Cancel/update borrow request status
app.patch('/borrow-requests/:requestId', (req, res) => {
    const { requestId } = req.params;
    const { status, lender_response, return_item, late_return, staff_processed_return_id } = req.body;
    
    if (!status) {
        return res.status(400).json({ error: 'Status is required' });
    }
    
    console.log(`🔄 Updating borrow request ${requestId}`, { status, return_item, late_return });
    
    // First, check current status (except for return operations which need Approved status)
    if (return_item !== true) {
        console.log(`🔍 Checking current status for request ${requestId} before approval/rejection...`);
        // For approve/reject operations, check if status is Pending
        db.query(
            'SELECT status FROM borrow_requests WHERE request_id = ?',
            [requestId],
            (err, rows) => {
                if (err) {
                    console.error('Error fetching request status:', err);
                    return res.status(500).json({ error: err.message });
                }
                
                if (!rows || rows.length === 0) {
                    return res.status(404).json({ error: 'Borrow request not found' });
                }
                
                const currentStatus = (rows[0].status || '').toString();
                console.log(`📊 Current status: "${currentStatus}", Attempting to change to: "${status}"`);
                
                // Only allow status updates if current status is Pending
                if (currentStatus.toLowerCase() !== 'pending') {
                    console.log(`❌ BLOCKED: Cannot update from ${currentStatus} to ${status}`);
                    return res.status(400).json({ 
                        error: `Cannot update request. Current status is ${currentStatus}`,
                        current_status: currentStatus
                    });
                }
                
                // If approving, check if borrower already has an approved item
                if (status.toLowerCase() === 'approved') {
                    // Get the borrower_id from the current request
                    db.query(
                        'SELECT borrower_id FROM borrow_requests WHERE request_id = ?',
                        [requestId],
                        (err, borrowerRows) => {
                            if (err) {
                                console.error('Error fetching borrower_id:', err);
                                return res.status(500).json({ error: err.message });
                            }
                            
                            const borrowerId = borrowerRows[0].borrower_id;
                            
                            // Check if this borrower has any other approved requests
                            db.query(
                                'SELECT request_id, item_id FROM borrow_requests WHERE borrower_id = ? AND status = ? AND request_id != ?',
                                [borrowerId, 'Approved', requestId],
                                (err, approvedRows) => {
                                    if (err) {
                                        console.error('Error checking existing approved requests:', err);
                                        return res.status(500).json({ error: err.message });
                                    }
                                    
                                    if (approvedRows && approvedRows.length > 0) {
                                        console.log(`❌ BLOCKED: User ${borrowerId} already has ${approvedRows.length} approved request(s)`);
                                        return res.status(400).json({ 
                                            error: 'User already has an approved item. Only one item can be borrowed at a time.',
                                            existing_approved_request: approvedRows[0].request_id
                                        });
                                    }
                                    
                                    console.log(`✅ User ${borrowerId} has no other approved requests, proceeding...`);
                                    // Proceed with the approval
                                    performStatusUpdate();
                                }
                            );
                        }
                    );
                } else {
                    // Not an approval, just update status (e.g., Declined)
                    performStatusUpdate();
                }
                
                function performStatusUpdate() {
                    console.log(`✅ Status check passed, proceeding with update...`);
                    // Proceed with status update
                    const updates = ['status = ?'];
                    const values = [status];
                    
                    if (lender_response !== undefined) {
                        updates.push('lender_response = ?');
                        values.push(lender_response);
                    }
                    
                    values.push(requestId);
                    
                    db.query(
                        `UPDATE borrow_requests SET ${updates.join(', ')} WHERE request_id = ?`,
                        values,
                        (err, result) => {
                            if (err) {
                                console.error('Error updating borrow request:', err);
                                return res.status(500).json({ error: err.message });
                            }
                            if (result.affectedRows === 0) {
                                return res.status(404).json({ error: 'Borrow request not found' });
                            }
                            console.log(`✅ Borrow request ${requestId} updated to ${status}`);
                            res.json({ success: true, updated: result.affectedRows });
                        }
                    );
                }
            }
        );
        return; // Exit early
    }
    
    // Handle return - move from borrow_requests to history
    if (return_item === true) {
        // First, get the borrow request details
        db.query(
            `SELECT br.*, i.item_name, u.username as borrower_name, i.image_url
             FROM borrow_requests br
             JOIN items i ON br.item_id = i.item_id
             JOIN users u ON br.borrower_id = u.user_id
             WHERE br.request_id = ?`,
            [requestId],
            (err, requests) => {
                if (err) {
                    console.error('Error fetching borrow request:', err);
                    return res.status(500).json({ error: err.message });
                }
                
                if (requests.length === 0) {
                    return res.status(404).json({ error: 'Borrow request not found' });
                }
                
                const request = requests[0];
                const historyStatus = late_return ? 'Returned_Late' : 'Returned';
                
                console.log(`📝 Inserting into history:`, {
                    user_id: request.borrower_id,
                    item_id: request.item_id,
                    status: historyStatus,
                    is_late_flagged: late_return ? 1 : 0
                });
                
                // Insert into history table (using actual schema)
                db.query(
                    `INSERT INTO history (user_id, item_id, borrow_date, return_date, status, 
                     borrower_reason, lender_response, is_late_flagged)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
                    [
                        request.borrower_id,
                        request.item_id,
                        request.borrow_date,
                        request.return_date,
                        historyStatus,
                        request.borrower_reason,
                        request.lender_response,
                        late_return ? 1 : 0
                    ],
                    (err, result) => {
                        if (err) {
                            console.error('❌ Error inserting into history:', {
                                code: err.code,
                                sqlMessage: err.sqlMessage,
                                sql: err.sql
                            });
                            return res.status(500).json({ 
                                error: 'Failed to insert into history',
                                details: err.sqlMessage 
                            });
                        }
                        
                        // Delete from borrow_requests
                        db.query(
                            'DELETE FROM borrow_requests WHERE request_id = ?',
                            [requestId],
                            (err, deleteResult) => {
                                if (err) {
                                    console.error('Error deleting borrow request:', err);
                                    return res.status(500).json({ error: err.message });
                                }
                                
                                console.log(`✅ Request ${requestId} moved to history as ${historyStatus}`);
                                res.json({ success: true, moved_to_history: true });
                            }
                        );
                    }
                );
            }
        );
    }
});

// -------- CANCEL BORROW REQUEST (borrower initiated) --------
app.patch('/borrow-requests/:requestId/cancel', (req, res) => {
    const { requestId } = req.params;
    const { borrower_id } = req.body;
    if (!borrower_id) {
        return res.status(400).json({ error: 'borrower_id required' });
    }
    // Fetch request to validate ownership and status
    db.query(
        'SELECT request_id, borrower_id, status FROM borrow_requests WHERE request_id = ?',
        [requestId],
        (err, rows) => {
            if (err) {
                console.error('Error fetching borrow request for cancel:', err);
                return res.status(500).json({ error: 'Database error.' });
            }
            if (!rows || rows.length === 0) {
                return res.status(404).json({ error: 'Borrow request not found.' });
            }
            const r = rows[0];
            if (parseInt(r.borrower_id) !== parseInt(borrower_id)) {
                return res.status(403).json({ error: 'Not authorized to cancel this request.' });
            }
            const currStatus = (r.status || '').toString().toLowerCase();
            if (currStatus !== 'pending') {
                return res.status(400).json({ error: 'Only pending requests can be cancelled.' });
            }
            db.query(
                'UPDATE borrow_requests SET status = ? WHERE request_id = ?',
                ['Canceled', requestId],
                (err2, result) => {
                    if (err2) {
                        console.error('Error cancelling borrow request:', {
                            code: err2.code,
                            sqlMessage: err2.sqlMessage,
                            message: err2.message
                        });
                        return res.status(500).json({ 
                            error: 'Failed to cancel request.',
                            details: err2.sqlMessage || err2.message
                        });
                    }
                    if (result.affectedRows === 0) {
                        return res.status(404).json({ error: 'Borrow request not found.' });
                    }
                    res.json({ success: true, cancelled: true, request_id: requestId });
                }
            );
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
    
    console.log('Login attempt - Username:', username, 'Password length:', password?.length);
    
    // First try to login as staff
    db.query(
        'SELECT staff_id, username, full_name, email, role, password_hash FROM staff WHERE username = ?',
        [username],
        async (err, staffResults) => {
            if (err) {
                console.error('Error querying staff table:', err);
                return res.status(500).json({ error: err });
            }
            
            console.log('Staff query results:', staffResults.length, 'found');
            
            // If found in staff table
            if (staffResults.length > 0) {
                const staff = staffResults[0];
                console.log('Staff found:', staff.username, 'Role:', staff.role);
                console.log('Password hash starts with:', staff.password_hash?.substring(0, 10));
                
                const isBcryptHash = staff.password_hash?.startsWith('$2');
                let isPasswordValid = false;
                
                if (isBcryptHash) {
                    isPasswordValid = await bcrypt.compare(password, staff.password_hash);
                    console.log('Bcrypt comparison result:', isPasswordValid);
                } else {
                    isPasswordValid = staff.password_hash === password;
                    console.log('Plain text comparison result:', isPasswordValid);
                }
                
                // Auto-upgrade password_hash to bcrypt if they log in with their existing password
                if (!isBcryptHash && isPasswordValid) {
                    const hashedPassword = await bcrypt.hash(password, 10);
                    db.query(
                        'UPDATE staff SET password_hash = ? WHERE staff_id = ?',
                        [hashedPassword, staff.staff_id],
                        () => {}
                    );
                }
                
                if (isPasswordValid) {
                    delete staff.password_hash;
                    staff.id = staff.staff_id;
                    staff.user_id = staff.staff_id;
                    staff.role = staff.role.toLowerCase();
                    console.log('✅ Staff login successful:', staff.username);
                    res.json(staff);
                } else {
                    console.log('❌ Invalid password for staff:', staff.username);
                    return res.status(403).json({ error: 'Invalid login' });
                }
            } else {
                console.log('Not found in staff table, checking lender table...');
                // If not found in staff table, try lender table
                db.query(
                    'SELECT lender_id, username, full_name, email, role, password_hash FROM lender WHERE username = ?',
                    [username],
                    async (err, lenderResults) => {
                        if (err) {
                            console.error('Error querying lender table:', err);
                            return res.status(500).json({ error: err });
                        }
                        
                        console.log('Lender query results:', lenderResults.length, 'found');
                        
                        // If found in lender table
                        if (lenderResults.length > 0) {
                            const lender = lenderResults[0];
                            console.log('Lender found:', lender.username, 'Role:', lender.role);
                            
                            const isBcryptHash = lender.password_hash?.startsWith('$2');
                            let isPasswordValid = false;
                            
                            if (isBcryptHash) {
                                isPasswordValid = await bcrypt.compare(password, lender.password_hash);
                                console.log('Bcrypt comparison result:', isPasswordValid);
                            } else {
                                isPasswordValid = lender.password_hash === password;
                                console.log('Plain text comparison result:', isPasswordValid);
                            }
                            
                            // Auto-upgrade password_hash to bcrypt if they log in with their existing password
                            if (!isBcryptHash && isPasswordValid) {
                                const hashedPassword = await bcrypt.hash(password, 10);
                                db.query(
                                    'UPDATE lender SET password_hash = ? WHERE lender_id = ?',
                                    [hashedPassword, lender.lender_id],
                                    () => {}
                                );
                            }
                            
                            if (isPasswordValid) {
                                delete lender.password_hash;
                                lender.id = lender.lender_id;
                                lender.user_id = lender.lender_id;
                                lender.role = 'lender';
                                console.log('✅ Lender login successful:', lender.username);
                                res.json(lender);
                            } else {
                                console.log('❌ Invalid password for lender:', lender.username);
                                return res.status(403).json({ error: 'Invalid login' });
                            }
                        } else {
                            console.log('Not found in lender table, checking users table...');
                            // If not found in lender table, try users table
                            db.query(
                                'SELECT user_id, username, full_name, email, role, password_hash FROM users WHERE username = ?',
                                [username],
                                async (err, results) => {
                                    if (err) {
                                        console.error('Error querying users table:', err);
                                        return res.status(500).json({ error: err });
                                    }
                                    
                                    console.log('Users query results:', results.length, 'found');
                                    
                                    if (results.length === 0) {
                                        console.log('❌ User not found in any table');
                                        return res.status(403).json({ error: 'Invalid login' });
                                    }
                                    
                                    const user = results[0];
                                    console.log('User found:', user.username, 'Role:', user.role);
                                    
                                    const isBcryptHash = user.password_hash?.startsWith('$2');
                                    let isPasswordValid = false;
                                    
                                    if (isBcryptHash) {
                                        isPasswordValid = await bcrypt.compare(password, user.password_hash);
                                        console.log('Bcrypt comparison result:', isPasswordValid);
                                    } else {
                                        isPasswordValid = user.password_hash === password;
                                        console.log('Plain text comparison result:', isPasswordValid);
                                    }
                                    
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
                                        console.log('✅ User login successful:', user.username);
                                        res.json(user);
                                    } else {
                                        console.log('❌ Invalid password for user:', user.username);
                                        return res.status(403).json({ error: 'Invalid login' });
                                    }
                                }
                            );
                        }
                    }
                );
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

// -------- ADD ITEM --------
app.post('/items', (req, res) => {
    const { item_name, item_description, availability_status, lender_id } = req.body;
    if (!item_name || !lender_id) return res.status(400).json({ error: 'Item name and lender ID required' });
    db.query('INSERT INTO items (item_name, description, availability_status, lender_id) VALUES (?, ?, ?, ?)',
        [item_name, item_description || '', availability_status || 'Available', lender_id],
        (err, result) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true, item_id: result.insertId });
        });
});

// -------- EDIT ITEM --------
app.patch('/items/:itemId', (req, res) => {
    const { item_name, item_description, availability_status } = req.body;
    db.query('UPDATE items SET item_name = ?, description = ?, availability_status = ? WHERE item_id = ?',
        [item_name, item_description, availability_status, req.params.itemId],
        (err, result) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true });
        });
});

// -------- DISABLE ITEM --------
app.patch('/items/:itemId/status', (req, res) => {
    const { availability_status } = req.body;
    db.query('UPDATE items SET availability_status = ? WHERE item_id = ?',
        [availability_status, req.params.itemId],
        (err) => {
            if (err) return res.status(500).json({ error: err });
            res.json({ success: true });
        });
});

// -------- GET HISTORY --------
app.get('/history', (req, res) => {
    const lenderId = req.query.lender_id;
    
    let query = `
        SELECT 
            h.history_id,
            h.user_id,
            h.item_id,
            h.borrow_date,
            h.return_date,
            h.status,
            h.borrower_reason,
            h.lender_response,
            h.is_late_flagged,
            h.created_at,
            i.item_name,
            i.image_url,
            i.lender_id,
            u.username as borrower_name,
            l.full_name AS lender_name
        FROM history h
        JOIN items i ON h.item_id = i.item_id
        JOIN users u ON h.user_id = u.user_id
        LEFT JOIN lender l ON i.lender_id = l.lender_id
    `;
    
    const params = [];
    
    if (lenderId) {
        query += ' WHERE i.lender_id = ?';
        params.push(lenderId);
    }
    
    query += ' ORDER BY h.created_at DESC';
    
    db.query(query, params, (err, results) => {
        if (err) {
            console.error('Error fetching history:', err);
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// -------- START SERVER --------
const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Accessible at http://10.2.8.26:${PORT}`);
});

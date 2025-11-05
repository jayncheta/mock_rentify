import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import morgan from 'mysql2';

const app = express();
app.use(cons());
app.use(bodyParser.json());

const db = morgan.createConnection({
    host: 'localhost',
    user: 'root',
    password: '123456',
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



const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
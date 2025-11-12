import fetch from 'node-fetch';

const testLogin = async (username, password) => {
    try {
        console.log(`\nTesting login for: ${username}`);
        console.log('=================================');
        
        const response = await fetch('http://10.2.8.21:3000/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ username, password }),
        });

        const data = await response.json();
        
        if (response.ok) {
            console.log('✅ LOGIN SUCCESS!');
            console.log('Response data:', JSON.stringify(data, null, 2));
        } else {
            console.log('❌ LOGIN FAILED');
            console.log('Status:', response.status);
            console.log('Response:', data);
        }
    } catch (error) {
        console.log('❌ ERROR:', error.message);
    }
};

// Test both staff accounts
(async () => {
    await testLogin('Andreastaff', 'staff123');
    await testLogin('Robertstaff', 'staff123');
})();

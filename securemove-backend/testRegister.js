async function registerUser() {
  try {
    const response = await fetch('http://localhost:3000/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Blessed',
        email: 'blessed@example.com',
        password: 'mypassword'
      })
    });

    const text = await response.text();
    try {
      const data = JSON.parse(text);
      console.log('Response:', data);
    } catch {
      console.log('Response (text):', text);
    }
  } catch (err) {
    console.error('Error:', err.message);
  }
}

registerUser();

import express from 'express';

const app = express();
app.use(express.json());

const CYCLOS_BASE = process.env.CYCLOS_URL || 'http://cyclos:8080';
const CYCLOS_NETWORK = process.env.CYCLOS_NETWORK || 'hcc_timebank';
const CYCLOS_URL = `${CYCLOS_BASE}/${CYCLOS_NETWORK}/api`;
const CYCLOS_AUTH = process.env.CYCLOS_AUTH || 'admin:HccAdmin2026';
const MEMBER_PASS = process.env.MEMBER_PASS || 'Demo2026x';

const adminHeaders = () => ({
  'Content-Type': 'application/json',
  'Authorization': `Basic ${Buffer.from(CYCLOS_AUTH).toString('base64')}`
});

const userHeaders = (username) => ({
  'Content-Type': 'application/json',
  'Authorization': `Basic ${Buffer.from(`${username}:${MEMBER_PASS}`).toString('base64')}`
});

// Cache username lookups (Cyclos IDs → usernames)
const usernameCache = new Map();

async function getUsername(userId) {
  if (usernameCache.has(userId)) return usernameCache.get(userId);
  const resp = await fetch(`${CYCLOS_URL}/users/${userId}`, { headers: adminHeaders() });
  if (resp.ok) {
    const user = await resp.json();
    usernameCache.set(userId, user.username);
    return user.username;
  }
  return null;
}

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Get members with balances
app.get('/members', async (req, res) => {
  try {
    const resp = await fetch(`${CYCLOS_URL}/users?roles=member&groups=members&fields=id,display,email,username`, { headers: adminHeaders() });
    if (!resp.ok) throw new Error(`Cyclos ${resp.status}`);
    const users = await resp.json();

    const members = (await Promise.all(users.filter(u => u.display).map(async (u) => {
      if (u.username) usernameCache.set(u.id, u.username);
      try {
        const balResp = await fetch(`${CYCLOS_URL}/${u.id}/accounts`, { headers: adminHeaders() });
        const accounts = balResp.ok ? await balResp.json() : [];
        const balance = accounts[0]?.status?.balance || '0';
        return { id: u.id, name: u.display, username: u.username, email: u.email, balance: parseFloat(balance) };
      } catch {
        return { id: u.id, name: u.display, username: u.username, email: u.email, balance: 0 };
      }
    }))).filter(m => m.name);

    res.json(members);
  } catch (err) {
    console.error('GET /members error:', err.message);
    res.status(502).json({ error: 'Failed to fetch members from Cyclos' });
  }
});

// Create a commitment (pledge) — user-to-system payment
app.post('/commitments', async (req, res) => {
  const { fromUserId, amount, description } = req.body;
  if (!fromUserId || !amount) return res.status(400).json({ error: 'fromUserId and amount required' });

  try {
    const username = await getUsername(fromUserId);
    if (!username) throw new Error('User not found');

    const resp = await fetch(`${CYCLOS_URL}/self/payments`, {
      method: 'POST',
      headers: userHeaders(username),
      body: JSON.stringify({
        type: 'member_account.community_payment',
        amount: String(amount),
        description: description || 'HCC Commitment',
        subject: 'community_account'
      })
    });
    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(err);
    }
    const result = await resp.json();
    res.json({ id: result.id, status: 'committed' });
  } catch (err) {
    console.error('POST /commitments error:', err.message);
    res.status(502).json({ error: 'Failed to create commitment' });
  }
});

// Execute hour transfer between members — authenticate as sender
app.post('/transfers', async (req, res) => {
  const { fromUserId, toUserId, amount, description } = req.body;
  if (!fromUserId || !toUserId || !amount) {
    return res.status(400).json({ error: 'fromUserId, toUserId, and amount required' });
  }

  try {
    const username = await getUsername(fromUserId);
    if (!username) throw new Error('Sender not found');

    const resp = await fetch(`${CYCLOS_URL}/self/payments`, {
      method: 'POST',
      headers: userHeaders(username),
      body: JSON.stringify({
        type: 'member_account.member_payment',
        amount: String(amount),
        description: description || 'HCC Hour Transfer',
        subject: toUserId
      })
    });
    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(err);
    }
    const result = await resp.json();
    res.json({ id: result.id, status: 'transferred' });
  } catch (err) {
    console.error('POST /transfers error:', err.message);
    res.status(502).json({ error: 'Failed to execute transfer' });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`HCC API listening on :${PORT}`));

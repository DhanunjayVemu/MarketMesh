const path = require('path');
const crypto = require('crypto');
const express = require('express');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const app = express();
const PORT = process.env.PORT || 3000;
const FRONTEND_DIR = path.join(__dirname, '..', 'frontend');
const FRONTEND_PATH = path.join(FRONTEND_DIR, 'marketplace_frontend.html');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'marketplace_db',
  waitForConnections: true,
  connectionLimit: 10,
  decimalNumbers: true,
  dateStrings: true,
});

app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(express.static(FRONTEND_DIR));

app.get('/', (_req, res) => {
  res.sendFile(FRONTEND_PATH);
});

app.get('/api/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, error: 'Database unavailable' });
  }
});

function getAuthToken(req) {
  const header = req.get('authorization') || '';
  if (header.startsWith('Bearer ')) {
    return header.slice(7).trim();
  }
  return req.get('x-session-token') || req.body?.token || req.query?.token || '';
}

async function getSessionUser(token) {
  if (!token) return null;
  const [rows] = await pool.query(
    `SELECT u.user_id, u.username, u.email, u.full_name, u.bio, u.avatar_url,
            u.avg_rating, u.total_reviews, u.status
     FROM user_session s
     JOIN user u ON u.user_id = s.user_id
     WHERE s.token = ?
       AND s.is_revoked = FALSE
       AND s.expires_at > NOW()
     LIMIT 1`,
    [token]
  );
  return rows[0] || null;
}

async function requireUser(req, res) {
  const token = getAuthToken(req);
  if (!token) {
    res.status(401).json({ error: 'Missing session token.' });
    return null;
  }

  const user = await getSessionUser(token);
  if (!user) {
    res.status(401).json({ error: 'Invalid or expired session.' });
    return null;
  }

  return { token, user };
}

function normalizeUser(row) {
  return {
    user_id: row.user_id,
    username: row.username,
    email: row.email,
    full_name: row.full_name,
    bio: row.bio || '',
    avatar_url: row.avatar_url || '',
    avg_rating: Number(row.avg_rating || 0),
    total_reviews: Number(row.total_reviews || 0),
    status: row.status,
  };
}

function splitTags(tagValue) {
  if (!tagValue) return [];
  return String(tagValue)
    .split('|')
    .map((tag) => tag.trim())
    .filter(Boolean);
}

async function loadBootstrapData() {
  const [users, communities, listings, tags] = await Promise.all([
    pool.query(
      `SELECT user_id, username, email, full_name, bio, avatar_url, avg_rating, total_reviews, status
       FROM user
       ORDER BY user_id`
    ),
    pool.query(
      `SELECT community_id AS id,
              name,
              COALESCE(icon_url, '🏪') AS icon,
              total_members AS members,
              total_listings AS listings,
              visibility,
              created_by,
              invite_code
       FROM community
       ORDER BY community_id`
    ),
    pool.query(
      `SELECT l.listing_id AS id,
              l.community_id,
              COALESCE(cat.name, 'General') AS category,
              l.title,
              l.description,
              l.price,
              l.price_type,
              l.\`condition\`,
              l.status,
              l.location,
              l.view_count,
              l.created_at,
              l.updated_at,
              l.sold_at,
              u.user_id AS seller_id,
              u.username AS seller,
              u.avg_rating AS seller_rating,
              com.name AS community,
              COALESCE(img.image_url, '') AS image
       FROM listing l
       JOIN user u ON u.user_id = l.seller_id
       JOIN community com ON com.community_id = l.community_id
       LEFT JOIN category cat ON cat.category_id = l.category_id
       LEFT JOIN listing_image img ON img.listing_id = l.listing_id AND img.is_primary = TRUE
       ORDER BY l.created_at DESC, l.listing_id DESC`
    ),
    pool.query(
      `SELECT lt.listing_id, t.name
       FROM listing_tag lt
       JOIN tag t ON t.tag_id = lt.tag_id
       ORDER BY lt.listing_id, t.name`
    ),
  ]);

  const tagsByListing = new Map();
  for (const row of tags[0]) {
    if (!tagsByListing.has(row.listing_id)) {
      tagsByListing.set(row.listing_id, []);
    }
    tagsByListing.get(row.listing_id).push(row.name);
  }

  const listingsData = listings[0].map((row) => ({
    id: row.id,
    community_id: row.community_id,
    category: row.category,
    title: row.title,
    description: row.description || '',
    price: Number(row.price || 0),
    price_type: row.price_type,
    condition: row.condition,
    status: row.status,
    location: row.location || '',
    view_count: Number(row.view_count || 0),
    created_at: row.created_at,
    updated_at: row.updated_at,
    sold_at: row.sold_at,
    seller_id: row.seller_id,
    seller: row.seller,
    seller_rating: Number(row.seller_rating || 0),
    community: row.community,
    image: row.image || '',
    tags: tagsByListing.get(row.id) || [],
  }));

  return {
    users: users[0].map(normalizeUser),
    communities: communities[0].map((row) => ({
      id: row.id,
      name: row.name,
      icon: row.icon,
      members: Number(row.members || 0),
      listings: Number(row.listings || 0),
      visibility: row.visibility,
      created_by: row.created_by,
      invite_code: row.invite_code,
    })),
    listings: listingsData,
  };
}

app.get('/api/bootstrap', async (req, res) => {
  try {
    const token = getAuthToken(req);
    const sessionUser = token ? await getSessionUser(token) : null;
    const data = await loadBootstrapData();
    res.json({ ...data, sessionUser: sessionUser ? normalizeUser(sessionUser) : null });
  } catch (error) {
    console.error('Bootstrap failed:', error);
    res.status(500).json({ error: 'Failed to load application data.' });
  }
});

app.get('/api/auth/me', async (req, res) => {
  try {
    const session = await requireUser(req, res);
    if (!session) return;
    res.json({ user: normalizeUser(session.user) });
  } catch (error) {
    console.error('Session lookup failed:', error);
    res.status(500).json({ error: 'Unable to validate session.' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { identifier, password } = req.body || {};
    if (!identifier || !password) {
      return res.status(400).json({ error: 'Username/email and password are required.' });
    }

    const [rows] = await pool.query(
      `SELECT user_id, username, email, full_name, bio, avatar_url, avg_rating, total_reviews, status
       FROM user
       WHERE (username = ? OR email = ?)
         AND password_hash = SHA2(?, 256)
         AND status = 'active'
       LIMIT 1`,
      [identifier, identifier, password]
    );

    const user = rows[0];
    if (!user) {
      return res.status(401).json({ error: 'Invalid username or password.' });
    }

    const token = crypto.randomUUID();
    await pool.query(
      `INSERT INTO user_session (user_id, token, ip_address, user_agent, expires_at)
       VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))`,
      [user.user_id, token, req.ip || null, req.get('user-agent') || null]
    );

    await pool.query('UPDATE user SET last_active = NOW() WHERE user_id = ?', [user.user_id]);

    res.json({ user: normalizeUser(user), token });
  } catch (error) {
    console.error('Login failed:', error);
    res.status(500).json({ error: 'Login failed.' });
  }
});

app.post('/api/auth/register', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { full_name, username, email, password } = req.body || {};
    if (!full_name || !username || !email || !password) {
      return res.status(400).json({ error: 'All registration fields are required.' });
    }
    if (String(password).length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters.' });
    }

    await connection.beginTransaction();
    const [insertResult] = await connection.query(
      `INSERT INTO user (username, email, password_hash, full_name, bio)
       VALUES (?, ?, SHA2(?, 256), ?, '')`,
      [username, email, password, full_name]
    );

    const userId = insertResult.insertId;
    const [userRows] = await connection.query(
      `SELECT user_id, username, email, full_name, bio, avatar_url, avg_rating, total_reviews, status
       FROM user
       WHERE user_id = ?
       LIMIT 1`,
      [userId]
    );

    const token = crypto.randomUUID();
    await connection.query(
      `INSERT INTO user_session (user_id, token, ip_address, user_agent, expires_at)
       VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))`,
      [userId, token, req.ip || null, req.get('user-agent') || null]
    );
    await connection.commit();

    res.json({ user: normalizeUser(userRows[0]), token });
  } catch (error) {
    await connection.rollback();
    if (error && error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Username or email already exists.' });
    }
    console.error('Registration failed:', error);
    res.status(500).json({ error: 'Registration failed.' });
  } finally {
    connection.release();
  }
});

app.post('/api/auth/logout', async (req, res) => {
  try {
    const token = getAuthToken(req);
    if (!token) {
      return res.status(400).json({ error: 'Session token is required.' });
    }
    await pool.query('UPDATE user_session SET is_revoked = TRUE WHERE token = ?', [token]);
    res.json({ ok: true });
  } catch (error) {
    console.error('Logout failed:', error);
    res.status(500).json({ error: 'Logout failed.' });
  }
});

app.post('/api/communities', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const session = await requireUser(req, res);
    if (!session) return;

    const { name, description = '', icon = '🏪', visibility = 'public' } = req.body || {};
    if (!name) {
      return res.status(400).json({ error: 'Community name is required.' });
    }

    const inviteCode = `COMM-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
    await connection.beginTransaction();

    const [insertResult] = await connection.query(
      `INSERT INTO community (name, description, invite_code, icon_url, visibility, created_by)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [name, description, inviteCode, icon, visibility, session.user.user_id]
    );

    const communityId = insertResult.insertId;
    await connection.query(
      `INSERT INTO membership (user_id, community_id, role)
       VALUES (?, ?, 'owner')`,
      [session.user.user_id, communityId]
    );

    await connection.commit();

    const [rows] = await connection.query(
      `SELECT community_id AS id, name, COALESCE(icon_url, '🏪') AS icon, total_members AS members,
              total_listings AS listings, visibility, created_by, invite_code
       FROM community
       WHERE community_id = ?
       LIMIT 1`,
      [communityId]
    );

    res.json({ community: rows[0] });
  } catch (error) {
    await connection.rollback();
    if (error && error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Community invite code collision. Try again.' });
    }
    console.error('Community creation failed:', error);
    res.status(500).json({ error: 'Community creation failed.' });
  } finally {
    connection.release();
  }
});

async function resolveCategoryId(connection, categoryName, communityId) {
  const normalizedName = String(categoryName || '').trim();
  if (!normalizedName) return null;

  const [rows] = await connection.query(
    `SELECT category_id
     FROM category
     WHERE name = ?
       AND (community_id = ? OR community_id IS NULL)
     ORDER BY community_id = ? DESC, parent_category_id IS NOT NULL, category_id ASC
     LIMIT 1`,
    [normalizedName, communityId, communityId]
  );

  if (rows[0]?.category_id) {
    return rows[0].category_id;
  }

  const [insertResult] = await connection.query(
    `INSERT INTO category (community_id, parent_category_id, name, description)
     VALUES (?, NULL, ?, '')`,
    [communityId, normalizedName]
  );

  return insertResult.insertId || null;
}

app.post('/api/listings', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const session = await requireUser(req, res);
    if (!session) return;

    const {
      title,
      price,
      price_type,
      condition,
      location = '',
      description = '',
      category,
      community_id,
      image = '',
    } = req.body || {};

    const communityId = Number(community_id);

    if (!title || price === undefined || price === null || !category || !communityId) {
      return res.status(400).json({ error: 'Title, price, category, and community are required.' });
    }

    const categoryId = await resolveCategoryId(connection, category, communityId);
    if (!categoryId) {
      return res.status(400).json({ error: `Unknown category: ${category}` });
    }

    await connection.query('SET @listing_id = NULL, @message = NULL');
    await connection.query(
      `CALL sp_create_listing(?, ?, ?, ?, ?, ?, ?, ?, ?, @listing_id, @message)`,
      [
        session.user.user_id,
        communityId,
        categoryId,
        title,
        description,
        price,
        price_type,
        condition || 'good',
        location,
      ]
    );

    const [[meta]] = await connection.query('SELECT @listing_id AS listing_id, @message AS message');
    if (!meta || meta.listing_id === -1) {
      return res.status(400).json({ error: meta?.message || 'Listing creation failed.' });
    }

    if (image) {
      await connection.query(
        `INSERT INTO listing_image (listing_id, image_url, sort_order, is_primary)
         VALUES (?, ?, 0, TRUE)`,
        [meta.listing_id, image]
      );
    }

    const [rows] = await connection.query(
      `SELECT l.listing_id AS id,
              l.community_id,
              COALESCE(cat.name, 'General') AS category,
              l.title,
              l.description,
              l.price,
              l.price_type,
              l.\`condition\`,
              l.status,
              l.location,
              l.view_count,
              l.created_at,
              l.updated_at,
              l.sold_at,
              u.user_id AS seller_id,
              u.username AS seller,
              u.avg_rating AS seller_rating,
              com.name AS community,
              COALESCE(img.image_url, '') AS image
       FROM listing l
       JOIN user u ON u.user_id = l.seller_id
       JOIN community com ON com.community_id = l.community_id
       LEFT JOIN category cat ON cat.category_id = l.category_id
       LEFT JOIN listing_image img ON img.listing_id = l.listing_id AND img.is_primary = TRUE
       WHERE l.listing_id = ?
       LIMIT 1`,
      [meta.listing_id]
    );

    const [tagRows] = await connection.query(
      `SELECT t.name
       FROM listing_tag lt
       JOIN tag t ON t.tag_id = lt.tag_id
       WHERE lt.listing_id = ?
       ORDER BY t.name`,
      [meta.listing_id]
    );

    const listing = rows[0];
    listing.tags = tagRows.map((row) => row.name);
    res.json({ listing, message: meta.message });
  } catch (error) {
    console.error('Listing creation failed:', error);
    res.status(500).json({ error: 'Listing creation failed.' });
  } finally {
    connection.release();
  }
});

app.patch('/api/listings/:id/sold', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const session = await requireUser(req, res);
    if (!session) return;

    const listingId = Number(req.params.id);
    const buyerId = req.body?.buyerId ? Number(req.body.buyerId) : null;

    const [listingRows] = await connection.query(
      `SELECT listing_id, seller_id, status
       FROM listing
       WHERE listing_id = ?
       LIMIT 1`,
      [listingId]
    );
    const listing = listingRows[0];
    if (!listing) {
      return res.status(404).json({ error: 'Listing not found.' });
    }

    if (listing.seller_id !== session.user.user_id) {
      return res.status(403).json({ error: 'Only the seller can mark a listing as sold.' });
    }

    if (buyerId) {
      await connection.query('SET @txn_id = NULL, @message = NULL');
      await connection.query('CALL sp_mark_sold(?, ?, @txn_id, @message)', [listingId, buyerId]);
      const [[meta]] = await connection.query('SELECT @txn_id AS txn_id, @message AS message');
      if (!meta || meta.txn_id === -1) {
        return res.status(400).json({ error: meta?.message || 'Unable to mark listing sold.' });
      }
      return res.json({ ok: true, transaction_id: meta.txn_id, message: meta.message });
    }

    await connection.query(
      `UPDATE listing
       SET status = 'sold', sold_at = NOW(), updated_at = NOW()
       WHERE listing_id = ?`,
      [listingId]
    );

    res.json({ ok: true, message: 'SUCCESS: Item marked as sold.' });
  } catch (error) {
    console.error('Mark sold failed:', error);
    res.status(500).json({ error: 'Unable to mark listing sold.' });
  } finally {
    connection.release();
  }
});

app.get('/api/listings/:id', async (req, res) => {
  try {
    const listingId = Number(req.params.id);
    const [rows] = await pool.query(
      `SELECT l.listing_id AS id,
              l.community_id,
              COALESCE(cat.name, 'General') AS category,
              l.title,
              l.description,
              l.price,
              l.price_type,
              l.\`condition\`,
              l.status,
              l.location,
              l.view_count,
              l.created_at,
              l.updated_at,
              l.sold_at,
              u.user_id AS seller_id,
              u.username AS seller,
              u.full_name AS seller_full_name,
              u.avg_rating AS seller_rating,
              com.name AS community,
              COALESCE(img.image_url, '') AS image
       FROM listing l
       JOIN user u ON u.user_id = l.seller_id
       JOIN community com ON com.community_id = l.community_id
       LEFT JOIN category cat ON cat.category_id = l.category_id
       LEFT JOIN listing_image img ON img.listing_id = l.listing_id AND img.is_primary = TRUE
       WHERE l.listing_id = ?
       LIMIT 1`,
      [listingId]
    );
    if (!rows[0]) {
      return res.status(404).json({ error: 'Listing not found.' });
    }

    const [tagRows] = await pool.query(
      `SELECT t.name
       FROM listing_tag lt
       JOIN tag t ON t.tag_id = lt.tag_id
       WHERE lt.listing_id = ?
       ORDER BY t.name`,
      [listingId]
    );

    const listing = rows[0];
    listing.tags = tagRows.map((row) => row.name);
    res.json({ listing });
  } catch (error) {
    console.error('Listing fetch failed:', error);
    res.status(500).json({ error: 'Unable to fetch listing.' });
  }
});

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.listen(PORT, () => {
  console.log(`MarketMesh server running on http://localhost:${PORT}`);
});

import pg from 'pg';
import config from '../config/index.js';
import logger from '../utils/logger.js';

const { Pool } = pg;

let pool = null;
let dbAvailable = false;

/**
 * Initialize the connection pool.
 * Returns true if connected, false otherwise.
 */
function createPool() {
    pool = new Pool(config.postgres);

    pool.on('connect', () => {
        logger.debug('New PostgreSQL client connected');
    });

    pool.on('error', (err) => {
        logger.error('PostgreSQL pool error:', err.message);
        dbAvailable = false;
    });
}

/**
 * Execute a query. Returns null if DB is unavailable.
 */
export const query = async (text, params) => {
    if (!dbAvailable || !pool) return null;
    try {
        return await pool.query(text, params);
    } catch (err) {
        logger.error('Query error:', err.message);
        throw err;
    }
};

export const getClient = async () => {
    if (!dbAvailable || !pool) return null;
    return pool.connect();
};

export const isAvailable = () => dbAvailable;

/**
 * Initialize the database — create tables if they don't exist.
 * Gracefully handles failure so the server can still run without PG.
 */
export const initDatabase = async () => {
    createPool();

    try {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Users table
            await client.query(`
                CREATE TABLE IF NOT EXISTS users (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    username VARCHAR(50) UNIQUE NOT NULL,
                    display_name VARCHAR(100) NOT NULL,
                    email VARCHAR(255),
                    password_hash TEXT NOT NULL,
                    avatar_url TEXT,
                    public_key TEXT,
                    device_id VARCHAR(255),
                    status VARCHAR(20) DEFAULT 'offline',
                    last_seen TIMESTAMPTZ DEFAULT NOW(),
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                );
            `);

            // Devices table
            await client.query(`
                CREATE TABLE IF NOT EXISTS devices (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                    device_name VARCHAR(100) NOT NULL,
                    device_type VARCHAR(50) NOT NULL,
                    device_fingerprint VARCHAR(255) UNIQUE NOT NULL,
                    public_key TEXT NOT NULL,
                    ip_address INET,
                    subnet VARCHAR(50),
                    vlan_id INTEGER,
                    is_active BOOLEAN DEFAULT true,
                    last_seen TIMESTAMPTZ DEFAULT NOW(),
                    registered_at TIMESTAMPTZ DEFAULT NOW()
                );
            `);

            // Channels
            await client.query(`
                CREATE TABLE IF NOT EXISTS channels (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    name VARCHAR(100) NOT NULL,
                    description TEXT,
                    type VARCHAR(20) DEFAULT 'group',
                    is_private BOOLEAN DEFAULT false,
                    created_by UUID REFERENCES users(id),
                    avatar_url TEXT,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                );
            `);

            // Channel members
            await client.query(`
                CREATE TABLE IF NOT EXISTS channel_members (
                    channel_id UUID REFERENCES channels(id) ON DELETE CASCADE,
                    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                    role VARCHAR(20) DEFAULT 'member',
                    joined_at TIMESTAMPTZ DEFAULT NOW(),
                    PRIMARY KEY (channel_id, user_id)
                );
            `);

            // Messages
            await client.query(`
                CREATE TABLE IF NOT EXISTS messages (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    channel_id UUID REFERENCES channels(id) ON DELETE CASCADE,
                    sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
                    content TEXT,
                    encrypted_content TEXT,
                    message_type VARCHAR(20) DEFAULT 'text',
                    reply_to UUID REFERENCES messages(id),
                    file_url TEXT,
                    file_name VARCHAR(255),
                    file_size BIGINT,
                    file_type VARCHAR(100),
                    is_edited BOOLEAN DEFAULT false,
                    is_deleted BOOLEAN DEFAULT false,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                );
            `);

            // Direct messages
            await client.query(`
                CREATE TABLE IF NOT EXISTS direct_messages (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
                    receiver_id UUID REFERENCES users(id) ON DELETE SET NULL,
                    content TEXT,
                    encrypted_content TEXT,
                    message_type VARCHAR(20) DEFAULT 'text',
                    file_url TEXT,
                    file_name VARCHAR(255),
                    file_size BIGINT,
                    file_type VARCHAR(100),
                    is_read BOOLEAN DEFAULT false,
                    is_deleted BOOLEAN DEFAULT false,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
            `);

            // File transfers tracking
            await client.query(`
                CREATE TABLE IF NOT EXISTS file_transfers (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    sender_id UUID REFERENCES users(id),
                    receiver_id UUID REFERENCES users(id),
                    file_name VARCHAR(255) NOT NULL,
                    file_size BIGINT NOT NULL,
                    file_type VARCHAR(100),
                    file_hash VARCHAR(255),
                    storage_path TEXT,
                    transfer_type VARCHAR(20) DEFAULT 'relay',
                    status VARCHAR(20) DEFAULT 'pending',
                    chunks_total INTEGER DEFAULT 0,
                    chunks_completed INTEGER DEFAULT 0,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    completed_at TIMESTAMPTZ
                );
            `);

            // Meetings
            await client.query(`
                CREATE TABLE IF NOT EXISTS meetings (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    title VARCHAR(200) NOT NULL,
                    host_id UUID REFERENCES users(id),
                    channel_id UUID REFERENCES channels(id),
                    room_id VARCHAR(100) UNIQUE NOT NULL,
                    status VARCHAR(20) DEFAULT 'scheduled',
                    max_participants INTEGER DEFAULT 50,
                    started_at TIMESTAMPTZ,
                    ended_at TIMESTAMPTZ,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
            `);

            // Meeting participants
            await client.query(`
                CREATE TABLE IF NOT EXISTS meeting_participants (
                    meeting_id UUID REFERENCES meetings(id) ON DELETE CASCADE,
                    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
                    joined_at TIMESTAMPTZ DEFAULT NOW(),
                    left_at TIMESTAMPTZ,
                    PRIMARY KEY (meeting_id, user_id)
                );
            `);

            // Indexes
            await client.query(`
                CREATE INDEX IF NOT EXISTS idx_messages_channel ON messages(channel_id, created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
                CREATE INDEX IF NOT EXISTS idx_dm_sender ON direct_messages(sender_id, created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_dm_receiver ON direct_messages(receiver_id, created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);
                CREATE INDEX IF NOT EXISTS idx_devices_subnet ON devices(subnet);
                CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
            `);

            await client.query('COMMIT');
            dbAvailable = true;
            logger.info('✅ Database initialized successfully');
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    } catch (error) {
        logger.error('Database initialization failed:', error.message);
        logger.warn('⚠️ Server will run without database — some features may be unavailable');
        dbAvailable = false;
    }
};

export default { query, getClient, initDatabase, isAvailable };

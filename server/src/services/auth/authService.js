import argon2 from 'argon2';
import { v4 as uuidv4 } from 'uuid';
import { query } from '../../models/database.js';
import { generateToken, generateRefreshToken } from '../../middleware/auth.js';
import logger from '../../utils/logger.js';

class AuthService {
    async register(userData) {
        const { username, displayName, email, password, deviceInfo } = userData;

        // Check if username exists
        const existing = await query('SELECT id FROM users WHERE username = $1', [username]);
        if (existing.rows.length > 0) {
            throw new Error('Username already exists');
        }

        // Hash password with argon2id
        const passwordHash = await argon2.hash(password, {
            type: argon2.argon2id,
            memoryCost: 65536,
            timeCost: 3,
            parallelism: 4,
        });

        const userId = uuidv4();

        // Create user
        const result = await query(
            `INSERT INTO users (id, username, display_name, email, password_hash)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, username, display_name, email, status, created_at`,
            [userId, username, displayName, email, passwordHash]
        );

        const user = result.rows[0];

        // Register device if provided
        if (deviceInfo) {
            await this.registerDevice(userId, deviceInfo);
        }

        // Generate tokens
        const tokenPayload = { userId: user.id, username: user.username };
        const token = generateToken(tokenPayload);
        const refreshToken = generateRefreshToken(tokenPayload);

        logger.info(`User registered: ${username}`);

        return {
            user: {
                id: user.id,
                username: user.username,
                displayName: user.display_name,
                email: user.email,
                status: user.status,
            },
            token,
            refreshToken,
        };
    }

    async login(username, password, deviceInfo) {
        const result = await query(
            'SELECT id, username, display_name, email, password_hash, status FROM users WHERE username = $1',
            [username]
        );

        if (result.rows.length === 0) {
            throw new Error('Invalid credentials');
        }

        const user = result.rows[0];

        // Verify password
        const validPassword = await argon2.verify(user.password_hash, password);
        if (!validPassword) {
            throw new Error('Invalid credentials');
        }

        // Update status
        await query("UPDATE users SET status = 'online', last_seen = NOW() WHERE id = $1", [user.id]);

        // Register/update device
        if (deviceInfo) {
            await this.registerDevice(user.id, deviceInfo);
        }

        const tokenPayload = { userId: user.id, username: user.username };
        const token = generateToken(tokenPayload);
        const refreshToken = generateRefreshToken(tokenPayload);

        logger.info(`User logged in: ${username}`);

        return {
            user: {
                id: user.id,
                username: user.username,
                displayName: user.display_name,
                email: user.email,
                status: 'online',
            },
            token,
            refreshToken,
        };
    }

    async registerDevice(userId, deviceInfo) {
        const { deviceName, deviceType, deviceFingerprint, publicKey, ipAddress, subnet, vlanId } = deviceInfo;

        await query(
            `INSERT INTO devices (user_id, device_name, device_type, device_fingerprint, public_key, ip_address, subnet, vlan_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (device_fingerprint) DO UPDATE
       SET ip_address = $6, subnet = $7, vlan_id = $8, last_seen = NOW(), is_active = true`,
            [userId, deviceName, deviceType, deviceFingerprint, publicKey, ipAddress, subnet, vlanId]
        );
    }

    async logout(userId) {
        await query("UPDATE users SET status = 'offline', last_seen = NOW() WHERE id = $1", [userId]);
        logger.info(`User logged out: ${userId}`);
    }

    async refreshToken(userId) {
        const result = await query('SELECT id, username FROM users WHERE id = $1', [userId]);
        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];
        const tokenPayload = { userId: user.id, username: user.username };
        return {
            token: generateToken(tokenPayload),
            refreshToken: generateRefreshToken(tokenPayload),
        };
    }

    async updatePublicKey(userId, publicKey) {
        await query('UPDATE users SET public_key = $1 WHERE id = $2', [publicKey, userId]);
    }

    async getUser(userId) {
        const result = await query(
            'SELECT id, username, display_name, email, avatar_url, public_key, status, last_seen FROM users WHERE id = $1',
            [userId]
        );
        return result.rows[0] || null;
    }

    async searchUsers(searchTerm) {
        const result = await query(
            `SELECT id, username, display_name, avatar_url, status, last_seen
       FROM users
       WHERE username ILIKE $1 OR display_name ILIKE $1
       LIMIT 50`,
            [`%${searchTerm}%`]
        );
        return result.rows;
    }

    async getOnlineUsers() {
        const result = await query(
            `SELECT id, username, display_name, avatar_url, status, last_seen
       FROM users WHERE status = 'online'
       ORDER BY display_name`
        );
        return result.rows;
    }
}

export default new AuthService();

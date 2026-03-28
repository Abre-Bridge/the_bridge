import { Router } from 'express';
import { body } from 'express-validator';
import { authenticateToken } from '../middleware/auth.js';
import { query } from '../models/database.js';
import messagingService from '../services/messaging/messagingService.js';
import logger from '../utils/logger.js';

const router = Router();

// GET /api/channels — list user's channels
router.get('/', authenticateToken, async (req, res) => {
    try {
        const result = await query(
            `SELECT c.*, cm.role,
        (SELECT COUNT(*) FROM channel_members WHERE channel_id = c.id) as member_count,
        (SELECT content FROM messages WHERE channel_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message,
        (SELECT created_at FROM messages WHERE channel_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_at
       FROM channels c
       JOIN channel_members cm ON c.id = cm.channel_id
       WHERE cm.user_id = $1
       ORDER BY last_message_at DESC NULLS LAST`,
            [req.user.userId]
        );
        res.json(result.rows);
    } catch (error) {
        logger.error('List channels error:', error);
        res.status(500).json({ error: error.message });
    }
});

// POST /api/channels — create channel
router.post(
    '/',
    authenticateToken,
    [
        body('name').trim().isLength({ min: 1, max: 100 }),
        body('description').optional().trim(),
        body('isPrivate').optional().isBoolean(),
        body('members').optional().isArray(),
    ],
    async (req, res) => {
        try {
            const { name, description, isPrivate = false, members = [] } = req.body;
            const userId = req.user.userId;

            const result = await query(
                `INSERT INTO channels (name, description, is_private, created_by, type)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
                [name, description, isPrivate, userId, 'group']
            );

            const channel = result.rows[0];

            // Add creator as admin
            await query(
                `INSERT INTO channel_members (channel_id, user_id, role) VALUES ($1, $2, 'admin')`,
                [channel.id, userId]
            );

            // Add invited members
            for (const memberId of members) {
                await query(
                    `INSERT INTO channel_members (channel_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
                    [channel.id, memberId]
                );
            }

            res.status(201).json(channel);
        } catch (error) {
            logger.error('Create channel error:', error);
            res.status(500).json({ error: error.message });
        }
    }
);

// GET /api/channels/:id/messages — get channel messages
router.get('/:id/messages', authenticateToken, async (req, res) => {
    try {
        const { limit = 50, before } = req.query;
        const messages = await messagingService.getChannelMessages(
            req.params.id,
            parseInt(limit),
            before
        );
        res.json(messages);
    } catch (error) {
        logger.error('Get messages error:', error);
        res.status(500).json({ error: error.message });
    }
});

// GET /api/channels/:id/members — get channel members
router.get('/:id/members', authenticateToken, async (req, res) => {
    try {
        const result = await query(
            `SELECT u.id, u.username, u.display_name, u.avatar_url, u.status, cm.role, cm.joined_at
       FROM channel_members cm
       JOIN users u ON cm.user_id = u.id
       WHERE cm.channel_id = $1
       ORDER BY u.display_name`,
            [req.params.id]
        );
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE /api/channels/:id
router.delete('/:id', authenticateToken, async (req, res) => {
    try {
        const result = await query(
            `DELETE FROM channels WHERE id = $1 AND created_by = $2 RETURNING id`,
            [req.params.id, req.user.userId]
        );
        if (result.rows.length === 0) {
            return res.status(403).json({ error: 'Not authorized to delete this channel' });
        }
        res.json({ message: 'Channel deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

export default router;

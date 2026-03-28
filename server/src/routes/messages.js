import { Router } from 'express';
import { authenticateToken } from '../middleware/auth.js';
import messagingService from '../services/messaging/messagingService.js';
import { query } from '../models/database.js';
import logger from '../utils/logger.js';

const router = Router();

// GET /api/messages/dm/:userId — get DM history with a user
router.get('/dm/:userId', authenticateToken, async (req, res) => {
    try {
        const { limit = 50, before } = req.query;
        const messages = await messagingService.getDirectMessages(
            req.user.userId,
            req.params.userId,
            parseInt(limit),
            before
        );
        res.json(messages);
    } catch (error) {
        logger.error('Get DMs error:', error);
        res.status(500).json({ error: error.message });
    }
});

// GET /api/messages/conversations — get DM conversation list
router.get('/conversations', authenticateToken, async (req, res) => {
    try {
        const result = await query(
            `SELECT DISTINCT ON (other_user_id) 
        other_user_id,
        u.username,
        u.display_name,
        u.avatar_url,
        u.status,
        dm.content as last_message,
        dm.created_at as last_message_at,
        dm.message_type
       FROM (
         SELECT 
           CASE WHEN sender_id = $1 THEN receiver_id ELSE sender_id END as other_user_id,
           content,
           created_at,
           message_type
         FROM direct_messages
         WHERE (sender_id = $1 OR receiver_id = $1) AND is_deleted = false
       ) dm
       JOIN users u ON dm.other_user_id = u.id
       ORDER BY other_user_id, dm.created_at DESC`,
            [req.user.userId]
        );
        res.json(result.rows);
    } catch (error) {
        logger.error('Get conversations error:', error);
        res.status(500).json({ error: error.message });
    }
});

// GET /api/messages/unread — get unread message count
router.get('/unread', authenticateToken, async (req, res) => {
    try {
        const result = await query(
            `SELECT COUNT(*) as count FROM direct_messages
       WHERE receiver_id = $1 AND is_read = false AND is_deleted = false`,
            [req.user.userId]
        );
        res.json({ unreadCount: parseInt(result.rows[0].count) });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

export default router;

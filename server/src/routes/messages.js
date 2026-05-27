import express from 'express';
import { query, isAvailable } from '../models/database.js';
import messagingService from '../services/messaging/messagingService.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

router.use(authenticateToken);

// Get conversations list (recent DMs)
router.get('/conversations', async (req, res) => {
    if (!isAvailable()) return res.status(503).json({ error: 'Database unavailable' });
    try {
        const userId = req.user.userId;
        
        // Find all users the current user has exchanged messages with
        const result = await query(`
            SELECT DISTINCT u.id, u.username, u.display_name, u.avatar_url, u.status, u.last_seen
            FROM users u
            JOIN direct_messages dm ON (dm.sender_id = u.id OR dm.receiver_id = u.id)
            WHERE (dm.sender_id = $1 OR dm.receiver_id = $1) AND u.id != $1
        `, [userId]);
        
        // For each, get the last message and unread count
        const conversations = await Promise.all(result.rows.map(async (u) => {
            const lastMsgRes = await query(`
                SELECT content, created_at FROM direct_messages 
                WHERE (sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1)
                ORDER BY created_at DESC LIMIT 1
            `, [userId, u.id]);
            
            const unreadRes = await query(`
                SELECT COUNT(*) FROM direct_messages 
                WHERE sender_id = $1 AND receiver_id = $2 AND is_read = false
            `, [u.id, userId]);
            
            return {
                ...u,
                last_message: lastMsgRes.rows[0] || null,
                unread_count: parseInt(unreadRes.rows[0].count, 10),
            };
        }));
        
        res.json(conversations);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get direct message history with a specific user
router.get('/:userId', async (req, res) => {
    try {
        const { limit, before } = req.query;
        const msgs = await messagingService.getDirectMessages(req.user.userId, req.params.userId, limit, before);
        res.json(msgs);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

export default router;

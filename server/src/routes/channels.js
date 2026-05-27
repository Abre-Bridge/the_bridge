import express from 'express';
import { query, isAvailable } from '../models/database.js';
import messagingService from '../services/messaging/messagingService.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

router.use(authenticateToken);

// Create channel
router.post('/', async (req, res) => {
    if (!isAvailable()) return res.status(503).json({ error: 'Database unavailable' });
    try {
        const { name, description, isPrivate } = req.body;
        const result = await query(
            'INSERT INTO channels (name, description, is_private, created_by) VALUES ($1, $2, $3, $4) RETURNING *',
            [name, description, isPrivate, req.user.userId]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// List channels
router.get('/', async (req, res) => {
    if (!isAvailable()) return res.status(503).json({ error: 'Database unavailable' });
    try {
        const result = await query(`
            SELECT c.*, 
            (SELECT COUNT(*) FROM channel_members WHERE channel_id = c.id) as "_count"
            FROM channels c
        `);
        // Map _count format for client compatibility
        const mapped = result.rows.map(r => ({ ...r, _count: { members: parseInt(r._count, 10) } }));
        res.json(mapped);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get channel history (REST lookup, not for sending)
router.get('/:id/messages', async (req, res) => {
    try {
        const { limit, before } = req.query;
        const msgs = await messagingService.getChannelMessages(req.params.id, limit, before);
        res.json(msgs);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

export default router;

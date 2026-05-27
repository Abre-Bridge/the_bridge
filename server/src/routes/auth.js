import express from 'express';
import authService from '../services/auth/authService.js';
import { authenticateToken } from '../middleware/auth.js';
import logger from '../utils/logger.js';

const router = express.Router();

router.post('/register', async (req, res) => {
    try {
        const result = await authService.register(req.body);
        res.status(201).json(result);
    } catch (error) {
        logger.error('Registration failed:', error.message);
        res.status(400).json({ error: error.message });
    }
});

router.post('/login', async (req, res) => {
    try {
        const { username, password, deviceInfo } = req.body;
        const result = await authService.login(username, password, deviceInfo);
        res.json(result);
    } catch (error) {
        logger.error('Login failed:', error.message);
        res.status(401).json({ error: error.message });
    }
});

router.post('/logout', authenticateToken, async (req, res) => {
    try {
        await authService.logout(req.user.userId);
        res.json({ success: true });
    } catch (error) {
        logger.error('Logout failed:', error.message);
        res.status(500).json({ error: 'Failed to logout' });
    }
});

router.post('/refresh', async (req, res) => {
    try {
        const { refreshToken } = req.body;
        if (!refreshToken) return res.status(400).json({ error: 'Refresh token required' });
        // NOTE: A real implementation would verify the refresh token. For now we use the main authService.
        res.status(501).json({ error: 'Not implemented in this demo' });
    } catch (error) {
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

router.get('/me', authenticateToken, async (req, res) => {
    try {
        const user = await authService.getUser(req.user.userId);
        if (!user) return res.status(404).json({ error: 'User not found' });
        res.json(user);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

export default router;

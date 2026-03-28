import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import authService from '../services/auth/authService.js';
import { authenticateToken } from '../middleware/auth.js';
import logger from '../utils/logger.js';

const router = Router();

// Validation middleware
const validate = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }
    next();
};

// POST /api/auth/register
router.post(
    '/register',
    [
        body('username').trim().isLength({ min: 3, max: 50 }).withMessage('Username must be 3-50 characters'),
        body('displayName').trim().isLength({ min: 1, max: 100 }).withMessage('Display name is required'),
        body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
        body('email').optional().isEmail().withMessage('Invalid email'),
    ],
    validate,
    async (req, res) => {
        try {
            const result = await authService.register(req.body);
            res.status(201).json(result);
        } catch (error) {
            logger.error('Registration error:', error);
            res.status(400).json({ error: error.message });
        }
    }
);

// POST /api/auth/login
router.post(
    '/login',
    [
        body('username').trim().notEmpty().withMessage('Username is required'),
        body('password').notEmpty().withMessage('Password is required'),
    ],
    validate,
    async (req, res) => {
        try {
            const { username, password, deviceInfo } = req.body;
            const result = await authService.login(username, password, deviceInfo);
            res.json(result);
        } catch (error) {
            logger.error('Login error:', error);
            res.status(401).json({ error: error.message });
        }
    }
);

// POST /api/auth/logout
router.post('/logout', authenticateToken, async (req, res) => {
    try {
        await authService.logout(req.user.userId);
        res.json({ message: 'Logged out successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// POST /api/auth/refresh
router.post('/refresh', authenticateToken, async (req, res) => {
    try {
        const tokens = await authService.refreshToken(req.user.userId);
        res.json(tokens);
    } catch (error) {
        res.status(401).json({ error: error.message });
    }
});

// GET /api/auth/me
router.get('/me', authenticateToken, async (req, res) => {
    try {
        const user = await authService.getUser(req.user.userId);
        if (!user) return res.status(404).json({ error: 'User not found' });
        res.json(user);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /api/auth/users/search?q=term
router.get('/users/search', authenticateToken, async (req, res) => {
    try {
        const users = await authService.searchUsers(req.query.q || '');
        res.json(users);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /api/auth/users/online
router.get('/users/online', authenticateToken, async (req, res) => {
    try {
        const users = await authService.getOnlineUsers();
        res.json(users);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT /api/auth/public-key
router.put('/public-key', authenticateToken, async (req, res) => {
    try {
        await authService.updatePublicKey(req.user.userId, req.body.publicKey);
        res.json({ message: 'Public key updated' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

export default router;

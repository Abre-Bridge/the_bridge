import jwt from 'jsonwebtoken';
import config from '../config/index.js';
import logger from '../utils/logger.js';

export const authenticateToken = (req, res, next) => {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Authentication required' });
    }

    try {
        const decoded = jwt.verify(token, config.jwt.secret);
        req.user = decoded;
        next();
    } catch (error) {
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({ error: 'Token expired' });
        }
        logger.warn('Invalid token attempt:', error.message);
        return res.status(403).json({ error: 'Invalid token' });
    }
};

export const authenticateSocket = (socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;

    if (!token) {
        return next(new Error('Authentication required'));
    }

    try {
        const decoded = jwt.verify(token, config.jwt.secret);
        socket.user = decoded;
        next();
    } catch (error) {
        logger.warn('Socket auth failed:', error.message);
        next(new Error('Invalid token'));
    }
};

export const generateToken = (payload) => {
    return jwt.sign(payload, config.jwt.secret, {
        expiresIn: config.jwt.expiresIn,
    });
};

export const generateRefreshToken = (payload) => {
    return jwt.sign(payload, config.jwt.secret, {
        expiresIn: config.jwt.refreshExpiresIn,
    });
};

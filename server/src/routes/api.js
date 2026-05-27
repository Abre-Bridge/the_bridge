import express from 'express';
import multer from 'multer';
import crypto from 'crypto';
import path from 'path';
import config from '../config/index.js';
import { authenticateToken } from '../middleware/auth.js';
import authService from '../services/auth/authService.js';
import discoveryService from '../services/discovery/discoveryService.js';
import signalingService from '../services/signaling/signalingService.js';
import os from 'os';

const router = express.Router();

// File upload handling via multer
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, config.fileTransfer.uploadDir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ 
    storage,
    limits: { fileSize: 500 * 1024 * 1024 } // 500MB
});

// Auto-discovery mapping
router.get('/discovery/devices', authenticateToken, (req, res) => {
    res.json(discoveryService.getDevices());
});

router.post('/discovery/heartbeat', authenticateToken, (req, res) => {
    const success = discoveryService.heartbeat(req.body.deviceFingerprint);
    res.json({ success });
});

// Users
router.get('/users/online', authenticateToken, async (req, res) => {
    const online = await authService.getOnlineUsers();
    res.json(online);
});

// File Upload endpoint (for API upload)
router.post('/upload', authenticateToken, upload.single('file'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    const host = req.headers.host; // e.g. "192.168.1.100:3000"
    
    // Using dynamic host instead of hardcoded localhost!
    const fileUrl = `${req.protocol}://${host}/uploads/${req.file.filename}`;

    res.json({
        success: true,
        file: {
            id: crypto.randomUUID(),
            name: req.file.originalname,
            size: req.file.size,
            type: req.file.mimetype,
            url: fileUrl,
            path: req.file.filename
        }
    });
});

// Meetings
router.get('/meetings/active', authenticateToken, (req, res) => {
    res.json(signalingService.getActiveRooms());
});

export default router;

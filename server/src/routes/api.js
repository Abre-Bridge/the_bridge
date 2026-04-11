import { Router } from 'express';
import { authenticateToken } from '../middleware/auth.js';
import multer from 'multer';
import { Client as MinioClient } from 'minio';
import crypto from 'crypto';
import discoveryService from '../services/discovery/discoveryService.js';
import signalingService from '../services/signaling/signalingService.js';
import fileTransferService from '../services/fileTransfer/fileTransferService.js';
import messagingService from '../services/messaging/messagingService.js';
import config from '../config/index.js';
import logger from '../utils/logger.js';

const router = Router();

// Initialize MinIO client
const minioClient = new MinioClient({
    endPoint: config.minio.endPoint,
    port: config.minio.port,
    useSSL: config.minio.useSSL,
    accessKey: config.minio.accessKey,
    secretKey: config.minio.secretKey,
});

// Configure multer for memory storage
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB limit
});

// === DISCOVERY ROUTES ===

// GET /api/discovery/server-info
router.get('/discovery/server-info', (req, res) => {
    res.json(discoveryService.getServerInfo());
});

// POST /api/discovery/register — register device in cross-VLAN registry
router.post('/discovery/register', authenticateToken, (req, res) => {
    try {
        discoveryService.registerDevice({
            ...req.body,
            userId: req.user.userId,
        });
        res.json({ message: 'Device registered' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /api/discovery/devices — get registered devices
router.get('/discovery/devices', authenticateToken, (req, res) => {
    const devices = discoveryService.getDevices(req.query.subnet);
    res.json(devices);
});

// GET /api/discovery/peers — get peers for P2P
router.get('/discovery/peers/:fingerprint', authenticateToken, (req, res) => {
    const peers = discoveryService.getPeersForDevice(req.params.fingerprint);
    res.json(peers);
});

// POST /api/discovery/heartbeat
router.post('/discovery/heartbeat', authenticateToken, (req, res) => {
    const result = discoveryService.heartbeat(req.body.fingerprint);
    res.json({ alive: result });
});

// === MEETING ROUTES ===

// POST /api/meetings — create a new meeting
router.post('/meetings', authenticateToken, (req, res) => {
    try {
        const { title, maxParticipants } = req.body;
        const roomId = signalingService._generateRoomId();
        const room = {
            id: roomId,
            title: title || 'Meeting',
            host: req.user.userId,
            participants: new Map(),
            createdAt: Date.now(),
            maxParticipants: maxParticipants || 50,
        };
        signalingService.rooms.set(roomId, room);
        logger.info(`Room created via API: ${roomId} by ${req.user.username}`);
        res.json({
            roomId,
            title: room.title,
            host: room.host,
            createdAt: room.createdAt,
        });
    } catch (error) {
        logger.error('Create meeting error:', error);
        res.status(500).json({ error: error.message });
    }
});

// GET /api/meetings — get active meetings
router.get('/meetings', authenticateToken, (req, res) => {
    const rooms = signalingService.getActiveRooms();
    res.json(rooms);
});

// GET /api/meetings/:roomId — get meeting info
router.get('/meetings/:roomId', authenticateToken, (req, res) => {
    const room = signalingService.getRoomInfo(req.params.roomId);
    if (!room) return res.status(404).json({ error: 'Meeting not found' });
    res.json(room);
});

// === FILE TRANSFER ROUTES ===

// POST /api/files/upload — upload file to MinIO
router.post('/files/upload', authenticateToken, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file provided' });
        }

        const file = req.file;
        const fileId = crypto.randomUUID();
        const fileName = `${fileId}-${file.originalname}`;

        // For testing: store file locally instead of MinIO
        const fs = await import('fs');
        const path = await import('path');
        const uploadDir = path.join(process.cwd(), 'uploads');
        
        // Ensure upload directory exists
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }

        const filePath = path.join(uploadDir, fileName);
        fs.writeFileSync(filePath, file.buffer);

        // Generate local URL
        const fileUrl = `http://localhost:3001/uploads/${fileName}`;

        res.json({
            fileId,
            fileName: file.originalname,
            fileUrl,
            fileSize: file.size,
            fileType: file.mimetype,
        });
    } catch (error) {
        logger.error('File upload error:', error);
        res.status(500).json({ error: error.message });
    }
});

// GET /api/files/transfers — get active file transfers
router.get('/files/transfers', authenticateToken, (req, res) => {
    const transfers = fileTransferService.getActiveTransfers(req.user.userId);
    res.json(transfers);
});

// GET /api/files/history — get file transfer history
router.get('/files/history', authenticateToken, async (req, res) => {
    try {
        const history = await fileTransferService.getTransferHistory(
            req.user.userId,
            parseInt(req.query.limit || '50')
        );
        res.json(history);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// === STATUS ROUTES ===

// GET /api/status — overall server status
router.get('/status', (req, res) => {
    res.json({
        status: 'operational',
        version: '1.0.0',
        uptime: process.uptime(),
        onlineUsers: messagingService.getOnlineCount(),
        activeMeetings: signalingService.getActiveRooms().length,
        timestamp: Date.now(),
    });
});

// GET /api/health — health check
router.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: Date.now() });
});

export default router;

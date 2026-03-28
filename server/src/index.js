import express from 'express';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import cookieParser from 'cookie-parser';

import config from './config/index.js';
import logger from './utils/logger.js';
import { initDatabase } from './models/database.js';
import { authenticateSocket } from './middleware/auth.js';

// Services
import discoveryService from './services/discovery/discoveryService.js';
import messagingService from './services/messaging/messagingService.js';
import signalingService from './services/signaling/signalingService.js';
import fileTransferService from './services/fileTransfer/fileTransferService.js';

// Routes
import authRoutes from './routes/auth.js';
import channelRoutes from './routes/channels.js';
import messageRoutes from './routes/messages.js';
import apiRoutes from './routes/api.js';

async function startServer() {
    // ========== EXPRESS APP ==========
    const app = express();

    app.use(helmet({ contentSecurityPolicy: false }));
    app.use(cors({ origin: true, credentials: true }));
    app.use(compression());
    app.use(express.json({ limit: '50mb' }));
    app.use(express.urlencoded({ extended: true }));
    app.use(cookieParser());
    app.use(morgan('short', { stream: { write: (msg) => logger.info(msg.trim()) } }));

    // API Routes
    app.use('/api/auth', authRoutes);
    app.use('/api/channels', channelRoutes);
    app.use('/api/messages', messageRoutes);
    app.use('/api', apiRoutes);

    // Error handler
    app.use((err, req, res, next) => {
        logger.error('Unhandled error:', err);
        res.status(500).json({ error: 'Internal server error' });
    });

    // ========== HTTP SERVER ==========
    const httpServer = createServer(app);

    // ========== SOCKET.IO — MESSAGING ==========
    const messagingIO = new SocketIOServer(httpServer, {
        path: '/ws/messaging',
        cors: { origin: '*', methods: ['GET', 'POST'] },
        maxHttpBufferSize: 50 * 1024 * 1024, // 50MB for file chunks
        pingTimeout: 60000,
        pingInterval: 25000,
    });

    messagingIO.use(authenticateSocket);

    // ========== SOCKET.IO — SIGNALING ==========
    const signalingIO = new SocketIOServer(httpServer, {
        path: '/ws/signaling',
        cors: { origin: '*', methods: ['GET', 'POST'] },
        pingTimeout: 30000,
        pingInterval: 10000,
    });

    signalingIO.use(authenticateSocket);

    // ========== SOCKET.IO — FILE TRANSFER ==========
    const fileTransferIO = new SocketIOServer(httpServer, {
        path: '/ws/files',
        cors: { origin: '*', methods: ['GET', 'POST'] },
        maxHttpBufferSize: 10 * 1024 * 1024, // 10MB per chunk
        pingTimeout: 120000,
    });

    fileTransferIO.use(authenticateSocket);

    // ========== INITIALIZE DATABASE ==========
    try {
        await initDatabase();
        logger.info('Database initialized');
    } catch (error) {
        logger.error('Database initialization failed:', error.message);
        logger.warn('Server starting without database — some features may be unavailable');
    }

    // ========== INITIALIZE SERVICES ==========

    // Start mDNS discovery
    try {
        discoveryService.start();
    } catch (error) {
        logger.warn('mDNS discovery failed to start:', error.message);
    }

    // Initialize messaging service
    messagingService.initialize(messagingIO);

    // Initialize signaling service
    signalingService.initialize(signalingIO);

    // Initialize file transfer service
    fileTransferService.initialize(fileTransferIO, null);

    // Periodic stale device cleanup
    setInterval(() => discoveryService.cleanupStaleDevices(), 60000);

    // ========== START LISTENING ==========
    const port = config.server.apiPort;
    httpServer.listen(port, config.server.host, () => {
        logger.info('');
        logger.info('╔══════════════════════════════════════════════════════════╗');
        logger.info('║                                                          ║');
        logger.info('║          🌉  TheBridge Server v1.0.0  🌉                 ║');
        logger.info('║          Enterprise LAN Collaboration Platform           ║');
        logger.info('║                                                          ║');
        logger.info('╠══════════════════════════════════════════════════════════╣');
        logger.info(`║  API Server:      http://${config.server.host}:${port}               ║`);
        logger.info(`║  WebSocket (msg): ws://${config.server.host}:${port}/ws/messaging    ║`);
        logger.info(`║  WebSocket (sig): ws://${config.server.host}:${port}/ws/signaling    ║`);
        logger.info(`║  WebSocket (ftp): ws://${config.server.host}:${port}/ws/files        ║`);
        logger.info('║                                                          ║');
        logger.info(`║  Environment:     ${config.env.padEnd(38)}║`);
        logger.info('╚══════════════════════════════════════════════════════════╝');
        logger.info('');
    });

    // Graceful shutdown
    const shutdown = async () => {
        logger.info('Shutting down TheBridge server...');
        discoveryService.stop();
        httpServer.close();
        process.exit(0);
    };

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
}

startServer().catch((error) => {
    logger.error('Failed to start server:', error);
    process.exit(1);
});

import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import fs from 'fs';
import path from 'path';
import morgan from 'morgan';


import config from './config/index.js';
import logger from './utils/logger.js';
import database from './models/database.js';
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

const app = express();
const httpServer = createServer(app);

// Use morgan for HTTP request logging
app.use(morgan(':method :url :status :res[content-length] - :response-time ms', {
    stream: { write: (message) => logger.info(message.trim()) }
}));

// Use a single Socket.IO instance on the HTTP server, avoiding the conflicting ports issue
const io = new Server(httpServer, {
    cors: {
        origin: config.corsOrigins || '*',
        methods: ['GET', 'POST'],
    },
    maxHttpBufferSize: 1e8, // 100MB
});

// Middleware
app.use(cors({ origin: config.corsOrigins || '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ensure upload directory exists
const uploadDir = path.resolve(config.fileTransfer.uploadDir);
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}
app.use('/uploads', express.static(uploadDir));

// Health Check
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'online', 
        message: 'TheBridge API is working',
        timestamp: new Date().toISOString() 
    });
});

app.use('/api/auth', authRoutes);
app.use('/api/channels', channelRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api', apiRoutes);

// Socket.IO Authn
io.use(authenticateSocket);

// Initialize Socket Services with the shared IO instance
messagingService.initialize(io);
signalingService.initialize(io);
fileTransferService.initialize(io);

// Server Init
const startServer = async () => {
    try {
        await database.initDatabase();
        
        httpServer.listen(config.server.port, config.server.host, () => {
            logger.info(`🚀 Server running on http://${config.server.host}:${config.server.port}`);
            
            // Start mDNS discovery advertising this server
            discoveryService.start();
        });

        // Graceful shutdown
        const shutdown = () => {
            logger.info('Shutting down server...');
            discoveryService.stop();
            httpServer.close(() => {
                logger.info('Server closed');
                process.exit(0);
            });
        };

        process.on('SIGINT', shutdown);
        process.on('SIGTERM', shutdown);

    } catch (error) {
        logger.error('Failed to start server:', error);
        process.exit(1);
    }
};

startServer();

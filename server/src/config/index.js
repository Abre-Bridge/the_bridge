import 'dotenv/config';
import os from 'os';

/**
 * Centralized server configuration.
 * All values are env-driven with sensible defaults.
 */

// Detect all non-loopback IPv4 addresses for discovery
function getServerAddresses() {
    const interfaces = os.networkInterfaces();
    const addresses = [];
    for (const [, addrs] of Object.entries(interfaces)) {
        for (const addr of addrs) {
            if (addr.family === 'IPv4' && !addr.internal) {
                addresses.push(addr.address);
            }
        }
    }
    return addresses;
}

const config = {
    env: process.env.NODE_ENV || 'development',

    server: {
        host: process.env.SERVER_HOST || '0.0.0.0',
        port: parseInt(process.env.API_PORT || '3000'),
        addresses: getServerAddresses(),
    },

    postgres: {
        host: process.env.POSTGRES_HOST || 'localhost',
        port: parseInt(process.env.POSTGRES_PORT || '5432'),
        database: process.env.POSTGRES_DB || 'thebridge',
        user: process.env.POSTGRES_USER || 'thebridge',
        password: process.env.POSTGRES_PASSWORD || 'change_me',
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
    },

    redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD || undefined,
    },

    jwt: {
        secret: process.env.JWT_SECRET || 'dev_secret_key',
        expiresIn: process.env.JWT_EXPIRES_IN || '24h',
        refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
    },

    turn: {
        secret: process.env.TURN_SECRET || 'turn_secret',
        server: process.env.TURN_SERVER || 'turn:0.0.0.0:3478',
        stunServer: process.env.STUN_SERVER || 'stun:0.0.0.0:3478',
    },

    mdns: {
        serviceName: process.env.MDNS_SERVICE_NAME || 'thebridge',
        serviceType: process.env.MDNS_SERVICE_TYPE || '_thebridge._tcp.local',
    },

    fileTransfer: {
        maxSize: process.env.MAX_FILE_SIZE || '500MB',
        chunkSize: parseInt(process.env.CHUNK_SIZE || '1048576'),
        uploadDir: process.env.UPLOAD_DIR || './uploads',
    },

    logging: {
        level: process.env.LOG_LEVEL || 'info',
    },
};

export default config;

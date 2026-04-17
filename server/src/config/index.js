import 'dotenv/config';

const config = {
    env: process.env.NODE_ENV || 'development',

    server: {
        host: process.env.SERVER_HOST || '0.0.0.0',
        apiPort: parseInt(process.env.API_PORT || '3001'),
        wsPort: parseInt(process.env.API_PORT || '3001'),
        signalingPort: parseInt(process.env.API_PORT || '3001'),
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

    minio: {
        endPoint: process.env.MINIO_ENDPOINT || 'localhost',
        port: parseInt(process.env.MINIO_PORT || '9000'),
        useSSL: false,
        accessKey: process.env.MINIO_ACCESS_KEY || 'thebridge',
        secretKey: process.env.MINIO_SECRET_KEY || 'change_me',
        bucket: process.env.MINIO_BUCKET || 'thebridge-files',
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
    },

    tls: {
        certPath: process.env.TLS_CERT_PATH || './certs/server.crt',
        keyPath: process.env.TLS_KEY_PATH || './certs/server.key',
    },

    logging: {
        level: process.env.LOG_LEVEL || 'info',
    },
};

export default config;

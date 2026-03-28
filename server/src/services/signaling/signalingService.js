import crypto from 'crypto';
import config from '../../config/index.js';
import logger from '../../utils/logger.js';

/**
 * WebRTC Signaling Service
 *
 * Handles:
 * - Room management for video meetings
 * - ICE candidate exchange
 * - SDP offer/answer relay
 * - TURN credential generation
 * - Multi-party conferencing support
 */
class SignalingService {
    constructor() {
        this.io = null;
        this.rooms = new Map(); // roomId -> { participants: Map, host: userId, createdAt }
        this.userRooms = new Map(); // userId -> roomId
    }

    initialize(io) {
        this.io = io;
        this._setupSignalingHandlers();
        logger.info('WebRTC signaling service initialized');
    }

    _setupSignalingHandlers() {
        this.io.on('connection', (socket) => {
            const userId = socket.user.userId;
            const username = socket.user.username;

            logger.info(`Signaling client connected: ${username}`);

            // Create a new meeting room
            socket.on('room:create', (data, callback) => {
                try {
                    const roomId = data.roomId || this._generateRoomId();
                    const room = {
                        id: roomId,
                        title: data.title || 'Meeting',
                        host: userId,
                        participants: new Map(),
                        createdAt: Date.now(),
                        maxParticipants: data.maxParticipants || 50,
                    };
                    this.rooms.set(roomId, room);
                    logger.info(`Room created: ${roomId} by ${username}`);
                    callback({ success: true, roomId });
                } catch (error) {
                    callback({ success: false, error: error.message });
                }
            });

            // Join a meeting room
            socket.on('room:join', (data, callback) => {
                try {
                    const { roomId } = data;
                    const room = this.rooms.get(roomId);

                    if (!room) {
                        return callback({ success: false, error: 'Room not found' });
                    }

                    if (room.participants.size >= room.maxParticipants) {
                        return callback({ success: false, error: 'Room is full' });
                    }

                    // Join the socket room
                    socket.join(`meeting:${roomId}`);

                    // Add participant
                    room.participants.set(userId, {
                        userId,
                        username,
                        socketId: socket.id,
                        joinedAt: Date.now(),
                        audio: true,
                        video: true,
                    });

                    this.userRooms.set(userId, roomId);

                    // Notify existing participants
                    socket.to(`meeting:${roomId}`).emit('room:peer_joined', {
                        userId,
                        username,
                        participants: this._getParticipantList(roomId),
                    });

                    callback({
                        success: true,
                        roomId,
                        participants: this._getParticipantList(roomId),
                        iceServers: this._getIceServers(userId),
                    });

                    logger.info(`${username} joined room ${roomId}`);
                } catch (error) {
                    callback({ success: false, error: error.message });
                }
            });

            // Leave a meeting room
            socket.on('room:leave', () => {
                this._handleLeaveRoom(socket, userId, username);
            });

            // WebRTC Signaling: Send offer
            socket.on('signal:offer', (data) => {
                const { targetUserId, offer } = data;
                const room = this.rooms.get(this.userRooms.get(userId));
                if (room) {
                    const target = room.participants.get(targetUserId);
                    if (target) {
                        this.io.to(target.socketId).emit('signal:offer', {
                            fromUserId: userId,
                            fromUsername: username,
                            offer,
                        });
                    }
                }
            });

            // WebRTC Signaling: Send answer
            socket.on('signal:answer', (data) => {
                const { targetUserId, answer } = data;
                const room = this.rooms.get(this.userRooms.get(userId));
                if (room) {
                    const target = room.participants.get(targetUserId);
                    if (target) {
                        this.io.to(target.socketId).emit('signal:answer', {
                            fromUserId: userId,
                            answer,
                        });
                    }
                }
            });

            // WebRTC Signaling: ICE candidate exchange
            socket.on('signal:ice_candidate', (data) => {
                const { targetUserId, candidate } = data;
                const room = this.rooms.get(this.userRooms.get(userId));
                if (room) {
                    const target = room.participants.get(targetUserId);
                    if (target) {
                        this.io.to(target.socketId).emit('signal:ice_candidate', {
                            fromUserId: userId,
                            candidate,
                        });
                    }
                }
            });

            // Toggle audio
            socket.on('media:toggle_audio', (data) => {
                const roomId = this.userRooms.get(userId);
                if (roomId) {
                    const room = this.rooms.get(roomId);
                    const participant = room?.participants.get(userId);
                    if (participant) {
                        participant.audio = data.enabled;
                        socket.to(`meeting:${roomId}`).emit('media:audio_toggled', {
                            userId,
                            enabled: data.enabled,
                        });
                    }
                }
            });

            // Toggle video
            socket.on('media:toggle_video', (data) => {
                const roomId = this.userRooms.get(userId);
                if (roomId) {
                    const room = this.rooms.get(roomId);
                    const participant = room?.participants.get(userId);
                    if (participant) {
                        participant.video = data.enabled;
                        socket.to(`meeting:${roomId}`).emit('media:video_toggled', {
                            userId,
                            enabled: data.enabled,
                        });
                    }
                }
            });

            // Screen sharing
            socket.on('media:screen_share', (data) => {
                const roomId = this.userRooms.get(userId);
                if (roomId) {
                    socket.to(`meeting:${roomId}`).emit('media:screen_share', {
                        userId,
                        username,
                        sharing: data.sharing,
                    });
                }
            });

            // Disconnect
            socket.on('disconnect', () => {
                this._handleLeaveRoom(socket, userId, username);
            });
        });
    }

    _handleLeaveRoom(socket, userId, username) {
        const roomId = this.userRooms.get(userId);
        if (!roomId) return;

        const room = this.rooms.get(roomId);
        if (!room) return;

        room.participants.delete(userId);
        this.userRooms.delete(userId);
        socket.leave(`meeting:${roomId}`);

        // Notify remaining participants
        this.io.to(`meeting:${roomId}`).emit('room:peer_left', {
            userId,
            username,
            participants: this._getParticipantList(roomId),
        });

        // Clean up empty rooms
        if (room.participants.size === 0) {
            this.rooms.delete(roomId);
            logger.info(`Room ${roomId} deleted (empty)`);
        }

        logger.info(`${username} left room ${roomId}`);
    }

    _getParticipantList(roomId) {
        const room = this.rooms.get(roomId);
        if (!room) return [];
        return Array.from(room.participants.values()).map((p) => ({
            userId: p.userId,
            username: p.username,
            audio: p.audio,
            video: p.video,
            joinedAt: p.joinedAt,
        }));
    }

    /**
     * Generate TURN credentials (time-limited)
     */
    _getIceServers(userId) {
        const timestamp = Math.floor(Date.now() / 1000) + 86400; // 24h TTL
        const turnUsername = `${timestamp}:${userId}`;
        const hmac = crypto.createHmac('sha1', config.turn.secret);
        hmac.update(turnUsername);
        const turnCredential = hmac.digest('base64');

        return [
            { urls: config.turn.stunServer },
            {
                urls: config.turn.server,
                username: turnUsername,
                credential: turnCredential,
            },
        ];
    }

    _generateRoomId() {
        return crypto.randomBytes(6).toString('hex');
    }

    getRoomInfo(roomId) {
        const room = this.rooms.get(roomId);
        if (!room) return null;
        return {
            id: room.id,
            title: room.title,
            host: room.host,
            participantCount: room.participants.size,
            participants: this._getParticipantList(roomId),
            createdAt: room.createdAt,
        };
    }

    getActiveRooms() {
        return Array.from(this.rooms.entries()).map(([id, room]) => ({
            id,
            title: room.title,
            host: room.host,
            participantCount: room.participants.size,
            createdAt: room.createdAt,
        }));
    }
}

export default new SignalingService();

import { query, isAvailable } from '../../models/database.js';
import logger from '../../utils/logger.js';

/**
 * Messaging Service
 *
 * ALL message sending/receiving happens through Socket.IO only.
 * The socket handler persists to DB AND broadcasts in one atomic flow.
 * No duplicate API path for sending messages.
 */
class MessagingService {
    constructor() {
        this.io = null;
        this.onlineUsers = new Map(); // userId -> Set<socketId>
    }

    initialize(io) {
        this.io = io;
        this._setupSocketHandlers();
        logger.info('💬 Messaging service initialized');
    }

    _setupSocketHandlers() {
        this.io.on('connection', (socket) => {
            const userId = socket.user.userId;
            const username = socket.user.username;

            logger.info(`User connected: ${username} (${socket.id})`);

            // Track online user
            if (!this.onlineUsers.has(userId)) {
                this.onlineUsers.set(userId, new Set());
            }
            this.onlineUsers.get(userId).add(socket.id);

            // Join a personal room for targeted delivery
            socket.join(`user:${userId}`);

            // Broadcast presence
            this._updateUserStatus(userId, 'online');

            // Auto-join user's channels
            this._joinUserChannels(socket, userId);

            // ============ MESSAGE HANDLERS ============

            // Send channel message (socket-only path)
            socket.on('message:send', async (data, callback) => {
                try {
                    const result = await this.sendChannelMessage(userId, data);
                    if (callback) callback({ success: true, message: result });
                } catch (error) {
                    logger.error('Message send error:', error);
                    if (callback) callback({ success: false, error: error.message });
                }
            });

            // Send direct message (socket-only path)
            socket.on('dm:send', async (data, callback) => {
                try {
                    const result = await this.sendDirectMessage(userId, data);
                    if (callback) callback({ success: true, message: result });
                } catch (error) {
                    logger.error('DM send error:', error);
                    if (callback) callback({ success: false, error: error.message });
                }
            });

            // Typing indicators
            socket.on('typing:start', (data) => {
                if (data.channelId) {
                    socket.to(`channel:${data.channelId}`).emit('typing:start', {
                        userId, username, channelId: data.channelId,
                    });
                } else if (data.receiverId) {
                    this._emitToUser(data.receiverId, 'typing:start', { userId, username });
                }
            });

            socket.on('typing:stop', (data) => {
                if (data.channelId) {
                    socket.to(`channel:${data.channelId}`).emit('typing:stop', {
                        userId, channelId: data.channelId,
                    });
                } else if (data.receiverId) {
                    this._emitToUser(data.receiverId, 'typing:stop', { userId });
                }
            });

            // Read receipt
            socket.on('message:read', async (data) => {
                try {
                    if (data.messageId && isAvailable()) {
                        await query(
                            'UPDATE direct_messages SET is_read = true WHERE id = $1 AND receiver_id = $2',
                            [data.messageId, userId]
                        );
                        this._emitToUser(data.senderId, 'message:read', {
                            messageId: data.messageId, readBy: userId,
                        });
                    }
                } catch (error) {
                    logger.error('Read receipt error:', error);
                }
            });

            // Edit message
            socket.on('message:edit', async (data, callback) => {
                try {
                    const result = await this.editMessage(userId, data);
                    if (callback) callback({ success: true, message: result });
                } catch (error) {
                    if (callback) callback({ success: false, error: error.message });
                }
            });

            // Delete message
            socket.on('message:delete', async (data, callback) => {
                try {
                    await this.deleteMessage(userId, data.messageId, data.channelId);
                    if (callback) callback({ success: true });
                } catch (error) {
                    if (callback) callback({ success: false, error: error.message });
                }
            });

            // Channel join/leave
            socket.on('channel:join', async (data) => {
                socket.join(`channel:${data.channelId}`);
                if (isAvailable()) {
                    await query(
                        `INSERT INTO channel_members (channel_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
                        [data.channelId, userId]
                    );
                }
                this.io.to(`channel:${data.channelId}`).emit('channel:user_joined', {
                    channelId: data.channelId, userId, username,
                });
            });

            socket.on('channel:leave', async (data) => {
                socket.leave(`channel:${data.channelId}`);
                if (isAvailable()) {
                    await query(
                        'DELETE FROM channel_members WHERE channel_id = $1 AND user_id = $2',
                        [data.channelId, userId]
                    );
                }
                this.io.to(`channel:${data.channelId}`).emit('channel:user_left', {
                    channelId: data.channelId, userId,
                });
            });

            // Presence ping
            socket.on('presence:ping', () => {
                socket.emit('presence:pong', { timestamp: Date.now() });
            });

            // Disconnect
            socket.on('disconnect', (reason) => {
                logger.info(`User disconnected: ${username} (${reason})`);
                const sockets = this.onlineUsers.get(userId);
                if (sockets) {
                    sockets.delete(socket.id);
                    if (sockets.size === 0) {
                        this.onlineUsers.delete(userId);
                        this._updateUserStatus(userId, 'offline');
                    }
                }
            });
        });
    }

    /**
     * Send a channel message: persist to DB + broadcast to room
     */
    async sendChannelMessage(senderId, data) {
        const { channelId, content, encryptedContent, messageType = 'text', replyTo, fileInfo } = data;

        let messageId = `temp_${Date.now()}`;
        let createdAt = new Date().toISOString();

        // Persist to DB if available
        if (isAvailable()) {
            const result = await query(
                `INSERT INTO messages (channel_id, sender_id, content, encrypted_content, message_type, reply_to, file_url, file_name, file_size, file_type)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                 RETURNING *`,
                [channelId, senderId, content, encryptedContent, messageType, replyTo,
                    fileInfo?.url, fileInfo?.name, fileInfo?.size, fileInfo?.type]
            );
            const row = result.rows[0];
            messageId = row.id;
            createdAt = row.created_at;
        }

        // Get sender info
        let sender = { id: senderId, username: 'Unknown', displayName: 'Unknown', avatarUrl: null };
        if (isAvailable()) {
            const senderResult = await query(
                'SELECT username, display_name, avatar_url FROM users WHERE id = $1', [senderId]
            );
            if (senderResult.rows.length > 0) {
                const s = senderResult.rows[0];
                sender = { id: senderId, username: s.username, displayName: s.display_name, avatarUrl: s.avatar_url };
            }
        }

        const broadcastMessage = {
            id: messageId,
            channel_id: channelId,
            sender_id: senderId,
            content, message_type: messageType,
            file_url: fileInfo?.url, file_name: fileInfo?.name, file_size: fileInfo?.size, file_type: fileInfo?.type,
            is_edited: false, is_deleted: false,
            created_at: createdAt,
            sender,
        };

        // Broadcast to everyone in the channel
        this.io.to(`channel:${channelId}`).emit('message:new', broadcastMessage);
        return broadcastMessage;
    }

    /**
     * Send a direct message: persist to DB + deliver to sender + receiver
     */
    async sendDirectMessage(senderId, data) {
        const { receiverId, content, encryptedContent, messageType = 'text', fileInfo } = data;

        let messageId = `temp_${Date.now()}`;
        let createdAt = new Date().toISOString();

        if (isAvailable()) {
            const result = await query(
                `INSERT INTO direct_messages (sender_id, receiver_id, content, encrypted_content, message_type, file_url, file_name, file_size, file_type)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                 RETURNING *`,
                [senderId, receiverId, content, encryptedContent, messageType,
                    fileInfo?.url, fileInfo?.name, fileInfo?.size, fileInfo?.type]
            );
            const row = result.rows[0];
            messageId = row.id;
            createdAt = row.created_at;
        }

        let sender = { id: senderId, username: 'Unknown', displayName: 'Unknown', avatarUrl: null };
        if (isAvailable()) {
            const senderResult = await query(
                'SELECT username, display_name, avatar_url FROM users WHERE id = $1', [senderId]
            );
            if (senderResult.rows.length > 0) {
                const s = senderResult.rows[0];
                sender = { id: senderId, username: s.username, displayName: s.display_name, avatarUrl: s.avatar_url };
            }
        }

        const dmMessage = {
            id: messageId,
            sender_id: senderId,
            receiver_id: receiverId,
            content, message_type: messageType,
            file_url: fileInfo?.url, file_name: fileInfo?.name, file_size: fileInfo?.size, file_type: fileInfo?.type,
            is_read: false, is_deleted: false,
            created_at: createdAt,
            sender,
        };

        // Deliver to both receiver AND sender (multi-device support)
        this._emitToUser(receiverId, 'dm:new', dmMessage);
        this._emitToUser(senderId, 'dm:new', dmMessage);

        return dmMessage;
    }

    async editMessage(userId, data) {
        if (!isAvailable()) throw new Error('Database unavailable');
        const { messageId, content, channelId } = data;
        const result = await query(
            `UPDATE messages SET content = $1, is_edited = true, updated_at = NOW()
             WHERE id = $2 AND sender_id = $3 RETURNING *`,
            [content, messageId, userId]
        );
        if (result.rows.length === 0) throw new Error('Message not found or unauthorized');
        this.io.to(`channel:${channelId}`).emit('message:edited', result.rows[0]);
        return result.rows[0];
    }

    async deleteMessage(userId, messageId, channelId) {
        if (!isAvailable()) throw new Error('Database unavailable');
        await query(
            `UPDATE messages SET is_deleted = true, content = NULL, updated_at = NOW()
             WHERE id = $1 AND sender_id = $2`,
            [messageId, userId]
        );
        this.io.to(`channel:${channelId}`).emit('message:deleted', { messageId, channelId });
    }

    /**
     * Emit to all sockets of a given user via their personal room
     */
    _emitToUser(userId, event, data) {
        this.io.to(`user:${userId}`).emit(event, data);
    }

    async _updateUserStatus(userId, status) {
        if (isAvailable()) {
            await query("UPDATE users SET status = $1, last_seen = NOW() WHERE id = $2", [status, userId]).catch(() => {});
        }
        this.io.emit('presence:update', { userId, status, timestamp: Date.now() });
    }

    async _joinUserChannels(socket, userId) {
        if (!isAvailable()) return;
        try {
            const result = await query('SELECT channel_id FROM channel_members WHERE user_id = $1', [userId]);
            if (result) {
                result.rows.forEach((row) => socket.join(`channel:${row.channel_id}`));
            }
        } catch (err) {
            logger.warn('Failed to join user channels:', err.message);
        }
    }

    /**
     * Get channel message history (REST endpoint for initial load)
     */
    async getChannelMessages(channelId, limit = 50, before = null) {
        if (!isAvailable()) return [];
        let q = `
            SELECT m.*, u.username, u.display_name, u.avatar_url
            FROM messages m JOIN users u ON m.sender_id = u.id
            WHERE m.channel_id = $1 AND m.is_deleted = false
        `;
        const params = [channelId];
        if (before) {
            q += ` AND m.created_at < $2`;
            params.push(before);
        }
        q += ` ORDER BY m.created_at ASC LIMIT $${params.length + 1}`;
        params.push(limit);
        const result = await query(q, params);
        return result ? result.rows : [];
    }

    /**
     * Get direct message history (REST endpoint for initial load)
     */
    async getDirectMessages(userId1, userId2, limit = 50, before = null) {
        if (!isAvailable()) return [];
        let q = `
            SELECT dm.*, u.username, u.display_name, u.avatar_url
            FROM direct_messages dm JOIN users u ON dm.sender_id = u.id
            WHERE ((dm.sender_id = $1 AND dm.receiver_id = $2)
                OR (dm.sender_id = $2 AND dm.receiver_id = $1))
                AND dm.is_deleted = false
        `;
        const params = [userId1, userId2];
        if (before) {
            q += ` AND dm.created_at < $3`;
            params.push(before);
        }
        q += ` ORDER BY dm.created_at ASC LIMIT $${params.length + 1}`;
        params.push(limit);
        const result = await query(q, params);
        return result ? result.rows : [];
    }

    getOnlineCount() {
        return this.onlineUsers.size;
    }

    isUserOnline(userId) {
        return this.onlineUsers.has(userId);
    }
}

export default new MessagingService();

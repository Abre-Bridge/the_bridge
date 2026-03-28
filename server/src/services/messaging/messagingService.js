import { query } from '../../models/database.js';
import logger from '../../utils/logger.js';

class MessagingService {
    constructor() {
        this.io = null;
        this.onlineUsers = new Map(); // userId -> Set of socketIds
        this.userChannels = new Map(); // userId -> Set of channelIds
    }

    initialize(io) {
        this.io = io;
        this._setupSocketHandlers();
        logger.info('Messaging service initialized');
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

            // Broadcast user online
            this._updateUserStatus(userId, 'online');

            // Join user's channels
            this._joinUserChannels(socket, userId);

            // === MESSAGE HANDLERS ===

            // Send message to channel
            socket.on('message:send', async (data, callback) => {
                try {
                    const result = await this.sendChannelMessage(userId, data);
                    if (callback) callback({ success: true, message: result });
                } catch (error) {
                    logger.error('Message send error:', error);
                    if (callback) callback({ success: false, error: error.message });
                }
            });

            // Send direct message
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
                        userId,
                        username,
                        channelId: data.channelId,
                    });
                } else if (data.receiverId) {
                    this._emitToUser(data.receiverId, 'typing:start', { userId, username });
                }
            });

            socket.on('typing:stop', (data) => {
                if (data.channelId) {
                    socket.to(`channel:${data.channelId}`).emit('typing:stop', {
                        userId,
                        channelId: data.channelId,
                    });
                } else if (data.receiverId) {
                    this._emitToUser(data.receiverId, 'typing:stop', { userId });
                }
            });

            // Message read receipt
            socket.on('message:read', async (data) => {
                try {
                    if (data.messageId) {
                        await query(
                            'UPDATE direct_messages SET is_read = true WHERE id = $1 AND receiver_id = $2',
                            [data.messageId, userId]
                        );
                        this._emitToUser(data.senderId, 'message:read', {
                            messageId: data.messageId,
                            readBy: userId,
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

            // Channel operations
            socket.on('channel:join', async (data) => {
                socket.join(`channel:${data.channelId}`);
                await query(
                    `INSERT INTO channel_members (channel_id, user_id) VALUES ($1, $2)
           ON CONFLICT DO NOTHING`,
                    [data.channelId, userId]
                );
                this.io.to(`channel:${data.channelId}`).emit('channel:user_joined', {
                    channelId: data.channelId,
                    userId,
                    username,
                });
            });

            socket.on('channel:leave', async (data) => {
                socket.leave(`channel:${data.channelId}`);
                await query(
                    'DELETE FROM channel_members WHERE channel_id = $1 AND user_id = $2',
                    [data.channelId, userId]
                );
                this.io.to(`channel:${data.channelId}`).emit('channel:user_left', {
                    channelId: data.channelId,
                    userId,
                });
            });

            // Presence
            socket.on('presence:ping', () => {
                socket.emit('presence:pong', { timestamp: Date.now() });
            });

            // Disconnect
            socket.on('disconnect', (reason) => {
                logger.info(`User disconnected: ${username} (${reason})`);
                const userSockets = this.onlineUsers.get(userId);
                if (userSockets) {
                    userSockets.delete(socket.id);
                    if (userSockets.size === 0) {
                        this.onlineUsers.delete(userId);
                        this._updateUserStatus(userId, 'offline');
                    }
                }
            });
        });
    }

    /**
     * Send a message to a channel
     */
    async sendChannelMessage(senderId, data) {
        const { channelId, content, encryptedContent, messageType = 'text', replyTo, fileInfo } = data;

        const result = await query(
            `INSERT INTO messages (channel_id, sender_id, content, encrypted_content, message_type, reply_to, file_url, file_name, file_size, file_type)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
            [
                channelId, senderId, content, encryptedContent, messageType, replyTo,
                fileInfo?.url, fileInfo?.name, fileInfo?.size, fileInfo?.type,
            ]
        );

        const message = result.rows[0];

        // Get sender info
        const senderResult = await query(
            'SELECT username, display_name, avatar_url FROM users WHERE id = $1',
            [senderId]
        );
        const sender = senderResult.rows[0];

        const broadcastMessage = {
            ...message,
            sender: {
                id: senderId,
                username: sender.username,
                displayName: sender.display_name,
                avatarUrl: sender.avatar_url,
            },
        };

        this.io.to(`channel:${channelId}`).emit('message:new', broadcastMessage);
        return broadcastMessage;
    }

    /**
     * Send a direct message
     */
    async sendDirectMessage(senderId, data) {
        const { receiverId, content, encryptedContent, messageType = 'text', fileInfo } = data;

        const result = await query(
            `INSERT INTO direct_messages (sender_id, receiver_id, content, encrypted_content, message_type, file_url, file_name, file_size, file_type)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
            [
                senderId, receiverId, content, encryptedContent, messageType,
                fileInfo?.url, fileInfo?.name, fileInfo?.size, fileInfo?.type,
            ]
        );

        const message = result.rows[0];

        const senderResult = await query(
            'SELECT username, display_name, avatar_url FROM users WHERE id = $1',
            [senderId]
        );
        const sender = senderResult.rows[0];

        const dmMessage = {
            ...message,
            sender: {
                id: senderId,
                username: sender.username,
                displayName: sender.display_name,
                avatarUrl: sender.avatar_url,
            },
        };

        // Send to receiver
        this._emitToUser(receiverId, 'dm:new', dmMessage);
        // Also echo back to sender (for multi-device support)
        this._emitToUser(senderId, 'dm:new', dmMessage);

        return dmMessage;
    }

    /**
     * Edit a message
     */
    async editMessage(userId, data) {
        const { messageId, content, channelId } = data;

        const result = await query(
            `UPDATE messages SET content = $1, is_edited = true, updated_at = NOW()
       WHERE id = $2 AND sender_id = $3
       RETURNING *`,
            [content, messageId, userId]
        );

        if (result.rows.length === 0) throw new Error('Message not found or unauthorized');

        this.io.to(`channel:${channelId}`).emit('message:edited', result.rows[0]);
        return result.rows[0];
    }

    /**
     * Delete a message
     */
    async deleteMessage(userId, messageId, channelId) {
        await query(
            `UPDATE messages SET is_deleted = true, content = NULL, updated_at = NOW()
       WHERE id = $1 AND sender_id = $2`,
            [messageId, userId]
        );

        this.io.to(`channel:${channelId}`).emit('message:deleted', { messageId, channelId });
    }

    /**
     * Emit event to a specific user (all their connected sockets)
     */
    _emitToUser(userId, event, data) {
        const sockets = this.onlineUsers.get(userId);
        if (sockets) {
            sockets.forEach((socketId) => {
                this.io.to(socketId).emit(event, data);
            });
        }
    }

    /**
     * Update user presence status
     */
    async _updateUserStatus(userId, status) {
        await query("UPDATE users SET status = $1, last_seen = NOW() WHERE id = $2", [status, userId]);
        this.io.emit('presence:update', { userId, status, timestamp: Date.now() });
    }

    /**
     * Join all channels the user is a member of
     */
    async _joinUserChannels(socket, userId) {
        const result = await query(
            'SELECT channel_id FROM channel_members WHERE user_id = $1',
            [userId]
        );
        result.rows.forEach((row) => {
            socket.join(`channel:${row.channel_id}`);
        });
    }

    /**
     * Get channel message history
     */
    async getChannelMessages(channelId, limit = 50, before = null) {
        let queryStr = `
      SELECT m.*, u.username, u.display_name, u.avatar_url
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.channel_id = $1 AND m.is_deleted = false
    `;
        const params = [channelId];

        if (before) {
            queryStr += ` AND m.created_at < $2`;
            params.push(before);
        }

        queryStr += ` ORDER BY m.created_at DESC LIMIT $${params.length + 1}`;
        params.push(limit);

        const result = await query(queryStr, params);
        return result.rows.reverse();
    }

    /**
     * Get direct message history
     */
    async getDirectMessages(userId1, userId2, limit = 50, before = null) {
        let queryStr = `
      SELECT dm.*, u.username, u.display_name, u.avatar_url
      FROM direct_messages dm
      JOIN users u ON dm.sender_id = u.id
      WHERE ((dm.sender_id = $1 AND dm.receiver_id = $2)
        OR (dm.sender_id = $2 AND dm.receiver_id = $1))
        AND dm.is_deleted = false
    `;
        const params = [userId1, userId2];

        if (before) {
            queryStr += ` AND dm.created_at < $3`;
            params.push(before);
        }

        queryStr += ` ORDER BY dm.created_at DESC LIMIT $${params.length + 1}`;
        params.push(limit);

        const result = await query(queryStr, params);
        return result.rows.reverse();
    }

    /**
     * Get online user count
     */
    getOnlineCount() {
        return this.onlineUsers.size;
    }

    /**
     * Check if a user is online
     */
    isUserOnline(userId) {
        return this.onlineUsers.has(userId);
    }
}

export default new MessagingService();

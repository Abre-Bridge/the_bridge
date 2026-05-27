import crypto from 'crypto';
import { query, isAvailable } from '../../models/database.js';
import logger from '../../utils/logger.js';
import config from '../../config/index.js';

/**
 * File Transfer Service
 *
 * Supports chunked relay transfer via WebSocket.
 * Uses the `user:${userId}` room for targeted delivery.
 */
class FileTransferService {
    constructor() {
        this.io = null;
        this.activeTransfers = new Map();
    }

    initialize(io) {
        this.io = io;
        this._setupTransferHandlers();
        logger.info('📁 File transfer service initialized');
    }

    _setupTransferHandlers() {
        this.io.on('connection', (socket) => {
            const userId = socket.user.userId;

            // Join personal room for file events
            socket.join(`user:${userId}`);

            // Request file transfer
            socket.on('file:request', async (data, callback) => {
                try {
                    const transfer = await this._createTransfer(userId, data);
                    callback({ success: true, transfer });

                    this._emitToUser(data.receiverId, 'file:incoming', {
                        transferId: transfer.id,
                        senderId: userId,
                        fileName: data.fileName,
                        fileSize: data.fileSize,
                        fileType: data.fileType,
                        fileHash: data.fileHash,
                    });
                } catch (error) {
                    callback({ success: false, error: error.message });
                }
            });

            // Accept transfer
            socket.on('file:accept', (data) => {
                const transfer = this.activeTransfers.get(data.transferId);
                if (transfer) {
                    transfer.status = 'accepted';
                    this._emitToUser(transfer.senderId, 'file:accepted', { transferId: data.transferId });
                }
            });

            // Reject transfer
            socket.on('file:reject', (data) => {
                const transfer = this.activeTransfers.get(data.transferId);
                if (transfer) {
                    transfer.status = 'rejected';
                    this._emitToUser(transfer.senderId, 'file:rejected', { transferId: data.transferId });
                    this.activeTransfers.delete(data.transferId);
                }
            });

            // Relay chunk
            socket.on('file:chunk', async (data) => {
                const { transferId, chunkIndex, chunkData, isLast } = data;
                const transfer = this.activeTransfers.get(transferId);
                if (!transfer) return;

                transfer.chunksCompleted = chunkIndex + 1;

                this._emitToUser(transfer.receiverId, 'file:chunk', {
                    transferId, chunkIndex, chunkData, isLast,
                    totalChunks: transfer.chunksTotal,
                });

                const progress = Math.round((transfer.chunksCompleted / transfer.chunksTotal) * 100);
                this._emitToUser(transfer.senderId, 'file:progress', { transferId, progress, chunkIndex });

                if (isLast) {
                    transfer.status = 'completed';
                    await this._completeTransfer(transferId);
                }
            });

            // P2P signaling for direct transfer
            socket.on('file:p2p_signal', (data) => {
                this._emitToUser(data.targetUserId, 'file:p2p_signal', {
                    transferId: data.transferId, fromUserId: userId, signal: data.signal,
                });
            });

            // Cancel
            socket.on('file:cancel', (data) => {
                const transfer = this.activeTransfers.get(data.transferId);
                if (transfer) {
                    transfer.status = 'cancelled';
                    const other = transfer.senderId === userId ? transfer.receiverId : transfer.senderId;
                    this._emitToUser(other, 'file:cancelled', { transferId: data.transferId });
                    this.activeTransfers.delete(data.transferId);
                }
            });

            // Resume
            socket.on('file:resume', (data, callback) => {
                const transfer = this.activeTransfers.get(data.transferId);
                if (transfer) {
                    transfer.status = 'transferring';
                    callback({ success: true, resumeFrom: data.fromChunk });
                    this._emitToUser(transfer.senderId, 'file:resume', {
                        transferId: data.transferId, resumeFrom: data.fromChunk,
                    });
                } else {
                    callback({ success: false, error: 'Transfer not found' });
                }
            });
        });
    }

    async _createTransfer(senderId, data) {
        const { receiverId, fileName, fileSize, fileType, fileHash } = data;
        const chunksTotal = Math.ceil(fileSize / config.fileTransfer.chunkSize);
        const transferId = crypto.randomUUID();

        const transfer = {
            id: transferId, senderId, receiverId, fileName, fileSize, fileType, fileHash,
            chunksTotal, chunksCompleted: 0, status: 'pending', transferType: 'relay',
            createdAt: Date.now(),
        };
        this.activeTransfers.set(transferId, transfer);

        if (isAvailable()) {
            await query(
                `INSERT INTO file_transfers (id, sender_id, receiver_id, file_name, file_size, file_type, file_hash, transfer_type, status, chunks_total)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
                [transferId, senderId, receiverId, fileName, fileSize, fileType, fileHash, 'relay', 'pending', chunksTotal]
            ).catch(() => {});
        }

        return transfer;
    }

    async _completeTransfer(transferId) {
        if (isAvailable()) {
            await query(
                `UPDATE file_transfers SET status = 'completed', completed_at = NOW(), chunks_completed = chunks_total WHERE id = $1`,
                [transferId]
            ).catch(() => {});
        }

        const transfer = this.activeTransfers.get(transferId);
        if (transfer) {
            this._emitToUser(transfer.senderId, 'file:completed', { transferId });
            this._emitToUser(transfer.receiverId, 'file:completed', { transferId });
            this.activeTransfers.delete(transferId);
        }
        logger.info(`File transfer completed: ${transferId}`);
    }

    _emitToUser(userId, event, data) {
        this.io.to(`user:${userId}`).emit(event, data);
    }

    getActiveTransfers(userId) {
        return Array.from(this.activeTransfers.values())
            .filter((t) => t.senderId === userId || t.receiverId === userId);
    }

    async getTransferHistory(userId, limit = 50) {
        if (!isAvailable()) return [];
        const result = await query(
            `SELECT * FROM file_transfers WHERE sender_id = $1 OR receiver_id = $1 ORDER BY created_at DESC LIMIT $2`,
            [userId, limit]
        );
        return result ? result.rows : [];
    }
}

export default new FileTransferService();

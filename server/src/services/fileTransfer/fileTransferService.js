import crypto from 'crypto';
import { query } from '../../models/database.js';
import logger from '../../utils/logger.js';
import config from '../../config/index.js';

/**
 * File Transfer Service
 * 
 * Supports:
 * - P2P file transfer via WebRTC data channels
 * - Server-relayed transfer for cross-VLAN
 * - Chunked transfer with resume capability
 * - MinIO-based storage for relay mode
 */
class FileTransferService {
    constructor() {
        this.io = null;
        this.activeTransfers = new Map(); // transferId -> transfer state
        this.minioClient = null;
    }

    initialize(io, minioClient) {
        this.io = io;
        this.minioClient = minioClient;
        this._setupTransferHandlers();
        logger.info('File transfer service initialized');
    }

    _setupTransferHandlers() {
        this.io.on('connection', (socket) => {
            const userId = socket.user.userId;

            // Initiate file transfer request
            socket.on('file:request', async (data, callback) => {
                try {
                    const transfer = await this._createTransfer(userId, data);
                    callback({ success: true, transfer });

                    // Notify receiver
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

            // Accept file transfer
            socket.on('file:accept', async (data) => {
                const { transferId } = data;
                const transfer = this.activeTransfers.get(transferId);
                if (transfer) {
                    transfer.status = 'accepted';
                    this._emitToUser(transfer.senderId, 'file:accepted', { transferId });
                }
            });

            // Reject file transfer
            socket.on('file:reject', async (data) => {
                const { transferId } = data;
                const transfer = this.activeTransfers.get(transferId);
                if (transfer) {
                    transfer.status = 'rejected';
                    this._emitToUser(transfer.senderId, 'file:rejected', { transferId });
                    this.activeTransfers.delete(transferId);
                }
            });

            // Relay chunk (server-mediated transfer)
            socket.on('file:chunk', async (data) => {
                const { transferId, chunkIndex, chunkData, isLast } = data;
                const transfer = this.activeTransfers.get(transferId);
                if (!transfer) return;

                transfer.chunksCompleted = chunkIndex + 1;

                // Forward chunk to receiver
                this._emitToUser(transfer.receiverId, 'file:chunk', {
                    transferId,
                    chunkIndex,
                    chunkData,
                    isLast,
                    totalChunks: transfer.chunksTotal,
                });

                // Update progress
                const progress = Math.round((transfer.chunksCompleted / transfer.chunksTotal) * 100);
                this._emitToUser(transfer.senderId, 'file:progress', { transferId, progress, chunkIndex });

                if (isLast) {
                    transfer.status = 'completed';
                    await this._completeTransfer(transferId);
                }
            });

            // P2P connection info exchange for direct transfer
            socket.on('file:p2p_signal', (data) => {
                const { transferId, targetUserId, signal } = data;
                this._emitToUser(targetUserId, 'file:p2p_signal', {
                    transferId,
                    fromUserId: userId,
                    signal,
                });
            });

            // Cancel transfer
            socket.on('file:cancel', async (data) => {
                const { transferId } = data;
                const transfer = this.activeTransfers.get(transferId);
                if (transfer) {
                    transfer.status = 'cancelled';
                    const otherUserId = transfer.senderId === userId ? transfer.receiverId : transfer.senderId;
                    this._emitToUser(otherUserId, 'file:cancelled', { transferId });
                    this.activeTransfers.delete(transferId);
                }
            });

            // Resume transfer
            socket.on('file:resume', async (data, callback) => {
                const { transferId, fromChunk } = data;
                const transfer = this.activeTransfers.get(transferId);
                if (transfer) {
                    transfer.status = 'transferring';
                    callback({ success: true, resumeFrom: fromChunk });
                    this._emitToUser(transfer.senderId, 'file:resume', {
                        transferId,
                        resumeFrom: fromChunk,
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
            id: transferId,
            senderId,
            receiverId,
            fileName,
            fileSize,
            fileType,
            fileHash,
            chunksTotal,
            chunksCompleted: 0,
            status: 'pending',
            transferType: 'relay', // will be upgraded to 'p2p' if direct connection succeeds
            createdAt: Date.now(),
        };

        this.activeTransfers.set(transferId, transfer);

        // Persist to database
        await query(
            `INSERT INTO file_transfers (id, sender_id, receiver_id, file_name, file_size, file_type, file_hash, transfer_type, status, chunks_total)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
            [transferId, senderId, receiverId, fileName, fileSize, fileType, fileHash, 'relay', 'pending', chunksTotal]
        );

        return transfer;
    }

    async _completeTransfer(transferId) {
        await query(
            `UPDATE file_transfers SET status = 'completed', completed_at = NOW(), chunks_completed = chunks_total
       WHERE id = $1`,
            [transferId]
        );

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
        const result = await query(
            `SELECT * FROM file_transfers
       WHERE sender_id = $1 OR receiver_id = $1
       ORDER BY created_at DESC LIMIT $2`,
            [userId, limit]
        );
        return result.rows;
    }
}

export default new FileTransferService();

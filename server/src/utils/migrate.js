import { initDatabase } from '../models/database.js';
import logger from './logger.js';

async function migrate() {
    try {
        logger.info('Starting manual database migration...');
        await initDatabase();
        logger.info('Database migration completed successfully.');
        process.exit(0);
    } catch (error) {
        logger.error('Database migration failed:', error);
        process.exit(1);
    }
}

migrate();

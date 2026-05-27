import mdns from 'multicast-dns';
import os from 'os';
import config from '../../config/index.js';
import logger from '../../utils/logger.js';

/**
 * mDNS Discovery Service
 *
 * Advertises the server on the LAN so clients can auto-discover it.
 * Also maintains a cross-VLAN device registry.
 */
class DiscoveryService {
    constructor() {
        this.mdnsServer = null;
        this.registeredDevices = new Map();
        this.serverInfo = null;
        this._advertiseInterval = null;
    }

    /**
     * Start mDNS advertisement + query responder
     */
    start() {
        this.serverInfo = this._buildServerInfo();
        this.mdnsServer = mdns();

        // Respond to mDNS queries for our service
        this.mdnsServer.on('query', (query) => {
            if (query.questions && query.questions.length > 0) {
                logger.debug(`Received mDNS query for: ${query.questions[0].name}`);
            }
            
            const isForUs = query.questions.some((q) => {
                const name = q.name.toLowerCase();
                const serviceName = config.mdns.serviceName.toLowerCase();
                const serviceType = config.mdns.serviceType.toLowerCase();
                return (
                    name === `${serviceName}.local` ||
                    name === `${serviceName}.local.` ||
                    name === serviceType ||
                    name === `${serviceType}.` ||
                    name.includes(serviceName)
                );
            });

            if (isForUs) {
                this._advertise();
            }
        });

        // Listen for peer TheBridge instances (for future clustering)
        this.mdnsServer.on('response', (response) => {
            const bridgeRecords = response.answers.filter(
                (a) => a.name && a.name.includes(config.mdns.serviceName)
            );
            if (bridgeRecords.length > 0) {
                logger.debug('Discovered TheBridge peer:', bridgeRecords);
            }
        });

        // Advertise immediately + periodically
        this._advertise();
        this._advertiseInterval = setInterval(() => this._advertise(), 30000);

        logger.info(`🔍 mDNS discovery started — advertising as ${config.mdns.serviceName}.local`);
        logger.info(`   Server IPs: ${this.serverInfo.addresses.join(', ')}`);
    }

    /**
     * Broadcast mDNS advertisement with server address + port info
     */
    _advertise() {
        if (!this.mdnsServer) return;

        const instanceName = `TheBridge Server.${config.mdns.serviceType}`;
        const answers = [
            {
                name: config.mdns.serviceType,
                type: 'PTR',
                ttl: 120,
                data: instanceName,
            },
            {
                name: instanceName,
                type: 'SRV',
                data: {
                    port: config.server.port,
                    target: `${config.mdns.serviceName}.local`,
                },
            },
            {
                name: instanceName,
                type: 'TXT',
                data: [
                    `port=${config.server.port}`,
                    `version=1.0.0`,
                    `name=TheBridge Server`,
                ],
            },
        ];

        // Add A records for every interface IP
        this.serverInfo.addresses.forEach((addr) => {
            answers.push({
                name: `${config.mdns.serviceName}.local`,
                type: 'A',
                ttl: 120,
                data: addr,
            });
        });

        this.mdnsServer.respond({ answers });
    }

    /**
     * Register a client device (cross-VLAN registry)
     */
    registerDevice(deviceInfo) {
        const { fingerprint } = deviceInfo;
        this.registeredDevices.set(fingerprint, {
            ...deviceInfo,
            lastSeen: Date.now(),
            registeredAt: this.registeredDevices.has(fingerprint)
                ? this.registeredDevices.get(fingerprint).registeredAt
                : Date.now(),
        });
        logger.info(`Device registered: ${fingerprint}`);
        return true;
    }

    /**
     * Get all registered devices, optionally filtered by subnet
     */
    getDevices(subnet = null) {
        const devices = Array.from(this.registeredDevices.values());
        return subnet ? devices.filter((d) => d.subnet === subnet) : devices;
    }

    /**
     * Get peers reachable from a given device
     */
    getPeersForDevice(fingerprint) {
        const device = this.registeredDevices.get(fingerprint);
        if (!device) return [];
        return Array.from(this.registeredDevices.values())
            .filter((d) => d.fingerprint !== fingerprint)
            .map((d) => ({
                ...d,
                sameSubnet: d.subnet === device.subnet,
                sameVlan: d.vlanId === device.vlanId,
            }));
    }

    /**
     * Remove devices not seen in 5 minutes
     */
    cleanupStaleDevices() {
        const cutoff = Date.now() - 5 * 60 * 1000;
        for (const [fp, dev] of this.registeredDevices) {
            if (dev.lastSeen < cutoff) {
                this.registeredDevices.delete(fp);
                logger.info(`Removed stale device: ${fp}`);
            }
        }
    }

    /**
     * Heartbeat from a device
     */
    heartbeat(fingerprint) {
        const device = this.registeredDevices.get(fingerprint);
        if (device) {
            device.lastSeen = Date.now();
            return true;
        }
        return false;
    }

    /**
     * Build server info object
     */
    _buildServerInfo() {
        return {
            hostname: os.hostname(),
            addresses: config.server.addresses,
            platform: os.platform(),
            port: config.server.port,
            version: '1.0.0',
        };
    }

    /**
     * Return server connection info for REST clients
     */
    getServerInfo() {
        return this.serverInfo;
    }

    stop() {
        if (this._advertiseInterval) clearInterval(this._advertiseInterval);
        if (this.mdnsServer) this.mdnsServer.destroy();
        logger.info('mDNS discovery stopped');
    }
}

export default new DiscoveryService();

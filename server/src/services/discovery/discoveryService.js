import mdns from 'multicast-dns';
import os from 'os';
import config from '../../config/index.js';
import logger from '../../utils/logger.js';

class DiscoveryService {
    constructor() {
        this.mdnsServer = null;
        this.registeredDevices = new Map(); // fingerprint -> device info
        this.serverInfo = null;
    }

    /**
     * Start mDNS service advertisement
     * Broadcasts the server's presence on the local subnet
     */
    start() {
        this.serverInfo = this._getServerInfo();
        this.mdnsServer = mdns();

        // Respond to mDNS queries for our service
        this.mdnsServer.on('query', (query) => {
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
                this._respondToQuery();
            }
        });

        // Listen for other TheBridge instances (for clustering)
        this.mdnsServer.on('response', (response) => {
            const thebridgeRecords = response.answers.filter(
                (a) => a.name && a.name.includes(config.mdns.serviceName)
            );
            if (thebridgeRecords.length > 0) {
                logger.debug('Discovered TheBridge peer:', thebridgeRecords);
            }
        });

        // Advertise periodically
        this._advertise();
        this._advertiseInterval = setInterval(() => this._advertise(), 30000);

        logger.info(`mDNS discovery started — advertising as ${config.mdns.serviceName}.local`);
        logger.info(`Server interfaces: ${JSON.stringify(this.serverInfo.addresses)}`);
    }

    /**
     * Broadcast server advertisement via mDNS
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
                    port: config.server.apiPort,
                    target: `${config.mdns.serviceName}.local`,
                },
            },
            {
                name: instanceName,
                type: 'TXT',
                data: [
                    `api_port=${config.server.apiPort}`,
                    `ws_port=${config.server.wsPort}`,
                    `signaling_port=${config.server.signalingPort}`,
                    `version=1.0.0`,
                    `name=TheBridge Server`,
                ],
            },
        ];

        // Add all server IP addresses
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

    _respondToQuery() {
        this._advertise();
    }

    /**
     * Register a device in the cross-VLAN registry
     */
    registerDevice(deviceInfo) {
        const { fingerprint, userId, ipAddress, subnet, vlanId, capabilities } = deviceInfo;

        this.registeredDevices.set(fingerprint, {
            ...deviceInfo,
            lastSeen: Date.now(),
            registeredAt: this.registeredDevices.has(fingerprint)
                ? this.registeredDevices.get(fingerprint).registeredAt
                : Date.now(),
        });

        logger.info(`Device registered: ${fingerprint} on subnet ${subnet} (VLAN ${vlanId})`);
        return true;
    }

    /**
     * Get all registered devices, optionally filtered by subnet
     */
    getDevices(subnet = null) {
        const devices = Array.from(this.registeredDevices.values());
        if (subnet) {
            return devices.filter((d) => d.subnet === subnet);
        }
        return devices;
    }

    /**
     * Get devices reachable from a specific subnet (for P2P optimization)
     */
    getPeersForDevice(fingerprint) {
        const device = this.registeredDevices.get(fingerprint);
        if (!device) return [];

        const allDevices = Array.from(this.registeredDevices.values());
        return allDevices
            .filter((d) => d.fingerprint !== fingerprint)
            .map((d) => ({
                ...d,
                sameSubnet: d.subnet === device.subnet,
                sameVlan: d.vlanId === device.vlanId,
            }));
    }

    /**
     * Remove stale devices (not seen in 5 minutes)
     */
    cleanupStaleDevices() {
        const staleThreshold = Date.now() - 5 * 60 * 1000;
        for (const [fingerprint, device] of this.registeredDevices) {
            if (device.lastSeen < staleThreshold) {
                this.registeredDevices.delete(fingerprint);
                logger.info(`Removed stale device: ${fingerprint}`);
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
     * Get server network information
     */
    _getServerInfo() {
        const interfaces = os.networkInterfaces();
        const addresses = [];

        for (const [name, addrs] of Object.entries(interfaces)) {
            for (const addr of addrs) {
                if (addr.family === 'IPv4' && !addr.internal) {
                    addresses.push(addr.address);
                }
            }
        }

        return {
            hostname: os.hostname(),
            addresses,
            platform: os.platform(),
            apiPort: config.server.apiPort,
            wsPort: config.server.wsPort,
            signalingPort: config.server.signalingPort,
        };
    }

    /**
     * Get server connection info for clients
     */
    getServerInfo() {
        return this.serverInfo;
    }

    stop() {
        if (this._advertiseInterval) {
            clearInterval(this._advertiseInterval);
        }
        if (this.mdnsServer) {
            this.mdnsServer.destroy();
        }
        logger.info('mDNS discovery stopped');
    }
}

export default new DiscoveryService();

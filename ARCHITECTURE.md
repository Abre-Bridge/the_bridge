# TheBridge — Enterprise LAN Collaboration Platform

## Architecture Overview

TheBridge is a fully offline enterprise collaboration platform designed to operate
entirely within a Local Area Network (LAN), supporting cross-VLAN communication,
real-time messaging, file sharing, and video conferencing.

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CORPORATE NETWORK                                │
│                                                                         │
│  ┌─────────────────────┐    ┌─────────────────────┐                     │
│  │    VLAN 10 (Eng)     │    │   VLAN 20 (Sales)    │                   │
│  │                      │    │                      │                   │
│  │  ┌──────┐ ┌──────┐  │    │  ┌──────┐ ┌──────┐  │                   │
│  │  │Client│ │Client│  │    │  │Client│ │Client│  │                   │
│  │  │ (A)  │ │ (B)  │──┼────┼──│ (C)  │ │ (D)  │  │                   │
│  │  └──┬───┘ └──┬───┘  │    │  └──┬───┘ └──┬───┘  │                   │
│  │     │        │       │    │     │        │       │                   │
│  │  mDNS Discovery      │    │  mDNS Discovery      │                   │
│  │  (Same Subnet)       │    │  (Same Subnet)       │                   │
│  └──────────┬───────────┘    └──────────┬───────────┘                   │
│             │                           │                               │
│             │    ┌──────────────────┐    │                               │
│             └────┤   L3 Router /    ├────┘                               │
│                  │   Core Switch    │                                    │
│                  └────────┬─────────┘                                    │
│                           │                                             │
│              ┌────────────┴────────────┐                                │
│              │   TheBridge Server      │                                │
│              │   (Docker Cluster)      │                                │
│              │                         │                                │
│              │  ┌───────────────────┐  │                                │
│              │  │  Service Registry │  │                                │
│              │  │  & Discovery      │  │                                │
│              │  └───────────────────┘  │                                │
│              │                         │                                │
│              │  ┌───────────────────┐  │                                │
│              │  │  Message Broker   │  │                                │
│              │  │  (WebSocket)      │  │                                │
│              │  └───────────────────┘  │                                │
│              │                         │                                │
│              │  ┌───────────────────┐  │                                │
│              │  │  WebRTC Signaling │  │                                │
│              │  │  + TURN/STUN      │  │                                │
│              │  └───────────────────┘  │                                │
│              │                         │                                │
│              │  ┌───────────────────┐  │                                │
│              │  │  File Relay       │  │                                │
│              │  │  Server           │  │                                │
│              │  └───────────────────┘  │                                │
│              │                         │                                │
│              │  ┌───────────────────┐  │                                │
│              │  │  Auth & Identity  │  │                                │
│              │  │  Manager          │  │                                │
│              │  └───────────────────┘  │                                │
│              │                         │                                │
│              │  ┌───────────────────┐  │                                │
│              │  │  PostgreSQL +     │  │                                │
│              │  │  Redis Cache      │  │                                │
│              │  └───────────────────┘  │                                │
│              └─────────────────────────┘                                │
│                                                                         │
│  ┌─────────────────────┐    ┌─────────────────────┐                     │
│  │   VLAN 30 (Mgmt)    │    │   VLAN 40 (Ops)      │                   │
│  │  ┌──────┐ ┌──────┐  │    │  ┌──────┐ ┌──────┐  │                   │
│  │  │Client│ │Client│  │    │  │Client│ │Client│  │                   │
│  │  │ (E)  │ │ (F)  │  │    │  │ (G)  │ │ (H)  │  │                   │
│  │  └──────┘ └──────┘  │    │  └──────┘ └──────┘  │                   │
│  └─────────────────────┘    └─────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Network Discovery Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    DISCOVERY FLOW                         │
│                                                           │
│  Step 1: mDNS Broadcast (Same Subnet)                    │
│  ┌──────────┐    mDNS Query     ┌──────────┐             │
│  │  Client   │ ──────────────>  │  Server   │             │
│  │           │ <──────────────  │  (mDNS)   │             │
│  └──────────┘   mDNS Response   └──────────┘             │
│                                                           │
│  Step 2: Fallback — DNS-SD / Manual Config               │
│  ┌──────────┐   HTTP/HTTPS      ┌──────────┐             │
│  │  Client   │ ──────────────>  │  Registry │             │
│  │           │ <──────────────  │  Server   │             │
│  └──────────┘   Server Info     └──────────┘             │
│                                                           │
│  Step 3: Cross-VLAN Registry                             │
│  ┌──────────┐   Register        ┌──────────┐             │
│  │  Client   │ ──────────────>  │  Central  │             │
│  │  (VLAN A) │ <──────────────  │  Registry │             │
│  └──────────┘   Peer List       └──────────┘             │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

## Technology Stack

### Server Side (Node.js)
| Component          | Technology              | Purpose                           |
|--------------------|-------------------------|-----------------------------------|
| Runtime            | Node.js 20 LTS         | Server runtime                    |
| Framework          | Express.js + Fastify    | HTTP API + High-perf endpoints    |
| WebSocket          | Socket.IO               | Real-time messaging               |
| WebRTC Signaling   | Custom + mediasoup      | Video conferencing                |
| TURN/STUN          | coturn (Docker)         | NAT traversal for WebRTC          |
| Database           | PostgreSQL 16           | Persistent storage                |
| Cache              | Redis 7                 | Session, presence, pub/sub        |
| File Storage       | MinIO (S3-compatible)   | Distributed file storage          |
| mDNS               | multicast-dns (npm)     | LAN service discovery             |
| Auth               | JWT + argon2            | Token-based authentication        |
| Encryption         | libsodium / tweetnacl   | E2E encryption                    |
| Container          | Docker + Docker Compose | Deployment                        |

### Client Side (Flutter)
| Component          | Technology              | Purpose                           |
|--------------------|-------------------------|-----------------------------------|
| Framework          | Flutter 3.x             | Cross-platform UI                 |
| State Management   | Riverpod                | Reactive state management         |
| WebSocket          | socket_io_client        | Real-time messaging               |
| WebRTC             | flutter_webrtc          | Video/audio calls                 |
| mDNS               | multicast_dns           | LAN discovery                     |
| HTTP               | dio                     | REST API communication            |
| Storage            | drift (SQLite)          | Local database                    |
| Encryption         | pointycastle            | E2E encryption                    |
| File Transfer      | Custom chunked protocol | P2P + relay file transfer         |
| UI Design          | Glassmorphism + Custom  | Modern premium UI                 |

---

## Data Flow Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      MESSAGE FLOW                               │
│                                                                  │
│  ┌────────┐  Encrypt   ┌─────────┐  Route   ┌────────┐         │
│  │ Sender │ ────────> │  Server  │ ──────> │Receiver│         │
│  │        │           │ (Broker) │         │        │         │
│  └────────┘           └─────────┘          └────────┘         │
│     │                      │                    │               │
│     │  E2E Encrypted       │  Forward Only      │  Decrypt     │
│     │  Payload             │  (cannot read)     │  Payload     │
│     └──────────────────────┴────────────────────┘               │
│                                                                  │
│                      FILE TRANSFER FLOW                          │
│                                                                  │
│  ┌────────┐  P2P Try   ┌─────────┐  Relay   ┌────────┐         │
│  │ Sender │ ────────> │   TURN   │ ──────> │Receiver│         │
│  │        │           │  Server  │         │        │         │
│  └────────┘           └─────────┘          └────────┘         │
│     │                                           │               │
│     │  Direct P2P (same subnet)                 │               │
│     └───────────────────────────────────────────┘               │
│                                                                  │
│                      VIDEO CALL FLOW                             │
│                                                                  │
│  ┌────────┐  Signal   ┌─────────┐  Signal  ┌────────┐          │
│  │ Caller │ ────────> │Signaling│ ──────> │ Callee │          │
│  │        │           │ Server  │         │        │          │
│  └────────┘           └─────────┘          └────────┘          │
│     │                                           │               │
│     │  WebRTC Media Stream (P2P or TURN)        │               │
│     └───────────────────────────────────────────┘               │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

---

## Security Architecture

```
┌─────────────────────────────────────────────────────┐
│                 ZERO TRUST MODEL                      │
│                                                       │
│  ┌───────────┐         ┌──────────────┐               │
│  │  Device    │──Auth──>│  Identity     │               │
│  │  Identity  │         │  Manager      │               │
│  │  (X.509)   │         │  (JWT+RBAC)   │               │
│  └───────────┘         └──────────────┘               │
│       │                       │                        │
│       ▼                       ▼                        │
│  ┌───────────┐         ┌──────────────┐               │
│  │  TLS 1.3   │         │  E2E Encrypt │               │
│  │  Transport │         │  (X25519 +   │               │
│  │  Security  │         │   XSalsa20)  │               │
│  └───────────┘         └──────────────┘               │
│                                                       │
│  Key Exchange: X25519 Diffie-Hellman                  │
│  Message Encryption: XSalsa20-Poly1305                │
│  Password Hashing: Argon2id                           │
│  Token Auth: JWT with RS256                           │
└─────────────────────────────────────────────────────┘
```

---

## Deployment Architecture

```yaml
# Docker Compose Services
services:
  - thebridge-api        # Main API server (Node.js)
  - thebridge-ws         # WebSocket server (Socket.IO)
  - thebridge-signaling  # WebRTC signaling server
  - thebridge-turn       # TURN/STUN server (coturn)
  - thebridge-postgres   # PostgreSQL database
  - thebridge-redis      # Redis cache + pub/sub
  - thebridge-minio      # MinIO file storage
  - thebridge-mdns       # mDNS discovery daemon
```

---

## Scalability Design

| Scale Factor      | Solution                                  |
|--------------------|-------------------------------------------|
| 1–100 users       | Single server, all-in-one Docker Compose  |
| 100–1000 users    | Separate WS/API servers, Redis pub/sub    |
| 1000–5000 users   | Multiple WS nodes, load balancer, sharding|
| 5000+ users       | Kubernetes cluster, horizontal scaling    |

---

## Port Allocations

| Service            | Port  | Protocol |
|--------------------|-------|----------|
| API Server         | 3000  | HTTPS    |
| WebSocket Server   | 3001  | WSS      |
| Signaling Server   | 3002  | WSS      |
| TURN Server        | 3478  | UDP/TCP  |
| STUN Server        | 3478  | UDP      |
| TURN TLS           | 5349  | TLS      |
| PostgreSQL         | 5432  | TCP      |
| Redis              | 6379  | TCP      |
| MinIO              | 9000  | HTTPS    |
| MinIO Console      | 9001  | HTTPS    |
| mDNS               | 5353  | UDP      |

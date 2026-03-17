# NetScaler VIP Address Allocation

This document tracks the allocation of NetScaler Virtual IP (VIP) addresses for Citrix Ingress Controller across all clusters.

## Allocated IP Addresses

### platform-prod01
- **External VIP (nsInternetVIP)**: `<CLUSTER_PROD_INTERNET_VIP>`
  - Used for public-facing services
- **Internal VIP (nsVIP)**: `<CLUSTER_PROD_NSVIP>`
  - Used for LAN/internal services
- **Reserved Internal**: `<CLUSTER_PROD_NSVIP_RESERVED>`
  - Reserved for additional internal services if needed

### platform-test01
- **External VIP (nsInternetVIP)**: `<CLUSTER_TEST_INTERNET_VIP>`
  - Used for public-facing services
- **Internal VIP (nsVIP)**: `<CLUSTER_TEST_NSVIP>`
  - Used for LAN/internal services
- **Reserved Internal**: `<CLUSTER_TEST_NSVIP_RESERVED>`
  - Reserved for additional internal services if needed

## Available IP Addresses

### External IPs (Public-Facing)
- `<CLUSTER_SHARED_PROD_INTERNET_VIP>`
- `<CLUSTER_SHARED_TEST_INTERNET_VIP>`
- `193.180.108.12`
- `193.180.108.13`

**Total Available**: 4 IPs

### Internal IPs (LAN Services)
- `10.230.13.64`
- `10.230.13.65`
- `10.230.13.66`
- `10.230.13.67`
- `10.230.13.68`

**Total Available**: 5 IPs (with 2 reserved: .61, .63)

## Shared Clusters (Planned)

### shared-prod01 (Not yet allocated)
- **External VIP**: TBD (suggest: <CLUSTER_SHARED_PROD_INTERNET_VIP>)
- **Internal VIP**: TBD (suggest: 10.230.13.64)
- **Reserved Internal**: TBD (suggest: 10.230.13.65)

### shared-test01 (Not yet allocated)
- **External VIP**: TBD (suggest: <CLUSTER_SHARED_TEST_INTERNET_VIP>)
- **Internal VIP**: TBD (suggest: 10.230.13.66)
- **Reserved Internal**: TBD (suggest: 10.230.13.67)

## Administrative Configuration

All clusters share the same NetScaler administrative IP:
- **Management IP (nsIP)**: `<NETSCALER_NSIP>`
  - Used for Nitro API communication
  - Configured in all cluster definitions

## Subnet Information

### platform-prod01
- **SNIP (Subnet IP)**: `<CLUSTER_PROD_SNIP>`
  - Cluster subnet: `10.230.27.0/24`
  - Used for Policy Based Routes

### platform-test01
- **SNIP (Subnet IP)**: `<CLUSTER_TEST_SNIP>`
  - Cluster subnet: `10.230.28.0/24`
  - Used for Policy Based Routes

## Allocation Strategy

- **1 External IP per cluster**: For public-facing services (HTTPS ingress)
- **2 Internal IPs per cluster**: Primary VIP + 1 reserved for future use
- **Naming Convention**:
  - External: `nsInternetVIP` in cluster config
  - Internal: `nsVIP` in cluster config

## Updates

| Date       | Cluster          | Action                                    |
|------------|------------------|-------------------------------------------|
| 2026-02-24 | platform-prod01  | Allocated <CLUSTER_PROD_INTERNET_VIP>, <CLUSTER_PROD_NSVIP>-61  |
| 2026-02-24 | platform-test01  | Allocated <CLUSTER_TEST_INTERNET_VIP>, <CLUSTER_TEST_NSVIP>-63  |

---

**Note**: Update this document when allocating IPs to new clusters to maintain accurate tracking.

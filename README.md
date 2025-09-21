# Aqua - Water Rights NFT System

A decentralized water rights allocation and trading platform built on the Stacks blockchain using Clarity smart contracts.

## Overview

Aqua enables the tokenization and trading of water rights and irrigation quotas as Non-Fungible Tokens (NFTs). This system provides a transparent, secure, and efficient marketplace for water resource management, allowing farmers, agricultural companies, and water authorities to allocate, trade, and manage water rights digitally.

## Key Features

### For Water Authorities
- **Issue Water Rights**: Create new water rights NFTs with specific quotas and parameters
- **Set Regional Policies**: Configure water allocation rules and restrictions
- **Monitor Usage**: Track water usage against allocated quotas
- **Manage Compliance**: Enforce water usage regulations and penalties

### For Water Rights Holders
- **Own Digital Rights**: Hold verifiable water rights as NFTs on the blockchain
- **Trade Water Rights**: Buy and sell water allocations in a secure marketplace
- **Transfer Rights**: Send water rights to other users or addresses
- **Track Allocations**: Monitor current quota usage and remaining allowances

### Smart Contract Features
- **NFT-based Rights**: Each water right is a unique, tradeable NFT
- **Quota Management**: Automated tracking of water usage against allocations
- **Regional Restrictions**: Geographic and seasonal limitations on water rights
- **Usage Verification**: On-chain verification of water consumption
- **Transfer Controls**: Built-in rules for valid water rights transfers

## How It Works

1. **Rights Issuance**: Water authorities mint new water rights NFTs with specific quotas
2. **Allocation**: Rights are distributed to farmers and agricultural entities
3. **Usage Tracking**: Water consumption is recorded against allocated quotas
4. **Trading**: Rights holders can trade their allocations in the marketplace
5. **Compliance**: System ensures usage stays within authorized limits

## Contract Architecture

The system consists of two main smart contracts:

- **`water-rights`**: Core NFT contract managing water rights tokens and transfers
- **`quota-manager`**: Quota allocation, usage tracking, and compliance management

## Technical Features

- Non-Fungible Token (NFT) implementation for unique water rights
- Automated quota enforcement and usage tracking
- Geographic and temporal restrictions on water usage
- Marketplace functionality for peer-to-peer trading
- Compliance monitoring and violation detection
- Multi-signature support for large transfers

## Water Rights Properties

Each water right NFT contains:
- **Unique ID**: Immutable identifier for the water right
- **Quota Amount**: Maximum water allocation (in acre-feet or liters)
- **Geographic Bounds**: Specific location where water can be used  
- **Validity Period**: Start and end dates for the water right
- **Usage Type**: Agricultural, municipal, industrial, etc.
- **Transfer Restrictions**: Rules governing who can receive the right

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet with STX tokens
- Node.js for running tests

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd aqua

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test
```

### Deployment

```bash
# Deploy to devnet
clarinet deploy --devnet

# Deploy to testnet
clarinet deploy --testnet
```

## Usage Examples

### Issuing a Water Right (Authority)
```clarity
(contract-call? .water-rights mint-water-right 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; recipient
  u1000                                        ;; quota (acre-feet)
  {x: u37, y: u122}                           ;; coordinates
  u1672531200                                 ;; start timestamp
  u1704067200                                 ;; end timestamp
  "agricultural")                             ;; usage type
```

### Trading a Water Right
```clarity
(contract-call? .water-rights transfer 
  u1                                          ;; token-id
  tx-sender                                   ;; sender
  'SP1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S)  ;; recipient
```

### Recording Water Usage
```clarity
(contract-call? .quota-manager record-usage 
  u1                                          ;; water-right-id
  u50)                                        ;; amount used (acre-feet)
```

## Contract Functions

### Water Rights Contract
- `mint-water-right`: Create new water right NFT
- `transfer`: Transfer ownership of water right
- `burn`: Permanently destroy a water right
- `get-water-right`: Retrieve water right details
- `get-owner`: Get current owner of water right

### Quota Manager Contract
- `record-usage`: Log water consumption
- `check-compliance`: Verify usage against quota
- `update-quota`: Modify allocation amounts
- `get-remaining-quota`: Check available allocation
- `report-violation`: Flag quota violations

## Compliance & Governance

- Automated compliance checking against quotas
- Violation reporting and penalty systems
- Multi-signature requirements for large transfers
- Geographic restriction enforcement
- Seasonal usage limitations
- Audit trails for all water usage

## Environmental Benefits

- **Water Conservation**: Efficient allocation reduces waste
- **Market Efficiency**: Pricing signals encourage conservation
- **Transparency**: Public ledger of water rights and usage
- **Sustainability**: Long-term water resource planning
- **Accountability**: Traceable water consumption records

## Regulatory Compliance

The system is designed to work within existing water law frameworks:
- Respects prior appropriation doctrine
- Maintains beneficial use requirements
- Supports seasonal and geographic restrictions
- Enables regulatory oversight and reporting

## Security Features

- Multi-signature support for high-value transfers
- Geographic validation for water usage
- Time-locked allocations for seasonal rights
- Automated compliance monitoring
- Immutable audit trails

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This software is provided for educational and demonstration purposes. Users should conduct thorough testing and legal review before deploying to production or using with actual water rights.

## Support

For questions, issues, or contributions, please open an issue on GitHub or contact the development team.

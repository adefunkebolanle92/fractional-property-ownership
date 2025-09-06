# Fractional Property Ownership System

A blockchain-based system for enabling fractional ownership of real estate properties through tokenization on the Stacks network using Clarity smart contracts.

## 🏠 System Overview

The Fractional Property Ownership System allows property owners to tokenize their real estate assets and enable multiple investors to own shares in these properties. This democratizes real estate investment by lowering the barrier to entry and providing liquidity to traditionally illiquid assets.

### Key Features

- **Property Tokenization**: Convert real estate properties into tradeable digital tokens
- **Fractional Ownership**: Enable multiple parties to own portions of a single property
- **Transparent Ownership**: All ownership records stored immutably on the blockchain
- **Transfer Mechanisms**: Secure transfer of ownership shares between parties
- **Property Management**: Track property details, valuation, and ownership distribution

## 🏗️ Architecture

The system consists of two main smart contracts:

### 1. Property Tokenization Contract (`property-tokenization.clar`)
- Handles the creation and management of property tokens
- Stores property metadata (address, value, size, etc.)
- Manages the tokenization process
- Tracks total supply and property details

### 2. Ownership Shares Contract (`ownership-shares.clar`)
- Manages fractional ownership of tokenized properties
- Handles buying and selling of property shares
- Tracks individual ownership percentages
- Implements transfer mechanisms
- Manages shareholder registry

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm for testing
- Stacks wallet for mainnet deployment

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd fractional-property-ownership
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## 📝 Contract Specifications

### Property Tokenization Contract

**Key Functions:**
- `tokenize-property`: Create a new tokenized property
- `get-property-info`: Retrieve property details
- `update-property-value`: Update property valuation
- `get-total-tokens`: Get total token supply for a property

**Data Structures:**
- Property registry with metadata
- Token supply tracking
- Valuation history

### Ownership Shares Contract

**Key Functions:**
- `buy-shares`: Purchase fractional ownership shares
- `sell-shares`: Sell ownership shares to another party
- `transfer-shares`: Transfer shares between addresses
- `get-ownership-percentage`: Check ownership percentage
- `get-shareholder-info`: Retrieve shareholder details

**Data Structures:**
- Shareholder registry
- Ownership percentage tracking
- Transaction history

## 🔧 Usage Examples

### Tokenizing a Property

```clarity
(contract-call? .property-tokenization tokenize-property 
  "123 Main St, City, State" 
  u1000000 
  u2000 
  "Residential")
```

### Buying Fractional Shares

```clarity
(contract-call? .ownership-shares buy-shares 
  u1 
  u100 
  u50000)
```

### Transferring Shares

```clarity
(contract-call? .ownership-shares transfer-shares 
  u1 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  u25)
```

## 🧪 Testing

The project includes comprehensive test suites for both contracts:

```bash
npm run test:property-tokenization
npm run test:ownership-shares
npm run test:all
```

## 🛡️ Security Considerations

- All ownership transfers require proper authorization
- Property valuations can only be updated by authorized parties
- Share transfers include built-in validation checks
- Immutable ownership records prevent fraud

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please read the contributing guidelines before submitting pull requests.

## 📞 Support

For questions and support, please open an issue in the repository or contact the development team.

# 🌱 Carbon Credit Trading Platform

> 🏆 **Environmental asset tokenization made simple** 🌍

A decentralized platform for minting, trading, and retiring carbon credits on the Stacks blockchain using Clarity smart contracts.

## 🚀 Features

- 🌿 **Project Registration** - Register environmental projects for carbon credit generation
- ✅ **Project Verification** - Admin verification system for legitimate projects  
- 🪙 **Credit Minting** - Tokenize carbon credits as fungible tokens
- 💱 **Marketplace Trading** - Create listings and trade credits peer-to-peer
- 🔥 **Credit Retirement** - Permanently retire credits for carbon offsetting
- 📊 **Balance Tracking** - Track credits by project and user
- 🔐 **Secure Transfers** - Safe and auditable credit transfers

## 📋 Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) (for testing)
- Basic understanding of Clarity and Stacks blockchain

## 🛠️ Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd carbon-credit-trading-platform

# Install dependencies
npm install

# Run tests
clarinet test
```

## 🎯 Contract Functions

### 📝 Project Management

#### `register-project`
Register a new carbon offset project.
```clarity
(contract-call? .carbon-credit-trading-platform register-project 
  "Solar Farm Project" 
  "1MW solar installation in Kenya" 
  "Nairobi, Kenya" 
  "Gold Standard VER")
```

#### `verify-project` (Admin Only)
Verify a registered project for credit minting.
```clarity
(contract-call? .carbon-credit-trading-platform verify-project u1)
```

### 🪙 Credit Operations

#### `mint-carbon-credits`
Mint carbon credits for a verified project.
```clarity
(contract-call? .carbon-credit-trading-platform mint-carbon-credits 
  u1      ; project-id
  u1000   ; amount (1000 credits)
  u2024)  ; vintage year
```

#### `transfer-credits`
Transfer credits to another user.
```clarity
(contract-call? .carbon-credit-trading-platform transfer-credits 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ; recipient
  u100    ; amount
  u1)     ; credit-id
```

#### `retire-credits`
Permanently retire credits for offsetting.
```clarity
(contract-call? .carbon-credit-trading-platform retire-credits 
  u1      ; credit-id
  u50     ; amount
  "Corporate carbon offsetting Q1 2024")
```

### 🏪 Marketplace Functions

#### `create-listing`
List credits for sale on the marketplace.
```clarity
(contract-call? .carbon-credit-trading-platform create-listing 
  u1        ; credit-id
  u100      ; amount
  u1500000) ; price per credit in microSTX
```

#### `buy-credits`
Purchase credits from a marketplace listing.
```clarity
(contract-call? .carbon-credit-trading-platform buy-credits u1)
```

#### `cancel-listing`
Cancel an active marketplace listing.
```clarity
(contract-call? .carbon-credit-trading-platform cancel-listing u1)
```

### 📊 Read-Only Functions

```clarity
;; Get project information
(contract-call? .carbon-credit-trading-platform get-project u1)

;; Check credit details
(contract-call? .carbon-credit-trading-platform get-credit-details u1)

;; View marketplace listing
(contract-call? .carbon-credit-trading-platform get-marketplace-listing u1)

;; Check user balance for specific project
(contract-call? .carbon-credit-trading-platform get-user-balance 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)

;; Get total carbon credit balance
(contract-call? .carbon-credit-trading-platform get-carbon-credit-balance 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🎮 Usage Example

Here's a complete workflow from project registration to credit retirement:

```clarity
;; 1. 🏗️ Register a project
(contract-call? .carbon-credit-trading-platform register-project 
  "Reforestation Initiative" 
  "Plant 10,000 trees in Amazon rainforest" 
  "Brazil" 
  "REDD+")

;; 2. ✅ Verify project (admin only)
(contract-call? .carbon-credit-trading-platform verify-project u1)

;; 3. 🪙 Mint carbon credits
(contract-call? .carbon-credit-trading-platform mint-carbon-credits 
  u1 u500 u2024)

;; 4. 🏪 Create marketplace listing
(contract-call? .carbon-credit-trading-platform create-listing 
  u1 u200 u2000000)

;; 5. 💰 Another user buys credits
(contract-call? .carbon-credit-trading-platform buy-credits u1)

;; 6. 🔥 Retire credits for offsetting
(contract-call? .carbon-credit-trading-platform retire-credits 
  u1 u100 "Company carbon neutral initiative")
```

## ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Function restricted to contract owner |
| u101 | `err-not-token-owner` | Caller doesn't own the credits |
| u102 | `err-insufficient-balance` | Not enough credits available |
| u103 | `err-listing-not-found` | Marketplace listing doesn't exist |
| u104 | `err-invalid-amount` | Amount must be greater than 0 |
| u105 | `err-project-not-verified` | Project needs verification first |
| u106 | `err-credit-already-retired` | Credits already permanently retired |
| u107 | `err-invalid-price` | Price must be greater than 0 |
| u108 | `err-cannot-buy-own-listing` | Cannot purchase your own listing |

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

Check contract syntax:

```bash
clarinet check
```

## 🌍 Environmental Impact

This platform enables:
- 🌳 **Transparent Carbon Markets** - Verifiable and tradeable environmental assets
- 📈 **Price Discovery** - Market-driven carbon credit pricing
- 🔍 **Auditable Offsetting** - Permanent, traceable credit retirement
- 🤝 **Direct Trading** - Peer-to-peer carbon credit transactions
- 🏛️ **Decentralized Governance** - Community-driven environmental finance

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🚀 Deployment

Deploy to testnet:

```bash
clarinet integrate
```

## 🛡️ Security Considerations

- ✅ Admin functions protected by owner-only checks
- ✅ Credit ownership verification before transfers
- ✅ Balance validation before operations
- ✅ Retirement prevents double-spending
- ✅ Marketplace listing ownership verification

---

**Built with ❤️ for a sustainable future** 🌱

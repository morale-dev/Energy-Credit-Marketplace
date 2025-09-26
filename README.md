# Energy Credit Marketplace

A decentralized platform for trading tokenized renewable energy credits with built-in verification and compliance features.

## Features

- **Issuer Verification**: Certified energy producers can issue verified credits
- **Tokenized Credits**: Renewable energy certificates as tradeable tokens
- **Peer-to-Peer Trading**: Direct marketplace for credit transactions
- **Compliance Tools**: Credit retirement for regulatory requirements
- **Metadata Tracking**: Location, type, and expiration data for all credits
- **Automated Validation**: Built-in checks for expired or invalid credits

## Contract Functions

### Public Functions
- `register-as-issuer()`: Apply for energy credit issuer status
- `verify-issuer()`: Admin verification of issuer credentials
- `issue-energy-credit()`: Create new renewable energy credits
- `list-credit-for-sale()`: List credits on marketplace
- `purchase-energy-credit()`: Buy credits from marketplace
- `retire-credit()`: Permanently retire credits for compliance

### Read-Only Functions
- `get-issuer-info()`: View issuer details and verification status
- `get-credit-info()`: Get complete credit information
- `get-listing-info()`: View marketplace listing details
- `get-user-credit-balance()`: Check user's credit holdings

## Usage

Energy producers register and get verified, issue tokenized credits, list them for sale, and buyers can purchase and retire credits for compliance purposes.

## Compliance

All credits include metadata for regulatory tracking and automatic expiration to ensure validity of environmental claims.
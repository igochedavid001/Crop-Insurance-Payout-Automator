# 🌾 Crop Insurance Payout Automator

A decentralized crop insurance system built on Stacks blockchain that automatically triggers payouts based on oracle-fed weather data, protecting farmers from natural disasters.

## 🌟 Features

- 🚜 **Automated Insurance Policies**: Farmers can create customized crop insurance policies
- 🌡️ **Weather Oracle Integration**: Real-time weather data from trusted oracles
- ⚡ **Automatic Payouts**: Smart contract automatically processes claims when conditions are met
- 🛡️ **Risk Management**: Configurable thresholds for temperature and rainfall
- 💰 **Premium Management**: Secure premium collection and refund system
- 📊 **Analytics**: Track contract performance and statistics

## 🏗️ Contract Architecture

The smart contract manages:
- **Policy Creation**: Farmers create policies with specific crop protection parameters
- **Weather Data**: Oracle submits weather information for different locations
- **Claim Processing**: Automatic payout triggers based on weather conditions
- **Fund Management**: Secure handling of premiums and payouts

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm (optional for testing)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Crop-Insurance-Payout-Automator
```

2. Check the contract:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📋 Usage

### For Farmers 🧑‍🌾

#### Create Insurance Policy
```clarity
(contract-call? .Crop-insurance-payout create-policy 
    u1000000  ;; premium in microSTX
    u5000000  ;; coverage amount in microSTX  
    "corn"    ;; crop type
    "Iowa, US" ;; location
    u8760     ;; duration in blocks (~1 year)
    -10       ;; minimum temperature (°C)
    45        ;; maximum temperature (°C)  
    u300      ;; minimum rainfall (mm)
    u1200     ;; maximum rainfall (mm)
)
```

#### Check Policy Status
```clarity
(contract-call? .Crop-insurance-payout get-policy u1)
```

#### Process Claim
```clarity
(contract-call? .Crop-insurance-payout process-claim u1)
```

#### Cancel Policy (50% refund)
```clarity
(contract-call? .Crop-insurance-payout cancel-policy u1)
```

### For Oracles 🌐

#### Submit Weather Data
```clarity
(contract-call? .Crop-insurance-payout submit-weather-data 
    "Iowa, US"  ;; location
    -15         ;; temperature in °C
    u250        ;; rainfall in mm
)
```

### For Contract Owner 👨‍💼

#### Set Oracle Address
```clarity
(contract-call? .Crop-insurance-payout set-oracle 'SP1EXAMPLE...)
```

#### Withdraw Contract Funds
```clarity
(contract-call? .Crop-insurance-payout withdraw-funds u1000000)
```

## 📊 Contract Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|--------|
| `create-policy` | Create new insurance policy | Farmers |
| `process-claim` | Process insurance claim | Anyone |
| `submit-weather-data` | Submit weather information | Oracle only |
| `cancel-policy` | Cancel active policy | Policy owner |
| `extend-policy` | Extend policy duration | Policy owner |
| `set-oracle` | Set oracle address | Owner only |
| `withdraw-funds` | Withdraw contract funds | Owner only |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-policy` | Get policy details |
| `get-farmer-policies` | Get all policies for a farmer |
| `get-weather-data` | Get weather data by ID |
| `get-contract-stats` | Get contract statistics |
| `is-policy-eligible-for-payout` | Check if policy qualifies for payout |

## 🔧 Configuration Parameters

### Policy Parameters
- **Premium**: Amount paid by farmer (microSTX)
- **Coverage**: Maximum payout amount (microSTX)
- **Crop Type**: Type of crop being insured
- **Location**: Geographic location for weather tracking
- **Duration**: Policy duration in blocks
- **Temperature Thresholds**: Min/max temperature triggers (°C)
- **Rainfall Thresholds**: Min/max rainfall triggers (mm)

### Weather Triggers
Payouts are triggered when weather conditions fall outside the specified ranges:
- Temperature below minimum threshold
- Temperature above maximum threshold  
- Rainfall below minimum threshold
- Rainfall above maximum threshold

## 💡 Example Scenarios

### Drought Protection 🏜️
```clarity
;; Policy for drought protection
(create-policy u500000 u2000000 "wheat" "Kansas, US" u4380 -5 40 u200 u800)
```

### Frost Protection ❄️
```clarity
;; Policy for frost protection  
(create-policy u300000 u1500000 "citrus" "Florida, US" u2190 u5 u35 u600 u1500)
```

### Flood Protection 🌊
```clarity
;; Policy for flood protection
(create-policy u800000 u4000000 "rice" "Louisiana, US" u4380 u10 u38 u800 u2000)
```

## 🔒 Security Features

- ✅ **Access Control**: Oracle and owner-only functions
- ✅ **Input Validation**: Comprehensive parameter checking
- ✅ **Reentrancy Protection**: Secure fund transfers
- ✅ **State Management**: Proper policy lifecycle management

## 📈 Contract Statistics

Monitor contract performance:
```clarity
(contract-call? .Crop-insurance-payout get-contract-stats)
```

Returns:
- Total number of policies created
- Total premiums collected
- Total payouts distributed
- Current contract balance
- Oracle address

## 🧪 Testing

The contract includes comprehensive error handling:

| Error Code | Description |
|------------|-------------|
| u100 | Not authorized |
| u101 | Invalid policy parameters |
| u102 | Insufficient funds |
| u103 | Policy not active |
| u104 | Policy expired |
| u105 | Already claimed |
| u106 | Not authorized oracle |
| u107 | Invalid weather data |
| u108 | Policy not found |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Review the contract source code

---

Built with ❤️ for farmers around the world 🌍

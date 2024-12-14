### **Pierogies (PIRGS) BEP-20 Token**

---

### **Project Overview**
**Name:** Pierogies  
**Symbol:** PIRGS  
**Decimals:** 18  
**Total Supply:** 1 trillion tokens  

**Pierogies (PIRGS)** is a decentralized token based on the Binance Smart Chain (BSC), implementing the BEP-20 standard. The project aims to provide secure and efficient financial management within the Pierogies community.

### **Key Features**
- **Standard BEP-20 Functions:**
  - **Transfer and Approve Functions:** Standard BEP-20 methods for managing tokens.
  - **Burn Function:** A function to reduce the total supply of tokens, ensuring deflationary characteristics.
- **Deployed TimeLock Mechanism:** 
  - A mechanism for secure token management, allowing specific accounts to lock tokens until a predefined unlock timestamp.
- **Events:** 
  - Tracking of TimeLock activities using appropriate events.
- **Burn Function:** 
  - Allows the reduction of the total supply of tokens, ensuring deflationary characteristics.

### **Special Features**
- **TimeLock Mechanism:** 
  - Deployed to enhance security by allowing specific accounts to lock tokens until a predefined unlock timestamp. Expanded support for multi-signature controls may be considered for future updates.

### **Tokenomics**
- **Presale:** 35%
- **Staking:** 25% (Separate staking contract with TimeLock functionality)
- **Liquidity Fund:** 10% (Separate contract secured with a TimeLock - 50% unlocked after 2 years, 50% after 4 years)
- **Marketing and Partnerships:** 20%

### **Installation**
1. **Create a Repository**: 
   - Fork this repository to your GitHub account.
2. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/Pierogies.git
   cd Pierogies
   ```
3. **Install Dependencies (if any)**:
   ```bash
   npm install
   ```

### **Usage**
- **Deployment**:
  - Open Remix IDE or a similar Ethereum development environment.
  - Copy the code from `Pierogies.sol` to the IDE.
  - Deploy the contract on the Binance Smart Chain.
  - Interact with the contract using a wallet like MetaMask.

### **Further Information**
- **Support**: 
  - If you have questions or need assistance, contact us through Issues.

### **Contact Us**
- **Webpage**: [pierogies.io](https://pierogies.io)
- **Email**: hello@pierogies.io

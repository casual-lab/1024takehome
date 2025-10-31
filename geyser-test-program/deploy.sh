#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Geyser Kafka Plugin Test Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ]; then
    echo -e "${RED}Error: Cargo.toml not found. Please run from project root.${NC}"
    exit 1
fi

# Step 1: Build the program
echo -e "\n${YELLOW}Step 1: Building the program...${NC}"
cargo build-sbf
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build successful${NC}"

# Step 2: Get the program keypair path
PROGRAM_SO="target/deploy/geyser_test_program.so"
PROGRAM_KEYPAIR="target/deploy/geyser_test_program-keypair.json"

if [ ! -f "$PROGRAM_SO" ]; then
    echo -e "${RED}Error: Program binary not found at $PROGRAM_SO${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 2: Program details${NC}"
echo "Program binary: $PROGRAM_SO"
echo "Program keypair: $PROGRAM_KEYPAIR"

# Get program ID
if [ -f "$PROGRAM_KEYPAIR" ]; then
    PROGRAM_ID=$(solana-keygen pubkey "$PROGRAM_KEYPAIR")
    echo "Program ID: $PROGRAM_ID"
else
    echo -e "${RED}Error: Program keypair not found${NC}"
    exit 1
fi

# Step 3: Check Solana config
echo -e "\n${YELLOW}Step 3: Checking Solana configuration...${NC}"
solana config get

# Check if we have enough SOL
BALANCE=$(solana balance | awk '{print $1}')
echo "Current balance: $BALANCE SOL"

if (( $(echo "$BALANCE < 2" | bc -l) )); then
    echo -e "${YELLOW}Warning: Balance is low. You may need more SOL for deployment.${NC}"
    echo "Request airdrop with: solana airdrop 2"
fi

# Step 4: Deploy the program
echo -e "\n${YELLOW}Step 4: Deploying program...${NC}"
solana program deploy "$PROGRAM_SO"
if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Program deployed successfully${NC}"

# Step 5: Verify deployment
echo -e "\n${YELLOW}Step 5: Verifying deployment...${NC}"
solana program show "$PROGRAM_ID"

# Step 6: Install Node dependencies
echo -e "\n${YELLOW}Step 6: Installing Node dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    yarn install
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install dependencies${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Step 7: Generate IDL
echo -e "\n${YELLOW}Step 7: Generating program IDL...${NC}"
# Create target/types directory if it doesn't exist
mkdir -p target/types
# Create a simple IDL file
cat > target/idl/geyser_test_program.json << 'EOF'
{
  "version": "0.1.0",
  "name": "geyser_test_program",
  "instructions": [
    {
      "name": "initialize",
      "accounts": [
        {
          "name": "counter",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "user",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": []
    },
    {
      "name": "increment",
      "accounts": [
        {
          "name": "counter",
          "isMut": true,
          "isSigner": false
        }
      ],
      "args": []
    },
    {
      "name": "complexOperation",
      "accounts": [
        {
          "name": "counter",
          "isMut": true,
          "isSigner": false
        }
      ],
      "args": [
        {
          "name": "amount",
          "type": "u64"
        }
      ]
    },
    {
      "name": "transferSol",
      "accounts": [
        {
          "name": "from",
          "isMut": true,
          "isSigner": true
        },
        {
          "name": "to",
          "isMut": true,
          "isSigner": false
        },
        {
          "name": "systemProgram",
          "isMut": false,
          "isSigner": false
        }
      ],
      "args": [
        {
          "name": "amount",
          "type": "u64"
        }
      ]
    }
  ],
  "accounts": [
    {
      "name": "Counter",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "count",
            "type": "u64"
          },
          {
            "name": "authority",
            "type": "publicKey"
          }
        ]
      }
    }
  ]
}
EOF

echo -e "${GREEN}✓ IDL generated${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nProgram ID: ${YELLOW}$PROGRAM_ID${NC}"
echo -e "\nYou can now run tests with:"
echo -e "  ${YELLOW}anchor test --skip-local-validator${NC}"
echo -e "\nOr run the test script:"
echo -e "  ${YELLOW}./run_tests.sh${NC}"

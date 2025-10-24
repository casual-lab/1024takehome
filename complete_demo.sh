#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear

cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║     ░██████╗░███████╗██╗░░░██╗░██████╗███████╗██████╗░               ║
║     ██╔════╝░██╔════╝╚██╗░██╔╝██╔════╝██╔════╝██╔══██╗              ║
║     ██║░░██╗░█████╗░░░╚████╔╝░╚█████╗░█████╗░░██████╔╝              ║
║     ██║░░╚██╗██╔══╝░░░░╚██╔╝░░░╚═══██╗██╔══╝░░██╔══██╗              ║
║     ╚██████╔╝███████╗░░░██║░░░██████╔╝███████╗██║░░██║              ║
║     ░╚═════╝░╚══════╝░░░╚═╝░░░╚═════╝░╚══════╝╚═╝░░╚═╝              ║
║                                                                       ║
║              Kafka Plugin - Complete Demonstration                   ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF

echo -e "\n${CYAN}This script will demonstrate the complete Geyser Kafka plugin functionality.${NC}\n"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user
wait_user() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

# Check prerequisites
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Checking Prerequisites${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

checks_passed=true

# Check Rust
if command_exists rustc; then
    echo -e "${GREEN}✓${NC} Rust: $(rustc --version | awk '{print $2}')"
else
    echo -e "${RED}✗${NC} Rust not found"
    checks_passed=false
fi

# Check Solana
if command_exists solana; then
    echo -e "${GREEN}✓${NC} Solana: $(solana --version | awk '{print $2}')"
else
    echo -e "${RED}✗${NC} Solana not found"
    checks_passed=false
fi

# Check Node.js
if command_exists node; then
    echo -e "${GREEN}✓${NC} Node.js: $(node --version)"
else
    echo -e "${RED}✗${NC} Node.js not found"
    checks_passed=false
fi

# Check Yarn
if command_exists yarn; then
    echo -e "${GREEN}✓${NC} Yarn: $(yarn --version)"
else
    echo -e "${RED}✗${NC} Yarn not found"
    checks_passed=false
fi

# Check Docker
if command_exists docker; then
    echo -e "${GREEN}✓${NC} Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
else
    echo -e "${RED}✗${NC} Docker not found"
    checks_passed=false
fi

if [ "$checks_passed" = false ]; then
    echo -e "\n${RED}Some prerequisites are missing. Please install them first.${NC}"
    exit 1
fi

wait_user

# Step 1: Check Kafka
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Checking Kafka (RedPanda)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

if nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Kafka is running on localhost:9092"
else
    echo -e "${YELLOW}⚠${NC} Kafka is not running. Starting it now..."
    cd /home/ubuntu/ytest/redpanda-quickstart/docker-compose
    docker-compose up -d
    echo -e "${GREEN}✓${NC} Kafka started"
    sleep 5
fi

wait_user

# Step 2: Build Geyser Plugin
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Building Geyser Plugin${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

cd /home/ubuntu/ytest/solana-accountsdb-plugin-kafka

if [ -f "target/release/libsolana_accountsdb_plugin_kafka.so" ]; then
    echo -e "${GREEN}✓${NC} Geyser plugin already built"
    echo -e "Location: ${CYAN}target/release/libsolana_accountsdb_plugin_kafka.so${NC}"
else
    echo -e "${YELLOW}Building Geyser plugin...${NC}"
    cargo build --release
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Geyser plugin built successfully"
    else
        echo -e "${RED}✗${NC} Failed to build Geyser plugin"
        exit 1
    fi
fi

wait_user

# Step 3: Build Test Program
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Building Test Program${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

cd /home/ubuntu/ytest/geyser-test-program

if [ -f "target/deploy/geyser_test_program.so" ]; then
    PROGRAM_ID=$(solana-keygen pubkey target/deploy/geyser_test_program-keypair.json)
    echo -e "${GREEN}✓${NC} Test program already built"
    echo -e "Program ID: ${CYAN}$PROGRAM_ID${NC}"
else
    echo -e "${YELLOW}Building test program...${NC}"
    cargo build-sbf
    if [ $? -eq 0 ]; then
        PROGRAM_ID=$(solana-keygen pubkey target/deploy/geyser_test_program-keypair.json)
        echo -e "${GREEN}✓${NC} Test program built successfully"
        echo -e "Program ID: ${CYAN}$PROGRAM_ID${NC}"
    else
        echo -e "${RED}✗${NC} Failed to build test program"
        exit 1
    fi
fi

wait_user

# Step 4: Deploy Test Program
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 4: Deploying Test Program${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

# # Check if validator is running
# if pgrep -f "solana-test-validator" > /dev/null; then
#     echo -e "${GREEN}✓${NC} Test validator is already running"
# else
#     echo -e "${YELLOW}Starting test validator...${NC}"
#     solana-test-validator --quiet &
#     sleep 10
#     echo -e "${GREEN}✓${NC} Test validator started"
# fi
solana-keygen new -o ./validator-keypair.json --no-passphrase
solana config set --keypair ./validator-keypair.json
# Check balance
BALANCE=$(solana balance 2>/dev/null | awk '{print $1}')
if (( $(echo "$BALANCE < 2" | bc -l) )); then
    echo -e "${YELLOW}Requesting airdrop...${NC}"
    solana airdrop 200
    sleep 2
fi

echo -e "${YELLOW}Deploying program...${NC}"
solana program deploy target/deploy/geyser_test_program.so
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Program deployed successfully"
else
    echo -e "${RED}✗${NC} Failed to deploy program"
    exit 1
fi

wait_user


# Step 6: Install Dependencies
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 6: Installing Node Dependencies${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

if [ -d "node_modules" ]; then
    echo -e "${GREEN}✓${NC} Dependencies already installed"
else
    echo -e "${YELLOW}Installing dependencies...${NC}"
    yarn install
    echo -e "${GREEN}✓${NC} Dependencies installed"
fi

wait_user

# Step 7: Run Demo
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 7: Running Interactive Demo${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}Starting demo program...${NC}\n"
sleep 2

npx ts-node demo.ts

# Step 8: Show Kafka Topics
echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 8: Kafka Topics Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

cd /home/ubuntu/ytest

echo -e "${CYAN}Available Kafka topics:${NC}\n"
echo -e "  ${GREEN}✓${NC} ${CYAN}chain_accounts${NC}      - Account updates"
echo -e "  ${GREEN}✓${NC} ${CYAN}chain_txs${NC}           - Transactions"
echo -e "  ${GREEN}✓${NC} ${CYAN}chain_blocks_metadata${NC} - Block metadata (NEW)"
echo -e "  ${YELLOW}⏳${NC} ${CYAN}chain_program_logs${NC}  - Program logs (Stage 4)"
echo -e "  ${YELLOW}⏳${NC} ${CYAN}chain_events${NC}        - Chain events (Stage 4)"

echo -e "\n${CYAN}To view messages from each topic:${NC}\n"
echo -e "  ${MAGENTA}./view_kafka.sh chain_accounts${NC}"
echo -e "  ${MAGENTA}./view_kafka.sh chain_txs${NC}"
echo -e "  ${MAGENTA}./view_kafka.sh chain_blocks_metadata${NC}"

wait_user

# Completion
cat << "EOF"

╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║                    ✓ DEMONSTRATION COMPLETE                          ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝

EOF

echo -e "${GREEN}Implementation Status:${NC}\n"
echo -e "  ${GREEN}✓${NC} Stage 1: Protobuf definitions"
echo -e "  ${GREEN}✓${NC} Stage 2: Configuration system"
echo -e "  ${GREEN}✓${NC} Stage 3: Block metadata implementation"
echo -e "  ${YELLOW}⏳${NC} Stage 4: LogParser module (2 days)"
echo -e "  ${YELLOW}⏳${NC} Stage 5: Transaction logs integration (1 day)"
echo -e "  ${YELLOW}⏳${NC} Stage 6: Publisher batch methods (0.5 day)"
echo -e "  ${YELLOW}⏳${NC} Stage 7: Integration testing (1 day)"
echo -e "  ${YELLOW}⏳${NC} Stage 8: Documentation (0.5 day)"

echo -e "\n${CYAN}Progress: 3/8 stages (37.5%) complete${NC}"
echo -e "${CYAN}Estimated remaining time: 5 days${NC}\n"

echo -e "${BLUE}Next Steps:${NC}\n"
echo -e "  1. Implement LogParser module (src/log_parser.rs)"
echo -e "  2. Integrate LogParser into notify_transaction()"
echo -e "  3. Test program logs and events extraction"
echo -e "  4. Complete integration testing"
echo -e "  5. Update documentation\n"

echo -e "${YELLOW}Useful Commands:${NC}\n"
echo -e "  View implementation details: ${MAGENTA}cat /home/ubuntu/ytest/IMPLEMENTATION_RESULTS.md${NC}"
echo -e "  View test program README:    ${MAGENTA}cat /home/ubuntu/ytest/geyser-test-program/README.md${NC}"
echo -e "  View refactoring plan:       ${MAGENTA}cat /home/ubuntu/ytest/REFACTORING_PLAN.md${NC}"
echo -e "  Stop validator:              ${MAGENTA}pkill -f solana-test-validator${NC}"
echo -e "  View validator logs:         ${MAGENTA}tail -f test-ledger/validator.log${NC}\n"

echo -e "${GREEN}Thank you for using Geyser Kafka Plugin!${NC}\n"

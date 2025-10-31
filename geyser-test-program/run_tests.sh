#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Geyser Kafka Plugin Test Runner${NC}"
echo -e "${GREEN}========================================${NC}"

# Get program ID
PROGRAM_KEYPAIR="target/deploy/geyser_test_program-keypair.json"
if [ -f "$PROGRAM_KEYPAIR" ]; then
    PROGRAM_ID=$(solana-keygen pubkey "$PROGRAM_KEYPAIR")
    echo -e "Program ID: ${YELLOW}$PROGRAM_ID${NC}"
else
    echo -e "${RED}Error: Program not deployed. Run ./deploy.sh first${NC}"
    exit 1
fi

# Check if test validator is running
echo -e "\n${YELLOW}Checking for running validator...${NC}"
if pgrep -f "solana-test-validator" > /dev/null; then
    echo -e "${GREEN}✓ Test validator is running${NC}"
else
    echo -e "${RED}✗ Test validator is not running${NC}"
    echo -e "\nOptions:"
    echo -e "  1. Start test validator with Geyser plugin:"
    echo -e "     ${YELLOW}./start_validator_with_geyser.sh${NC}"
    echo -e "  2. Start test validator without Geyser plugin:"
    echo -e "     ${YELLOW}solana-test-validator${NC}"
    read -p "Start a basic test validator now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Starting test validator...${NC}"
        solana-test-validator > /tmp/validator.log 2>&1 &
        VALIDATOR_PID=$!
        echo "Validator PID: $VALIDATOR_PID"
        sleep 5
        echo -e "${GREEN}✓ Test validator started${NC}"
    else
        exit 1
    fi
fi

# Check Kafka (optional)
echo -e "\n${YELLOW}Checking for Kafka...${NC}"
if nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓ Kafka is running on localhost:9092${NC}"
else
    echo -e "${YELLOW}⚠ Kafka is not running (optional for basic tests)${NC}"
fi

# Run the tests
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Running Tests${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Use anchor test with skip-local-validator
yarn run ts-mocha -p ./tsconfig.json -t 1000000 tests/**/*.ts

TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "\n${RED}========================================${NC}"
    echo -e "${RED}Some tests failed ✗${NC}"
    echo -e "${RED}========================================${NC}"
fi

# Show logs location
echo -e "\nTest validator logs: ${YELLOW}/tmp/validator.log${NC}"
echo -e "To stop validator: ${YELLOW}solana-test-validator exit${NC}"

exit $TEST_EXIT_CODE

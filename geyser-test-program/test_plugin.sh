#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing Geyser Plugin Configuration${NC}"
echo -e "${GREEN}========================================${NC}"

CONFIG_FILE="/home/ubuntu/ytest/geyser-test-program/geyser-config.json"
PLUGIN_PATH="/home/ubuntu/ytest/solana-accountsdb-plugin-kafka/target/release/libsolana_accountsdb_plugin_kafka.so"

# Check plugin exists
echo -e "\n${YELLOW}Checking plugin file...${NC}"
if [ -f "$PLUGIN_PATH" ]; then
    echo -e "${GREEN}✓${NC} Plugin found: $PLUGIN_PATH"
    ls -lh "$PLUGIN_PATH"
else
    echo -e "${RED}✗${NC} Plugin not found: $PLUGIN_PATH"
    echo -e "Build it with: cd /home/ubuntu/ytest/solana-accountsdb-plugin-kafka && cargo build --release"
    exit 1
fi

# Check config exists
echo -e "\n${YELLOW}Checking config file...${NC}"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓${NC} Config found: $CONFIG_FILE"
else
    echo -e "${RED}✗${NC} Config not found: $CONFIG_FILE"
    exit 1
fi

# Validate JSON
echo -e "\n${YELLOW}Validating JSON syntax...${NC}"
if jq . "$CONFIG_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} JSON syntax is valid"
else
    echo -e "${RED}✗${NC} JSON syntax is invalid"
    exit 1
fi

# Check Kafka
echo -e "\n${YELLOW}Checking Kafka connection...${NC}"
if nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Kafka is running on localhost:9092"
else
    echo -e "${YELLOW}⚠${NC} Kafka is not running (optional for config test)"
fi

# Stop any existing validator
echo -e "\n${YELLOW}Stopping any existing validators...${NC}"
pkill -f solana-test-validator
sleep 2

# Try to start validator with plugin
echo -e "\n${YELLOW}Starting test validator with Geyser plugin...${NC}"
echo -e "This will test if the plugin loads correctly."
echo -e "\n${YELLOW}Starting validator in 3 seconds... (Press Ctrl+C to cancel)${NC}"
sleep 3

# Start validator with plugin (in background, but capture errors)
solana-test-validator \
    --geyser-plugin-config "$CONFIG_FILE" \
    --reset \
    --log \
    > /tmp/validator-test.log 2>&1 &

VALIDATOR_PID=$!
echo -e "Validator PID: $VALIDATOR_PID"

# Wait a bit for startup
echo -e "\n${YELLOW}Waiting for validator to start...${NC}"
sleep 5

# Check if still running
if ps -p $VALIDATOR_PID > /dev/null; then
    echo -e "${GREEN}✓${NC} Validator is running with Geyser plugin!"
    
    # Try to get slot
    sleep 2
    SLOT=$(solana slot 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Validator is functional (current slot: $SLOT)"
    fi
    
    # Check logs for Geyser messages
    echo -e "\n${YELLOW}Checking for Geyser plugin messages in logs...${NC}"
    if grep -i "kafka" /tmp/validator-test.log | head -5; then
        echo -e "${GREEN}✓${NC} Geyser plugin messages found"
    else
        echo -e "${YELLOW}⚠${NC} No Geyser plugin messages found (yet)"
    fi
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}SUCCESS! Plugin loaded correctly${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    echo -e "\n${YELLOW}Validator is running. To stop it:${NC}"
    echo -e "  kill $VALIDATOR_PID"
    echo -e "\n${YELLOW}To view logs:${NC}"
    echo -e "  tail -f /tmp/validator-test.log"
    
else
    echo -e "${RED}✗${NC} Validator failed to start"
    echo -e "\n${RED}Error log:${NC}"
    tail -50 /tmp/validator-test.log
    exit 1
fi

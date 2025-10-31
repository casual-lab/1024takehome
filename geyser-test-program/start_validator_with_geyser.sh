#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Start Test Validator with Geyser Plugin${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if Geyser plugin is built
PLUGIN_PATH="/home/ubuntu/ytest/solana-accountsdb-plugin-kafka/target/release/libsolana_accountsdb_plugin_kafka.so"

if [ ! -f "$PLUGIN_PATH" ]; then
    echo -e "${RED}Error: Geyser plugin not found at $PLUGIN_PATH${NC}"
    echo -e "Build it first with:"
    echo -e "  ${YELLOW}cd /home/ubuntu/ytest/solana-accountsdb-plugin-kafka${NC}"
    echo -e "  ${YELLOW}cargo build --release${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found Geyser plugin at $PLUGIN_PATH${NC}"

# Check if Kafka is running
echo -e "\n${YELLOW}Checking Kafka...${NC}"
if nc -z localhost 9092 2>/dev/null; then
    echo -e "${GREEN}✓ Kafka is running on localhost:9092${NC}"
else
    echo -e "${RED}✗ Kafka is not running${NC}"
    echo -e "Start Kafka first with:"
    echo -e "  ${YELLOW}cd /home/ubuntu/ytest/redpanda-quickstart${NC}"
    echo -e "  ${YELLOW}docker-compose up -d${NC}"
    exit 1
fi

# Create Geyser config file
CONFIG_FILE="/home/ubuntu/ytest/geyser-test-program/geyser-config.json"
echo -e "\n${YELLOW}Creating Geyser configuration at $CONFIG_FILE${NC}"

cat > "$CONFIG_FILE" << 'EOF'
{
  "libpath": "/home/ubuntu/ytest/solana-accountsdb-plugin-kafka/target/release/libsolana_accountsdb_plugin_kafka.so",
  "kafka": {
    "bootstrap.servers": "localhost:9092",
    "request.required.acks": "1",
    "message.timeout.ms": "30000",
    "compression.type": "lz4",
    "partitioner": "murmur2_random"
  },
  "shutdown_timeout_ms": 30000,
  "prometheus": "0.0.0.0:9091",
  "filters": [
    {
      "update_account_topic": "chain_accounts",
      "slot_status_topic": "chain_blocks",
      "transaction_topic": "chain_txs",
      "block_metadata_topic": "chain_blocks_metadata",
      "program_log_topic": "chain_program_logs",
      "chain_event_topic": "chain_events",
      "publish_all_accounts": true,
      "program_ignores": [],
      "program_filters": [],
      "account_filters": [],
      "include_vote_transactions": false,
      "include_failed_transactions": true,
      "extract_program_logs": true,
      "extract_anchor_events": true,
      "event_discriminators": [],
      "wrap_messages": false
    }
  ]
}
EOF

echo -e "${GREEN}✓ Geyser configuration created${NC}"

# Stop any existing validator
echo -e "\n${YELLOW}Stopping any existing validator...${NC}"
pkill -f solana-test-validator
sleep 2

# Start the validator with Geyser plugin
echo -e "\n${YELLOW}Starting test validator with Geyser plugin...${NC}"
echo -e "Config: $CONFIG_FILE"
echo -e "Plugin: $PLUGIN_PATH"
echo -e "\n${BLUE}Validator output:${NC}\n"

solana-test-validator \
    --geyser-plugin-config "$CONFIG_FILE" \
    --reset \
    --quiet &

VALIDATOR_PID=$!

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Validator started with PID: $VALIDATOR_PID${NC}"
echo -e "${GREEN}========================================${NC}"

# Wait a bit for validator to start
echo -e "\n${YELLOW}Waiting for validator to be ready...${NC}"
sleep 5

# Check if validator is running
if ps -p $VALIDATOR_PID > /dev/null; then
    echo -e "${GREEN}✓ Validator is running${NC}"
    
    # Try to get slot
    SLOT=$(solana slot 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Validator is ready (current slot: $SLOT)${NC}"
    else
        echo -e "${YELLOW}⚠ Validator started but not ready yet${NC}"
    fi
else
    echo -e "${RED}✗ Validator failed to start${NC}"
    exit 1
fi

echo -e "\n${YELLOW}To monitor Kafka messages:${NC}"
echo -e "  ${YELLOW}cd /home/ubuntu/ytest${NC}"
echo -e "  ${YELLOW}./view_kafka.sh chain_accounts${NC}"
echo -e "  ${YELLOW}./view_kafka.sh chain_txs${NC}"
echo -e "  ${YELLOW}./view_kafka.sh chain_blocks_metadata${NC}"

echo -e "\n${YELLOW}To stop the validator:${NC}"
echo -e "  ${YELLOW}pkill -f solana-test-validator${NC}"

echo -e "\n${YELLOW}To view validator logs:${NC}"
echo -e "  ${YELLOW}tail -f test-ledger/validator.log${NC}"

#!/usr/bin/env python3
"""
查看 Kafka 中的 Solana 数据
解析 Protobuf 消息并美化显示
"""

import os
import sys
import json
from datetime import datetime
from kafka import KafkaConsumer
from kafka.structs import TopicPartition
import argparse

# 设置 protobuf 使用纯 Python 实现（避免版本不匹配问题）
os.environ['PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION'] = 'python'

# 导入 Protobuf 定义
try:
    sys.path.append('/home/ubuntu')
    sys.path.append('/home/ubuntu/ytest')
    import event_pb2
except ImportError:
    print("❌ 错误: 找不到 event_pb2.py")
    print("请先生成 Protobuf 代码:")
    print("  cd /home/ubuntu/ytest")
    print("  protoc --experimental_allow_proto3_optional --python_out=. solana-accountsdb-plugin-kafka/proto/event.proto")
    print("  cp solana_accountsdb_plugin_kafka/proto/event_pb2.py event_pb2.py")
    sys.exit(1)


def format_bytes(data: bytes, max_len: int = 64) -> str:
    """格式化字节数据为十六进制"""
    hex_str = data.hex()
    if len(hex_str) > max_len:
        return hex_str[:max_len] + f"... ({len(data)} bytes)"
    return hex_str


def display_account_update(data: bytes):
    """显示账户更新信息"""
    event = event_pb2.UpdateAccountEvent()
    event.ParseFromString(data)
    
    print("📦 账户更新 (chain_accounts)")
    print("─" * 80)
    print(f"  pubkey:         {format_bytes(event.pubkey)}")
    print(f"  owner_program:  {format_bytes(event.owner)}")
    print(f"  lamports:       {event.lamports:,}")
    print(f"  slot:           {event.slot:,}")
    print(f"  write_version:  {event.write_version}")
    print(f"  executable:     {bool(event.executable)}")
    print(f"  rent_epoch:     {event.rent_epoch}")
    if event.txn_signature:
        print(f"  txn_signature:  {format_bytes(event.txn_signature)}")
    print(f"  data:           {format_bytes(event.data, 32)}")
    print(f"  data_version:   {event.data_version}")
    print(f"  is_startup:     {bool(event.is_startup)}")
    print(f"  account_age:    {event.account_age}")
    print()


def display_transaction(data: bytes):
    """显示交易信息"""
    event = event_pb2.TransactionEvent()
    event.ParseFromString(data)
    
    print("💳 交易 (chain_txs)")
    print("─" * 80)
    print(f"  tx_signature:   {format_bytes(event.signature)}")
    print(f"  slot:           {event.slot:,}")
    print(f"  status:         {'✅ success' if event.is_successful else '❌ failed'}")
    print(f"  is_vote:        {bool(event.is_vote)}")
    
    if event.transaction_status_meta:
        meta = event.transaction_status_meta
        print(f"  fee:            {meta.fee:,} lamports")
        print(f"  compute_units:  {meta.compute_units_consumed:,}")
        if meta.error_info:
            print(f"  error:          {meta.error_info}")
    
    print(f"  compute_price:  {event.compute_units_price}")
    print(f"  total_cost:     {event.total_cost:,}")
    print(f"  instructions:   {event.instruction_count}")
    print(f"  accounts:       {event.account_count}")
    print()


def display_slot_status(data: bytes):
    """显示插槽状态信息"""
    event = event_pb2.SlotStatusEvent()
    event.ParseFromString(data)
    
    status_names = {
        0: "Processed",
        1: "Rooted", 
        2: "Confirmed",
        3: "FirstShredReceived",
        4: "Completed",
        5: "CreatedBank",
        57005: "Dead"
    }
    
    print("🔷 区块/插槽状态 (chain_blocks)")
    print("─" * 80)
    print(f"  slot:               {event.slot:,}")
    print(f"  parent_slot:        {event.parent:,}")
    print(f"  status:             {status_names.get(event.status, f'Unknown({event.status})')}")
    print(f"  is_confirmed:       {bool(event.is_confirmed)}")
    print(f"  confirmation_count: {event.confirmation_count}")
    print(f"  status_description: {event.status_description}")
    print()


def display_block_metadata(data: bytes):
    """显示区块元数据信息"""
    event = event_pb2.BlockMetadataEvent()
    event.ParseFromString(data)
    
    print("📊 区块元数据 (chain_blocks_metadata) ⭐ NEW")
    print("─" * 80)
    print(f"  slot:                {event.slot:,}")
    print(f"  blockhash:           {event.blockhash}")
    print(f"  parent_slot:         {event.parent_slot}")
    print(f"  parent_blockhash:    {event.parent_blockhash}")
    
    if event.block_time:
        dt = datetime.fromtimestamp(event.block_time)
        print(f"  block_time:          {event.block_time} ({dt.strftime('%Y-%m-%d %H:%M:%S')})")
    
    if event.block_height:
        print(f"  block_height:        {event.block_height:,}")
    
    print(f"  executed_tx_count:   {event.executed_transaction_count}")
    print(f"  entry_count:         {event.entry_count}")
    
    if event.entries_data_shreds:
        print(f"  data_shreds:         {event.entries_data_shreds}")
    if event.entries_coding_shreds:
        print(f"  coding_shreds:       {event.entries_coding_shreds}")
    
    if event.rewards:
        print(f"  rewards:             {len(event.rewards)} reward(s)")
        for i, reward in enumerate(event.rewards[:3]):  # 只显示前3个
            print(f"    [{i+1}] pubkey: {reward.pubkey}")
            print(f"        lamports: {reward.lamports:,}")
            if reward.post_balance:
                print(f"        post_balance: {reward.post_balance:,}")
            if reward.reward_type:
                reward_types = {1: "Fee", 2: "Rent", 3: "Staking", 4: "Voting"}
                print(f"        type: {reward_types.get(reward.reward_type, 'Unknown')}")
        if len(event.rewards) > 3:
            print(f"    ... and {len(event.rewards) - 3} more")
    
    print()


def display_program_log(data: bytes):
    """显示程序日志信息"""
    event = event_pb2.ProgramLogEvent()
    event.ParseFromString(data)
    
    log_types = {
        0: "UNKNOWN",
        1: "INVOKE",
        2: "LOG",
        3: "DATA",
        4: "SUCCESS",
        5: "FAILED",
        6: "CONSUMED"
    }
    
    print("📝 程序日志 (chain_program_logs)")
    print("─" * 80)
    print(f"  tx_signature: {format_bytes(event.tx_signature)}")
    print(f"  slot:         {event.slot:,}")
    print(f"  tx_index:     {event.tx_index}")
    print(f"  program_id:   {event.program_id}")
    print(f"  log_type:     {log_types.get(event.log_type, 'UNKNOWN')} ({event.log_type})")
    print(f"  log_index:    {event.log_index}")
    print(f"  depth:        {event.depth}")
    print(f"  message:      {event.message}")
    
    print()


def display_chain_event(data: bytes):
    """显示链事件信息"""
    event = event_pb2.ChainEvent()
    event.ParseFromString(data)
    
    print("🎯 链事件 (chain_events)")
    print("─" * 80)
    print(f"  tx_signature:        {format_bytes(event.tx_signature)}")
    print(f"  slot:                {event.slot:,}")
    print(f"  tx_index:            {event.tx_index}")
    print(f"  program_id:          {event.program_id}")
    print(f"  event_discriminator: {format_bytes(event.event_discriminator)}")
    print(f"  log_index:           {event.log_index}")
    
    if event.event_type:
        print(f"  event_type:          {event.event_type}")
    
    print(f"  raw_data:            {format_bytes(event.raw_data, 32)}")
    
    if event.json_payload:
        print(f"  json_payload:        {event.json_payload}")
    
    print()


def consume_topic(topic: str, max_messages: int = 10):
    """消费指定 topic 的消息"""
    print(f"\n{'='*80}")
    print(f"📡 消费 Topic: {topic}")
    print(f"{'='*80}\n")
    
    consumer = KafkaConsumer(
        bootstrap_servers=['localhost:19092'],
        security_protocol='SASL_PLAINTEXT',
        sasl_mechanism='SCRAM-SHA-256',
        sasl_plain_username='superuser',
        sasl_plain_password='secretpassword',
        auto_offset_reset='earliest',
        consumer_timeout_ms=5000,
        value_deserializer=lambda m: m
    )
    
    # 手动分配分区并从开始消费
    partition = TopicPartition(topic, 0)
    consumer.assign([partition])
    consumer.seek_to_beginning(partition)
    
    count = 0
    try:
        for message in consumer:
            if count >= max_messages:
                break
            
            try:
                if topic == 'solana.accounts':
                    display_account_update(message.value)
                elif topic == 'solana.transactions':
                    display_transaction(message.value)
                elif topic == 'solana.slots':
                    display_slot_status(message.value)
                elif topic == 'solana.blocks':
                    display_block_metadata(message.value)
                elif topic == 'solana.program_logs':
                    display_program_log(message.value)
                elif topic == 'solana.events':
                    display_chain_event(message.value)
                elif topic == 'chain_accounts':
                    display_account_update(message.value)
                elif topic == 'chain_txs':
                    display_transaction(message.value)
                elif topic == 'chain_blocks':
                    display_slot_status(message.value)
                elif topic == 'chain_blocks_metadata':
                    display_block_metadata(message.value)
                elif topic == 'chain_program_logs':
                    display_program_log(message.value)
                elif topic == 'chain_events':
                    display_chain_event(message.value)
                else:
                    print(f"⚠️  未知的 topic 类型: {topic}")
                    print(f"   原始数据 (前64字节): {format_bytes(message.value, 64)}")
                
                count += 1
            except Exception as e:
                print(f"❌ 解析消息失败: {e}")
                print(f"   Offset: {message.offset}")
                print()
                continue
        
        if count == 0:
            print(f"⚠️  Topic '{topic}' 中没有消息")
            print(f"   提示: 确保 Solana 验证器正在运行并配置了 Geyser 插件\n")
        else:
            print(f"✅ 共显示 {count} 条消息\n")
    
    finally:
        consumer.close()


def main():
    parser = argparse.ArgumentParser(description='查看 Kafka 中的 Solana 数据')
    parser.add_argument('--topic', 
                        choices=['accounts', 'txs', 'blocks', 'metadata', 'logs', 'events', 'all'], 
                        default='all', 
                        help='要查看的数据类型')
    parser.add_argument('--max', type=int, default=10, 
                        help='每个 topic 最多显示的消息数')
    parser.add_argument('--raw-topic', type=str,
                        help='直接指定 Kafka topic 名称 (例如: chain_blocks_metadata)')
    
    args = parser.parse_args()
    
    topics = {
        'accounts': 'solana.accounts',
        'txs': 'solana.transactions',
        'blocks': 'solana.slots',
        'metadata': 'solana.blocks',
        'logs': 'solana.program_logs',
        'events': 'solana.events'
    }
    
    # 如果指定了原始 topic 名称
    if args.raw_topic:
        consume_topic(args.raw_topic, args.max)
        return
    
    if args.topic == 'all':
        # 显示所有已实现的主题
        for name in ['accounts', 'txs', 'blocks', 'metadata']:
            if name in topics:
                consume_topic(topics[name], args.max)
    else:
        consume_topic(topics[args.topic], args.max)


if __name__ == '__main__':
    main()

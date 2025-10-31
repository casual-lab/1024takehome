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
    
    print("📊 区块元数据 (chain_blocks_metadata)")
    print("─" * 80)
    print(f"  slot:                {event.slot:,}")
    print(f"  block_hash:          {event.block_hash}")
    print(f"  parent_slot:         {event.parent_slot:,}")
    print(f"  parent_block_hash:   {event.parent_block_hash}")
    
    if event.leader:
        print(f"  leader:              {event.leader}")
    
    if event.block_time:
        dt = datetime.fromtimestamp(event.block_time)
        print(f"  block_time:          {event.block_time} ({dt.strftime('%Y-%m-%d %H:%M:%S')})")
    
    if event.block_height:
        print(f"  block_height:        {event.block_height:,}")
    
    print(f"  executed_tx_count:   {event.executed_transaction_count}")
    
    if event.total_compute_units:
        print(f"  total_compute_units: {event.total_compute_units:,}")
    
    if event.total_fees:
        print(f"  total_fees:          {event.total_fees:,} lamports")
    
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


def consume_topic(topic: str, max_messages: int = 10, offset: str = 'earliest', delete_after: bool = False, timeout_ms: int = 5000):
    """消费指定 topic 的消息
    
    Args:
        topic: Kafka topic 名称
        max_messages: 最大消息数量
        offset: 起始位置 ('earliest', 'latest', 或具体数字如 '100')
        delete_after: 是否在读取后删除消息（通过提交 offset）
        timeout_ms: 超时时间（毫秒）
    """
    print(f"\n{'='*80}")
    print(f"📡 消费 Topic: {topic}")
    print(f"   Offset: {offset} | Max: {max_messages} | Delete: {'是' if delete_after else '否'}")
    if offset == 'latest':
        print(f"   ⏱️  等待新消息... (timeout: {timeout_ms/1000:.1f}s)")
    print(f"{'='*80}\n")
    
    partition = TopicPartition(topic, 0)
    
    # 如果需要删除，使用带 group_id 的消费者
    if delete_after:
        consumer = KafkaConsumer(
            bootstrap_servers=['localhost:19092'],
            security_protocol='SASL_PLAINTEXT',
            sasl_mechanism='SCRAM-SHA-256',
            sasl_plain_username='superuser',
            sasl_plain_password='secretpassword',
            group_id='view_kafka_consumer',  # 用于提交 offset
            auto_offset_reset=offset if offset in ['earliest', 'latest'] else 'earliest',
            enable_auto_commit=False,  # 禁用自动提交，手动控制
            consumer_timeout_ms=timeout_ms,
            value_deserializer=lambda m: m
        )
        
        # 使用 assign 而不是 subscribe
        consumer.assign([partition])
        
        # 根据 offset 参数设置起始位置
        if offset == 'earliest':
            consumer.seek_to_beginning(partition)
        elif offset == 'latest':
            consumer.seek_to_end(partition)
        elif offset.isdigit():
            consumer.seek(partition, int(offset))
        else:
            print(f"⚠️  无效的 offset 值: {offset}，使用 earliest")
            consumer.seek_to_beginning(partition)
    else:
        consumer = KafkaConsumer(
            bootstrap_servers=['localhost:19092'],
            security_protocol='SASL_PLAINTEXT',
            sasl_mechanism='SCRAM-SHA-256',
            sasl_plain_username='superuser',
            sasl_plain_password='secretpassword',
            auto_offset_reset='earliest',
            enable_auto_commit=False,
            consumer_timeout_ms=timeout_ms,
            value_deserializer=lambda m: m
        )
        
        # 手动分配分区
        consumer.assign([partition])
        
        # 根据 offset 参数设置起始位置
        if offset == 'earliest':
            consumer.seek_to_beginning(partition)
        elif offset == 'latest':
            consumer.seek_to_end(partition)
        elif offset.isdigit():
            consumer.seek(partition, int(offset))
        else:
            print(f"⚠️  无效的 offset 值: {offset}，使用 earliest")
            consumer.seek_to_beginning(partition)
    
    count = 0
    last_offset = None
    try:
        for message in consumer:
            if count >= max_messages:
                break
            
            last_offset = message.offset
            print(f"[Offset: {message.offset}]")
            
            try:
                # 根据 topic 名称判断消息类型
                if 'account' in topic.lower():
                    display_account_update(message.value)
                elif 'transaction' in topic.lower() or 'txs' in topic.lower():
                    display_transaction(message.value)
                elif 'slot' in topic.lower():
                    display_slot_status(message.value)
                elif 'block' in topic.lower():
                    # 区块相关的 topic 可能包含 BlockMetadataEvent 或 SlotStatusEvent
                    # 先尝试解析为 BlockMetadataEvent，如果 block_hash 为空则可能是 SlotStatusEvent
                    try:
                        import event_pb2
                        test_event = event_pb2.BlockMetadataEvent()
                        test_event.ParseFromString(message.value)
                        # 检查是否有实际的区块元数据
                        if test_event.block_hash or test_event.block_time or len(test_event.rewards) > 0:
                            display_block_metadata(message.value)
                        else:
                            # 没有区块元数据，尝试作为 SlotStatusEvent
                            display_slot_status(message.value)
                    except:
                        # 解析失败，尝试作为 SlotStatusEvent
                        display_slot_status(message.value)
                elif 'program_log' in topic.lower() or 'logs' in topic.lower():
                    display_program_log(message.value)
                elif 'event' in topic.lower():
                    display_chain_event(message.value)
                else:
                    # 尝试解析为 MessageWrapper
                    try:
                        wrapper = event_pb2.MessageWrapper()
                        wrapper.ParseFromString(message.value)
                        
                        if wrapper.HasField('account'):
                            print("📦 [Wrapped] 账户更新")
                            display_account_update(wrapper.account.SerializeToString())
                        elif wrapper.HasField('slot'):
                            print("🔷 [Wrapped] 插槽状态")
                            display_slot_status(wrapper.slot.SerializeToString())
                        elif wrapper.HasField('transaction'):
                            print("💳 [Wrapped] 交易")
                            display_transaction(wrapper.transaction.SerializeToString())
                        elif wrapper.HasField('block'):
                            print("📊 [Wrapped] 区块元数据")
                            display_block_metadata(wrapper.block.SerializeToString())
                        elif wrapper.HasField('program_log'):
                            print("📝 [Wrapped] 程序日志")
                            display_program_log(wrapper.program_log.SerializeToString())
                        elif wrapper.HasField('chain_event'):
                            print("🎯 [Wrapped] 链事件")
                            display_chain_event(wrapper.chain_event.SerializeToString())
                        else:
                            print(f"⚠️  未知的包装消息类型")
                            print(f"   原始数据 (前64字节): {format_bytes(message.value, 64)}")
                    except Exception as wrapper_err:
                        print(f"⚠️  无法识别的 topic 类型: {topic}")
                        print(f"   尝试解析为包装消息失败: {wrapper_err}")
                        print(f"   原始数据 (前64字节): {format_bytes(message.value, 64)}")
                
                count += 1
            except Exception as e:
                print(f"❌ 解析消息失败: {e}")
                print(f"   Offset: {message.offset}")
                print(f"   原始数据 (前64字节): {format_bytes(message.value, 64)}")
                print()
                continue
        
        if count == 0:
            print(f"⚠️  Topic '{topic}' 中没有消息")
            print(f"   提示: 确保 Solana 验证器正在运行并配置了 Geyser 插件\n")
        else:
            print(f"✅ 共显示 {count} 条消息\n")
            
            # 如果需要删除，提交 offset
            if delete_after and last_offset is not None:
                # 提交到最后一条消息的下一个 offset
                consumer.commit()
                print(f"🗑️  已提交 offset 到 {last_offset + 1}，之前的消息将被标记为已消费\n")
    
    finally:
        consumer.close()


def main():
    parser = argparse.ArgumentParser(
        description='查看 Kafka 中的 Solana 数据',
        epilog="""
示例:
  # 查看账户更新（从最早的消息开始）
  %(prog)s --topic accounts
  
  # 查看交易数据，显示20条，从最新消息开始
  %(prog)s --topic txs --max 20 --offset latest
  
  # 从指定 offset 开始读取
  %(prog)s --topic txs --offset 1000 --max 10
  
  # 读取后删除消息（提交 offset）
  %(prog)s --topic accounts --max 100 --delete
  
  # 直接指定 topic 名称
  %(prog)s --raw-topic solana.chain_accounts --offset 500
  
  # 查看所有类型的数据
  %(prog)s --topic all --max 5
  
Offset 选项:
  earliest  - 从最早的消息开始（默认）
  latest    - 从最新的消息开始
  数字      - 从指定的 offset 开始（如：1000）
  
Geyser 插件实际发送的 Topics (基于 config.json):
  1. solana.chain_accounts      账户更新 (UpdateAccountEvent)
  2. solana.slots               插槽状态 (SlotStatusEvent)
  3. solana.chain_txs           交易 (TransactionEvent)
  4. solana.chain_blocks        区块元数据 (BlockMetadataEvent)
  5. solana.chain_program_logs  程序日志 (ProgramLogEvent)
  6. solana.chain_events        链事件/Anchor事件 (ChainEvent)
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('--topic', 
                        choices=['accounts', 'txs', 'slots', 'blocks', 'logs', 'events', 'all'], 
                        default='all', 
                        help='要查看的数据类型')
    parser.add_argument('--max', type=int, default=10, 
                        help='每个 topic 最多显示的消息数')
    parser.add_argument('--raw-topic', type=str,
                        help='直接指定 Kafka topic 名称 (例如: solana.chain_accounts)')
    parser.add_argument('--offset', type=str, default='earliest',
                        help='起始 offset (earliest/latest/数字)')
    parser.add_argument('--delete', action='store_true',
                        help='读取后删除消息（通过提交 offset）')
    parser.add_argument('--timeout', type=int, default=5,
                        help='等待消息的超时时间（秒），默认 5 秒')
    
    args = parser.parse_args()
    
    # 基于实际 config.json 中的 topic 配置
    topics = {
        'accounts': 'solana.chain_accounts',
        'txs': 'solana.chain_txs',
        'slots': 'solana.slots',
        'blocks': 'solana.chain_blocks',
        'logs': 'solana.chain_program_logs',
        'events': 'solana.chain_events'
    }
    
    # 如果指定了原始 topic 名称
    if args.raw_topic:
        consume_topic(args.raw_topic, args.max, args.offset, args.delete, args.timeout * 1000)
        return
    
    if args.topic == 'all':
        # 显示所有已实现的主题
        for name in ['accounts', 'txs', 'slots', 'blocks', 'logs', 'events']:
            if name in topics:
                try:
                    consume_topic(topics[name], args.max, args.offset, args.delete, args.timeout * 1000)
                except Exception as e:
                    print(f"⚠️  跳过 topic {topics[name]}: {e}\n")
    else:
        consume_topic(topics[args.topic], args.max, args.offset, args.delete, args.timeout * 1000)


if __name__ == '__main__':
    main()

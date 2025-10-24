#!/usr/bin/env python3
"""
计算 Anchor Event Discriminator
用于配置 event_discriminators 白名单
"""

import sys
import hashlib
import argparse

def calculate_discriminator(event_name: str) -> str:
    """
    计算 Anchor event discriminator
    
    Anchor 使用格式: sha256("event:{EventName}")[0..8]
    """
    namespace = f"event:{event_name}"
    hash_bytes = hashlib.sha256(namespace.encode('utf-8')).digest()
    discriminator = hash_bytes[:8].hex()
    return discriminator

def main():
    parser = argparse.ArgumentParser(
        description='计算 Anchor Event Discriminator',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s TransferEvent
  %(prog)s SwapEvent InitializeEvent
  %(prog)s --json TransferEvent SwapEvent
        """
    )
    parser.add_argument('event_names', nargs='+', help='事件名称（可以指定多个）')
    parser.add_argument('--json', action='store_true', help='输出 JSON 格式（用于配置文件）')
    
    args = parser.parse_args()
    
    results = {}
    for event_name in args.event_names:
        discriminator = calculate_discriminator(event_name)
        results[event_name] = discriminator
    
    if args.json:
        # JSON 格式，方便复制到配置文件
        import json
        discriminators = list(results.values())
        print(json.dumps(discriminators, indent=2))
    else:
        # 人类可读格式
        print("Anchor Event Discriminators:")
        print("=" * 60)
        for event_name, discriminator in results.items():
            namespace = f"event:{event_name}"
            print(f"  {event_name:30s} -> {discriminator}")
            print(f"    Namespace: {namespace}")
        print("=" * 60)
        print("\n配置示例:")
        print('  "event_discriminators": [')
        for i, (event_name, discriminator) in enumerate(results.items()):
            comma = "," if i < len(results) - 1 else ""
            print(f'    "{discriminator}"{comma}  // {event_name}')
        print('  ]')

if __name__ == '__main__':
    main()

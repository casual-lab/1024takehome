# 测试说明

## clone

在项目根目录下克隆：

- https://github.com/casual-lab/bridge
- https://github.com/casual-lab/solana-accountsdb-plugin-kafka
- https://github.com/casual-lab/kafka-clickhouse-sync
- https://github.com/casual-lab/agave


## 1. 本地链部署

工作目录：`./agave`

```bash
./multinode-demo/setup.sh
```

编译 geyser 插件

```bash
cd ../solana-accountsdb-plugin-kafka
cargo build --release
cd ../agave
```

```bash
./multinode-demo/faucet.sh
```

启动 validator 节点

```bash
./multinode-demo/bootstrap-validator.sh
```

启动 rpc 节点

```bash
./multinode-demo/rpc-node.sh
```

启动indexer节点

```bash
./multinode-demo/index-node.sh
```

特殊的为了只测试geyser插件，可以只启动validator节点并指定geyser插件：

```bash
./multinode-demo/bootstrap-validator-with-geyser.sh
```

## 2. 数据推送

确保 `solana-accountsdb-plugin-kafka/target/release/libsolana_accountsdb_plugin_kafka.so` 已编译完成。

按照上节说明启动本地链。

启动同步服务：`kafka-clickhouse-sync`：

如有需要首先设置配置文件 `kafka-clickhouse-sync/config.yaml`，然后运行：

```bash
RUST_LOG=debug cargo run
```

然后部署并调用实例合约

```bash
./complete_demo.sh
```

等待一段时间，查看 ClickHouse 数据库中的数据：

```bash
clickhouse-client
```

## 3. 跨链桥

需要进入开发容器中进行测试，Dockerfile 位于 `./bridge/Dockerfile`。

容器中的工作目录位于 `/workspace`。

```bash
# 确保已安装依赖
npm install
cd relayer && npm install && cd ..
```

生成测试密钥

```bash
npm run generate-keys
```

启动服务并部署合约

```bash
# 在终端 1 中运行
npm run setup
```

在一个单独的终端启动 Relayer

```bash
# 在终端 2 中运行
cd relayer && npm run dev
```

测试 EVM → Solana 跨链

```bash
# 在终端 3 中运行
npm run demo:evm-to-solana
```

测试 Solana → EVM 跨链

```bash
# 在终端 3 中运行
npm run demo:solana-to-evm
```

停止所有服务

```bash
npm run stop
```

## 4. 流动性池与质押挖矿模块

需要进入开发容器中进行测试，Dockerfile 位于 `./lp_module/Dockerfile`。

容器中的工作目录位于 `/workspace`。

```bash
# 4. 编译项目
anchor build
```

启动测试验证器（新终端）或使用第一节中的本地链部署

```bash
solana-test-validator --reset
```

```bash
# 5. 运行测试（仅 deposit 和 withdraw）
anchor test
```

stack、unstack 和 claim 机制需要在 deposit 的基础上（执行过 anchor test），执行 `lp_module/scripts/setup-dev-env.sh`。

/// 程序常量定义

/// PDA Seeds
pub const POOL_STATE_SEED: &[u8] = b"pool_state";
pub const USER_POSITION_SEED: &[u8] = b"user_position";
pub const REWARD_CONFIG_SEED: &[u8] = b"reward_config";
pub const REWARD_VAULT_SEED: &[u8] = b"reward_vault";

/// 最小存入金额（1 USDC，假设 6 位小数）
pub const MIN_DEPOSIT_AMOUNT: u64 = 1_000_000;

/// 最小质押金额（0.1 LP Token）
pub const MIN_STAKE_AMOUNT: u64 = 100_000;

/// 基点基数（用于百分比计算）
pub const BASIS_POINTS: u64 = 10_000;

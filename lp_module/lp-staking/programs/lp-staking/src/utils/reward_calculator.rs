use anchor_lang::prelude::*;
use crate::errors::LpStakingError;
use crate::state::{RewardConfig, PoolState, EmissionType};

/// 计算用户待领取的奖励（公共函数）
pub fn calculate_pending_reward(
    user_staked: u64,
    acc_reward_per_share: u128,
    reward_debt: u128,
) -> Result<u64> {
    if user_staked == 0 {
        return Ok(0);
    }
    
    let user_staked_u128 = user_staked as u128;
    let accumulated = user_staked_u128
        .checked_mul(acc_reward_per_share)
        .ok_or(LpStakingError::MathOverflow)?;
    
    let pending = accumulated
        .checked_sub(reward_debt)
        .ok_or(LpStakingError::MathOverflow)?
        / RewardConfig::PRECISION;
    
    Ok(pending as u64)
}

/// 更新奖励池状态（公共函数）
pub fn update_pool_reward(
    pool_state: &PoolState,
    reward_config: &mut RewardConfig,
    current_slot: u64,
) -> Result<()> {
    // 如果没有质押，不需要更新
    if pool_state.total_staked == 0 {
        reward_config.last_update_slot = current_slot;
        return Ok(());
    }
    
    // 如果区块高度没有变化，不需要更新
    if current_slot <= reward_config.last_update_slot {
        return Ok(());
    }
    
    match reward_config.emission_type {
        EmissionType::FixedRate => {
            // 固定速率模式：按 slot 估算时间
            // Solana 平均 0.4秒/slot，但为了简化使用 slot 差值
            let slot_diff = current_slot - reward_config.last_update_slot;
            // 每 slot 约 0.4秒，为简化计算，将 emission_rate 理解为"每slot排放量"
            // 或者：time_elapsed ≈ slot_diff * 0.4，但这会引入浮点数
            // 更好的方案：直接使用 slot_diff 作为时间单位
            let time_elapsed = slot_diff as i64;
            
            reward_config.acc_reward_per_share = RewardCalculator::update_fixed_rate_reward(
                reward_config.acc_reward_per_share,
                pool_state.total_staked,
                reward_config.emission_rate,
                time_elapsed,
            )?;
        },
        EmissionType::BlockBased => {
            // 按块动态模式
            reward_config.acc_reward_per_share = RewardCalculator::update_block_based_reward(
                reward_config.acc_reward_per_share,
                pool_state.total_staked,
                reward_config,
                current_slot,
            )?;
        },
    }
    
    reward_config.last_update_slot = current_slot;
    Ok(())
}

/// 奖励计算器
/// 实现固定速率和按块动态两种奖励分配机制
pub struct RewardCalculator;

impl RewardCalculator {
    /// 计算用户待领取的奖励
    /// 
    /// # 参数
    /// * `user_staked` - 用户质押的 LP Token 数量
    /// * `reward_debt` - 用户的奖励债务
    /// * `acc_reward_per_share` - 累计每份奖励
    /// 
    /// # 返回
    /// 用户待领取的奖励数量（lamports）
    pub fn calculate_pending_reward(
        user_staked: u64,
        reward_debt: u128,
        acc_reward_per_share: u128,
    ) -> Result<u64> {
        if user_staked == 0 {
            return Ok(0);
        }
        
        let user_staked_u128 = user_staked as u128;
        let accumulated = user_staked_u128
            .checked_mul(acc_reward_per_share)
            .ok_or(LpStakingError::MathOverflow)?;
        
        let pending = accumulated
            .checked_sub(reward_debt)
            .ok_or(LpStakingError::MathOverflow)?
            / RewardConfig::PRECISION;
        
        Ok(pending as u64)
    }
    
    /// 更新累计每份奖励（固定速率模式）
    /// 
    /// # 参数
    /// * `acc_reward_per_share` - 当前累计每份奖励
    /// * `total_staked` - 总质押量
    /// * `emission_rate` - 每秒排放速率（lamports/秒）
    /// * `time_elapsed` - 经过的时间（秒）
    /// 
    /// # 返回
    /// 更新后的累计每份奖励
    pub fn update_fixed_rate_reward(
        acc_reward_per_share: u128,
        total_staked: u64,
        emission_rate: u64,
        time_elapsed: i64,
    ) -> Result<u128> {
        if total_staked == 0 || time_elapsed <= 0 {
            return Ok(acc_reward_per_share);
        }
        
        let total_reward = (emission_rate as u128)
            .checked_mul(time_elapsed as u128)
            .ok_or(LpStakingError::MathOverflow)?;
        
        let reward_per_share = total_reward
            .checked_mul(RewardConfig::PRECISION)
            .ok_or(LpStakingError::MathOverflow)?
            .checked_div(total_staked as u128)
            .ok_or(LpStakingError::MathOverflow)?;
        
        acc_reward_per_share
            .checked_add(reward_per_share)
            .ok_or(LpStakingError::MathOverflow.into())
    }
    
    /// 计算按块动态排放的当前速率
    /// 
    /// # 参数
    /// * `initial_rate` - 初始每块排放量
    /// * `decay_factor` - 衰减因子（基点，10000 = 1.0）
    /// * `blocks_per_period` - 每个周期的区块数
    /// * `current_slot` - 当前区块高度
    /// 
    /// # 返回
    /// 当前的每块排放量
    pub fn calculate_block_rate(
        initial_rate: u64,
        decay_factor: u64,
        blocks_per_period: u64,
        current_slot: u64,
    ) -> Result<u64> {
        if blocks_per_period == 0 {
            return Err(LpStakingError::InvalidBlocksPerPeriod.into());
        }
        
        let period = current_slot / blocks_per_period;
        
        // rate = initial_rate * (decay_factor / 10000) ^ period
        let mut rate = initial_rate as u128;
        for _ in 0..period {
            rate = rate
                .checked_mul(decay_factor as u128)
                .ok_or(LpStakingError::MathOverflow)?
                / 10000;
        }
        
        Ok(rate as u64)
    }
    
    /// 更新累计每份奖励（按块动态模式）
    /// 
    /// # 参数
    /// * `acc_reward_per_share` - 当前累计每份奖励
    /// * `total_staked` - 总质押量
    /// * `config` - 奖励配置
    /// * `current_slot` - 当前区块高度
    /// 
    /// # 返回
    /// 更新后的累计每份奖励
    pub fn update_block_based_reward(
        acc_reward_per_share: u128,
        total_staked: u64,
        config: &RewardConfig,
        current_slot: u64,
    ) -> Result<u128> {
        if total_staked == 0 || current_slot <= config.last_update_slot {
            return Ok(acc_reward_per_share);
        }
        
        let blocks_elapsed = current_slot - config.last_update_slot;
        
        // 简化计算：使用当前周期的平均速率
        // TODO: 更精确的计算应该考虑跨周期的情况
        let current_rate = Self::calculate_block_rate(
            config.initial_block_rate,
            config.decay_factor,
            config.blocks_per_period,
            current_slot,
        )?;
        
        let total_reward = (current_rate as u128)
            .checked_mul(blocks_elapsed as u128)
            .ok_or(LpStakingError::MathOverflow)?;
        
        let reward_per_share = total_reward
            .checked_mul(RewardConfig::PRECISION)
            .ok_or(LpStakingError::MathOverflow)?
            .checked_div(total_staked as u128)
            .ok_or(LpStakingError::MathOverflow)?;
        
        acc_reward_per_share
            .checked_add(reward_per_share)
            .ok_or(LpStakingError::MathOverflow.into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_calculate_pending_reward() {
        // 用户质押 1000 个 LP Token
        // acc_reward_per_share = 1e12 (表示每个 LP 累计 1 lamport)
        // reward_debt = 0
        let pending = RewardCalculator::calculate_pending_reward(
            1000,
            0,
            RewardConfig::PRECISION,
        ).unwrap();
        
        assert_eq!(pending, 1000); // 应该获得 1000 lamports
    }
    
    #[test]
    fn test_calculate_block_rate_no_decay() {
        // decay_factor = 10000 (100%，不衰减)
        let rate = RewardCalculator::calculate_block_rate(
            100,
            10000,
            1000,
            5000, // 第 5 个周期
        ).unwrap();
        
        assert_eq!(rate, 100); // 应该保持不变
    }
    
    #[test]
    fn test_calculate_block_rate_with_decay() {
        // decay_factor = 9000 (90%，每周期衰减到 90%)
        let rate = RewardCalculator::calculate_block_rate(
            100,
            9000,
            1000,
            1000, // 第 1 个周期
        ).unwrap();
        
        assert_eq!(rate, 90); // 100 * 0.9 = 90
    }
}

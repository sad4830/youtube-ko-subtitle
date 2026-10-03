package com.jujutsukaisen.block;

import com.jujutsukaisen.domain.DomainManager;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;

/**
 * The barrier (결계) of a closed Domain Expansion. It is placed only into empty space and
 * removes itself if the domain that owns it no longer exists (e.g. after a server restart).
 */
public class DomainBarrierBlock extends Block {
    public DomainBarrierBlock(Properties properties) {
        super(properties);
    }

    @Override
    public void tick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
        if (!DomainManager.ownsBarrier(level, pos)) {
            level.setBlock(pos, Blocks.AIR.defaultBlockState(), Block.UPDATE_CLIENTS);
        } else {
            level.scheduleTick(pos, this, 100);
        }
    }
}

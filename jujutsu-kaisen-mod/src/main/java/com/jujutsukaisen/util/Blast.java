package com.jujutsukaisen.util;

import com.jujutsukaisen.sorcery.JJK;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseFireBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.common.util.BlockSnapshot;
import net.minecraftforge.event.ForgeEventFactory;
import org.jetbrains.annotations.Nullable;

/** Controlled block destruction for techniques (no drops, no vanilla explosion side effects). */
public final class Blast {
    private Blast() {
    }

    /**
     * Removes destructible blocks inside a sphere. Blocks further from the center must be softer.
     *
     * @return number of blocks removed
     */
    public static int carveSphere(Level level, @Nullable Entity breaker, Vec3 center, double radius, float maxHardness, int limit, boolean particles) {
        if (!(level instanceof ServerLevel server)) return 0;
        int removed = 0;
        int r = (int) Math.ceil(radius);
        BlockPos origin = BlockPos.containing(center);
        RandomSource random = level.random;
        BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos();
        for (int x = -r; x <= r && removed < limit; x++) {
            for (int y = -r; y <= r && removed < limit; y++) {
                for (int z = -r; z <= r && removed < limit; z++) {
                    double dist = Math.sqrt(x * x + y * y + z * z);
                    if (dist > radius) continue;
                    pos.set(origin.getX() + x, origin.getY() + y, origin.getZ() + z);
                    BlockState state = level.getBlockState(pos);
                    float allowed = (float) (maxHardness * (1.0 - 0.5 * dist / radius));
                    if (!JJK.isDestructible(level, pos, state, allowed)) continue;
                    if (dist > radius - 1 && random.nextFloat() < 0.35f) continue; // ragged edge
                    if (!JJK.mayBreak(level, pos, state, breaker)) continue;
                    level.setBlock(pos, Blocks.AIR.defaultBlockState(), Block.UPDATE_ALL);
                    removed++;
                    if (particles && random.nextInt(4) == 0) {
                        server.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, state),
                                pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, 3, 0.3, 0.3, 0.3, 0.1);
                    }
                }
            }
        }
        return removed;
    }

    /** Removes one block if allowed. */
    public static boolean cut(Level level, @Nullable Entity breaker, BlockPos pos, float maxHardness, boolean particles) {
        BlockState state = level.getBlockState(pos);
        if (!JJK.isDestructible(level, pos, state, maxHardness)) return false;
        if (!JJK.mayBreak(level, pos, state, breaker)) return false;
        level.setBlock(pos, Blocks.AIR.defaultBlockState(), Block.UPDATE_ALL);
        if (particles && level instanceof ServerLevel server) {
            server.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, state),
                    pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, 4, 0.3, 0.3, 0.3, 0.05);
        }
        return true;
    }

    /** Lights fires on exposed top surfaces around a point. */
    public static void scatterFire(Level level, @Nullable Entity breaker, Vec3 center, double radius, int attempts) {
        RandomSource random = level.random;
        for (int i = 0; i < attempts; i++) {
            BlockPos pos = BlockPos.containing(center.add((random.nextDouble() * 2 - 1) * radius,
                    (random.nextDouble() * 2 - 1) * radius * 0.5, (random.nextDouble() * 2 - 1) * radius));
            if (level.isEmptyBlock(pos) && level.getBlockState(pos.below()).isFaceSturdy(level, pos.below(), net.minecraft.core.Direction.UP)
                    && !(breaker instanceof net.minecraft.server.level.ServerPlayer player && !level.mayInteract(player, pos))) {
                // Placed like a block: claim and protection mods can veto it through the place event.
                BlockSnapshot snapshot = BlockSnapshot.create(level.dimension(), level, pos);
                level.setBlock(pos, BaseFireBlock.getState(level, pos), Block.UPDATE_ALL);
                if (breaker != null && ForgeEventFactory.onBlockPlace(breaker, snapshot, net.minecraft.core.Direction.UP)) {
                    snapshot.restore(true, false);
                }
            }
        }
    }
}

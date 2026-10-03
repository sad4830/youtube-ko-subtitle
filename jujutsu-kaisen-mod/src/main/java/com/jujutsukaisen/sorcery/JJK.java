package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.config.JJKConfig;
import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.entity.SorcererEntity;
import com.jujutsukaisen.registry.ModTags;
import net.minecraft.core.BlockPos;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.projectile.ProjectileUtil;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.EntityHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

/** Shared helpers for anything that uses cursed energy. */
public final class JJK {
    private JJK() {
    }

    @Nullable
    public static SorcererData get(@Nullable Entity entity) {
        if (entity instanceof SorcererHolder holder) return holder.getSorcererData();
        if (entity instanceof Player player) {
            return player.getCapability(SorcererCapability.SORCERER).resolve().orElse(null);
        }
        return null;
    }

    /** Direction a caster is aiming: players use their view, mobs aim at their target. */
    public static Vec3 aim(LivingEntity caster) {
        if (caster instanceof Mob mob && mob.getTarget() != null && mob.getTarget().isAlive()) {
            Vec3 to = mob.getTarget().getBoundingBox().getCenter().subtract(caster.getEyePosition());
            if (to.lengthSqr() > 1.0E-4) return to.normalize();
        }
        return caster.getLookAngle();
    }

    /** The living entity the caster is aiming at, if any is within range and not behind a wall. */
    @Nullable
    public static LivingEntity aimEntity(LivingEntity caster, double range) {
        if (caster instanceof Mob mob && mob.getTarget() != null && mob.getTarget().isAlive()
                && mob.distanceTo(mob.getTarget()) <= range + mob.getTarget().getBbWidth()) {
            return mob.getTarget();
        }
        Level level = caster.level();
        Vec3 eye = caster.getEyePosition();
        Vec3 end = eye.add(aim(caster).scale(range));
        BlockHitResult block = level.clip(new ClipContext(eye, end, ClipContext.Block.COLLIDER, ClipContext.Fluid.NONE, caster));
        if (block.getType() != HitResult.Type.MISS) end = block.getLocation();
        EntityHitResult hit = ProjectileUtil.getEntityHitResult(level, caster, eye, end, new AABB(eye, end).inflate(1.5),
                e -> e instanceof LivingEntity && e.isAlive() && e != caster && !e.isSpectator() && e.isPickable());
        return hit != null && hit.getEntity() instanceof LivingEntity living ? living : null;
    }

    /** Point the caster is aiming at: an entity, a block face or the end of the range. */
    public static Vec3 aimPoint(LivingEntity caster, double range) {
        LivingEntity target = aimEntity(caster, range);
        if (target != null) return target.getBoundingBox().getCenter();
        Vec3 eye = caster.getEyePosition();
        Vec3 end = eye.add(aim(caster).scale(range));
        BlockHitResult block = caster.level().clip(new ClipContext(eye, end, ClipContext.Block.COLLIDER, ClipContext.Fluid.NONE, caster));
        if (block.getType() != HitResult.Type.MISS) {
            return block.getLocation().subtract(aim(caster).scale(0.5));
        }
        return end;
    }

    /** Whether a technique cast by this entity may break blocks. */
    public static boolean canGrief(@Nullable Entity caster, boolean domain) {
        if (caster == null) return false;
        boolean config = domain ? JJKConfig.DOMAIN_BLOCK_DESTRUCTION.get() : JJKConfig.TECHNIQUE_BLOCK_DESTRUCTION.get();
        if (!config) return false;
        if (caster instanceof Player) return true;
        return net.minecraftforge.event.ForgeEventFactory.getMobGriefingEvent(caster.level(), caster);
    }

    /**
     * Whether {@code breaker} may destroy this block: spawn protection and claim/protection mods
     * (via {@link net.minecraftforge.event.level.BlockEvent.BreakEvent}) are respected for players.
     */
    public static boolean mayBreak(Level level, BlockPos pos, BlockState state, @Nullable Entity breaker) {
        if (breaker instanceof net.minecraft.server.level.ServerPlayer player) {
            if (!level.mayInteract(player, pos)) return false;
            return !net.minecraftforge.common.MinecraftForge.EVENT_BUS.post(
                    new net.minecraftforge.event.level.BlockEvent.BreakEvent(level, pos, state, player));
        }
        return true;
    }

    /** Blocks a technique may erase: no bedrock-likes, no barriers, no containers. */
    public static boolean isDestructible(Level level, BlockPos pos, BlockState state, float maxHardness) {
        if (state.isAir() || state.hasBlockEntity()) return false;
        if (state.is(ModTags.TECHNIQUE_IMMUNE)) return false;
        float hardness = state.getDestroySpeed(level, pos);
        return hardness >= 0 && hardness <= maxHardness;
    }

    /** Whether the caster considers the other entity a friend (never hit by its techniques). */
    public static boolean isAlly(LivingEntity caster, @Nullable Entity other) {
        if (other == null) return false;
        if (other == caster) return true;
        if (caster.isAlliedTo(other)) return true;
        if (other == caster.getVehicle() || caster == other.getVehicle()) return true; // rider and mount
        if (other instanceof MahoragaEntity mahoraga && mahoraga.isOwnedBy(caster)) return true;
        if (caster instanceof MahoragaEntity mahoraga && mahoraga.isOwnedBy(other)) return true;
        if (caster instanceof MahoragaEntity a && other instanceof MahoragaEntity b
                && a.getOwnerUUID() != null && a.getOwnerUUID().equals(b.getOwnerUUID())) return true;
        if (caster instanceof SorcererEntity a && other instanceof SorcererEntity b) return a.isFriendlyWith(b);
        // A tamed Mahoraga fights for its owner: whoever is the owner's ally is its ally too.
        LivingEntity casterOwner = caster instanceof MahoragaEntity m ? m.getOwner() : null;
        if (casterOwner != null && casterOwner != caster && !(casterOwner instanceof MahoragaEntity) && isAlly(casterOwner, other)) return true;
        LivingEntity otherOwner = other instanceof MahoragaEntity m ? m.getOwner() : null;
        if (otherOwner != null && otherOwner != other && !(otherOwner instanceof MahoragaEntity) && isAlly(caster, otherOwner)) return true;
        // Never hit your own tamed animals.
        if (other instanceof net.minecraft.world.entity.OwnableEntity pet && caster.getUUID().equals(pet.getOwnerUUID())) return true;
        return false;
    }

    /** A valid victim for a technique cast by {@code caster}. */
    public static boolean canHit(LivingEntity caster, Entity target) {
        if (!(target instanceof LivingEntity living) || !living.isAlive()) return false;
        if (target.isSpectator()) return false;
        if (target instanceof Player player && player.isCreative()) return false;
        return !isAlly(caster, target);
    }
}

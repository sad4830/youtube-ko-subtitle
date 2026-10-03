package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererLogic;
import com.jujutsukaisen.util.Blast;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;

/**
 * 술식순전 「창」 — Cursed Technique Lapse: Blue. Amplified Limitless creates a point of
 * attraction: everything nearby is dragged in and crushed together.
 */
public class BlueEntity extends JJKProjectile {
    private static final EntityDataAccessor<Float> RADIUS = SynchedEntityData.defineId(BlueEntity.class, EntityDataSerializers.FLOAT);

    public BlueEntity(EntityType<? extends BlueEntity> type, Level level) {
        super(type, level);
    }

    public BlueEntity(Level level, LivingEntity owner, Vec3 point, float radius) {
        this(ModEntities.BLUE.get(), level);
        setOwner(owner);
        setPos(point.x, point.y - 0.5, point.z);
        setRadius(radius);
    }

    @Override
    protected void defineSynchedData() {
        entityData.define(RADIUS, 7.0f);
    }

    public float getRadius() {
        return entityData.get(RADIUS);
    }

    public void setRadius(float radius) {
        entityData.set(RADIUS, radius);
    }

    @Override
    protected int maxAge() {
        return 70;
    }

    @Override
    protected boolean collidesWithEntities() {
        return false;
    }

    @Override
    protected boolean collidesWithBlocks() {
        return false;
    }

    @Override
    protected void serverTick() {
        Vec3 center = getBoundingBox().getCenter();
        float radius = getRadius();
        LivingEntity owner = ownerLiving();

        for (Entity entity : level().getEntities(this, getBoundingBox().inflate(radius),
                e -> e != owner && !(e instanceof JJKProjectile) && !e.isSpectator())) {
            if (entity instanceof Player player && player.isCreative()) continue;
            if (entity instanceof LivingEntity living && owner != null && !JJK.canHit(owner, living)) continue;
            // Infinity holds them in place, paying a little cursed energy each tick it resists the pull.
            if (entity instanceof LivingEntity living
                    && SorcererLogic.infinityStops(living, ModDamageTypes.source(level(), ModDamageTypes.LIMITLESS, this, owner), 0.5f)) continue;
            Vec3 toCenter = center.subtract(entity.position().add(0, entity.getBbHeight() * 0.5, 0));
            double dist = toCenter.length();
            if (dist > radius || dist < 0.05) continue;
            double strength = 0.1 + 0.24 * (1.0 - dist / radius);
            if (dist < 1.3) strength *= 0.35;
            entity.setDeltaMovement(entity.getDeltaMovement().scale(0.5).add(toCenter.normalize().scale(strength)));
            entity.hurtMarked = true;
            entity.fallDistance = 0;
            if (entity instanceof LivingEntity living && dist < 2.6 && age % 8 == 0) {
                living.hurt(ModDamageTypes.source(level(), ModDamageTypes.LIMITLESS, this, owner), 4.0f);
            }
        }

        if (age % 3 == 0 && JJK.canGrief(owner, false) && level() instanceof ServerLevel server) {
            RandomSource random = level().random;
            for (int i = 0; i < 3; i++) {
                Vec3 offset = new Vec3(random.nextGaussian(), random.nextGaussian(), random.nextGaussian()).normalize().scale(1.5 + random.nextDouble() * 2.0);
                BlockPos pos = BlockPos.containing(center.add(offset));
                BlockState state = level().getBlockState(pos);
                if (Blast.cut(level(), owner, pos, 3.0f, false)) {
                    Vec3 p = Vec3.atCenterOf(pos);
                    Vec3 v = center.subtract(p).scale(0.2);
                    server.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, state), p.x, p.y, p.z, 0, v.x, v.y, v.z, 1.0);
                }
            }
        }

        if (age % 20 == 1) Fx.sound(level(), center, SoundEvents.BEACON_AMBIENT, 2.0f, 1.9f);
    }

    @Override
    protected void clientTick() {
        Vec3 center = getBoundingBox().getCenter();
        RandomSource random = level().random;
        float radius = getRadius();
        for (int i = 0; i < 4; i++) {
            Vec3 offset = new Vec3(random.nextGaussian(), random.nextGaussian(), random.nextGaussian()).normalize()
                    .scale(radius * (0.35 + random.nextDouble() * 0.6));
            Vec3 p = center.add(offset);
            Vec3 v = offset.scale(-0.9);
            level().addParticle(Fx.BLUE, p.x, p.y, p.z, v.x, v.y, v.z);
            level().addParticle(ParticleTypes.ENCHANT, center.x, center.y, center.z, offset.x * 0.6, offset.y * 0.6, offset.z * 0.6);
        }
    }

    @Override
    protected void onExpire() {
        Vec3 center = getBoundingBox().getCenter();
        LivingEntity owner = ownerLiving();
        for (LivingEntity living : level().getEntitiesOfClass(LivingEntity.class, getBoundingBox().inflate(3.0),
                e -> owner == null || JJK.canHit(owner, e))) {
            living.hurt(ModDamageTypes.source(level(), ModDamageTypes.LIMITLESS, this, owner), 7.0f);
        }
        Fx.burst(level(), Fx.BLUE, center, 60, 1.2, 0.2);
        Fx.burst(level(), ParticleTypes.FLASH, center, 1, 0, 0);
        Fx.sound(level(), center, SoundEvents.BEACON_DEACTIVATE, 2.0f, 1.6f);
        discard();
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putFloat("Radius", getRadius());
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        setRadius(tag.getFloat("Radius"));
    }
}

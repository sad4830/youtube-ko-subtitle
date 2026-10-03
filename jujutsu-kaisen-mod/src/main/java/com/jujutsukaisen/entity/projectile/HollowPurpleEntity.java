package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.config.JJKConfig;
import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.registry.ModTags;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;

import java.util.HashSet;
import java.util.Set;

/**
 * 허식 「자」 — Hollow Technique: Purple. Blue and Red collide and produce imaginary mass that
 * erases everything in its path.
 */
public class HollowPurpleEntity extends JJKProjectile {
    private static final EntityDataAccessor<Float> RADIUS = SynchedEntityData.defineId(HollowPurpleEntity.class, EntityDataSerializers.FLOAT);
    private final Set<Integer> erased = new HashSet<>();

    public HollowPurpleEntity(EntityType<? extends HollowPurpleEntity> type, Level level) {
        super(type, level);
    }

    public HollowPurpleEntity(Level level, LivingEntity owner, float radius) {
        this(ModEntities.HOLLOW_PURPLE.get(), level);
        setOwner(owner);
        setRadius(radius);
    }

    @Override
    protected void defineSynchedData() {
        entityData.define(RADIUS, 2.6f);
    }

    public float getRadius() {
        return entityData.get(RADIUS);
    }

    public void setRadius(float radius) {
        entityData.set(RADIUS, radius);
    }

    @Override
    protected int maxAge() {
        return 130;
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

        for (Entity entity : level().getEntities(this, getBoundingBox().inflate(radius + 0.6),
                e -> e != owner && !e.isSpectator() && !(e instanceof HollowPurpleEntity))) {
            if (entity.getBoundingBox().getCenter().distanceTo(center) > radius + entity.getBbWidth()) continue;
            if (entity instanceof LivingEntity living) {
                if (owner != null && !JJK.canHit(owner, living)) continue;
                if (erased.add(living.getId())) {
                    living.hurt(ModDamageTypes.source(level(), ModDamageTypes.HOLLOW_PURPLE, this, owner), 60.0f);
                    Fx.burst(level(), Fx.PURPLE, living.getBoundingBox().getCenter(), 40, 0.6, 0.2);
                }
            } else if (entity instanceof net.minecraft.world.entity.projectile.Projectile && !(entity instanceof HollowPurpleEntity)) {
                entity.discard(); // imaginary mass erases whatever is flying at it
            }
        }

        if (JJKConfig.HOLLOW_PURPLE_BLOCK_DESTRUCTION.get() && JJK.canGrief(owner, false)) {
            int r = (int) Math.ceil(radius);
            BlockPos origin = BlockPos.containing(center);
            BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos();
            for (int x = -r; x <= r; x++) {
                for (int y = -r; y <= r; y++) {
                    for (int z = -r; z <= r; z++) {
                        if (x * x + y * y + z * z > radius * radius) continue;
                        pos.set(origin.getX() + x, origin.getY() + y, origin.getZ() + z);
                        BlockState state = level().getBlockState(pos);
                        if (state.isAir() || state.hasBlockEntity() || state.is(ModTags.TECHNIQUE_IMMUNE)) continue;
                        if (state.getDestroySpeed(level(), pos) < 0) continue;
                        if (!JJK.mayBreak(level(), pos, state, owner)) continue;
                        level().setBlock(pos, Blocks.AIR.defaultBlockState(), Block.UPDATE_CLIENTS);
                    }
                }
            }
        }

        if (age % 2 == 0) Fx.sphere(level(), Fx.PURPLE, center, radius * 1.05, 26);
        if (age % 12 == 0) Fx.sound(level(), center, SoundEvents.BEACON_DEACTIVATE, 3.0f, 0.4f);
    }

    @Override
    protected void clientTick() {
        Vec3 center = getBoundingBox().getCenter();
        float radius = getRadius();
        for (int i = 0; i < 6; i++) {
            Vec3 dir = new Vec3(random.nextGaussian(), random.nextGaussian(), random.nextGaussian()).normalize();
            Vec3 p = center.add(dir.scale(radius * (0.9 + random.nextDouble() * 0.5)));
            level().addParticle(ParticleTypes.REVERSE_PORTAL, p.x, p.y, p.z, dir.x * 0.05, dir.y * 0.05, dir.z * 0.05);
        }
        Vec3 back = center.subtract(getDeltaMovement().normalize().scale(radius));
        level().addParticle(ParticleTypes.DRAGON_BREATH, back.x, back.y, back.z, 0, 0, 0);
    }

    @Override
    protected void onExpire() {
        Vec3 center = getBoundingBox().getCenter();
        Fx.burst(level(), Fx.PURPLE, center, 80, getRadius(), 0.3);
        Fx.sound(level(), center, SoundEvents.ENDER_DRAGON_FLAP, 3.0f, 0.5f);
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

package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.util.Blast;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

import java.util.HashSet;
import java.util.Set;

/**
 * 세계를 가르는 참격 — World-Cutting Slash. Dismantle aimed not at the target but at the space the
 * target occupies; no defence, not even Infinity, stops it.
 */
public class WorldSlashEntity extends JJKProjectile implements InfinityPiercing {
    private static final EntityDataAccessor<Float> ROLL = SynchedEntityData.defineId(WorldSlashEntity.class, EntityDataSerializers.FLOAT);
    public static final double HALF_WIDTH = 7.0;
    private final Set<Integer> hit = new HashSet<>();
    private float damage = 80.0f;

    public WorldSlashEntity(EntityType<? extends WorldSlashEntity> type, Level level) {
        super(type, level);
    }

    public WorldSlashEntity(Level level, LivingEntity owner, float damage) {
        this(ModEntities.WORLD_SLASH.get(), level);
        setOwner(owner);
        this.damage = damage;
        entityData.set(ROLL, (level.random.nextFloat() * 2 - 1) * 35f);
    }

    @Override
    protected void defineSynchedData() {
        entityData.define(ROLL, 0f);
    }

    public float getRoll() {
        return entityData.get(ROLL);
    }

    @Override
    protected int maxAge() {
        return 24;
    }

    @Override
    protected boolean collidesWithEntities() {
        return false;
    }

    @Override
    protected boolean collidesWithBlocks() {
        return false;
    }

    /** Unit vector along the cut line (perpendicular to flight, rolled). */
    public Vec3 cutAxis() {
        Vec3 forward = getDeltaMovement().normalize();
        Vec3 side = forward.cross(new Vec3(0, 1, 0));
        if (side.lengthSqr() < 1.0E-4) side = new Vec3(1, 0, 0);
        side = side.normalize();
        Vec3 up = side.cross(forward).normalize();
        float roll = getRoll() * Mth.DEG_TO_RAD;
        return up.scale(Mth.cos(roll)).add(side.scale(Mth.sin(roll))).normalize();
    }

    @Override
    protected void serverTick() {
        LivingEntity owner = ownerLiving();
        Vec3 velocity = getDeltaMovement();
        Vec3 now = getBoundingBox().getCenter();
        Vec3 forward = velocity.normalize();
        Vec3 axis = cutAxis();
        double speed = velocity.length();

        for (LivingEntity living : level().getEntitiesOfClass(LivingEntity.class, getBoundingBox().inflate(HALF_WIDTH + 1, HALF_WIDTH + 1, HALF_WIDTH + 1).expandTowards(velocity.scale(-1)),
                e -> owner == null || JJK.canHit(owner, e))) {
            Vec3 rel = living.getBoundingBox().getCenter().subtract(now);
            double along = rel.dot(forward);
            double onAxis = Math.abs(rel.dot(axis));
            Vec3 lateral = rel.subtract(forward.scale(along)).subtract(axis.scale(rel.dot(axis)));
            if (along > 0.8 || along < -speed - 0.8 || onAxis > HALF_WIDTH || lateral.length() > 1.2 + living.getBbWidth()) continue;
            if (!hit.add(living.getId())) continue;
            living.hurt(ModDamageTypes.source(level(), ModDamageTypes.WORLD_SLASH, this, owner), damage);
            Fx.burst(level(), Fx.CRIMSON, living.getBoundingBox().getCenter(), 40, 0.5, 0.2);
            Fx.burst(level(), ParticleTypes.SONIC_BOOM, living.getBoundingBox().getCenter(), 1, 0, 0);
        }

        if (JJK.canGrief(owner, false)) {
            for (double back = 0; back < speed; back += 0.8) {
                Vec3 point = now.subtract(forward.scale(back));
                for (double s = -HALF_WIDTH; s <= HALF_WIDTH; s += 0.8) {
                    Blast.cut(level(), BlockPos.containing(point.add(axis.scale(s))), 60f, false);
                }
            }
        }
        for (double s = -HALF_WIDTH; s <= HALF_WIDTH; s += 1.2) {
            Vec3 p = now.add(axis.scale(s));
            Fx.burst(level(), ParticleTypes.END_ROD, p, 1, 0.05, 0.0);
        }
        if (age == 1) {
            Fx.sound(level(), now, SoundEvents.WARDEN_SONIC_BOOM, 3.0f, 0.7f);
            Fx.sound(level(), now, SoundEvents.TRIDENT_THUNDER, 2.0f, 1.4f);
        }
    }
}

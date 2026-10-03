package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.util.Blast;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;

/**
 * 술식반전 「혁」 — Cursed Technique Reversal: Red. Positive energy fed into Limitless reverses it
 * into an overwhelming repulsion, at least twice the output of Blue.
 */
public class RedEntity extends JJKProjectile {
    private boolean detonated;

    public RedEntity(EntityType<? extends RedEntity> type, Level level) {
        super(type, level);
    }

    public RedEntity(Level level, LivingEntity owner) {
        this(ModEntities.RED.get(), level);
        setOwner(owner);
    }

    @Override
    protected int maxAge() {
        return 30;
    }

    @Override
    protected void onHit(HitResult result) {
        detonate();
    }

    @Override
    protected void onExpire() {
        detonate();
    }

    @Override
    protected void clientTick() {
        Vec3 p = getBoundingBox().getCenter();
        for (int i = 0; i < 3; i++) {
            level().addParticle(Fx.RED, p.x + random.nextGaussian() * 0.2, p.y + random.nextGaussian() * 0.2, p.z + random.nextGaussian() * 0.2, 0, 0, 0);
        }
        level().addParticle(ParticleTypes.FLAME, p.x, p.y, p.z, 0, 0, 0);
    }

    private void detonate() {
        if (detonated) return;
        detonated = true;
        Vec3 center = getBoundingBox().getCenter();
        LivingEntity owner = ownerLiving();
        double radius = 6.5;
        Vec3 forward = getDeltaMovement().lengthSqr() > 1.0E-4 ? getDeltaMovement().normalize() : Vec3.ZERO;

        for (LivingEntity living : level().getEntitiesOfClass(LivingEntity.class, getBoundingBox().inflate(radius),
                e -> owner == null || JJK.canHit(owner, e))) {
            Vec3 offset = living.getBoundingBox().getCenter().subtract(center);
            double dist = offset.length();
            if (dist > radius) continue;
            double falloff = 1.0 - dist / radius;
            living.hurt(ModDamageTypes.source(level(), ModDamageTypes.LIMITLESS, this, owner), (float) (9 + 17 * falloff));
            Vec3 dir = dist < 0.2 ? forward : offset.normalize();
            living.setDeltaMovement(living.getDeltaMovement().add(dir.scale(1.4 + 2.8 * falloff)).add(0, 0.35 + 0.45 * falloff, 0));
            living.hurtMarked = true;
        }

        if (JJK.canGrief(owner, false)) Blast.carveSphere(level(), center, 3.2, 3.5f, 400, true);
        Fx.burst(level(), Fx.RED, center, 120, 1.6, 0.4);
        Fx.burst(level(), ParticleTypes.EXPLOSION_EMITTER, center, 1, 0, 0);
        Fx.burst(level(), ParticleTypes.FLASH, center, 1, 0, 0);
        Fx.sphere(level(), Fx.RED, center, radius * 0.8, 90);
        Fx.sound(level(), center, SoundEvents.GENERIC_EXPLODE, 3.0f, 0.8f);
        Fx.sound(level(), center, SoundEvents.FIREWORK_ROCKET_BLAST, 3.0f, 0.5f);
        discard();
    }
}

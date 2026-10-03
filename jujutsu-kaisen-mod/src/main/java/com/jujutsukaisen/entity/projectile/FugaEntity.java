package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.util.Blast;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;

/**
 * 「竈」 開 — Divine Flame: Open (Fuga). A fire arrow drawn like a bow, far hotter than Jogo's fire.
 * Inside Malevolent Shrine all the cut-up dust carries its cursed energy: a thermobaric explosion.
 */
public class FugaEntity extends JJKProjectile {
    private boolean empowered;
    private boolean detonated;

    public FugaEntity(EntityType<? extends FugaEntity> type, Level level) {
        super(type, level);
    }

    public FugaEntity(Level level, LivingEntity owner, boolean empowered) {
        this(ModEntities.FUGA.get(), level);
        setOwner(owner);
        this.empowered = empowered;
    }

    @Override
    protected int maxAge() {
        return 60;
    }

    @Override
    protected void onHit(HitResult result) {
        ignite();
    }

    @Override
    protected void onExpire() {
        ignite();
    }

    @Override
    protected void clientTick() {
        Vec3 p = getBoundingBox().getCenter();
        Vec3 back = getDeltaMovement().scale(-0.5);
        for (int i = 0; i < 4; i++) {
            level().addParticle(ParticleTypes.FLAME, p.x + random.nextGaussian() * 0.12, p.y + random.nextGaussian() * 0.12,
                    p.z + random.nextGaussian() * 0.12, back.x * 0.1, back.y * 0.1, back.z * 0.1);
        }
        level().addParticle(ParticleTypes.LAVA, p.x, p.y, p.z, 0, 0, 0);
    }

    private void ignite() {
        if (detonated) return;
        detonated = true;
        Vec3 center = getBoundingBox().getCenter();
        LivingEntity owner = ownerLiving();
        double radius = empowered ? 9.0 : 6.0;

        for (LivingEntity living : level().getEntitiesOfClass(LivingEntity.class, getBoundingBox().inflate(radius),
                e -> owner == null || JJK.canHit(owner, e))) {
            double dist = living.getBoundingBox().getCenter().distanceTo(center);
            if (dist > radius) continue;
            float dmg = (float) ((empowered ? 38 : 28) * (1.0 - 0.55 * dist / radius));
            living.hurt(ModDamageTypes.source(level(), ModDamageTypes.FUGA, this, owner), dmg);
            living.setSecondsOnFire(10);
            Vec3 push = living.getBoundingBox().getCenter().subtract(center).normalize().scale(1.2);
            living.setDeltaMovement(living.getDeltaMovement().add(push.x, 0.4, push.z));
            living.hurtMarked = true;
        }

        if (JJK.canGrief(owner, false)) {
            Blast.carveSphere(level(), owner, center, empowered ? 4.0 : 2.8, 6f, 600, true);
            Blast.scatterFire(level(), owner, center, radius, empowered ? 60 : 30);
        }
        Fx.burst(level(), ParticleTypes.FLAME, center, 200, radius * 0.4, 0.25);
        Fx.burst(level(), ParticleTypes.LAVA, center, 40, radius * 0.3, 0.2);
        Fx.burst(level(), ParticleTypes.EXPLOSION_EMITTER, center, 2, 0.5, 0);
        Fx.burst(level(), ParticleTypes.LARGE_SMOKE, center, 60, radius * 0.4, 0.05);
        Fx.sound(level(), center, SoundEvents.GENERIC_EXPLODE, 4.0f, 0.6f);
        Fx.sound(level(), center, SoundEvents.FIRECHARGE_USE, 3.0f, 0.5f);
        discard();
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putBoolean("Empowered", empowered);
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        empowered = tag.getBoolean("Empowered");
    }
}

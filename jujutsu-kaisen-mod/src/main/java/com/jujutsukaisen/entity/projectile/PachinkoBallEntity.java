package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.domain.Indicator;
import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.registry.ModItems;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ItemParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.projectile.ThrowableItemProjectile;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.EntityHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;

/**
 * 보류 구슬 — a reserve ball. Hakari's cursed energy is rough (까칠까칠한 주력): even a blunt hit
 * cuts and stings. The indicator colour decides how hard it hits.
 */
public class PachinkoBallEntity extends ThrowableItemProjectile {
    private static final EntityDataAccessor<Byte> COLOR = SynchedEntityData.defineId(PachinkoBallEntity.class, EntityDataSerializers.BYTE);
    private float damage = 3.0f;

    public PachinkoBallEntity(EntityType<? extends PachinkoBallEntity> type, Level level) {
        super(type, level);
    }

    public PachinkoBallEntity(Level level, LivingEntity owner, Indicator color, float damage) {
        super(ModEntities.PACHINKO_BALL.get(), owner, level);
        this.entityData.set(COLOR, (byte) color.ordinal());
        this.damage = damage;
    }

    @Override
    protected void defineSynchedData() {
        super.defineSynchedData();
        entityData.define(COLOR, (byte) 0);
    }

    public Indicator getIndicator() {
        return Indicator.byOrdinal(entityData.get(COLOR));
    }

    @Override
    protected Item getDefaultItem() {
        return ModItems.PACHINKO_BALL.get();
    }

    @Override
    protected boolean canHitEntity(Entity entity) {
        return super.canHitEntity(entity) && !(getOwner() instanceof LivingEntity owner && JJK.isAlly(owner, entity));
    }

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide && tickCount % 2 == 0) {
            Vec3 p = position();
            level().addParticle(getIndicator().dust(), p.x, p.y + 0.1, p.z, 0, 0, 0);
        }
    }

    @Override
    protected void onHitEntity(EntityHitResult result) {
        super.onHitEntity(result);
        Entity target = result.getEntity();
        LivingEntity owner = getOwner() instanceof LivingEntity living ? living : null;
        target.hurt(ModDamageTypes.source(level(), ModDamageTypes.ROUGH_ENERGY, this, owner), damage * getIndicator().power());
        Fx.burst(level(), getIndicator().dust(), target.getBoundingBox().getCenter(), 10, 0.3, 0.1);
        Fx.burst(level(), ParticleTypes.CRIT, target.getBoundingBox().getCenter(), 6, 0.2, 0.2);
    }

    @Override
    protected void onHit(HitResult result) {
        super.onHit(result);
        if (!level().isClientSide) {
            Fx.burst(level(), new ItemParticleOption(ParticleTypes.ITEM, getItem()), position(), 6, 0.1, 0.08);
            Fx.sound(level(), position(), SoundEvents.CHAIN_HIT, 0.6f, 1.8f);
            discard();
        }
    }
}

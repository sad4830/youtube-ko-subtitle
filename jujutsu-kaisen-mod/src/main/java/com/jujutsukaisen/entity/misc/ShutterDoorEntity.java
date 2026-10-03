package com.jujutsukaisen.entity.misc;

import com.jujutsukaisen.domain.Indicator;
import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientGamePacketListener;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.network.NetworkHooks;
import org.jetbrains.annotations.Nullable;

import java.util.UUID;

/**
 * 셔터 — the train's shutter doors, an offensive notice effect of Private Pure Love Train.
 * Two panels appear on either side of the target and slam shut.
 */
public class ShutterDoorEntity extends Entity {
    public static final int SLAM_TICK = 7;
    public static final int LIFETIME = 26;
    private static final EntityDataAccessor<Byte> COLOR = SynchedEntityData.defineId(ShutterDoorEntity.class, EntityDataSerializers.BYTE);
    @Nullable
    private UUID ownerId;
    private float damage = 13f;

    public ShutterDoorEntity(EntityType<? extends ShutterDoorEntity> type, Level level) {
        super(type, level);
        this.noPhysics = true;
    }

    public ShutterDoorEntity(Level level, LivingEntity owner, Vec3 pos, float yaw, Indicator color, float damage) {
        this(ModEntities.SHUTTER_DOOR.get(), level);
        this.ownerId = owner.getUUID();
        this.damage = damage;
        setPos(pos.x, pos.y, pos.z);
        setYRot(yaw);
        yRotO = yaw;
        entityData.set(COLOR, (byte) color.ordinal());
    }

    public Indicator getIndicator() {
        return Indicator.byOrdinal(entityData.get(COLOR));
    }

    @Override
    protected void defineSynchedData() {
        entityData.define(COLOR, (byte) 0);
    }

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide) return;
        if (tickCount == 1) Fx.sound(level(), position(), SoundEvents.IRON_DOOR_OPEN, 1.5f, 0.6f);
        if (tickCount == SLAM_TICK) slam();
        if (tickCount >= LIFETIME) discard();
    }

    private void slam() {
        LivingEntity owner = ownerId != null && level() instanceof ServerLevel server && server.getEntity(ownerId) instanceof LivingEntity living ? living : null;
        Vec3 center = position().add(0, 1.2, 0);
        for (LivingEntity living : level().getEntitiesOfClass(LivingEntity.class, getBoundingBox().inflate(0.8, 0.2, 0.8),
                e -> owner == null || JJK.canHit(owner, e))) {
            living.hurt(ModDamageTypes.source(level(), ModDamageTypes.SHUTTER_DOOR, this, owner), damage * getIndicator().power());
            living.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN, 40, 3));
            living.setDeltaMovement(Vec3.ZERO);
            living.hurtMarked = true;
        }
        Fx.sound(level(), center, SoundEvents.IRON_DOOR_CLOSE, 2.5f, 0.5f);
        Fx.sound(level(), center, SoundEvents.ANVIL_LAND, 1.2f, 0.8f);
        Fx.burst(level(), ParticleTypes.CRIT, center, 30, 0.2, 1.0, 0.2, 0.3);
        Fx.burst(level(), getIndicator().dust(), center, 30, 0.3, 1.0, 0.3, 0.0);
    }

    @Override
    public boolean isPickable() {
        return false;
    }

    @Override
    public boolean shouldBeSaved() {
        return false;
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
    }

    @Override
    public Packet<ClientGamePacketListener> getAddEntityPacket() {
        return NetworkHooks.getEntitySpawningPacket(this);
    }
}

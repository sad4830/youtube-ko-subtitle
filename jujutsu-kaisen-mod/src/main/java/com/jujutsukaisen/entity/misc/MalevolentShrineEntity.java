package com.jujutsukaisen.entity.misc;

import com.jujutsukaisen.registry.ModEntities;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientGamePacketListener;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.Level;
import net.minecraftforge.network.NetworkHooks;

/**
 * 복마어주자 — the shrine of Malevolent Shrine itself: a Buddhist shrine heaped with skulls and
 * gaping with a mouth. Purely visual; the domain logic lives in {@code DomainManager}.
 */
public class MalevolentShrineEntity extends Entity {
    private int lifetime = 20 * 30;

    public MalevolentShrineEntity(EntityType<? extends MalevolentShrineEntity> type, Level level) {
        super(type, level);
        this.noPhysics = true;
    }

    public MalevolentShrineEntity(Level level, double x, double y, double z, float yaw, int lifetime) {
        this(ModEntities.MALEVOLENT_SHRINE.get(), level);
        setPos(x, y, z);
        setYRot(yaw);
        yRotO = yaw;
        this.lifetime = lifetime;
    }

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide) {
            if (random.nextInt(3) == 0) {
                level().addParticle(ParticleTypes.LARGE_SMOKE, getX() + random.nextGaussian() * 2, getY() + 0.3, getZ() + random.nextGaussian() * 2, 0, 0.03, 0);
            }
            return;
        }
        if (tickCount > lifetime) discard();
    }

    /** Height the shrine has risen out of the ground (0..1) for the rising animation. */
    public float rise(float partialTick) {
        return Math.min(1f, (tickCount + partialTick) / 20f);
    }

    public void collapse() {
        discard();
    }

    @Override
    protected void defineSynchedData() {
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
    public boolean shouldRenderAtSqrDistance(double distance) {
        return distance < 160 * 160;
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

package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.util.Blast;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import java.util.HashSet;
import java.util.Set;

/**
 * 해 — Dismantle. Sukuna's default, invisible, rapid slash. It cuts through whatever it passes,
 * weakening the further it travels.
 */
public class DismantleEntity extends JJKProjectile {
    private static final EntityDataAccessor<Float> ROLL = SynchedEntityData.defineId(DismantleEntity.class, EntityDataSerializers.FLOAT);
    private static final EntityDataAccessor<Float> SCALE = SynchedEntityData.defineId(DismantleEntity.class, EntityDataSerializers.FLOAT);
    private final Set<Integer> hit = new HashSet<>();
    private float damage = 9.0f;
    private int blocksLeft = 10;
    private Vec3 origin = Vec3.ZERO;

    public DismantleEntity(EntityType<? extends DismantleEntity> type, Level level) {
        super(type, level);
    }

    public DismantleEntity(Level level, LivingEntity owner, float damage, float scale) {
        this(ModEntities.DISMANTLE.get(), level);
        setOwner(owner);
        this.damage = damage;
        entityData.set(SCALE, scale);
        entityData.set(ROLL, (level.random.nextFloat() * 2 - 1) * 75f);
    }

    @Override
    protected void defineSynchedData() {
        entityData.define(ROLL, 0f);
        entityData.define(SCALE, 1f);
    }

    public float getRoll() {
        return entityData.get(ROLL);
    }

    public float getScale() {
        return entityData.get(SCALE);
    }

    @Override
    public void launch(LivingEntity caster, Vec3 direction, float speed) {
        super.launch(caster, direction, speed);
        origin = position();
    }

    @Override
    protected int maxAge() {
        return 22;
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
        LivingEntity owner = ownerLiving();
        Vec3 velocity = getDeltaMovement();
        Vec3 now = getBoundingBox().getCenter();
        Vec3 before = now.subtract(velocity);
        float scale = getScale();
        AABB swept = new AABB(before, now).inflate(0.7 * scale);
        double traveled = origin == Vec3.ZERO ? age * velocity.length() : position().distanceTo(origin);
        float power = (float) Math.max(0.45, 1.0 - traveled / 70.0);

        for (LivingEntity living : level().getEntitiesOfClass(LivingEntity.class, swept,
                e -> canHitEntity(e) && owner != null && JJK.canHit(owner, e))) {
            if (!hit.add(living.getId())) continue;
            if (living.hurt(ModDamageTypes.source(level(), ModDamageTypes.DISMANTLE, this, owner), damage * power)) {
                SorcererData data = JJK.get(owner);
                if (data != null) data.setLastDismantleHit(level().getGameTime());
            }
            Fx.burst(level(), Fx.CRIMSON, living.getBoundingBox().getCenter(), 14, 0.3, 0.1);
            Fx.burst(level(), ParticleTypes.SWEEP_ATTACK, living.getBoundingBox().getCenter(), 1, 0, 0);
        }

        // Cut through soft matter along the path; hard matter stops the slash.
        BlockPos pos = BlockPos.containing(now);
        if (!level().getBlockState(pos).isAir()) {
            boolean cut = blocksLeft > 0 && JJK.canGrief(owner, false) && Blast.cut(level(), pos, 3.0f, true);
            if (cut) {
                blocksLeft--;
                Blast.cut(level(), pos.above(), 3.0f, false);
            } else if (level().getBlockState(pos).blocksMotion()) {
                Fx.burst(level(), ParticleTypes.CRIT, now, 10, 0.2, 0.2);
                Fx.sound(level(), now, SoundEvents.ANVIL_PLACE, 0.5f, 1.8f);
                discard();
            }
        }
        if (age == 1) Fx.sound(level(), now, SoundEvents.PLAYER_ATTACK_SWEEP, 1.2f, 1.6f);
    }

    @Override
    protected void clientTick() {
        Vec3 p = getBoundingBox().getCenter();
        level().addParticle(ParticleTypes.CRIT, p.x, p.y, p.z, 0, 0, 0);
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putFloat("Damage", damage);
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        damage = tag.getFloat("Damage");
    }
}

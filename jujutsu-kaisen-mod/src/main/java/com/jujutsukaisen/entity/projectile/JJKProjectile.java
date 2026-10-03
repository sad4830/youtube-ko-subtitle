package com.jujutsukaisen.entity.projectile;

import com.jujutsukaisen.sorcery.JJK;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.projectile.Projectile;
import net.minecraft.world.entity.projectile.ProjectileUtil;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

/**
 * Base for technique projectiles: straight flight without drag, a lifetime, and owner-aware
 * hit filtering (a technique never hits its caster's allies).
 */
public abstract class JJKProjectile extends Projectile {
    protected int age;

    protected JJKProjectile(EntityType<? extends JJKProjectile> type, Level level) {
        super(type, level);
        this.noCulling = true;
    }

    protected abstract int maxAge();

    /** Called on the logical server every tick after moving. */
    protected void serverTick() {
    }

    /** Called on the client every tick (particles). */
    protected void clientTick() {
    }

    /** Called when the lifetime runs out (server). */
    protected void onExpire() {
        discard();
    }

    protected boolean usesGravity() {
        return false;
    }

    /** Projectiles that pass through entities handle contact themselves in {@link #serverTick()}. */
    protected boolean collidesWithEntities() {
        return true;
    }

    protected boolean collidesWithBlocks() {
        return true;
    }

    public void launch(LivingEntity caster, Vec3 direction, float speed) {
        setOwner(caster);
        Vec3 dir = direction.normalize();
        Vec3 start = caster.getEyePosition().add(dir.scale(0.8)).subtract(0, getBbHeight() * 0.5, 0);
        setPos(start.x, start.y, start.z);
        setDeltaMovement(dir.scale(speed));
        faceMovement();
    }

    protected void faceMovement() {
        Vec3 v = getDeltaMovement();
        if (v.lengthSqr() < 1.0E-6) return;
        double horizontal = v.horizontalDistance();
        setYRot((float) (Mth.atan2(v.x, v.z) * Mth.RAD_TO_DEG));
        setXRot((float) (Mth.atan2(v.y, horizontal) * Mth.RAD_TO_DEG));
        yRotO = getYRot();
        xRotO = getXRot();
    }

    @Nullable
    public LivingEntity ownerLiving() {
        return getOwner() instanceof LivingEntity living ? living : null;
    }

    @Override
    public void tick() {
        super.tick();
        age++;
        if (!level().isClientSide && age > maxAge()) {
            onExpire();
            return;
        }

        if (!level().isClientSide && (collidesWithBlocks() || collidesWithEntities())) {
            HitResult hit = ProjectileUtil.getHitResultOnMoveVector(this, this::canHitEntity);
            boolean relevant = hit.getType() == HitResult.Type.ENTITY ? collidesWithEntities()
                    : hit.getType() == HitResult.Type.BLOCK && collidesWithBlocks();
            if (relevant && !net.minecraftforge.event.ForgeEventFactory.onProjectileImpact(this, hit)) {
                onHit(hit);
                if (isRemoved()) return;
            }
        }

        Vec3 v = getDeltaMovement();
        setPos(getX() + v.x, getY() + v.y, getZ() + v.z);
        if (usesGravity() && !isNoGravity()) setDeltaMovement(v.add(0, -0.04, 0));
        faceMovement();

        if (level().isClientSide) clientTick();
        else serverTick();
    }

    @Override
    protected boolean canHitEntity(Entity entity) {
        if (!super.canHitEntity(entity)) return false;
        LivingEntity owner = ownerLiving();
        return owner == null || !JJK.isAlly(owner, entity);
    }

    @Override
    public boolean isPickable() {
        return false;
    }

    @Override
    public boolean shouldRenderAtSqrDistance(double distance) {
        return distance < 256 * 256;
    }

    @Override
    protected void defineSynchedData() {
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putInt("Age", age);
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        age = tag.getInt("Age");
    }

    public int getAge() {
        return age;
    }
}

package com.jujutsukaisen.entity;

import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.Technique;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.BossEvent;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import net.minecraft.world.entity.monster.Creeper;
import net.minecraft.world.entity.monster.Enemy;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

/**
 * 고죠 사토루 — the strongest sorcerer. Six Eyes + Limitless: Infinity is always on, Blue pulls,
 * Red repels, Hollow Purple erases, and Unlimited Void ends fights. He repairs his burned-out
 * brain with Reverse Cursed Technique, so his technique comes back quickly after a domain.
 */
public class GojoEntity extends SorcererEntity {
    private int blinkCooldown;
    private boolean lastStand;

    public GojoEntity(EntityType<? extends GojoEntity> type, Level level) {
        super(type, level);
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Mob.createMobAttributes()
                .add(Attributes.MAX_HEALTH, 320.0)
                .add(Attributes.ATTACK_DAMAGE, 11.0)
                .add(Attributes.MOVEMENT_SPEED, 0.34)
                .add(Attributes.FOLLOW_RANGE, 48.0)
                .add(Attributes.ARMOR, 4.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 0.6);
    }

    @Override
    public Technique technique() {
        return Technique.LIMITLESS;
    }

    @Override
    protected float maxEnergy() {
        return 6000f;
    }

    @Override
    protected BossEvent.BossBarColor barColor() {
        return BossEvent.BossBarColor.BLUE;
    }

    @Override
    public float costMultiplier() {
        return 0.45f;
    }

    @Override
    public float cooldownMultiplier() {
        return 0.8f;
    }

    @Override
    public float domainMastery() {
        return 1.15f;
    }

    @Override
    public int burnoutTicks() {
        return 60;
    }

    @Override
    public boolean isFriendlyWith(SorcererEntity other) {
        return other instanceof HakariEntity || other instanceof GojoEntity;
    }

    @Override
    protected @Nullable String engageLine() {
        return "line.jujutsukaisen.gojo.engage";
    }

    @Override
    protected void registerTargets() {
        targetSelector.addGoal(1, new HurtByTargetGoal(this));
        targetSelector.addGoal(2, new NearestAttackableTargetGoal<>(this, SukunaEntity.class, false));
        targetSelector.addGoal(3, new NearestAttackableTargetGoal<>(this, MahoragaEntity.class, 10, true, false,
                e -> e instanceof MahoragaEntity m && m.getTarget() == this));
        targetSelector.addGoal(4, new NearestAttackableTargetGoal<>(this, Mob.class, 10, true, false,
                e -> e instanceof Enemy && !(e instanceof Creeper) && !(e instanceof SorcererEntity)));
    }

    @Override
    public void tick() {
        super.tick();
        if (blinkCooldown > 0) blinkCooldown--;
    }

    @Override
    public void combatTick(LivingEntity target, double distSqr) {
        float hp = healthRatio();
        boolean strong = target.getMaxHealth() >= 100;
        boolean seen = getSensing().hasLineOfSight(target);

        if (hp < 0.45f && !data.isRctActive() && data.getCursedEnergy() > 400) {
            data.setRctActive(true);
            say("line.jujutsukaisen.gojo.rct");
        }
        if (hp < 0.3f && !lastStand) {
            lastStand = true;
            say("line.jujutsukaisen.gojo.honored_one");
        }

        if (DomainManager.find(this) == null && distSqr < 12 * 12 && (strong || hp < 0.7f)
                && ready(Ability.DOMAIN_INFINITE_VOID) && random.nextInt(30) == 0) {
            use(Ability.DOMAIN_INFINITE_VOID);
            return;
        }
        if (seen && distSqr > 7 * 7 && distSqr < 42 * 42 && (strong || hp < 0.5f)
                && ready(Ability.HOLLOW_PURPLE) && random.nextInt(25) == 0) {
            use(Ability.HOLLOW_PURPLE);
            return;
        }
        if (distSqr < 5 * 5 && ready(Ability.RED) && random.nextInt(28) == 0) {
            use(Ability.RED);
            return;
        }
        if (seen && distSqr > 6 * 6 && ready(Ability.BLUE) && random.nextInt(18) == 0) {
            use(Ability.BLUE);
            return;
        }
        if (distSqr > 14 * 14 && blinkCooldown <= 0 && !data.isBurntOut()) blink(target);
    }

    /** Blue-powered movement: Gojo pulls himself to a point beside the target. */
    private void blink(LivingEntity target) {
        Vec3 toMe = position().subtract(target.position());
        Vec3 offset = toMe.lengthSqr() < 1.0E-4 ? new Vec3(1, 0, 0) : toMe.normalize().scale(2.5);
        Vec3 dest = target.position().add(offset);
        Fx.burst(level(), Fx.BLUE, getBoundingBox().getCenter(), 25, 0.4, 0.05);
        if (randomTeleport(dest.x, dest.y, dest.z, true)) {
            Fx.burst(level(), Fx.BLUE, getBoundingBox().getCenter(), 25, 0.4, 0.05);
            Fx.burst(level(), ParticleTypes.REVERSE_PORTAL, getBoundingBox().getCenter(), 20, 0.3, 0.1);
            Fx.sound(this, SoundEvents.ILLUSIONER_MIRROR_MOVE, 1.4f, 1.6f);
            data.consume(20f);
            blinkCooldown = 80;
        } else {
            blinkCooldown = 20;
        }
    }
}

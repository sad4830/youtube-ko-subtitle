package com.jujutsukaisen.entity.ai;

import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.phys.Vec3;

import java.util.EnumSet;

/**
 * Mahoraga's brute combat: it closes the distance with huge leaps, then alternates crushing punches
 * with sweeps of the Sword of Extermination. The hit lands mid-swing.
 */
public class MahoragaAttackGoal extends Goal {
    private final MahoragaEntity mob;
    private int cooldown;
    private int windup = -1;
    private boolean sword;
    private int leapCooldown;
    private int repath;

    public MahoragaAttackGoal(MahoragaEntity mob) {
        this.mob = mob;
        setFlags(EnumSet.of(Flag.MOVE, Flag.LOOK));
    }

    @Override
    public boolean canUse() {
        LivingEntity target = mob.getTarget();
        return target != null && target.isAlive();
    }

    @Override
    public boolean canContinueToUse() {
        return canUse();
    }

    @Override
    public boolean requiresUpdateEveryTick() {
        return true;
    }

    @Override
    public void start() {
        mob.setAggressive(true);
    }

    @Override
    public void stop() {
        mob.setAggressive(false);
        mob.getNavigation().stop();
        windup = -1;
    }

    @Override
    public void tick() {
        LivingEntity target = mob.getTarget();
        if (target == null) return;
        mob.getLookControl().setLookAt(target, 30f, 30f);
        if (cooldown > 0) cooldown--;
        if (leapCooldown > 0) leapCooldown--;
        double distSqr = mob.distanceToSqr(target);
        double reach = 4.2 + target.getBbWidth();

        if (windup >= 0) {
            mob.getNavigation().stop();
            if (--windup == 0) {
                if (distSqr <= (reach + 1.5) * (reach + 1.5) && JJK.canHit(mob, target)) {
                    if (sword) {
                        mob.swordSweep(target);
                    } else {
                        mob.doHurtTarget(target);
                        Fx.burst(mob.level(), ParticleTypes.EXPLOSION, target.getBoundingBox().getCenter(), 1, 0, 0);
                        Fx.sound(mob, SoundEvents.IRON_GOLEM_ATTACK, 2.0f, 0.5f);
                    }
                }
                windup = -1;
                cooldown = 14 + mob.getRandom().nextInt(8);
            }
            return;
        }

        if (distSqr > 10 * 10 && leapCooldown <= 0 && mob.onGround() && mob.getSensing().hasLineOfSight(target)) {
            Vec3 to = target.position().subtract(mob.position());
            Vec3 horizontal = new Vec3(to.x, 0, to.z).normalize().scale(Math.min(2.4, Math.sqrt(distSqr) * 0.11));
            mob.setDeltaMovement(horizontal.x, 0.75, horizontal.z);
            mob.hurtMarked = true;
            leapCooldown = 70;
            Fx.burst(mob.level(), ParticleTypes.CLOUD, mob.position(), 20, 0.8, 0.05);
            Fx.sound(mob, SoundEvents.RAVAGER_ROAR, 1.6f, 0.7f);
            return;
        }

        if (distSqr > reach * reach) {
            if (--repath <= 0) {
                mob.getNavigation().moveTo(target, 1.25);
                repath = 5;
            }
        } else {
            mob.getNavigation().stop();
            if (cooldown <= 0) {
                sword = mob.getRandom().nextFloat() < 0.45f;
                windup = 6;
                mob.startAttack(sword);
            }
        }
    }
}

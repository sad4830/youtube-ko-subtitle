package com.jujutsukaisen.entity.ai;

import com.jujutsukaisen.entity.SorcererEntity;
import com.jujutsukaisen.registry.ModEffects;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.goal.Goal;

import java.util.EnumSet;

/** Chases the target, punches in melee range, and lets the character pick techniques. */
public class SorcererCombatGoal extends Goal {
    private final SorcererEntity mob;
    private int repath;

    public SorcererCombatGoal(SorcererEntity mob) {
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
        repath = 0;
    }

    @Override
    public void stop() {
        mob.setAggressive(false);
        mob.getNavigation().stop();
    }

    @Override
    public void tick() {
        LivingEntity target = mob.getTarget();
        if (target == null) return;
        if (mob.hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) {
            mob.getNavigation().stop();
            return;
        }
        mob.getLookControl().setLookAt(target, 40f, 40f);
        if (mob.getSorcererData().getCasting() != null) {
            mob.getNavigation().stop();
            return;
        }
        double distSqr = mob.distanceToSqr(target);
        mob.combatTick(target, distSqr);
        if (mob.getSorcererData().getCasting() != null) return;

        double range = mob.preferredRange();
        boolean seen = mob.getSensing().hasLineOfSight(target);
        double reach = mob.getBbWidth() * 2.0 * mob.getBbWidth() * 2.0 + target.getBbWidth() + 1.2;
        // Close in until the target is inside melee reach, not just inside the preferred range.
        double stopSqr = Math.min(range * range, reach * 0.9);
        if (distSqr > stopSqr || !seen) {
            if (--repath <= 0) {
                mob.getNavigation().moveTo(target, mob.chaseSpeed());
                repath = 4 + mob.getRandom().nextInt(6);
            }
        } else {
            mob.getNavigation().stop();
        }

        if (distSqr <= reach && seen && mob.meleeReady()) {
            mob.swing(InteractionHand.MAIN_HAND);
            mob.doHurtTarget(target);
            mob.resetMelee();
        }
    }
}

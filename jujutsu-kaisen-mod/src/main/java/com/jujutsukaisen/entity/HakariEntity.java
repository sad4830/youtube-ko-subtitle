package com.jujutsukaisen.entity;

import com.jujutsukaisen.domain.ActiveDomain;
import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.BossEvent;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.UUID;

/**
 * 하카리 킨지 — "I love fever." Private Pure Love Train: notice effects as attacks, Idle Death
 * Gamble as the domain, and after a jackpot 4:11 of unlimited cursed energy with automatic RCT.
 */
public class HakariEntity extends SorcererEntity {
    @Nullable
    private UUID challenger;

    public HakariEntity(EntityType<? extends HakariEntity> type, Level level) {
        super(type, level);
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Mob.createMobAttributes()
                .add(Attributes.MAX_HEALTH, 260.0)
                .add(Attributes.ATTACK_DAMAGE, 13.0)
                .add(Attributes.MOVEMENT_SPEED, 0.36)
                .add(Attributes.FOLLOW_RANGE, 40.0)
                .add(Attributes.ARMOR, 6.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 0.4);
    }

    @Override
    public Technique technique() {
        return Technique.IDLE_DEATH_GAMBLE;
    }

    @Override
    protected float maxEnergy() {
        return 3000f;
    }

    @Override
    protected BossEvent.BossBarColor barColor() {
        return BossEvent.BossBarColor.YELLOW;
    }

    @Override
    public float costMultiplier() {
        return 0.6f;
    }

    @Override
    public float domainMastery() {
        // The harmless sure-hit lets the domain build in under 0.2 s: very strong in clashes.
        return 1.2f;
    }

    @Override
    public int burnoutTicks() {
        return 160;
    }

    @Override
    public int meleeInterval() {
        return 11;
    }

    @Override
    public boolean isFriendlyWith(SorcererEntity other) {
        return other instanceof GojoEntity || other instanceof HakariEntity;
    }

    @Override
    protected @Nullable String engageLine() {
        return "line.jujutsukaisen.hakari.engage";
    }

    /** Underground fight club: this player challenged Hakari. */
    public void setChallenger(Player player) {
        this.challenger = player.getUUID();
        setTarget(player);
        say("line.jujutsukaisen.hakari.challenge");
    }

    @Override
    protected void registerTargets() {
        targetSelector.addGoal(1, new HurtByTargetGoal(this));
        targetSelector.addGoal(2, new NearestAttackableTargetGoal<>(this, Player.class, 10, true, false,
                p -> challenger != null && challenger.equals(p.getUUID())));
        targetSelector.addGoal(3, new NearestAttackableTargetGoal<>(this, SukunaEntity.class, false));
    }

    @Override
    public void combatTick(LivingEntity target, double distSqr) {
        float hp = healthRatio();
        ActiveDomain domain = DomainManager.find(this);

        if (domain != null) {
            // Inside the domain every notice leads into a riichi.
            if (domain.isSpinning()) return;
            if (hp < 0.6f && ready(Ability.PSEUDO_CONSECUTIVE) && random.nextInt(10) == 0) {
                use(Ability.PSEUDO_CONSECUTIVE);
            } else if (ready(Ability.SHUTTER_DOORS) && random.nextInt(12) == 0) {
                use(Ability.SHUTTER_DOORS);
            } else if (distSqr > 3 * 3 && ready(Ability.RESERVE_BALLS) && random.nextInt(8) == 0) {
                use(Ability.RESERVE_BALLS);
            }
            return;
        }

        boolean wantsDomain = data.isJackpot() || hp < 0.75f || target.getMaxHealth() >= 100;
        if (wantsDomain && distSqr < 10 * 10 && ready(Ability.DOMAIN_IDLE_DEATH_GAMBLE) && random.nextInt(25) == 0) {
            use(Ability.DOMAIN_IDLE_DEATH_GAMBLE);
            return;
        }
        if (hp < 0.4f && ready(Ability.PSEUDO_CONSECUTIVE) && random.nextInt(30) == 0) {
            use(Ability.PSEUDO_CONSECUTIVE);
            return;
        }
        if (distSqr > 5 * 5 && ready(Ability.RESERVE_BALLS) && random.nextInt(14) == 0) {
            use(Ability.RESERVE_BALLS);
            return;
        }
        if (ready(Ability.SHUTTER_DOORS) && random.nextInt(35) == 0) {
            use(Ability.SHUTTER_DOORS);
        }
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        if (challenger != null) tag.putUUID("Challenger", challenger);
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        if (tag.hasUUID("Challenger")) challenger = tag.getUUID("Challenger");
    }
}

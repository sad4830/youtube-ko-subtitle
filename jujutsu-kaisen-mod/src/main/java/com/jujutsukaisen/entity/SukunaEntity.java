package com.jujutsukaisen.entity;

import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.SorcererLogic;
import com.jujutsukaisen.sorcery.Technique;
import com.jujutsukaisen.sorcery.technique.Shrine;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.BossEvent;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import net.minecraft.world.entity.animal.IronGolem;
import net.minecraft.world.entity.npc.AbstractVillager;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

/**
 * 료멘 스쿠나 — the King of Curses in his true Heian form: four arms, four eyes, a second face and
 * a mouth on his abdomen. Shrine (해 · 팔 · 竈), Malevolent Shrine, World-Cutting Slash and,
 * as in Shinjuku, the tamed Mahoraga.
 */
public class SukunaEntity extends SorcererEntity {
    private int volley;
    private int volleyDelay;
    private boolean summonedMahoraga;
    private boolean praised;

    public SukunaEntity(EntityType<? extends SukunaEntity> type, Level level) {
        super(type, level);
        data.setFingers(SorcererData.MAX_FINGERS);
        data.setFixedMax(maxEnergy());
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Mob.createMobAttributes()
                .add(Attributes.MAX_HEALTH, 400.0)
                .add(Attributes.ATTACK_DAMAGE, 14.0)
                .add(Attributes.MOVEMENT_SPEED, 0.33)
                .add(Attributes.FOLLOW_RANGE, 48.0)
                .add(Attributes.ARMOR, 10.0)
                .add(Attributes.ARMOR_TOUGHNESS, 6.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 0.8);
    }

    @Override
    public Technique technique() {
        return Technique.SHRINE;
    }

    @Override
    protected float maxEnergy() {
        return 7000f;
    }

    @Override
    protected BossEvent.BossBarColor barColor() {
        return BossEvent.BossBarColor.RED;
    }

    @Override
    public float costMultiplier() {
        return 0.45f;
    }

    @Override
    public float cooldownMultiplier() {
        return 0.75f;
    }

    @Override
    public float domainMastery() {
        return 1.2f;
    }

    @Override
    public int burnoutTicks() {
        return 70;
    }

    @Override
    public float blackFlashAffinity() {
        return 2.0f;
    }

    @Override
    public double preferredRange() {
        return 2.6;
    }

    @Override
    protected @Nullable String engageLine() {
        return "line.jujutsukaisen.sukuna.engage";
    }

    @Override
    protected void registerTargets() {
        targetSelector.addGoal(1, new HurtByTargetGoal(this));
        targetSelector.addGoal(2, new NearestAttackableTargetGoal<>(this, Player.class, true));
        targetSelector.addGoal(3, new NearestAttackableTargetGoal<>(this, GojoEntity.class, false));
        targetSelector.addGoal(3, new NearestAttackableTargetGoal<>(this, HakariEntity.class, false));
        targetSelector.addGoal(4, new NearestAttackableTargetGoal<>(this, AbstractVillager.class, true));
        targetSelector.addGoal(4, new NearestAttackableTargetGoal<>(this, IronGolem.class, true));
    }

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide) return;
        // A volley of Dismantle: invisible slashes fired dozens at a time.
        if (volley > 0 && --volleyDelay <= 0) {
            LivingEntity target = getTarget();
            if (target != null && data.getCasting() == null && data.consume(15f)) {
                getLookControl().setLookAt(target, 60f, 60f);
                Shrine.dismantle(this, data);
            }
            volley--;
            volleyDelay = 3;
        }
    }

    @Override
    public void combatTick(LivingEntity target, double distSqr) {
        float hp = healthRatio();
        boolean strong = target.getMaxHealth() >= 100 || target instanceof Player;
        boolean seen = getSensing().hasLineOfSight(target);

        if (hp < 0.5f && !data.isRctActive() && data.getCursedEnergy() > 600) data.setRctActive(true);
        if (hp < 0.5f && !praised && target.getMaxHealth() >= 40) {
            praised = true;
            say("line.jujutsukaisen.sukuna.praise");
        }
        if (hp < 0.35f && !summonedMahoraga) {
            summonedMahoraga = true;
            summonMahoraga(target);
            return;
        }

        double shrineRange = Math.max(6, com.jujutsukaisen.domain.DomainType.MALEVOLENT_SHRINE.radius() - 4);
        if (DomainManager.find(this) == null && distSqr < shrineRange * shrineRange && (strong || hp < 0.6f)
                && ready(Ability.DOMAIN_MALEVOLENT_SHRINE) && random.nextInt(30) == 0) {
            use(Ability.DOMAIN_MALEVOLENT_SHRINE);
            return;
        }
        if (seen && hp < 0.6f && ready(Ability.WORLD_SLASH) && (SorcererLogic.hasInfinity(target) || strong) && random.nextInt(40) == 0) {
            use(Ability.WORLD_SLASH);
            return;
        }
        if (seen && distSqr > 4 * 4 && distSqr < 34 * 34 && ready(Ability.FUGA) && Shrine.canUseFuga(this, data) && random.nextInt(12) == 0) {
            use(Ability.FUGA);
            return;
        }
        if (distSqr < 4.2 * 4.2 && ready(Ability.CLEAVE) && random.nextInt(8) == 0) {
            use(Ability.CLEAVE);
            return;
        }
        if (seen && distSqr > 3.5 * 3.5 && volley <= 0 && ready(Ability.DISMANTLE) && random.nextInt(7) == 0) {
            if (use(Ability.DISMANTLE)) {
                volley = 2 + random.nextInt(4);
                volleyDelay = 3;
            }
        }
    }

    /** 「후루베 유라유라 — 팔악검 이계신장 마허라」 */
    private void summonMahoraga(LivingEntity target) {
        if (!(level() instanceof ServerLevel server)) return;
        MahoragaEntity mahoraga = ModEntities.MAHORAGA.get().create(server);
        if (mahoraga == null) return;
        Vec3 pos = position().add(Vec3.directionFromRotation(0, getYRot()).scale(-2.5));
        mahoraga.moveTo(pos.x, pos.y, pos.z, getYRot(), 0);
        mahoraga.finalizeSpawn(server, server.getCurrentDifficultyAt(blockPosition()), MobSpawnType.MOB_SUMMONED, null, null);
        mahoraga.setOwner(this, -1);
        mahoraga.setTarget(target);
        // Sukuna already carries the adaptations his wheel bore for him.
        SorcererData mine = JJK.get(this);
        if (mine != null) mine.adaptationView().forEach(mahoraga.getSorcererData()::setAdaptation);
        server.addFreshEntity(mahoraga);
        say("line.jujutsukaisen.summon_mahoraga");
        Fx.burst(server, ParticleTypes.SQUID_INK, pos.add(0, 0.2, 0), 120, 1.5, 0.05);
        Fx.burst(server, Fx.BLACK, pos.add(0, 1.5, 0), 80, 1.0, 0.0);
        Fx.sound(server, pos, SoundEvents.WARDEN_EMERGE, 2.5f, 0.8f);
    }
}

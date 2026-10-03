package com.jujutsukaisen.entity;

import com.jujutsukaisen.entity.ai.SorcererCombatGoal;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.AbilityHandler;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.SorcererHolder;
import com.jujutsukaisen.sorcery.SorcererLogic;
import com.jujutsukaisen.sorcery.Technique;
import com.jujutsukaisen.util.Fx;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerBossEvent;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.BossEvent;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.LookAtPlayerGoal;
import net.minecraft.world.entity.ai.goal.RandomLookAroundGoal;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

/**
 * Base class of the sorcerer characters (Gojo, Sukuna, Hakari): cursed energy, technique AI with
 * wind-ups and poses, a boss bar, and spoken lines.
 */
public abstract class SorcererEntity extends PathfinderMob implements SorcererHolder {
    private static final EntityDataAccessor<Byte> CAST_POSE = SynchedEntityData.defineId(SorcererEntity.class, EntityDataSerializers.BYTE);
    private static final EntityDataAccessor<Byte> FLAGS = SynchedEntityData.defineId(SorcererEntity.class, EntityDataSerializers.BYTE);
    public static final int FLAG_INFINITY = 1, FLAG_RCT = 2, FLAG_JACKPOT = 4, FLAG_BURNOUT = 8, FLAG_CASTING = 16;

    protected final SorcererData data = new SorcererData();
    private final ServerBossEvent bossEvent;
    private int meleeCooldown;
    @Nullable
    private LivingEntity lastTarget;

    protected SorcererEntity(EntityType<? extends SorcererEntity> type, Level level) {
        super(type, level);
        data.setTechnique(technique());
        data.setFixedMax(maxEnergy());
        this.bossEvent = new ServerBossEvent(getDisplayName(), barColor(), BossEvent.BossBarOverlay.NOTCHED_10);
        this.xpReward = 250;
        setPersistenceRequired();
    }

    // ───────────────────────────── character definition ──────────────────

    public abstract Technique technique();

    protected abstract float maxEnergy();

    protected abstract BossEvent.BossBarColor barColor();

    /** Decide what to cast this tick. Called by the combat goal while the target is valid. */
    public abstract void combatTick(LivingEntity target, double distanceSqr);

    /** Line spoken the first time a new opponent is engaged (translation key) or null. */
    @Nullable
    protected String engageLine() {
        return null;
    }

    public float costMultiplier() {
        return 1f;
    }

    public float cooldownMultiplier() {
        return 1f;
    }

    public float domainDurationMultiplier() {
        return 1f;
    }

    public float domainMastery() {
        return 1f;
    }

    public int burnoutTicks() {
        return 100;
    }

    public float blackFlashAffinity() {
        return 1.5f;
    }

    public double preferredRange() {
        return 2.2;
    }

    public double chaseSpeed() {
        return 1.15;
    }

    public int meleeInterval() {
        return 14;
    }

    public boolean isFriendlyWith(SorcererEntity other) {
        return false;
    }

    // ───────────────────────────── state ─────────────────────────────────

    @Override
    public SorcererData getSorcererData() {
        return data;
    }

    public Ability.CastPose getCastPose() {
        return Ability.CastPose.byOrdinal(entityData.get(CAST_POSE));
    }

    public boolean hasFlag(int flag) {
        return (entityData.get(FLAGS) & flag) != 0;
    }

    protected boolean use(Ability ability) {
        return AbilityHandler.tryUse(this, data, ability);
    }

    protected boolean ready(Ability ability) {
        return data.getCooldown(ability) <= 0 && data.getCasting() == null && !data.isBurntOut()
                && data.getCursedEnergy() >= AbilityHandler.costOf(this, data, ability);
    }

    public boolean meleeReady() {
        return meleeCooldown <= 0 && data.getCasting() == null;
    }

    public void resetMelee() {
        meleeCooldown = meleeInterval();
    }

    protected float healthRatio() {
        return getHealth() / getMaxHealth();
    }

    protected void say(String key) {
        Fx.say(this, key, 40);
    }

    // ───────────────────────────── lifecycle ─────────────────────────────

    @Override
    protected void defineSynchedData() {
        super.defineSynchedData();
        entityData.define(CAST_POSE, (byte) 0);
        entityData.define(FLAGS, (byte) 0);
    }

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(0, new FloatGoal(this));
        goalSelector.addGoal(2, new SorcererCombatGoal(this));
        goalSelector.addGoal(6, new WaterAvoidingRandomStrollGoal(this, 0.8));
        goalSelector.addGoal(7, new LookAtPlayerGoal(this, Player.class, 12f));
        goalSelector.addGoal(8, new RandomLookAroundGoal(this));
        registerTargets();
    }

    protected abstract void registerTargets();

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide) return;
        if (meleeCooldown > 0) meleeCooldown--;
        SorcererLogic.tick(this, data);
        entityData.set(CAST_POSE, (byte) data.currentPose().ordinal());
        int flags = 0;
        if (SorcererLogic.hasInfinity(this)) flags |= FLAG_INFINITY;
        if (data.isRctActive() || data.isJackpot()) flags |= FLAG_RCT;
        if (data.isJackpot()) flags |= FLAG_JACKPOT;
        if (data.isBurntOut()) flags |= FLAG_BURNOUT;
        if (data.getCasting() != null) flags |= FLAG_CASTING;
        entityData.set(FLAGS, (byte) flags);
        bossEvent.setProgress(getHealth() / getMaxHealth());

        LivingEntity target = getTarget();
        if (target != null && target != lastTarget && target.isAlive()) {
            String line = engageLine();
            if (line != null && (target instanceof Player || target.getMaxHealth() >= 100)) say(line);
        }
        lastTarget = target;

        if (data.isRctActive() && healthRatio() > 0.9f && !data.isBurntOut()) data.setRctActive(false);
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return false;
    }

    @Override
    public void startSeenByPlayer(ServerPlayer player) {
        super.startSeenByPlayer(player);
        bossEvent.addPlayer(player);
    }

    @Override
    public void stopSeenByPlayer(ServerPlayer player) {
        super.stopSeenByPlayer(player);
        bossEvent.removePlayer(player);
    }

    @Override
    public void setCustomName(@Nullable Component name) {
        super.setCustomName(name);
        bossEvent.setName(getDisplayName());
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.put("Sorcerer", data.save());
        tag.putInt("XpReward", xpReward);
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        boolean saved = tag.contains("Sorcerer");
        if (saved) data.load(tag.getCompound("Sorcerer"));
        float energy = data.getCursedEnergy();
        data.setTechnique(technique());
        data.setFixedMax(maxEnergy());
        if (saved) data.setCursedEnergy(Math.min(energy, data.getMaxCursedEnergy())); // a drained Gojo stays drained
        if (tag.contains("XpReward")) xpReward = tag.getInt("XpReward");
        if (hasCustomName()) bossEvent.setName(getDisplayName());
    }

    /** XP dropped on death: a cheaply summoned sorcerer is worth less (saved, since xpReward itself is not). */
    public void setXpReward(int xp) {
        this.xpReward = xp;
    }
}

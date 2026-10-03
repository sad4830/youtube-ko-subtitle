package com.jujutsukaisen.entity;

import com.jujutsukaisen.config.JJKConfig;
import com.jujutsukaisen.entity.ai.MahoragaAttackGoal;
import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModTags;
import com.jujutsukaisen.sorcery.Adaptation;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.SorcererHolder;
import com.jujutsukaisen.sorcery.SorcererLogic;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.NbtUtils;
import net.minecraft.nbt.Tag;
import net.minecraft.network.chat.Component;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerBossEvent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.BossEvent;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.MobType;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.LookAtPlayerGoal;
import net.minecraft.world.entity.ai.goal.RandomLookAroundGoal;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * 팔악검 이계신장 마허라 — Eight-Handled Sword Divergent Sila Divine General Mahoraga, the strongest
 * shikigami of the Ten Shadows. It adapts to every phenomenon by turning the wheel above its head,
 * and the Sword of Extermination on its right arm carries positive energy.
 * <p>
 * Three ways to meet it: the taming ritual (조복의 의식), as a tamed shikigami, or untamed (spawn egg).
 */
public class MahoragaEntity extends PathfinderMob implements SorcererHolder {
    private static final EntityDataAccessor<Integer> WHEEL_TURNS = SynchedEntityData.defineId(MahoragaEntity.class, EntityDataSerializers.INT);
    private static final EntityDataAccessor<Byte> ATTACK_ANIM = SynchedEntityData.defineId(MahoragaEntity.class, EntityDataSerializers.BYTE);
    private static final EntityDataAccessor<Boolean> SWORD_ATTACK = SynchedEntityData.defineId(MahoragaEntity.class, EntityDataSerializers.BOOLEAN);
    public static final int ATTACK_ANIM_TICKS = 12;

    private final SorcererData data = new SorcererData();
    private final ServerBossEvent bossEvent = new ServerBossEvent(Component.translatable("entity.jujutsukaisen.mahoraga"),
            BossEvent.BossBarColor.WHITE, BossEvent.BossBarOverlay.NOTCHED_20);

    @Nullable
    private UUID ownerId;
    private int lifetime = -1;
    private boolean ritual;
    @Nullable
    private UUID summonerId;
    private final Set<UUID> participants = new HashSet<>();
    private boolean outsideHelp;
    private int lonelyTicks;
    private int attackSwing;
    private float wheelAngle;
    private float wheelAngleO;

    public MahoragaEntity(EntityType<? extends MahoragaEntity> type, Level level) {
        super(type, level);
        data.setFixedMax(1000f);
        setMaxUpStep(1.5f);
        this.xpReward = 400;
        setPersistenceRequired();
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Mob.createMobAttributes()
                .add(Attributes.MAX_HEALTH, 450.0)
                .add(Attributes.ATTACK_DAMAGE, 20.0)
                .add(Attributes.ATTACK_KNOCKBACK, 1.6)
                .add(Attributes.MOVEMENT_SPEED, 0.33)
                .add(Attributes.FOLLOW_RANGE, 48.0)
                .add(Attributes.ARMOR, 12.0)
                .add(Attributes.ARMOR_TOUGHNESS, 8.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0);
    }

    // ───────────────────────────── ownership & ritual ────────────────────

    @Override
    public SorcererData getSorcererData() {
        return data;
    }

    @Nullable
    public UUID getOwnerUUID() {
        return ownerId;
    }

    public boolean isOwnedBy(@Nullable Entity entity) {
        return entity != null && ownerId != null && ownerId.equals(entity.getUUID());
    }

    @Nullable
    public LivingEntity getOwner() {
        if (ownerId == null || !(level() instanceof ServerLevel server)) return null;
        return server.getEntity(ownerId) instanceof LivingEntity living ? living : null;
    }

    /** A tamed Mahoraga answering its summoner; lifetime in ticks, or -1 for unlimited. */
    public void setOwner(LivingEntity owner, int lifetime) {
        this.ownerId = owner.getUUID();
        this.lifetime = lifetime;
        this.ritual = false;
    }

    /** 조복의 의식: everyone nearby is dragged into the ritual; Mahoraga attacks them all. */
    public void startRitual(ServerPlayer summoner) {
        this.ritual = true;
        this.summonerId = summonerId == null ? summoner.getUUID() : summonerId;
        participants.add(summoner.getUUID());
        for (Player player : level().getEntitiesOfClass(Player.class, getBoundingBox().inflate(24), p -> !p.isSpectator() && !p.isCreative())) {
            participants.add(player.getUUID());
        }
        setTarget(summoner);
    }

    public boolean isRitual() {
        return ritual;
    }

    public boolean isParticipant(Entity entity) {
        return participants.contains(entity.getUUID());
    }

    // ───────────────────────────── synced visuals ────────────────────────

    public int getWheelTurns() {
        return entityData.get(WHEEL_TURNS);
    }

    public int getAttackAnim() {
        return entityData.get(ATTACK_ANIM);
    }

    public boolean isSwordAttack() {
        return entityData.get(SWORD_ATTACK);
    }

    @Override
    protected void defineSynchedData() {
        super.defineSynchedData();
        entityData.define(WHEEL_TURNS, 0);
        entityData.define(ATTACK_ANIM, (byte) 0);
        entityData.define(SWORD_ATTACK, false);
    }

    // ───────────────────────────── AI ────────────────────────────────────

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(0, new FloatGoal(this));
        goalSelector.addGoal(2, new MahoragaAttackGoal(this));
        goalSelector.addGoal(6, new WaterAvoidingRandomStrollGoal(this, 0.7));
        goalSelector.addGoal(7, new LookAtPlayerGoal(this, Player.class, 16f));
        goalSelector.addGoal(8, new RandomLookAroundGoal(this));

        targetSelector.addGoal(1, new HurtByTargetGoal(this) {
            @Override
            public boolean canUse() {
                return super.canUse() && !isOwnedBy(getLastHurtByMob());
            }
        });
        targetSelector.addGoal(2, new NearestAttackableTargetGoal<>(this, Player.class, 10, false, false,
                p -> ownerId == null && (!ritual || participants.contains(p.getUUID()))));
        targetSelector.addGoal(3, new NearestAttackableTargetGoal<>(this, Mob.class, 10, false, false,
                m -> ownerId != null && m instanceof Mob mob && isOwnedBy(mob.getTarget())));
    }

    /** Client: the wheel turns 45° per adaptation step, easing into place. */
    public float wheelAngle(float partialTick) {
        return Mth.lerp(partialTick, wheelAngleO, wheelAngle);
    }

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide) {
            wheelAngleO = wheelAngle;
            float target = getWheelTurns() * 45f;
            wheelAngle += (target - wheelAngle) * 0.18f;
            return;
        }
        SorcererLogic.tick(this, data);
        if (entityData.get(WHEEL_TURNS) != data.getWheelTurns()) entityData.set(WHEEL_TURNS, data.getWheelTurns());
        if (attackSwing > 0 && --attackSwing == 0) entityData.set(ATTACK_ANIM, (byte) 0);
        else if (attackSwing > 0) entityData.set(ATTACK_ANIM, (byte) attackSwing);
        bossEvent.setProgress(getHealth() / getMaxHealth());

        if (ownerId != null) tickTamed();
        if (ritual) tickRitual();
        if (data.isRctActive()) data.setRctActive(false);
    }

    private void tickTamed() {
        LivingEntity owner = getOwner();
        if (owner == null || !owner.isAlive()) {
            if (++lonelyTicks > 100) dissolve();
            return;
        }
        lonelyTicks = 0;
        if (lifetime > 0 && --lifetime == 0) {
            dissolve();
            return;
        }
        LivingEntity ownerTarget = owner instanceof Mob mob ? mob.getTarget() : owner.getLastHurtMob();
        if (owner.getLastHurtByMob() != null && owner.getLastHurtByMob().isAlive() && !isOwnedBy(owner.getLastHurtByMob())) {
            ownerTarget = owner.getLastHurtByMob();
        }
        if (ownerTarget != null && ownerTarget.isAlive() && ownerTarget != this && getTarget() != ownerTarget && JJK.canHit(this, ownerTarget)) {
            setTarget(ownerTarget);
        }
        if (getTarget() == null && distanceToSqr(owner) > 10 * 10) {
            getNavigation().moveTo(owner, 1.1);
            if (distanceToSqr(owner) > 40 * 40) teleportTo(owner.getX(), owner.getY(), owner.getZ());
        }
    }

    private void tickRitual() {
        if (!(level() instanceof ServerLevel server)) return;
        boolean anyone = false;
        for (UUID id : participants) {
            Entity e = server.getEntity(id);
            if (e instanceof Player p && p.isAlive() && p.distanceToSqr(this) < 64 * 64) {
                anyone = true;
                break;
            }
        }
        if (anyone) {
            lonelyTicks = 0;
        } else if (++lonelyTicks > 200) {
            broadcast(Component.translatable("message.jujutsukaisen.ritual_over").withStyle(ChatFormatting.GRAY));
            dissolve();
        }
    }

    /** Returns into the shadows. */
    private void dissolve() {
        Fx.burst(level(), ParticleTypes.SQUID_INK, position().add(0, 1, 0), 80, 1.0, 0.05);
        Fx.sound(this, SoundEvents.WARDEN_DIG, 2.0f, 0.8f);
        discard();
    }

    private void broadcast(Component message) {
        if (!(level() instanceof ServerLevel server)) return;
        for (ServerPlayer player : server.players()) {
            if (player.distanceToSqr(this) < 80 * 80) player.sendSystemMessage(message);
        }
    }

    // ───────────────────────────── combat ────────────────────────────────

    /** Attack animation: a punch, or a slash of the Sword of Extermination. */
    public void startAttack(boolean sword) {
        attackSwing = ATTACK_ANIM_TICKS;
        entityData.set(SWORD_ATTACK, sword);
        entityData.set(ATTACK_ANIM, (byte) ATTACK_ANIM_TICKS);
        swing(InteractionHand.MAIN_HAND);
    }

    /** Sword of Extermination: a wide slash in front, strongest against curses. */
    public void swordSweep(LivingEntity primary) {
        Vec3 forward = Vec3.directionFromRotation(0, getYRot());
        float base = (float) getAttributeValue(Attributes.ATTACK_DAMAGE) * 0.85f;
        for (LivingEntity victim : level().getEntitiesOfClass(LivingEntity.class, getBoundingBox().inflate(4.5, 1.0, 4.5),
                e -> e != this && JJK.canHit(this, e))) {
            Vec3 to = victim.position().subtract(position());
            if (to.horizontalDistance() > 5.0 || (victim != primary && to.normalize().dot(forward) < 0.2)) continue;
            victim.hurt(ModDamageTypes.source(level(), ModDamageTypes.EXTERMINATION, this), base * exterminationBonus(victim));
            victim.knockback(0.8, -forward.x, -forward.z);
        }
        Vec3 c = position().add(forward.scale(2.2)).add(0, 1.6, 0);
        Fx.burst(level(), ParticleTypes.SWEEP_ATTACK, c, 4, 1.2, 0.0);
        Fx.burst(level(), ParticleTypes.END_ROD, c, 20, 1.2, 0.05);
        Fx.sound(this, SoundEvents.PLAYER_ATTACK_SWEEP, 2.0f, 0.5f);
    }

    /** Positive energy exorcises cursed spirits (and wrecks the undead). */
    public static float exterminationBonus(LivingEntity victim) {
        if (victim.getType().is(ModTags.CURSED_SPIRITS)) return 3.0f;
        if (victim.getMobType() == MobType.UNDEAD) return 2.0f;
        return 1.0f;
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (!level().isClientSide && source.getEntity() instanceof Player player && ritual && !participants.contains(player.getUUID())) {
            participants.add(player.getUUID());
            outsideHelp = true;
        }
        if (!level().isClientSide && ritual && source.getEntity() instanceof LivingEntity attacker && !(attacker instanceof Player)) {
            outsideHelp = true;
        }
        if (!level().isClientSide && amount > 0 && !source.is(net.minecraft.tags.DamageTypeTags.BYPASSES_INVULNERABILITY)) {
            amount = Adaptation.onHurt(this, data, source, amount);
            if (amount <= 0.01f) {
                Fx.sound(this, SoundEvents.ANVIL_PLACE, 0.8f, 1.6f);
                return false;
            }
        }
        if (isOwnedBy(source.getEntity())) return false;
        return super.hurt(source, amount);
    }

    /** The wheel turned: adaptation advanced one step. */
    public void onWheelTurn(String key, int level) {
        if (!(this.level() instanceof ServerLevel)) return;
        Component phenomenon = Component.translatable("adaptation.jujutsukaisen." + key);
        Component message = Component.translatable("message.jujutsukaisen.mahoraga_adapt", phenomenon, Math.min(level, Adaptation.MAX), Adaptation.MAX)
                .withStyle(ChatFormatting.GOLD);
        if (Adaptation.INFINITY.equals(key) && level == Adaptation.MAX) {
            message = Component.translatable("message.jujutsukaisen.mahoraga_infinity").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD);
        } else if (Adaptation.INFINITY.equals(key) && level >= Adaptation.SPACE_CUT) {
            message = Component.translatable("message.jujutsukaisen.mahoraga_space").withStyle(ChatFormatting.DARK_RED, ChatFormatting.BOLD);
        }
        for (ServerPlayer player : ((ServerLevel) this.level()).players()) {
            if (player.distanceToSqr(this) < 48 * 48) player.displayClientMessage(message, true);
        }
    }

    @Override
    public void die(DamageSource source) {
        if (!level().isClientSide) {
            if (ritual) resolveRitual(source);
            if (ownerId != null && getOwner() instanceof ServerPlayer owner && JJKConfig.TAMED_MAHORAGA_LOST_ON_DEATH.get()) {
                SorcererData ownerData = JJK.get(owner);
                if (ownerData != null) ownerData.setMahoragaTamed(false);
                owner.sendSystemMessage(Component.translatable("message.jujutsukaisen.mahoraga_lost").withStyle(ChatFormatting.DARK_RED));
            }
        }
        super.die(source);
    }

    /** A win achieved with outside help, or by an outsider, voids the taming. */
    private void resolveRitual(DamageSource source) {
        Entity killer = source.getEntity();
        boolean byOwnHand = summonerId != null && killer != null && summonerId.equals(killer.getUUID());
        boolean alone = participants.size() <= 1 && !outsideHelp;
        if (byOwnHand && alone && killer instanceof ServerPlayer summoner) {
            SorcererData sd = JJK.get(summoner);
            if (sd != null) sd.setMahoragaTamed(true);
            summoner.sendSystemMessage(Component.translatable("message.jujutsukaisen.ritual_tamed").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD));
            Advancements.award(summoner, "tame_mahoraga");
        } else {
            broadcast(Component.translatable("message.jujutsukaisen.ritual_void").withStyle(ChatFormatting.GRAY));
        }
        ritual = false;
    }

    @Override
    protected boolean shouldDropLoot() {
        return ownerId == null;
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return false;
    }

    @Override
    public void startSeenByPlayer(ServerPlayer player) {
        super.startSeenByPlayer(player);
        if (ownerId == null) bossEvent.addPlayer(player);
    }

    @Override
    public void stopSeenByPlayer(ServerPlayer player) {
        super.stopSeenByPlayer(player);
        bossEvent.removePlayer(player);
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.put("Sorcerer", data.save());
        if (ownerId != null) tag.putUUID("Owner", ownerId);
        tag.putInt("Lifetime", lifetime);
        tag.putBoolean("Ritual", ritual);
        tag.putBoolean("OutsideHelp", outsideHelp);
        if (summonerId != null) tag.putUUID("Summoner", summonerId);
        ListTag list = new ListTag();
        participants.forEach(id -> list.add(NbtUtils.createUUID(id)));
        tag.put("Participants", list);
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        if (tag.contains("Sorcerer")) data.load(tag.getCompound("Sorcerer"));
        data.setFixedMax(1000f);
        ownerId = tag.hasUUID("Owner") ? tag.getUUID("Owner") : null;
        lifetime = tag.getInt("Lifetime");
        ritual = tag.getBoolean("Ritual");
        outsideHelp = tag.getBoolean("OutsideHelp");
        summonerId = tag.hasUUID("Summoner") ? tag.getUUID("Summoner") : null;
        participants.clear();
        for (Tag t : tag.getList("Participants", Tag.TAG_INT_ARRAY)) participants.add(NbtUtils.loadUUID(t));
        entityData.set(WHEEL_TURNS, data.getWheelTurns());
    }
}

package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.domain.Indicator;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.IntArrayTag;
import net.minecraft.nbt.Tag;
import net.minecraft.util.Mth;
import org.jetbrains.annotations.Nullable;

import java.util.HashMap;
import java.util.Map;

/**
 * All jujutsu state of one living being: cursed energy (주력), innate technique, cooldowns,
 * Reverse Cursed Technique, technique burnout, Hakari's jackpot, and Mahoraga-style adaptation.
 * <p>
 * Players carry this as a capability; the character entities own an instance directly.
 */
public class SorcererData {
    public static final int MAX_FINGERS = 20;
    /** Jackpot lasts exactly as long as the song in the domain: 4 minutes 11 seconds. */
    public static final int JACKPOT_TICKS = (4 * 60 + 11) * 20;

    private Technique technique = Technique.NONE;
    private float cursedEnergy = 100f;
    private float maxCursedEnergy = 100f;
    private boolean fixedMax;
    private int fingers;
    private int selected;
    private final int[] cooldowns = new int[Ability.values().length];

    private boolean infinity = true;
    private boolean rct;
    private int burnout;
    private int jackpot;
    private int jackpotCount;
    private boolean probabilityUp;
    private int zone;
    private boolean mahoragaTamed;

    @Nullable
    private Ability casting;
    private int castTicks;
    private int castTotal;

    private long lastDismantleHit = -10000;
    private long lastCleaveHit = -10000;
    private long lastShrineDomain = -10000;
    private int pseudoStreak;
    private Indicator lastIndicator = Indicator.GREEN;

    private final Map<String, Integer> adaptation = new HashMap<>();
    private final Map<String, Float> adaptDamage = new HashMap<>();
    private String pendingAdapt = "";
    private int adaptTimer;
    private int wheelTurns;

    /** Health snapshots for Hakari's pseudo-consecutive (유사연속): one every 10 ticks, newest last. */
    private final float[] healthHistory = new float[8];
    private int healthHistoryFill;

    private boolean dirty = true;

    // ───────────────────────────── technique ─────────────────────────────

    public Technique getTechnique() {
        return technique;
    }

    public void setTechnique(Technique technique) {
        this.technique = technique;
        this.selected = 0;
        this.casting = null;
        recalcMax();
        this.cursedEnergy = Math.min(cursedEnergy, maxCursedEnergy);
        markDirty();
    }

    public void recalcMax() {
        if (fixedMax) return;
        float bonus = technique == Technique.SHRINE ? 60f : 40f;
        this.maxCursedEnergy = technique.baseMaxEnergy() + fingers * bonus;
    }

    public void setFixedMax(float max) {
        this.fixedMax = true;
        this.maxCursedEnergy = max;
        this.cursedEnergy = max;
        markDirty();
    }

    // ───────────────────────────── cursed energy ─────────────────────────

    public float getCursedEnergy() {
        return cursedEnergy;
    }

    public float getMaxCursedEnergy() {
        return maxCursedEnergy;
    }

    public void setCursedEnergy(float value) {
        float clamped = Mth.clamp(value, 0f, maxCursedEnergy);
        if (clamped != cursedEnergy) {
            cursedEnergy = clamped;
            markDirty();
        }
    }

    public void addCursedEnergy(float delta) {
        setCursedEnergy(cursedEnergy + delta);
    }

    /** Spends energy if available. During a jackpot cursed energy is unlimited. */
    public boolean consume(float amount) {
        if (isJackpot()) return true;
        if (cursedEnergy < amount) return false;
        setCursedEnergy(cursedEnergy - amount);
        return true;
    }

    public float energyRatio() {
        return maxCursedEnergy <= 0 ? 0 : cursedEnergy / maxCursedEnergy;
    }

    // ───────────────────────────── fingers ───────────────────────────────

    public int getFingers() {
        return fingers;
    }

    public void setFingers(int fingers) {
        this.fingers = Mth.clamp(fingers, 0, MAX_FINGERS);
        recalcMax();
        markDirty();
    }

    // ───────────────────────────── selection / cooldown ──────────────────

    public int getSelected() {
        return selected;
    }

    @Nullable
    public Ability getSelectedAbility() {
        var list = technique.abilities();
        if (list.isEmpty()) return null;
        return list.get(Mth.clamp(selected, 0, list.size() - 1));
    }

    public void cycle(int dir) {
        var list = technique.abilities();
        if (list.isEmpty()) return;
        selected = Math.floorMod(selected + dir, list.size());
        markDirty();
    }

    public int getCooldown(Ability ability) {
        return cooldowns[ability.ordinal()];
    }

    public void setCooldown(Ability ability, int ticks) {
        cooldowns[ability.ordinal()] = Math.max(0, ticks);
        markDirty();
    }

    public void tickCooldowns() {
        boolean any = false;
        for (int i = 0; i < cooldowns.length; i++) {
            if (cooldowns[i] > 0) {
                cooldowns[i]--;
                any = true;
            }
        }
        if (any && cooldownSyncPulse++ % 10 == 0) markDirty();
    }

    private int cooldownSyncPulse;

    // ───────────────────────────── states ────────────────────────────────

    public boolean isInfinityEnabled() {
        return infinity;
    }

    public void setInfinityEnabled(boolean infinity) {
        this.infinity = infinity;
        markDirty();
    }

    public boolean isRctActive() {
        return rct;
    }

    public void setRctActive(boolean rct) {
        if (this.rct != rct) {
            this.rct = rct;
            markDirty();
        }
    }

    public int getBurnout() {
        return burnout;
    }

    public void setBurnout(int burnout) {
        this.burnout = Math.max(0, burnout);
        markDirty();
    }

    public boolean isBurntOut() {
        return burnout > 0;
    }

    public int getJackpot() {
        return jackpot;
    }

    public void setJackpot(int jackpot) {
        this.jackpot = Math.max(0, jackpot);
        markDirty();
    }

    public boolean isJackpot() {
        return jackpot > 0;
    }

    public int getJackpotCount() {
        return jackpotCount;
    }

    public void setJackpotCount(int jackpotCount) {
        this.jackpotCount = jackpotCount;
    }

    /** 확변 — after an odd-numbered jackpot the next expansion starts with increased probability. */
    public boolean isProbabilityUp() {
        return probabilityUp;
    }

    public void setProbabilityUp(boolean probabilityUp) {
        this.probabilityUp = probabilityUp;
        markDirty();
    }

    public int getZone() {
        return zone;
    }

    public void setZone(int zone) {
        this.zone = Math.max(0, zone);
        markDirty();
    }

    public boolean isMahoragaTamed() {
        return mahoragaTamed;
    }

    public void setMahoragaTamed(boolean tamed) {
        this.mahoragaTamed = tamed;
        markDirty();
    }

    // ───────────────────────────── casting ───────────────────────────────

    @Nullable
    public Ability getCasting() {
        return casting;
    }

    public int getCastTicks() {
        return castTicks;
    }

    public int getCastTotal() {
        return castTotal;
    }

    public void startCast(Ability ability, int ticks) {
        this.casting = ability;
        this.castTicks = ticks;
        this.castTotal = ticks;
        markDirty();
    }

    public void setCastTicks(int ticks) {
        this.castTicks = ticks;
    }

    public void clearCast() {
        if (casting != null) {
            casting = null;
            castTicks = 0;
            castTotal = 0;
            markDirty();
        }
    }

    public Ability.CastPose currentPose() {
        return casting == null ? Ability.CastPose.NONE : casting.pose();
    }

    // ───────────────────────────── shrine bookkeeping ────────────────────

    public long getLastDismantleHit() {
        return lastDismantleHit;
    }

    public void setLastDismantleHit(long time) {
        this.lastDismantleHit = time;
    }

    public long getLastCleaveHit() {
        return lastCleaveHit;
    }

    public void setLastCleaveHit(long time) {
        this.lastCleaveHit = time;
    }

    public long getLastShrineDomain() {
        return lastShrineDomain;
    }

    public void setLastShrineDomain(long time) {
        this.lastShrineDomain = time;
    }

    public int getPseudoStreak() {
        return pseudoStreak;
    }

    public void setPseudoStreak(int pseudoStreak) {
        this.pseudoStreak = pseudoStreak;
    }

    public Indicator getLastIndicator() {
        return lastIndicator;
    }

    public void setLastIndicator(Indicator lastIndicator) {
        this.lastIndicator = lastIndicator;
    }

    // ───────────────────────────── adaptation (Mahoraga / Dharma wheel) ──

    public int getAdaptation(String key) {
        return adaptation.getOrDefault(key, 0);
    }

    public void setAdaptation(String key, int level) {
        adaptation.put(key, level);
        markDirty();
    }

    public Map<String, Integer> adaptationView() {
        return adaptation;
    }

    public void clearAdaptation() {
        adaptation.clear();
        adaptDamage.clear();
        pendingAdapt = "";
        adaptTimer = 0;
        markDirty();
    }

    public String getPendingAdapt() {
        return pendingAdapt;
    }

    public void setPendingAdapt(String key, int timer) {
        this.pendingAdapt = key;
        this.adaptTimer = timer;
    }

    public int getAdaptTimer() {
        return adaptTimer;
    }

    public void setAdaptTimer(int adaptTimer) {
        this.adaptTimer = adaptTimer;
    }

    public void addAdaptDamage(String key, float amount) {
        adaptDamage.merge(key, amount, Float::sum);
    }

    public float takeAdaptDamage(String key) {
        Float v = adaptDamage.remove(key);
        return v == null ? 0f : v;
    }

    public int getWheelTurns() {
        return wheelTurns;
    }

    public void setWheelTurns(int wheelTurns) {
        this.wheelTurns = wheelTurns;
        markDirty();
    }

    // ───────────────────────────── health history ────────────────────────

    public void recordHealth(float health) {
        System.arraycopy(healthHistory, 1, healthHistory, 0, healthHistory.length - 1);
        healthHistory[healthHistory.length - 1] = health;
        healthHistoryFill = Math.min(healthHistory.length, healthHistoryFill + 1);
    }

    /** Highest health recorded during the last ~4 seconds. */
    public float bestRecentHealth() {
        float best = 0;
        int start = healthHistory.length - healthHistoryFill;
        for (int i = start; i < healthHistory.length; i++) best = Math.max(best, healthHistory[i]);
        return best;
    }

    // ───────────────────────────── sync / persistence ────────────────────

    public boolean isDirty() {
        return dirty;
    }

    public void markDirty() {
        this.dirty = true;
    }

    public void clearDirty() {
        this.dirty = false;
    }

    public CompoundTag save() {
        CompoundTag tag = new CompoundTag();
        tag.putString("Technique", technique.id());
        tag.putFloat("CursedEnergy", cursedEnergy);
        if (fixedMax) tag.putFloat("FixedMax", maxCursedEnergy);
        tag.putInt("Fingers", fingers);
        tag.putInt("Selected", selected);
        tag.putBoolean("Infinity", infinity);
        tag.putInt("Burnout", burnout);
        tag.putInt("Jackpot", jackpot);
        tag.putInt("JackpotCount", jackpotCount);
        tag.putBoolean("ProbabilityUp", probabilityUp);
        tag.putBoolean("MahoragaTamed", mahoragaTamed);
        tag.putInt("WheelTurns", wheelTurns);
        tag.put("Cooldowns", new IntArrayTag(cooldowns.clone()));
        CompoundTag adapt = new CompoundTag();
        adaptation.forEach(adapt::putInt);
        tag.put("Adaptation", adapt);
        return tag;
    }

    public void load(CompoundTag tag) {
        technique = Technique.byId(tag.getString("Technique"));
        fingers = tag.getInt("Fingers");
        if (tag.contains("FixedMax", Tag.TAG_FLOAT)) {
            fixedMax = true;
            maxCursedEnergy = tag.getFloat("FixedMax");
        } else {
            recalcMax();
        }
        cursedEnergy = Math.min(tag.getFloat("CursedEnergy"), maxCursedEnergy);
        selected = tag.getInt("Selected");
        infinity = !tag.contains("Infinity") || tag.getBoolean("Infinity");
        burnout = tag.getInt("Burnout");
        jackpot = tag.getInt("Jackpot");
        jackpotCount = tag.getInt("JackpotCount");
        probabilityUp = tag.getBoolean("ProbabilityUp");
        mahoragaTamed = tag.getBoolean("MahoragaTamed");
        wheelTurns = tag.getInt("WheelTurns");
        int[] saved = tag.getIntArray("Cooldowns");
        for (int i = 0; i < Math.min(saved.length, cooldowns.length); i++) cooldowns[i] = saved[i];
        adaptation.clear();
        CompoundTag adapt = tag.getCompound("Adaptation");
        for (String key : adapt.getAllKeys()) adaptation.put(key, adapt.getInt(key));
        markDirty();
    }

    /** Compact state sent to clients (HUD and rendering). */
    public CompoundTag saveSync() {
        CompoundTag tag = new CompoundTag();
        tag.putByte("T", (byte) technique.ordinal());
        tag.putFloat("CE", cursedEnergy);
        tag.putFloat("Max", maxCursedEnergy);
        tag.putByte("F", (byte) fingers);
        tag.putByte("Sel", (byte) selected);
        tag.putBoolean("Inf", infinity);
        tag.putBoolean("Rct", rct);
        tag.putInt("Burn", burnout);
        tag.putInt("Jack", jackpot);
        tag.putBoolean("PUp", probabilityUp);
        tag.putInt("Zone", zone);
        tag.putBoolean("Tamed", mahoragaTamed);
        tag.putInt("Wheel", wheelTurns);
        tag.putByte("Cast", (byte) (casting == null ? -1 : casting.ordinal()));
        tag.putShort("CastT", (short) castTicks);
        tag.putShort("CastMax", (short) castTotal);
        tag.put("Cd", new IntArrayTag(cooldowns.clone()));
        tag.putByte("Adapt", (byte) adaptation.size());
        return tag;
    }

    public void loadSync(CompoundTag tag) {
        Technique[] techniques = Technique.values();
        int t = tag.getByte("T");
        technique = t >= 0 && t < techniques.length ? techniques[t] : Technique.NONE;
        cursedEnergy = tag.getFloat("CE");
        maxCursedEnergy = tag.getFloat("Max");
        fingers = tag.getByte("F");
        selected = tag.getByte("Sel");
        infinity = tag.getBoolean("Inf");
        rct = tag.getBoolean("Rct");
        burnout = tag.getInt("Burn");
        jackpot = tag.getInt("Jack");
        probabilityUp = tag.getBoolean("PUp");
        zone = tag.getInt("Zone");
        mahoragaTamed = tag.getBoolean("Tamed");
        wheelTurns = tag.getInt("Wheel");
        casting = Ability.byOrdinal(tag.getByte("Cast"));
        castTicks = tag.getShort("CastT");
        castTotal = tag.getShort("CastMax");
        int[] cd = tag.getIntArray("Cd");
        for (int i = 0; i < Math.min(cd.length, cooldowns.length); i++) cooldowns[i] = cd[i];
        clientAdaptCount = tag.getByte("Adapt");
    }

    private int clientAdaptCount;

    public int clientAdaptCount() {
        return clientAdaptCount;
    }

    /** Copies persistent state on respawn / dimension change. */
    public void copyFrom(SorcererData other, boolean death) {
        load(other.save());
        if (death) {
            cursedEnergy = maxCursedEnergy * 0.25f;
            burnout = 0;
            jackpot = 0;
            zone = 0;
            rct = false;
            adaptation.clear();
            wheelTurns = 0;
        }
        markDirty();
    }
}

package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.item.DharmaWheelItem;
import com.jujutsukaisen.registry.ModTags;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageTypes;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.phys.Vec3;

/**
 * Mahoraga's adaptation to all phenomena (적응). The eight-handled wheel (법진) turns once per
 * step — ガコン — and each turn grants resistance to the phenomenon and heals the damage it caused.
 * Adaptation follows the <em>nature</em> of a phenomenon, so all slashes share one adaptation.
 */
public final class Adaptation {
    public static final String INFINITY = "infinity";
    public static final String UNLIMITED_VOID = "infinite_void";
    /** Turns needed for complete adaptation. */
    public static final int MAX = 4;
    /** One extra turn after neutralising Infinity: the slash aimed at space itself. */
    public static final int SPACE_CUT = 5;

    private static final float[] MAHORAGA_RESIST = {0f, 0.4f, 0.65f, 0.85f, 1.0f};
    private static final float[] WHEEL_RESIST = {0f, 0.25f, 0.45f, 0.6f, 0.7f};

    private Adaptation() {
    }

    /** Whether this entity bears the wheel (Mahoraga itself, or someone holding the Dharma Wheel). */
    public static boolean bearsWheel(LivingEntity entity) {
        if (entity instanceof MahoragaEntity) return true;
        return entity.getOffhandItem().getItem() instanceof DharmaWheelItem
                || entity.getMainHandItem().getItem() instanceof DharmaWheelItem;
    }

    public static String keyFor(DamageSource source) {
        if (source.is(ModTags.SLASHING)) return "slashing";
        if (source.is(DamageTypeTags.IS_FIRE)) return "fire";
        if (source.is(DamageTypeTags.IS_EXPLOSION)) return "explosion";
        if (source.is(DamageTypeTags.IS_PROJECTILE)) return "projectile";
        if (source.is(DamageTypeTags.IS_LIGHTNING)) return "lightning";
        if (source.is(DamageTypeTags.IS_FREEZING)) return "freezing";
        if (source.is(DamageTypes.PLAYER_ATTACK) || source.is(DamageTypes.MOB_ATTACK) || source.is(DamageTypes.MOB_ATTACK_NO_AGGRO)) {
            return "physical";
        }
        return source.typeHolder().unwrapKey().map(k -> k.location().getPath()).orElse("unknown");
    }

    private static float resist(LivingEntity entity, int level) {
        float[] table = entity instanceof MahoragaEntity ? MAHORAGA_RESIST : WHEEL_RESIST;
        return table[Math.min(level, table.length - 1)];
    }

    private static int turnDelay(LivingEntity entity) {
        return entity instanceof MahoragaEntity ? 70 : 110;
    }

    /** Reduces incoming damage according to the current adaptation and keeps adapting. */
    public static float onHurt(LivingEntity entity, SorcererData data, DamageSource source, float amount) {
        if (source.is(DamageTypeTags.BYPASSES_INVULNERABILITY)) return amount;
        String key = keyFor(source);
        int level = data.getAdaptation(key);
        float reduced = amount * (1f - resist(entity, level));
        if (level >= MAX && entity instanceof MahoragaEntity) {
            Fx.burst(entity.level(), ParticleTypes.ENCHANTED_HIT, entity.getBoundingBox().getCenter(), 8, 0.6, 0.1);
        }
        expose(entity, data, key, reduced);
        return reduced;
    }

    /** Registers exposure to a phenomenon; the wheel starts (or speeds up) turning. */
    public static void expose(LivingEntity entity, SorcererData data, String key, float damage) {
        int level = data.getAdaptation(key);
        int cap = INFINITY.equals(key) ? SPACE_CUT : MAX;
        if (level >= cap) return;
        data.addAdaptDamage(key, damage);
        if (data.getPendingAdapt().isEmpty()) {
            data.setPendingAdapt(key, turnDelay(entity));
        } else if (data.getPendingAdapt().equals(key)) {
            // Repeated exposure speeds the analysis up.
            data.setAdaptTimer(Math.max(5, data.getAdaptTimer() - 8));
        }
    }

    public static void tick(LivingEntity entity, SorcererData data) {
        String key = data.getPendingAdapt();
        if (key.isEmpty()) return;
        if (!bearsWheel(entity)) {
            data.setPendingAdapt("", 0);
            return;
        }
        int timer = data.getAdaptTimer() - 1;
        data.setAdaptTimer(timer);
        if (timer <= 0) turn(entity, data, key);
    }

    private static void turn(LivingEntity entity, SorcererData data, String key) {
        int level = data.getAdaptation(key) + 1;
        data.setAdaptation(key, level);
        data.setPendingAdapt("", 0);
        data.setWheelTurns(data.getWheelTurns() + 1);

        // Defensive adaptation: the damage dealt by this phenomenon is healed.
        float heal = data.takeAdaptDamage(key);
        if (heal > 0) entity.heal(entity instanceof MahoragaEntity ? heal : heal * 0.5f);

        Vec3 top = entity.position().add(0, entity.getBbHeight() + 0.6, 0);
        Fx.sound(entity.level(), top, SoundEvents.ANVIL_LAND, 1.4f, 0.55f);
        Fx.sound(entity.level(), top, SoundEvents.BELL_BLOCK, 1.6f, 0.7f);
        Fx.ring(entity.level(), Fx.GOLD, top, 0.9, 24);
        Fx.burst(entity.level(), ParticleTypes.END_ROD, top, 10, 0.4, 0.05);

        if (entity instanceof MahoragaEntity mahoraga) mahoraga.onWheelTurn(key, level);
        if (entity instanceof ServerPlayer player) {
            player.displayClientMessage(Component.translatable("message.jujutsukaisen.wheel_turn",
                    Component.translatable("adaptation.jujutsukaisen." + key), level).withStyle(ChatFormatting.GOLD), true);
        }
    }

    /** Whether attacks from this entity neutralise Infinity on contact. */
    public static boolean pierces(LivingEntity attacker) {
        SorcererData data = JJK.get(attacker);
        return data != null && bearsWheel(attacker) && data.getAdaptation(INFINITY) >= MAX;
    }
}

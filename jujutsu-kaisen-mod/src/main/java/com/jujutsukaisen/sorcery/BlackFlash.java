package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.config.JJKConfig;
import com.jujutsukaisen.entity.SorcererEntity;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageTypes;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.Vec3;

import java.util.Map;
import java.util.UUID;
import java.util.WeakHashMap;

/**
 * Black Flash (흑섬): cursed energy applied within 0.000001 seconds of a physical blow. The space
 * distorts, cursed energy flashes black, and the sorcerer enters "the zone". Nobody can do it at will,
 * so it is a chance on every fully charged cursed-energy strike.
 */
public final class BlackFlash {
    private static final Map<UUID, Long> FULL_STRIKES = new WeakHashMap<>();

    private BlackFlash() {
    }

    /** Remember that a player started a fully charged swing this tick. */
    public static void markStrike(Player player) {
        if (player.getAttackStrengthScale(0.5f) > 0.9f) {
            FULL_STRIKES.put(player.getUUID(), player.level().getGameTime());
        }
    }

    public static float apply(LivingEntity attacker, LivingEntity target, DamageSource source, float amount) {
        if (source.getDirectEntity() != attacker) return amount;
        if (!(source.is(DamageTypes.PLAYER_ATTACK) || source.is(DamageTypes.MOB_ATTACK))) return amount;
        SorcererData data = JJK.get(attacker);
        if (data == null || data.getCursedEnergy() < 10f) return amount;
        if (attacker instanceof Player player) {
            Long tick = FULL_STRIKES.remove(player.getUUID());
            if (tick == null || player.level().getGameTime() - tick > 1) return amount;
        }

        double chance = data.getZone() > 0 ? JJKConfig.BLACK_FLASH_ZONE_CHANCE.get() : JJKConfig.BLACK_FLASH_CHANCE.get();
        if (attacker instanceof SorcererEntity sorcerer) chance *= sorcerer.blackFlashAffinity();
        if (attacker.getRandom().nextDouble() >= chance) return amount;
        if (!data.consume(10f)) return amount;

        data.setZone(400);
        attacker.addEffect(new MobEffectInstance(ModEffects.THE_ZONE.get(), 400, 0, false, true, true));
        effects(attacker, target);
        if (attacker instanceof ServerPlayer player) {
            player.displayClientMessage(Component.translatable("message.jujutsukaisen.black_flash").withStyle(ChatFormatting.DARK_RED, ChatFormatting.BOLD), true);
            Advancements.award(player, "black_flash");
        }
        return (float) (amount * JJKConfig.BLACK_FLASH_MULTIPLIER.get());
    }

    public static void effects(LivingEntity attacker, LivingEntity target) {
        Vec3 hit = target.getBoundingBox().getCenter();
        Fx.burst(attacker.level(), Fx.BLACK, hit, 40, 0.5, 0.4);
        Fx.burst(attacker.level(), Fx.CRIMSON, hit, 30, 0.6, 0.6);
        Fx.burst(attacker.level(), ParticleTypes.ELECTRIC_SPARK, hit, 25, 0.5, 0.6);
        Fx.burst(attacker.level(), ParticleTypes.SONIC_BOOM, hit, 1, 0, 0);
        Fx.sound(attacker.level(), hit, SoundEvents.LIGHTNING_BOLT_IMPACT, 1.2f, 1.6f);
        Fx.sound(attacker.level(), hit, SoundEvents.GENERIC_EXPLODE, 0.8f, 1.9f);
        Fx.sound(attacker.level(), hit, SoundEvents.PLAYER_ATTACK_CRIT, 1.5f, 0.6f);
    }
}

package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.domain.DomainType;
import com.jujutsukaisen.entity.SorcererEntity;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.sorcery.technique.IdleDeathGamble;
import com.jujutsukaisen.sorcery.technique.Limitless;
import com.jujutsukaisen.sorcery.technique.Shrine;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.player.Player;

/** Validates, pays for, winds up and finally executes abilities for players and mobs alike. */
public final class AbilityHandler {
    private AbilityHandler() {
    }

    /** Casts started by the character entities' own AI (read by the CI smoke test). */
    public static int aiCasts;
    /** Abilities that players ran all the way to execution (read by the CI client test). */
    public static final java.util.Set<Ability> playerExecuted = java.util.EnumSet.noneOf(Ability.class);

    /** Attempts to use an ability. Returns true if it started (or executed). */
    public static boolean tryUse(LivingEntity caster, SorcererData data, Ability ability) {
        if (caster.level().isClientSide || !caster.isAlive()) return false;
        if (ability.technique() != data.getTechnique()) return false;
        if (data.getCasting() != null) return false;
        if (caster.hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) {
            fail(caster, "message.jujutsukaisen.overloaded");
            return false;
        }
        if (data.isBurntOut()) {
            fail(caster, "message.jujutsukaisen.burnt_out", String.format("%.1f", data.getBurnout() / 20f));
            return false;
        }
        int cooldown = data.getCooldown(ability);
        if (cooldown > 0) {
            fail(caster, "message.jujutsukaisen.cooldown", ability.displayName(), String.format("%.1f", cooldown / 20f));
            return false;
        }
        if (!meetsRequirements(caster, data, ability)) return false;

        float cost = costOf(caster, data, ability);
        if (!data.consume(cost)) {
            fail(caster, "message.jujutsukaisen.no_energy", ability.displayName());
            return false;
        }
        if (caster instanceof SorcererEntity) aiCasts++;
        int cd = ability.cooldown();
        if (data.isJackpot()) cd /= 2;
        if (caster instanceof SorcererEntity sorcerer) cd = (int) (cd * sorcerer.cooldownMultiplier());
        data.setCooldown(ability, cd);

        if (ability.windup() > 0) {
            data.startCast(ability, ability.windup());
            onCastStart(caster, data, ability);
        } else {
            execute(caster, data, ability);
        }
        return true;
    }

    public static float costOf(LivingEntity caster, SorcererData data, Ability ability) {
        float cost = ability.cost();
        // Six Eyes: Limitless with near-zero cursed energy waste.
        if (ability.technique() == Technique.LIMITLESS) cost *= 0.5f;
        if (caster instanceof SorcererEntity sorcerer) cost *= sorcerer.costMultiplier();
        return cost;
    }

    private static boolean meetsRequirements(LivingEntity caster, SorcererData data, Ability ability) {
        switch (ability) {
            case CLEAVE -> {
                if (Shrine.cleaveTarget(caster) == null) {
                    fail(caster, "message.jujutsukaisen.cleave_contact");
                    return false;
                }
            }
            case FUGA -> {
                if (!Shrine.canUseFuga(caster, data)) {
                    fail(caster, "message.jujutsukaisen.fuga_order");
                    return false;
                }
            }
            case WORLD_SLASH -> {
                if (caster instanceof Player && !data.isMahoragaTamed() && data.getFingers() < SorcererData.MAX_FINGERS) {
                    fail(caster, "message.jujutsukaisen.world_slash_locked");
                    return false;
                }
            }
            default -> {
                if (ability.isDomain()) {
                    DomainType type = DomainType.forAbility(ability);
                    if (type == null || DomainManager.find(caster) != null) return false;
                }
            }
        }
        return true;
    }

    private static void onCastStart(LivingEntity caster, SorcererData data, Ability ability) {
        switch (ability) {
            case HOLLOW_PURPLE -> {
                Fx.sound(caster, SoundEvents.BEACON_POWER_SELECT, 2.0f, 0.5f);
                Fx.actionBar(caster, Component.translatable("chant.jujutsukaisen.hollow_purple").withStyle(ChatFormatting.LIGHT_PURPLE));
            }
            case RED -> Fx.sound(caster, SoundEvents.BEACON_ACTIVATE, 1.5f, 1.8f);
            case FUGA -> {
                Fx.sound(caster, SoundEvents.BLAZE_SHOOT, 1.5f, 0.5f);
                Fx.actionBar(caster, Component.translatable("chant.jujutsukaisen.fuga").withStyle(ChatFormatting.GOLD));
            }
            case WORLD_SLASH -> Fx.sound(caster, SoundEvents.WARDEN_HEARTBEAT, 2.0f, 0.6f);
            default -> {
                if (ability.isDomain()) {
                    Fx.sound(caster, SoundEvents.BELL_RESONATE, 2.5f, 0.6f);
                }
            }
        }
    }

    /** Called every tick while an ability winds up. */
    public static void tickCast(LivingEntity caster, SorcererData data) {
        Ability ability = data.getCasting();
        if (ability == null) return;
        if (!caster.isAlive() || caster.hasEffect(ModEffects.INFORMATION_OVERLOAD.get()) || data.isBurntOut()) {
            data.clearCast();
            return;
        }
        int left = data.getCastTicks() - 1;
        data.setCastTicks(left);
        int elapsed = data.getCastTotal() - left;

        if (caster instanceof Mob mob) mob.getNavigation().stop();
        else caster.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN, 3, 2, false, false, false));

        switch (ability) {
            case HOLLOW_PURPLE -> Limitless.chargePurple(caster, elapsed, data.getCastTotal());
            case RED -> Fx.casterBurst(caster, Fx.RED, Fx.hand(caster, true), 4, 0.08, 0.0);
            case FUGA -> Shrine.chargeFuga(caster, elapsed);
            case WORLD_SLASH -> Shrine.chantWorldSlash(caster, elapsed, data.getCastTotal());
            default -> {
                if (ability.isDomain()) {
                    DomainType type = DomainType.forAbility(ability);
                    if (type != null) DomainManager.chargeFx(caster, type, elapsed);
                }
            }
        }

        if (left <= 0) {
            data.clearCast();
            execute(caster, data, ability);
        }
    }

    public static void execute(LivingEntity caster, SorcererData data, Ability ability) {
        switch (ability) {
            case BLUE -> Limitless.blue(caster, data);
            case RED -> Limitless.red(caster, data);
            case HOLLOW_PURPLE -> Limitless.hollowPurple(caster, data);
            case DISMANTLE -> Shrine.dismantle(caster, data);
            case CLEAVE -> Shrine.cleave(caster, data);
            case FUGA -> Shrine.fuga(caster, data);
            case WORLD_SLASH -> Shrine.worldSlash(caster, data);
            case RESERVE_BALLS -> IdleDeathGamble.reserveBalls(caster, data);
            case SHUTTER_DOORS -> IdleDeathGamble.shutterDoors(caster, data);
            case PSEUDO_CONSECUTIVE -> IdleDeathGamble.pseudoConsecutive(caster, data);
            case DOMAIN_INFINITE_VOID -> DomainManager.expand(caster, data, DomainType.INFINITE_VOID);
            case DOMAIN_MALEVOLENT_SHRINE -> DomainManager.expand(caster, data, DomainType.MALEVOLENT_SHRINE);
            case DOMAIN_IDLE_DEATH_GAMBLE -> DomainManager.expand(caster, data, DomainType.IDLE_DEATH_GAMBLE);
        }
        if (ability.technique() == Technique.IDLE_DEATH_GAMBLE && !ability.isDomain()) {
            DomainManager.onGambleIndicator(caster, ability);
        }
        if (caster instanceof Player) playerExecuted.add(ability);
    }

    private static void fail(LivingEntity caster, String key, Object... args) {
        if (caster instanceof ServerPlayer player) {
            player.displayClientMessage(Component.translatable(key, args).withStyle(ChatFormatting.RED), true);
        }
    }
}

package com.jujutsukaisen.sorcery.technique;

import com.jujutsukaisen.domain.ActiveDomain;
import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.domain.DomainType;
import com.jujutsukaisen.entity.SukunaEntity;
import com.jujutsukaisen.entity.projectile.DismantleEntity;
import com.jujutsukaisen.entity.projectile.FugaEntity;
import com.jujutsukaisen.entity.projectile.WorldSlashEntity;
import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

/**
 * 어주자 — Shrine. Slashes and fire, modelled on cooking: first cut (해 · 팔), then cook (竈).
 */
public final class Shrine {
    /** "Recently" for the cooking order and post-domain flame: 15 seconds. */
    private static final long RECENT = 300;

    private Shrine() {
    }

    private static float fingerBonus(LivingEntity caster, SorcererData data) {
        return caster instanceof Player ? data.getFingers() * 0.35f : 0f;
    }

    /** 해 — the default, invisible, rapid slash. */
    public static void dismantle(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        float damage = (caster instanceof SukunaEntity ? 11f : 8f) + fingerBonus(caster, data);
        DismantleEntity slash = new DismantleEntity(level, caster, damage, caster instanceof SukunaEntity ? 1.4f : 1.0f);
        Vec3 dir = JJK.aim(caster).add(caster.getRandom().nextGaussian() * 0.03, caster.getRandom().nextGaussian() * 0.03, caster.getRandom().nextGaussian() * 0.03);
        slash.launch(caster, dir, 2.6f);
        level.addFreshEntity(slash);
        caster.swing(caster.getRandom().nextBoolean() ? InteractionHand.MAIN_HAND : InteractionHand.OFF_HAND, true);
        Fx.sound(caster, SoundEvents.PLAYER_ATTACK_SWEEP, 1.0f, 1.4f + caster.getRandom().nextFloat() * 0.3f);
    }

    /** Cleave needs contact outside the domain. */
    @Nullable
    public static LivingEntity cleaveTarget(LivingEntity caster) {
        LivingEntity target = JJK.aimEntity(caster, 3.5 + caster.getBbWidth());
        if (target == null || !JJK.canHit(caster, target)) return null;
        return target;
    }

    /** 팔 — adjusts itself to the target's toughness and cursed energy to cut it down in one blow. */
    public static void cleave(LivingEntity caster, SorcererData data) {
        LivingEntity target = cleaveTarget(caster);
        if (target == null) return;
        float toughness = target.getArmorValue() * 0.7f;
        SorcererData victim = JJK.get(target);
        if (victim != null) toughness += victim.getMaxCursedEnergy() / 400f;
        float cap = caster instanceof SukunaEntity ? 90f : 60f;
        float damage = Math.min(cap, 7f + target.getMaxHealth() * 0.22f + toughness + fingerBonus(caster, data) * 2f);
        if (target.hurt(ModDamageTypes.source(caster.level(), ModDamageTypes.CLEAVE, caster), damage)) {
            data.setLastCleaveHit(caster.level().getGameTime());
        }
        caster.swing(InteractionHand.MAIN_HAND, true);
        Vec3 c = target.getBoundingBox().getCenter();
        Vec3 side = JJK.aim(caster).cross(new Vec3(0, 1, 0)).normalize();
        Fx.line(caster.level(), Fx.CRIMSON, c.add(side.scale(0.9)).add(0, 0.9, 0), c.subtract(side.scale(0.9)).subtract(0, 0.9, 0), 0.15);
        Fx.line(caster.level(), Fx.CRIMSON, c.subtract(side.scale(0.9)).add(0, 0.9, 0), c.add(side.scale(0.9)).subtract(0, 0.9, 0), 0.15);
        Fx.burst(caster.level(), ParticleTypes.SWEEP_ATTACK, c, 3, 0.4, 0);
        Fx.sound(caster, SoundEvents.PLAYER_ATTACK_SWEEP, 1.4f, 0.7f);
        Fx.sound(caster, SoundEvents.ZOMBIE_BREAK_WOODEN_DOOR, 0.8f, 1.6f);
    }

    /** Fuga may only be drawn after Dismantle and Cleave have both landed, or around his domain. */
    public static boolean canUseFuga(LivingEntity caster, SorcererData data) {
        long now = caster.level().getGameTime();
        boolean cooked = now - data.getLastDismantleHit() < RECENT && now - data.getLastCleaveHit() < RECENT;
        return cooked || inOrAfterShrine(caster, data);
    }

    private static boolean inOrAfterShrine(LivingEntity caster, SorcererData data) {
        ActiveDomain domain = DomainManager.find(caster);
        if (domain != null && domain.type() == DomainType.MALEVOLENT_SHRINE) return true;
        return caster.level().getGameTime() - data.getLastShrineDomain() < RECENT;
    }

    public static void chargeFuga(LivingEntity caster, int elapsed) {
        Vec3 hand = Fx.hand(caster, false);
        Fx.burst(caster.level(), ParticleTypes.FLAME, hand, 6, 0.15, 0.02);
        if (elapsed == 2) {
            if (caster instanceof ServerPlayer player) {
                player.displayClientMessage(Component.translatable("chant.jujutsukaisen.fuga").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD), true);
            } else {
                Fx.say(caster, "chant.jujutsukaisen.fuga", 48);
            }
        }
        if (elapsed % 5 == 0) Fx.sound(caster, SoundEvents.FIRE_AMBIENT, 2.0f, 0.6f);
    }

    /** 「竈」 開 — the divine flame arrow. */
    public static void fuga(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        boolean empowered = inOrAfterShrine(caster, data);
        FugaEntity arrow = new FugaEntity(level, caster, empowered);
        arrow.launch(caster, JJK.aim(caster), 2.2f);
        level.addFreshEntity(arrow);
        caster.swing(InteractionHand.MAIN_HAND, true);
        Fx.sound(caster, SoundEvents.BLAZE_SHOOT, 2.0f, 0.6f);
        Fx.sound(caster, SoundEvents.CROSSBOW_SHOOT, 1.5f, 0.6f);
        if (caster instanceof ServerPlayer player) Advancements.award(player, "fuga");
    }

    /** The chant: 「용린, 반발, 한 쌍의 유성」 — dragon scales, recoil, twin meteors. */
    public static void chantWorldSlash(LivingEntity caster, int elapsed, int total) {
        int step = Math.max(1, total / 3);
        String line = null;
        if (elapsed == 1) line = "chant.jujutsukaisen.world_slash.1";
        else if (elapsed == step) line = "chant.jujutsukaisen.world_slash.2";
        else if (elapsed == step * 2) line = "chant.jujutsukaisen.world_slash.3";
        if (line != null) {
            Fx.say(caster, line, 64);
            Fx.sound(caster, SoundEvents.BELL_BLOCK, 1.5f, 0.5f);
        }
        Vec3 palm = caster.getEyePosition().add(JJK.aim(caster).scale(0.9)).subtract(0, 0.25, 0);
        Fx.burst(caster.level(), Fx.BLACK, palm, 4, 0.15, 0.0);
        Fx.burst(caster.level(), Fx.CRIMSON, palm, 3, 0.25, 0.0);
    }

    /** 세계를 가르는 참격 — aimed with the palm at the world itself. */
    public static void worldSlash(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        WorldSlashEntity slash = new WorldSlashEntity(level, caster, caster instanceof SukunaEntity ? 90f : 80f);
        slash.launch(caster, JJK.aim(caster), 3.6f);
        level.addFreshEntity(slash);
        caster.swing(InteractionHand.MAIN_HAND, true);
        Fx.burst(level, ParticleTypes.FLASH, caster.getEyePosition(), 1, 0, 0);
        if (caster instanceof ServerPlayer player) Advancements.award(player, "world_slash");
    }
}

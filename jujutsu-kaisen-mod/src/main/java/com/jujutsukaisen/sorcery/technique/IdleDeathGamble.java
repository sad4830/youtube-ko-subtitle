package com.jujutsukaisen.sorcery.technique;

import com.jujutsukaisen.domain.Indicator;
import com.jujutsukaisen.entity.HakariEntity;
import com.jujutsukaisen.entity.misc.ShutterDoorEntity;
import com.jujutsukaisen.entity.projectile.PachinkoBallEntity;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

import java.util.ArrayList;
import java.util.List;

/**
 * 사철순애열차 — Private Pure Love Train. Outside the domain Hakari manifests the machine's notice
 * effects as attacks; inside Idle Death Gamble each notice leads into a riichi.
 */
public final class IdleDeathGamble {
    private IdleDeathGamble() {
    }

    private static Indicator rollIndicator(LivingEntity caster, SorcererData data) {
        Indicator color = Indicator.roll(caster.getRandom(), data.isProbabilityUp() || data.isJackpot());
        data.setLastIndicator(color);
        return color;
    }

    private static void announce(LivingEntity caster, String notice, Indicator color) {
        if (caster instanceof ServerPlayer player) {
            player.displayClientMessage(Component.translatable("message.jujutsukaisen.indicator",
                    Component.translatable(notice), color.displayName()).withStyle(ChatFormatting.WHITE), true);
        }
    }

    /** 보류 구슬 — a spread of reserve balls (offensive notice). */
    public static void reserveBalls(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        Indicator color = rollIndicator(caster, data);
        data.setPseudoStreak(0);
        Vec3 aim = JJK.aim(caster);
        int count = caster instanceof HakariEntity ? 7 : 6;
        float damage = caster instanceof HakariEntity ? 4.5f : 3.5f;
        for (int i = 0; i < count; i++) {
            PachinkoBallEntity ball = new PachinkoBallEntity(level, caster, color, damage);
            ball.shoot(aim.x, aim.y + 0.04, aim.z, 1.9f, 7.0f);
            level.addFreshEntity(ball);
        }
        caster.swing(InteractionHand.MAIN_HAND, true);
        Fx.sound(caster, SoundEvents.CHAIN_PLACE, 1.4f, 1.6f);
        Fx.sound(caster, SoundEvents.NOTE_BLOCK_CHIME.value(), 1.0f, 1.2f + color.ordinal() * 0.2f);
        announce(caster, "notice.jujutsukaisen.reserve_balls", color);
    }

    /** 셔터 — the doors slam shut on the target (offensive notice). */
    public static void shutterDoors(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        Indicator color = rollIndicator(caster, data);
        data.setPseudoStreak(0);
        LivingEntity target = JJK.aimEntity(caster, 20);
        Vec3 pos = target != null ? target.position() : JJK.aimPoint(caster, 10);
        BlockPos ground = BlockPos.containing(pos);
        for (int i = 0; i < 6 && level.isEmptyBlock(ground.below()); i++) ground = ground.below();
        pos = new Vec3(pos.x, ground.getY(), pos.z);
        Vec3 dir = pos.subtract(caster.position());
        float yaw = (float) (Mth.atan2(-dir.x, dir.z) * Mth.RAD_TO_DEG);
        level.addFreshEntity(new ShutterDoorEntity(level, caster, pos, yaw, color, caster instanceof HakariEntity ? 15f : 12f));
        caster.swing(InteractionHand.MAIN_HAND, true);
        announce(caster, "notice.jujutsukaisen.shutter_doors", color);
    }

    /**
     * 유사연속 — pseudo-consecutive (defensive notice): the sequence is replayed and the damage taken
     * in it is reverted.
     */
    public static void pseudoConsecutive(LivingEntity caster, SorcererData data) {
        Indicator color = rollIndicator(caster, data);
        data.setPseudoStreak(data.getPseudoStreak() + 1);
        float best = data.bestRecentHealth();
        if (best > caster.getHealth()) caster.setHealth(Math.min(caster.getMaxHealth(), best));
        List<MobEffectInstance> harmful = new ArrayList<>();
        for (MobEffectInstance effect : caster.getActiveEffects()) {
            if (!effect.getEffect().isBeneficial() && effect.getEffect() != ModEffects.TECHNIQUE_BURNOUT.get()) harmful.add(effect);
        }
        harmful.forEach(e -> caster.removeEffect(e.getEffect()));
        caster.clearFire();
        Vec3 c = caster.getBoundingBox().getCenter();
        Fx.burst(caster.level(), ParticleTypes.REVERSE_PORTAL, c, 50, 0.5, 0.15);
        Fx.burst(caster.level(), color.dust(), c, 30, 0.6, 0.0);
        Fx.sound(caster, SoundEvents.AMETHYST_BLOCK_CHIME, 2.0f, 0.5f);
        Fx.sound(caster, SoundEvents.BEACON_POWER_SELECT, 1.0f, 2.0f);
        announce(caster, "notice.jujutsukaisen.pseudo_consecutive", color);
    }
}

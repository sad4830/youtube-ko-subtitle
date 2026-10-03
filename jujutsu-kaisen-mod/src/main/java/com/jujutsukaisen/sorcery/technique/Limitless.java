package com.jujutsukaisen.sorcery.technique;

import com.jujutsukaisen.entity.GojoEntity;
import com.jujutsukaisen.entity.projectile.BlueEntity;
import com.jujutsukaisen.entity.projectile.HollowPurpleEntity;
import com.jujutsukaisen.entity.projectile.RedEntity;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

/** 무하한 주술 — Limitless: control of space at the atomic level, made usable by the Six Eyes. */
public final class Limitless {
    private Limitless() {
    }

    /** 술식순전 「창」 — a point of attraction. Mobs drop it on their target to drag it into their fists. */
    public static void blue(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        Vec3 point = JJK.aimPoint(caster, 18);
        if (caster instanceof Mob mob && mob.getTarget() != null) {
            Vec3 target = mob.getTarget().getBoundingBox().getCenter();
            point = target.add(caster.getBoundingBox().getCenter().subtract(target).normalize().scale(1.2));
        }
        float radius = caster instanceof GojoEntity ? 8.5f : 7.0f;
        level.addFreshEntity(new BlueEntity(level, caster, point, radius));
        caster.swing(InteractionHand.MAIN_HAND, true);
        Fx.sound(caster, SoundEvents.BEACON_ACTIVATE, 1.6f, 1.7f);
        Fx.sound(caster, SoundEvents.ILLUSIONER_CAST_SPELL, 1.2f, 1.4f);
        Fx.line(level, Fx.BLUE_SMALL, Fx.hand(caster, true), point, 0.6);
    }

    /** 술식반전 「혁」 — reversal into repulsion, fired from the fingertip. */
    public static void red(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        RedEntity red = new RedEntity(level, caster);
        red.launch(caster, JJK.aim(caster), 1.7f);
        level.addFreshEntity(red);
        caster.swing(InteractionHand.MAIN_HAND, true);
        Fx.sound(caster, SoundEvents.FIREWORK_ROCKET_LAUNCH, 2.0f, 0.5f);
        Fx.burst(level, Fx.RED, Fx.hand(caster, true), 20, 0.2, 0.05);
    }

    /** Wind-up of Purple: Blue in one hand, Red in the other, drawn together. */
    public static void chargePurple(LivingEntity caster, int elapsed, int total) {
        Level level = caster.level();
        float t = Math.min(1f, elapsed / (float) total);
        Vec3 front = caster.getEyePosition().add(JJK.aim(caster).scale(1.1)).subtract(0, 0.3, 0);
        Vec3 right = Fx.hand(caster, true).lerp(front, t * t);
        Vec3 left = Fx.hand(caster, false).lerp(front, t * t);
        Fx.casterBurst(caster, Fx.RED, right, 5, 0.12, 0.0);
        Fx.casterBurst(caster, Fx.BLUE, left, 5, 0.12, 0.0);
        if (t > 0.6f) Fx.casterBurst(caster, Fx.PURPLE, front, 4, 0.2, 0.0);
        if (elapsed % 8 == 0) Fx.sound(level, front, SoundEvents.BEACON_AMBIENT, 2.0f, 0.6f + t);
        if (elapsed == 1 && caster instanceof Mob) Fx.say(caster, "chant.jujutsukaisen.hollow_purple", 48);
    }

    /** 허식 「자」 — imaginary mass that erases everything in its path. */
    public static void hollowPurple(LivingEntity caster, SorcererData data) {
        Level level = caster.level();
        float radius = caster instanceof GojoEntity ? 3.2f : 2.6f;
        HollowPurpleEntity purple = new HollowPurpleEntity(level, caster, radius);
        Vec3 dir = JJK.aim(caster);
        purple.launch(caster, dir, 1.05f);
        Vec3 start = caster.getEyePosition().add(dir.scale(radius + 1.2)).subtract(0, purple.getBbHeight() * 0.5, 0);
        purple.setPos(start.x, start.y, start.z);
        level.addFreshEntity(purple);
        caster.swing(InteractionHand.MAIN_HAND, true);
        Fx.burst(level, ParticleTypes.FLASH, start, 1, 0, 0);
        Fx.burst(level, Fx.PURPLE, start, 80, radius * 0.6, 0.3);
        Fx.sound(caster, SoundEvents.WARDEN_SONIC_BOOM, 3.0f, 0.6f);
        Fx.sound(caster, SoundEvents.GENERIC_EXPLODE, 2.5f, 0.4f);
        if (caster instanceof ServerPlayer player) Advancements.award(player, "hollow_purple");
    }
}

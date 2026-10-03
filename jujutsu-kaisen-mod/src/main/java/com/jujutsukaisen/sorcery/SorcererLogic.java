package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.entity.projectile.InfinityPiercing;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.registry.ModTags;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.projectile.Projectile;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

/** Per-tick upkeep shared by players and the character entities (server side). */
public final class SorcererLogic {
    public static final String FROZEN_TAG = "jujutsukaisen.infinity_frozen";
    private static final String DROPPED_TAG = "jujutsukaisen.infinity_dropped";
    private static final String FROZEN_AT = "jujutsukaisen.frozen_at";

    private SorcererLogic() {
    }

    public static void tick(LivingEntity entity, SorcererData data) {
        if (entity.level().isClientSide) return;
        data.tickCooldowns();

        // Technique burnout after a domain; RCT repairs the burned-out brain faster.
        if (data.getBurnout() > 0) {
            int next = data.getBurnout() - (data.isRctActive() ? 3 : 1);
            data.setBurnout(next);
            if (next <= 0) {
                entity.removeEffect(ModEffects.TECHNIQUE_BURNOUT.get());
                Fx.actionBar(entity, Component.translatable("message.jujutsukaisen.technique_restored").withStyle(ChatFormatting.AQUA));
            } else if (entity.tickCount % 20 == 0) {
                MobEffectInstance current = entity.getEffect(ModEffects.TECHNIQUE_BURNOUT.get());
                if (current == null || Math.abs(current.getDuration() - next) > 25) {
                    entity.removeEffect(ModEffects.TECHNIQUE_BURNOUT.get());
                    entity.addEffect(new MobEffectInstance(ModEffects.TECHNIQUE_BURNOUT.get(), next, 0, false, false, true));
                }
            }
        }

        // Jackpot: unlimited cursed energy and fully automatic Reverse Cursed Technique.
        if (data.isJackpot()) {
            int left = data.getJackpot() - 1;
            data.setJackpot(left);
            data.setCursedEnergy(data.getMaxCursedEnergy());
            if (data.getBurnout() > 0) data.setBurnout(0);
            if (entity.getHealth() < entity.getMaxHealth()) {
                entity.heal(1.5f);
                if (entity.tickCount % 4 == 0) {
                    Fx.burst(entity.level(), ParticleTypes.HAPPY_VILLAGER, entity.getBoundingBox().getCenter(), 3, 0.4, 0.0);
                }
            }
            if (entity.tickCount % 6 == 0) {
                Fx.burst(entity.level(), Fx.GOLD, entity.position().add(0, entity.getBbHeight() * 0.5, 0), 2, 0.35, 0.6, 0.35, 0.0);
            }
            if (left <= 0) {
                entity.removeEffect(ModEffects.JACKPOT.get());
                Fx.actionBar(entity, Component.translatable("message.jujutsukaisen.jackpot_end").withStyle(ChatFormatting.YELLOW));
            }
        }

        if (data.getZone() > 0) data.setZone(data.getZone() - 1);

        // Cursed energy recovery.
        if (!data.isRctActive() && data.getCasting() == null) {
            float regen = data.getMaxCursedEnergy() / 1200f;
            if (data.getTechnique() == Technique.LIMITLESS) regen *= 1.6f; // Six Eyes
            data.addCursedEnergy(regen);
        }

        // Infinity upkeep and Zeno's paradox on incoming projectiles.
        if (hasInfinity(entity)) {
            if (entity.tickCount % 2 == 0) data.consume(0.35f);
            slowProjectiles(entity);
        }

        // Reverse Cursed Technique: negative × negative = positive energy.
        if (data.isRctActive()) {
            boolean usable = data.getTechnique().canUseRct() && !data.isJackpot();
            boolean needed = entity.getHealth() < entity.getMaxHealth() || data.isBurntOut();
            if (!usable || (entity instanceof Mob && !needed)) {
                data.setRctActive(false);
            } else if (needed) {
                if (data.consume(4.5f)) {
                    entity.heal(0.6f);
                    if (entity.tickCount % 5 == 0) {
                        Fx.burst(entity.level(), Fx.WHITE, entity.getBoundingBox().getCenter(), 3, 0.35, 0.5, 0.35, 0.0);
                    }
                } else {
                    data.setRctActive(false);
                    Fx.actionBar(entity, Component.translatable("message.jujutsukaisen.no_energy_rct").withStyle(ChatFormatting.RED));
                }
            }
        }

        if (data.getCasting() != null) AbilityHandler.tickCast(entity, data);
        Adaptation.tick(entity, data);
        if (entity.tickCount % 10 == 0) data.recordHealth(entity.getHealth());

        // Unlimited Void: Mahoraga (or a wheel bearer) adapts to the endless information too.
        if (entity.hasEffect(ModEffects.INFORMATION_OVERLOAD.get()) && Adaptation.bearsWheel(entity)) {
            if (data.getAdaptation(Adaptation.UNLIMITED_VOID) >= Adaptation.MAX) {
                entity.removeEffect(ModEffects.INFORMATION_OVERLOAD.get());
            } else if (entity.tickCount % 10 == 0) {
                Adaptation.expose(entity, data, Adaptation.UNLIMITED_VOID, 0f);
            }
        }
    }

    /** Infinity (무한) is up: Limitless user, not burnt out, with cursed energy left. */
    public static boolean hasInfinity(LivingEntity entity) {
        SorcererData data = JJK.get(entity);
        return data != null && data.getTechnique() == Technique.LIMITLESS && data.isInfinityEnabled()
                && !data.isBurntOut() && data.getCursedEnergy() >= 1f
                && !entity.hasEffect(ModEffects.INFORMATION_OVERLOAD.get());
    }

    /** Whether Infinity stops this damage before it reaches the body. */
    public static boolean infinityBlocks(LivingEntity target, DamageSource source) {
        if (!hasInfinity(target)) return false;
        if (source.is(DamageTypeTags.BYPASSES_INVULNERABILITY) || source.is(ModTags.BYPASSES_INFINITY)) return false;
        Entity attacker = source.getEntity();
        Entity direct = source.getDirectEntity();
        if (attacker == null && direct == null && !source.is(DamageTypeTags.IS_EXPLOSION)) return false;
        if (direct instanceof InfinityPiercing || attacker instanceof InfinityPiercing) return false;
        if (attacker instanceof LivingEntity living && Adaptation.pierces(living)) return false;
        return true;
    }

    private static void slowProjectiles(LivingEntity entity) {
        AABB box = entity.getBoundingBox().inflate(3.5);
        Vec3 center = entity.getBoundingBox().getCenter();
        for (Projectile projectile : entity.level().getEntitiesOfClass(Projectile.class, box,
                p -> p.getOwner() != entity && !(p instanceof InfinityPiercing))) {
            Vec3 toBody = center.subtract(projectile.position());
            double dist = toBody.length();
            Vec3 velocity = projectile.getDeltaMovement();
            boolean frozen = projectile.getTags().contains(FROZEN_TAG);
            if (projectile.getTags().contains(DROPPED_TAG)) continue;
            if (frozen && entity.level().getGameTime() - projectile.getPersistentData().getLong(FROZEN_AT) > 100) {
                // Held for five seconds at the edge of Infinity, it finally falls.
                projectile.removeTag(FROZEN_TAG);
                projectile.addTag(DROPPED_TAG);
                projectile.setNoGravity(false);
                projectile.setDeltaMovement(Vec3.ZERO);
                projectile.hurtMarked = true;
                continue;
            }
            if (dist < 3.2 && (velocity.dot(toBody) > 0 || frozen)) {
                // The closer it gets, the slower it moves: it never arrives.
                double factor = Math.max(0.0, Math.min(1.0, (dist - 0.9) / 2.3));
                projectile.setDeltaMovement(velocity.scale(0.25 + 0.35 * factor));
                if (!frozen) {
                    projectile.addTag(FROZEN_TAG);
                    projectile.getPersistentData().putLong(FROZEN_AT, entity.level().getGameTime());
                    projectile.setNoGravity(true);
                    if (entity.level() instanceof ServerLevel server) {
                        server.sendParticles(Fx.BLUE_SMALL, projectile.getX(), projectile.getY(), projectile.getZ(), 6, 0.15, 0.15, 0.15, 0.0);
                    }
                }
                projectile.hurtMarked = true;
            }
        }
    }

    /** Releases projectiles held by an Infinity that is no longer around. */
    public static void releaseFrozen(ServerLevel level) {
        for (Entity entity : level.getAllEntities()) {
            if (entity instanceof Projectile projectile && projectile.getTags().contains(FROZEN_TAG)) {
                boolean held = !level.getEntitiesOfClass(LivingEntity.class, projectile.getBoundingBox().inflate(3.6),
                        SorcererLogic::hasInfinity).isEmpty();
                if (!held) {
                    projectile.removeTag(FROZEN_TAG);
                    projectile.setNoGravity(false);
                    projectile.hurtMarked = true;
                }
            }
        }
    }

    /** Visual + audio feedback when Infinity stops something. */
    public static void infinityFeedback(LivingEntity target, DamageSource source) {
        if (target.tickCount % 3 != 0) return;
        Entity from = source.getDirectEntity() != null ? source.getDirectEntity() : source.getEntity();
        Vec3 center = target.getBoundingBox().getCenter();
        Vec3 point = from == null ? center : center.add(from.position().add(0, from.getBbHeight() * 0.5, 0).subtract(center).normalize().scale(0.9));
        Fx.burst(target.level(), Fx.BLUE_SMALL, point, 8, 0.2, 0.0);
        Fx.sound(target.level(), point, SoundEvents.AMETHYST_BLOCK_RESONATE, 0.7f, 1.7f);
    }

    public static boolean isSorcererPlayer(Entity entity) {
        return entity instanceof Player && JJK.get(entity) != null;
    }
}

package com.jujutsukaisen.util;

import net.minecraft.core.particles.DustParticleOptions;
import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.network.chat.Component;
import net.minecraft.network.protocol.game.ClientboundSetSubtitleTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetTitleTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetTitlesAnimationPacket;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import org.joml.Vector3f;

/** Particle, sound and text helpers used by techniques (server side). */
public final class Fx {
    public static final DustParticleOptions BLUE = new DustParticleOptions(new Vector3f(0.25f, 0.65f, 1.0f), 1.6f);
    public static final DustParticleOptions BLUE_SMALL = new DustParticleOptions(new Vector3f(0.45f, 0.85f, 1.0f), 0.8f);
    public static final DustParticleOptions RED = new DustParticleOptions(new Vector3f(1.0f, 0.12f, 0.1f), 1.6f);
    public static final DustParticleOptions PURPLE = new DustParticleOptions(new Vector3f(0.62f, 0.2f, 1.0f), 2.2f);
    public static final DustParticleOptions BLACK = new DustParticleOptions(new Vector3f(0.02f, 0.0f, 0.02f), 1.8f);
    public static final DustParticleOptions CRIMSON = new DustParticleOptions(new Vector3f(0.85f, 0.0f, 0.08f), 1.4f);
    public static final DustParticleOptions WHITE = new DustParticleOptions(new Vector3f(1.0f, 1.0f, 1.0f), 1.2f);
    public static final DustParticleOptions GOLD = new DustParticleOptions(new Vector3f(1.0f, 0.8f, 0.2f), 1.5f);
    public static final DustParticleOptions GREEN = new DustParticleOptions(new Vector3f(0.3f, 1.0f, 0.4f), 1.4f);
    public static final DustParticleOptions CURSED = new DustParticleOptions(new Vector3f(0.35f, 0.1f, 0.55f), 1.1f);

    private Fx() {
    }

    public static void burst(Level level, ParticleOptions particle, Vec3 pos, int count, double spread, double speed) {
        if (level instanceof ServerLevel server) {
            server.sendParticles(particle, pos.x, pos.y, pos.z, count, spread, spread, spread, speed);
        }
    }

    /**
     * Particles at a caster's hands or just in front of their eyes. Everyone else sees them as given; the caster
     * gets fewer, smaller ones, because in first person they sit right in front of the camera and fill the view.
     */
    public static void casterBurst(LivingEntity caster, ParticleOptions particle, Vec3 pos, int count, double spread, double speed) {
        if (!(caster.level() instanceof ServerLevel server)) return;
        for (ServerPlayer viewer : server.players()) {
            if (viewer == caster) {
                ParticleOptions own = particle instanceof DustParticleOptions dust && dust.getScale() > OWN_DUST_SCALE
                        ? new DustParticleOptions(dust.getColor(), OWN_DUST_SCALE) : particle;
                server.sendParticles(viewer, own, false, pos.x, pos.y, pos.z, Math.max(1, count / 2), spread, spread, spread, speed);
            } else {
                server.sendParticles(viewer, particle, false, pos.x, pos.y, pos.z, count, spread, spread, spread, speed);
            }
        }
    }

    private static final float OWN_DUST_SCALE = 0.5f;

    public static void burst(Level level, ParticleOptions particle, Vec3 pos, int count, double sx, double sy, double sz, double speed) {
        if (level instanceof ServerLevel server) {
            server.sendParticles(particle, pos.x, pos.y, pos.z, count, sx, sy, sz, speed);
        }
    }

    public static void line(Level level, ParticleOptions particle, Vec3 from, Vec3 to, double step) {
        if (!(level instanceof ServerLevel server)) return;
        Vec3 delta = to.subtract(from);
        double len = delta.length();
        if (len < 1.0E-3) return;
        Vec3 dir = delta.scale(1.0 / len);
        for (double d = 0; d <= len; d += step) {
            Vec3 p = from.add(dir.scale(d));
            server.sendParticles(particle, p.x, p.y, p.z, 1, 0, 0, 0, 0);
        }
    }

    public static void ring(Level level, ParticleOptions particle, Vec3 center, double radius, int points) {
        if (!(level instanceof ServerLevel server)) return;
        for (int i = 0; i < points; i++) {
            double a = Math.PI * 2 * i / points;
            server.sendParticles(particle, center.x + Math.cos(a) * radius, center.y, center.z + Math.sin(a) * radius, 1, 0, 0, 0, 0);
        }
    }

    public static void sphere(Level level, ParticleOptions particle, Vec3 center, double radius, int points) {
        if (!(level instanceof ServerLevel server)) return;
        double golden = Math.PI * (3 - Math.sqrt(5));
        for (int i = 0; i < points; i++) {
            double y = 1 - (i / (double) (points - 1)) * 2;
            double r = Math.sqrt(1 - y * y);
            double t = golden * i;
            server.sendParticles(particle, center.x + Math.cos(t) * r * radius, center.y + y * radius,
                    center.z + Math.sin(t) * r * radius, 1, 0, 0, 0, 0);
        }
    }

    public static void sound(Level level, Vec3 pos, SoundEvent sound, float volume, float pitch) {
        level.playSound(null, pos.x, pos.y, pos.z, sound, SoundSource.HOSTILE, volume, pitch);
    }

    public static void sound(LivingEntity entity, SoundEvent sound, float volume, float pitch) {
        sound(entity.level(), entity.position(), sound, volume, pitch);
    }

    /** Point where a caster's right (or left) hand roughly is, for charge particles. */
    public static Vec3 hand(LivingEntity entity, boolean right) {
        float yaw = entity.yBodyRot * Mth.DEG_TO_RAD;
        double side = right ? -0.45 : 0.45;
        double fx = -Mth.sin(yaw) * 0.55, fz = Mth.cos(yaw) * 0.55;
        double sx = Mth.cos(yaw) * side, sz = Mth.sin(yaw) * side;
        double scale = entity.getBbHeight() / 1.8;
        return entity.position().add((fx + sx) * scale, entity.getBbHeight() * 0.62, (fz + sz) * scale);
    }

    /** A spoken line shown in chat to players nearby: {@code <Name> line}. */
    public static void say(LivingEntity speaker, String key, double radius, Object... args) {
        if (!(speaker.level() instanceof ServerLevel server)) return;
        Component line = Component.translatable("chat.type.text", speaker.getDisplayName(), Component.translatable(key, args));
        for (ServerPlayer player : server.players()) {
            if (player.distanceToSqr(speaker) <= radius * radius) player.sendSystemMessage(line);
        }
    }

    /** Big title + subtitle for every player around a point (used for Domain Expansion calls). */
    public static void title(Level level, Vec3 pos, double radius, Component title, Component subtitle) {
        if (!(level instanceof ServerLevel server)) return;
        for (ServerPlayer player : server.players()) {
            if (player.position().distanceToSqr(pos) <= radius * radius) {
                player.connection.send(new ClientboundSetTitlesAnimationPacket(4, 50, 16));
                player.connection.send(new ClientboundSetSubtitleTextPacket(subtitle));
                player.connection.send(new ClientboundSetTitleTextPacket(title));
            }
        }
    }

    public static void actionBar(LivingEntity entity, Component message) {
        if (entity instanceof ServerPlayer player) player.displayClientMessage(message, true);
    }
}

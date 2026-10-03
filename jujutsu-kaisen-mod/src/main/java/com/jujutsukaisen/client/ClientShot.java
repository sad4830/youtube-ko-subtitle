package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.hud.SlotMachineHud;
import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.domain.DomainType;
import com.jujutsukaisen.domain.Indicator;
import com.jujutsukaisen.entity.GojoEntity;
import com.jujutsukaisen.entity.SukunaEntity;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.entity.projectile.BlueEntity;
import com.jujutsukaisen.entity.projectile.DismantleEntity;
import com.jujutsukaisen.entity.projectile.FugaEntity;
import com.jujutsukaisen.entity.projectile.HollowPurpleEntity;
import com.jujutsukaisen.entity.projectile.JJKProjectile;
import com.jujutsukaisen.entity.projectile.RedEntity;
import com.jujutsukaisen.entity.projectile.WorldSlashEntity;
import com.jujutsukaisen.network.S2CSlotSpin;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.client.Minecraft;
import net.minecraft.client.Screenshot;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.Difficulty;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.level.GameRules;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

/**
 * CI only (JJK_CLIENTSHOT=1): stages scenes in a singleplayer world and saves screenshots so the
 * models, textures and effects can be reviewed without a person at the keyboard.
 */
@Mod.EventBusSubscriber(modid = JujutsuKaisen.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public final class ClientShot {
    private static final boolean ENABLED = System.getenv("JJK_CLIENTSHOT") != null;
    private static int ticks = -1;
    private static Vec3 origin = Vec3.ZERO;
    private static final List<Entity> staged = new ArrayList<>();

    private ClientShot() {
    }

    @SubscribeEvent
    public static void tick(TickEvent.ClientTickEvent event) {
        if (!ENABLED || event.phase != TickEvent.Phase.END) return;
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.level == null || mc.getSingleplayerServer() == null) return;
        if (mc.screen != null) mc.setScreen(null);
        ticks++;
        switch (ticks) {
            case 60 -> server(mc, ClientShot::stageCharacters);
            case 140 -> shot(mc, "01_characters");
            case 150 -> server(mc, s -> stageCloseup(s, 0));
            case 200 -> shot(mc, "02_gojo_sukuna_casting");
            case 210 -> server(mc, s -> stageCloseup(s, 1));
            case 250 -> shot(mc, "03_hakari");
            case 260 -> server(mc, s -> stageCloseup(s, 2));
            case 300 -> shot(mc, "04_mahoraga");
            case 310 -> server(mc, ClientShot::stageTechniques);
            case 323 -> shot(mc, "05_techniques");
            case 330 -> server(mc, ClientShot::stageShrine);
            case 390 -> shot(mc, "06_malevolent_shrine");
            case 400 -> {
                server(mc, ClientShot::clear);
                int[] reels = {7, 7, 7};
                SlotMachineHud.start(new S2CSlotSpin(reels, Indicator.GOLD.ordinal(), 3, true, 30, 12));
            }
            case 440 -> shot(mc, "07_idle_death_gamble_hud");
            case 450 -> server(mc, ClientShot::stageVoid);
            case 520 -> shot(mc, "08_unlimited_void");
            case 540 -> mc.stop();
            default -> {
            }
        }
    }

    private static void server(Minecraft mc, Consumer<ServerPlayer> action) {
        var server = mc.getSingleplayerServer();
        if (server == null) return;
        server.execute(() -> {
            ServerPlayer player = server.getPlayerList().getPlayers().isEmpty() ? null : server.getPlayerList().getPlayers().get(0);
            if (player == null) return;
            try {
                action.accept(player);
            } catch (Throwable t) {
                JujutsuKaisen.LOGGER.error("ClientShot stage failed", t);
            }
        });
    }

    private static void shot(Minecraft mc, String name) {
        Screenshot.grab(mc.gameDirectory, "jjk_" + name + ".png", mc.getMainRenderTarget(),
                message -> JujutsuKaisen.LOGGER.info("JJK-CLIENTSHOT: {}", message.getString()));
    }

    private static void clear(ServerPlayer player) {
        staged.forEach(Entity::discard);
        staged.clear();
    }

    private static <T extends Entity> T put(ServerLevel level, EntityType<T> type, double x, double y, double z, float yaw) {
        T entity = type.create(level);
        if (entity == null) throw new IllegalStateException("cannot create " + type);
        entity.moveTo(x, y, z, yaw, 0);
        if (entity instanceof Mob mob) {
            mob.finalizeSpawn(level, level.getCurrentDifficultyAt(mob.blockPosition()), MobSpawnType.COMMAND, null, null);
            mob.setNoAi(true);
            mob.setYHeadRot(yaw);
            mob.yBodyRot = yaw;
        }
        level.addFreshEntity(entity);
        staged.add(entity);
        return entity;
    }

    private static void look(ServerPlayer player, Vec3 eyeFrom, Vec3 at) {
        Vec3 d = at.subtract(eyeFrom);
        float yaw = (float) (Math.atan2(-d.x, d.z) * 180 / Math.PI);
        float pitch = (float) (-Math.atan2(d.y, d.horizontalDistance()) * 180 / Math.PI);
        player.connection.teleport(eyeFrom.x, eyeFrom.y - player.getEyeHeight(), eyeFrom.z, yaw, pitch);
    }

    private static void stageCharacters(ServerPlayer player) {
        ServerLevel level = player.serverLevel();
        level.getServer().setDifficulty(Difficulty.PEACEFUL, true);
        level.getGameRules().getRule(GameRules.RULE_DAYLIGHT).set(false, level.getServer());
        level.getGameRules().getRule(GameRules.RULE_MOBGRIEFING).set(false, level.getServer());
        level.setDayTime(6000);
        level.setWeatherParameters(6000, 0, false, false);
        player.setGameMode(net.minecraft.world.level.GameType.CREATIVE);
        SorcererData data = JJK.get(player);
        if (data != null) {
            data.setTechnique(Technique.LIMITLESS);
            data.setCursedEnergy(1100);
        }
        origin = player.position();
        // Remove fighters left over from the server smoke test so only the staged cast is on screen.
        List<Entity> leftovers = new ArrayList<>();
        for (Entity e : level.getAllEntities()) {
            if (e instanceof com.jujutsukaisen.entity.SorcererEntity || e instanceof com.jujutsukaisen.entity.MahoragaEntity) leftovers.add(e);
        }
        leftovers.forEach(Entity::discard);
        double z = origin.z + 8;
        put(level, ModEntities.SATORU_GOJO.get(), origin.x - 5.5, origin.y, z, 180);
        put(level, ModEntities.RYOMEN_SUKUNA.get(), origin.x - 1.8, origin.y, z, 180);
        put(level, ModEntities.KINJI_HAKARI.get(), origin.x + 1.8, origin.y, z, 180);
        put(level, ModEntities.MAHORAGA.get(), origin.x + 6.0, origin.y, z + 1, 200);
        look(player, origin.add(0, 2.2, 0), new Vec3(origin.x, origin.y + 1.6, z));
    }

    private static void stageCloseup(ServerPlayer player, int which) {
        double z = origin.z + 8;
        switch (which) {
            case 0 -> {
                // Gojo draws Blue and Red together; Sukuna chants the World-Cutting Slash.
                for (Entity e : staged) {
                    if (e instanceof GojoEntity gojo) gojo.getSorcererData().startCast(Ability.HOLLOW_PURPLE, 400);
                    if (e instanceof SukunaEntity sukuna) sukuna.getSorcererData().startCast(Ability.WORLD_SLASH, 400);
                }
                look(player, new Vec3(origin.x - 3.6, origin.y + 2.0, z - 4.4), new Vec3(origin.x - 3.6, origin.y + 1.3, z));
            }
            case 1 -> look(player, new Vec3(origin.x + 1.8, origin.y + 1.5, z - 4.2), new Vec3(origin.x + 1.8, origin.y + 1.25, z));
            default -> look(player, new Vec3(origin.x + 6.0, origin.y + 3.2, z - 6.5), new Vec3(origin.x + 6.0, origin.y + 2.6, z + 1));
        }
    }

    private static void stageTechniques(ServerPlayer player) {
        ServerLevel level = player.serverLevel();
        clear(player);
        double z = origin.z + 10;
        GojoEntity gojo = put(level, ModEntities.SATORU_GOJO.get(), origin.x, origin.y, z + 6, 180);
        BlueEntity blue = new BlueEntity(level, gojo, new Vec3(origin.x - 5, origin.y + 2.5, z), 7f);
        add(level, blue);
        RedEntity red = new RedEntity(level, gojo);
        red.setPos(origin.x - 2, origin.y + 2, z);
        add(level, red);
        HollowPurpleEntity purple = new HollowPurpleEntity(level, gojo, 2.4f);
        purple.setPos(origin.x + 4, origin.y + 1.2, z + 3);
        add(level, purple);
        DismantleEntity dismantle = new DismantleEntity(level, gojo, 1f, 1.4f);
        dismantle.setPos(origin.x + 1, origin.y + 1, z - 3);
        dismantle.setDeltaMovement(0.001, 0, -0.001);
        add(level, dismantle);
        FugaEntity fuga = new FugaEntity(level, gojo, false);
        fuga.setPos(origin.x - 3, origin.y + 0.5, z - 3);
        fuga.setDeltaMovement(0.001, 0, 0);
        add(level, fuga);
        WorldSlashEntity slash = new WorldSlashEntity(level, gojo, 1f);
        slash.setPos(origin.x + 8, origin.y + 6, z + 4);
        slash.setDeltaMovement(-0.001, 0, -0.001);
        add(level, slash);
        put(level, ModEntities.SHUTTER_DOOR.get(), origin.x + 1, origin.y, z - 1, 0);
        look(player, origin.add(0, 2.4, 0), new Vec3(origin.x, origin.y + 2, z));
    }

    private static void add(ServerLevel level, JJKProjectile projectile) {
        if (projectile.getDeltaMovement().lengthSqr() == 0) projectile.setDeltaMovement(0, 0.0001, 0);
        level.addFreshEntity(projectile);
        staged.add(projectile);
    }

    private static void stageShrine(ServerPlayer player) {
        ServerLevel level = player.serverLevel();
        clear(player);
        double z = origin.z + 16;
        put(level, ModEntities.MALEVOLENT_SHRINE.get(), origin.x, origin.y, z, 180);
        put(level, ModEntities.RYOMEN_SUKUNA.get(), origin.x, origin.y, z - 6, 180);
        look(player, origin.add(0, 4, -4), new Vec3(origin.x, origin.y + 6, z));
    }

    private static void stageVoid(ServerPlayer player) {
        ServerLevel level = player.serverLevel();
        clear(player);
        GojoEntity gojo = put(level, ModEntities.SATORU_GOJO.get(), origin.x, origin.y, origin.z + 4, 180);
        gojo.setNoAi(false);
        SorcererData data = gojo.getSorcererData();
        DomainManager.expand(gojo, data, DomainType.INFINITE_VOID);
        gojo.setNoAi(true);
        player.addEffect(new MobEffectInstance(ModEffects.INFORMATION_OVERLOAD.get(), 200, 0));
        look(player, origin.add(0, 1.62, 0), new Vec3(origin.x, origin.y + 1.6, origin.z + 4));
    }
}

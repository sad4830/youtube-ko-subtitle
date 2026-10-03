package com.jujutsukaisen.smoke;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.entity.GojoEntity;
import com.jujutsukaisen.entity.HakariEntity;
import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.entity.SukunaEntity;
import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.AbilityHandler;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.damagesource.DamageType;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.storage.loot.LootTable;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.event.TickEvent;

import java.util.ArrayList;
import java.util.List;

/**
 * Headless end-to-end check used by CI (JJK_SMOKETEST=1): spawns the four characters, makes them fight,
 * forces every ability and every domain once, verifies data packs, then stops the server.
 */
public final class SmokeTest {
    private static final List<String> FAILURES = new ArrayList<>();
    private static int ticks;
    private static GojoEntity gojo;
    private static SukunaEntity sukuna;
    private static HakariEntity hakari;
    private static MahoragaEntity mahoraga;
    private static MinecraftServer server;

    private SmokeTest() {
    }

    public static boolean enabled() {
        return System.getenv("JJK_SMOKETEST") != null;
    }

    public static void start(MinecraftServer srv) {
        server = srv;
        ServerLevel level = server.overworld();
        try {
            checkData(level);
            // Fight away from spawn so the client screenshot stage stays intact.
            BlockPos spawn = level.getHeightmapPos(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, level.getSharedSpawnPos().offset(80, 0, 0));
            gojo = spawn(level, ModEntities.SATORU_GOJO.get(), spawn.offset(-6, 0, 0));
            sukuna = spawn(level, ModEntities.RYOMEN_SUKUNA.get(), spawn.offset(6, 0, 0));
            hakari = spawn(level, ModEntities.KINJI_HAKARI.get(), spawn.offset(0, 0, 8));
            mahoraga = spawn(level, ModEntities.MAHORAGA.get(), spawn.offset(0, 0, -10));
            sukuna.setTarget(gojo);
            gojo.setTarget(sukuna);
            hakari.setTarget(sukuna);
            mahoraga.setTarget(gojo);
        } catch (Throwable t) {
            fail("setup: " + t);
            JujutsuKaisen.LOGGER.error("Smoke test setup failed", t);
        }
        MinecraftForge.EVENT_BUS.addListener(SmokeTest::tick);
        JujutsuKaisen.LOGGER.info("JJK-SMOKETEST: started");
    }

    private static <T extends Mob> T spawn(ServerLevel level, EntityType<T> type, BlockPos pos) {
        T mob = type.create(level);
        if (mob == null) throw new IllegalStateException("could not create " + type);
        mob.moveTo(pos.getX() + 0.5, pos.getY(), pos.getZ() + 0.5, 0, 0);
        mob.finalizeSpawn(level, level.getCurrentDifficultyAt(pos), MobSpawnType.COMMAND, null, null);
        level.addFreshEntity(mob);
        return mob;
    }

    private static void checkData(ServerLevel level) {
        String[] lootTables = {"entities/satoru_gojo", "entities/ryomen_sukuna", "entities/kinji_hakari", "entities/mahoraga"};
        for (String table : lootTables) {
            ResourceLocation id = JujutsuKaisen.id(table);
            if (server.getLootData().getLootTable(id) == LootTable.EMPTY) fail("missing loot table " + id);
        }
        String[] recipes = {"ten_shadows_talisman", "prison_realm", "fight_club_invitation", "pachinko_ball"};
        for (String recipe : recipes) {
            if (server.getRecipeManager().byKey(JujutsuKaisen.id(recipe)).isEmpty()) fail("missing recipe " + recipe);
        }
        String[] advancements = {"root", "black_flash", "domain_expansion", "vessel", "jackpot", "tame_mahoraga", "hollow_purple", "world_slash"};
        for (String adv : advancements) {
            if (server.getAdvancements().getAdvancement(JujutsuKaisen.id(adv)) == null) fail("missing advancement " + adv);
        }
        for (ResourceKey<DamageType> key : List.of(ModDamageTypes.LIMITLESS, ModDamageTypes.HOLLOW_PURPLE, ModDamageTypes.DISMANTLE,
                ModDamageTypes.CLEAVE, ModDamageTypes.FUGA, ModDamageTypes.WORLD_SLASH, ModDamageTypes.MALEVOLENT_SHRINE,
                ModDamageTypes.INFINITE_VOID, ModDamageTypes.BLACK_FLASH, ModDamageTypes.ROUGH_ENERGY, ModDamageTypes.SHUTTER_DOOR,
                ModDamageTypes.EXTERMINATION, ModDamageTypes.SPACE_CUT)) {
            if (level.registryAccess().registryOrThrow(Registries.DAMAGE_TYPE).getHolder(key).isEmpty()) fail("missing damage type " + key.location());
        }
    }

    private static void fail(String message) {
        FAILURES.add(message);
        JujutsuKaisen.LOGGER.error("JJK-SMOKETEST failure: {}", message);
    }

    private static void force(SorcererData data, net.minecraft.world.entity.LivingEntity caster, Ability ability) {
        try {
            data.clearCast();
            data.setBurnout(0);
            data.setCursedEnergy(data.getMaxCursedEnergy());
            AbilityHandler.execute(caster, data, ability);
            JujutsuKaisen.LOGGER.info("JJK-SMOKETEST: executed {}", ability);
        } catch (Throwable t) {
            fail(ability + " threw " + t);
            JujutsuKaisen.LOGGER.error("Ability failed", t);
        }
    }

    private static void tick(TickEvent.ServerTickEvent event) {
        if (event.phase != TickEvent.Phase.END) return;
        ticks++;
        if (ticks % 40 == 0) {
            for (Mob mob : new Mob[]{gojo, sukuna, hakari, mahoraga}) {
                if (mob != null && mob.isAlive()) mob.setHealth(mob.getMaxHealth());
            }
        }
        try {
            if (gojo != null && gojo.isAlive() && sukuna != null && sukuna.isAlive() && hakari != null && hakari.isAlive()) {
                switch (ticks) {
                    case 40 -> force(gojo.getSorcererData(), gojo, Ability.BLUE);
                    case 80 -> force(gojo.getSorcererData(), gojo, Ability.RED);
                    case 120 -> force(sukuna.getSorcererData(), sukuna, Ability.DISMANTLE);
                    case 140 -> force(sukuna.getSorcererData(), sukuna, Ability.WORLD_SLASH);
                    case 170 -> force(gojo.getSorcererData(), gojo, Ability.HOLLOW_PURPLE);
                    case 200 -> force(hakari.getSorcererData(), hakari, Ability.RESERVE_BALLS);
                    case 220 -> force(hakari.getSorcererData(), hakari, Ability.SHUTTER_DOORS);
                    case 240 -> force(hakari.getSorcererData(), hakari, Ability.PSEUDO_CONSECUTIVE);
                    case 260 -> force(sukuna.getSorcererData(), sukuna, Ability.FUGA);
                    case 300 -> force(gojo.getSorcererData(), gojo, Ability.DOMAIN_INFINITE_VOID);
                    case 420 -> force(sukuna.getSorcererData(), sukuna, Ability.DOMAIN_MALEVOLENT_SHRINE);
                    case 560 -> force(hakari.getSorcererData(), hakari, Ability.DOMAIN_IDLE_DEATH_GAMBLE);
                    case 700 -> DomainManager.grantJackpot(hakari, hakari.getSorcererData());
                    default -> {
                    }
                }
            }
        } catch (Throwable t) {
            fail("tick " + ticks + ": " + t);
        }
        if (ticks == 1200) finish();
    }

    private static void finish() {
        report("Gojo", gojo);
        report("Sukuna", sukuna);
        report("Hakari", hakari);
        report("Mahoraga", mahoraga);
        if (mahoraga != null) {
            JujutsuKaisen.LOGGER.info("JJK-SMOKETEST: Mahoraga wheel turns = {}, adaptations = {}",
                    mahoraga.getWheelTurns(), mahoraga.getSorcererData().adaptationView());
        }
        if (FAILURES.isEmpty()) {
            JujutsuKaisen.LOGGER.info("JJK-SMOKETEST: PASS");
        } else {
            JujutsuKaisen.LOGGER.error("JJK-SMOKETEST: FAIL {}", FAILURES);
        }
        server.halt(false);
    }

    private static void report(String name, Mob mob) {
        if (mob == null) return;
        JujutsuKaisen.LOGGER.info("JJK-SMOKETEST: {} alive={} health={}/{}", name, mob.isAlive(), mob.getHealth(), mob.getMaxHealth());
    }
}

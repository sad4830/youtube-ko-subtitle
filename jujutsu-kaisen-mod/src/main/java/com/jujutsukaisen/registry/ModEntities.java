package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.entity.GojoEntity;
import com.jujutsukaisen.entity.HakariEntity;
import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.entity.SukunaEntity;
import com.jujutsukaisen.entity.misc.MalevolentShrineEntity;
import com.jujutsukaisen.entity.misc.ShutterDoorEntity;
import com.jujutsukaisen.entity.projectile.BlueEntity;
import com.jujutsukaisen.entity.projectile.DismantleEntity;
import com.jujutsukaisen.entity.projectile.FugaEntity;
import com.jujutsukaisen.entity.projectile.HollowPurpleEntity;
import com.jujutsukaisen.entity.projectile.PachinkoBallEntity;
import com.jujutsukaisen.entity.projectile.RedEntity;
import com.jujutsukaisen.entity.projectile.WorldSlashEntity;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModEntities {
    public static final DeferredRegister<EntityType<?>> ENTITIES = DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, JujutsuKaisen.MODID);

    // ── Characters ──────────────────────────────────────────────────────────
    public static final RegistryObject<EntityType<GojoEntity>> SATORU_GOJO = ENTITIES.register("satoru_gojo",
            () -> EntityType.Builder.of(GojoEntity::new, MobCategory.MISC).sized(0.6f, 1.98f).clientTrackingRange(12).build("satoru_gojo"));
    public static final RegistryObject<EntityType<SukunaEntity>> RYOMEN_SUKUNA = ENTITIES.register("ryomen_sukuna",
            () -> EntityType.Builder.of(SukunaEntity::new, MobCategory.MONSTER).sized(0.75f, 2.3f).clientTrackingRange(12).fireImmune().build("ryomen_sukuna"));
    public static final RegistryObject<EntityType<HakariEntity>> KINJI_HAKARI = ENTITIES.register("kinji_hakari",
            () -> EntityType.Builder.of(HakariEntity::new, MobCategory.MISC).sized(0.62f, 1.95f).clientTrackingRange(12).build("kinji_hakari"));
    public static final RegistryObject<EntityType<MahoragaEntity>> MAHORAGA = ENTITIES.register("mahoraga",
            () -> EntityType.Builder.of(MahoragaEntity::new, MobCategory.MONSTER).sized(1.3f, 3.5f).clientTrackingRange(12).build("mahoraga"));

    // ── Techniques ─────────────────────────────────────────────────────────
    public static final RegistryObject<EntityType<BlueEntity>> BLUE = projectile("blue", BlueEntity::new, 1.0f, 1.0f);
    public static final RegistryObject<EntityType<RedEntity>> RED = projectile("red", RedEntity::new, 0.7f, 0.7f);
    public static final RegistryObject<EntityType<HollowPurpleEntity>> HOLLOW_PURPLE = projectile("hollow_purple", HollowPurpleEntity::new, 2.0f, 2.0f);
    public static final RegistryObject<EntityType<DismantleEntity>> DISMANTLE = projectile("dismantle", DismantleEntity::new, 1.2f, 0.4f);
    public static final RegistryObject<EntityType<WorldSlashEntity>> WORLD_SLASH = projectile("world_slash", WorldSlashEntity::new, 2.0f, 2.0f);
    public static final RegistryObject<EntityType<FugaEntity>> FUGA = projectile("fuga", FugaEntity::new, 0.6f, 0.6f);
    public static final RegistryObject<EntityType<PachinkoBallEntity>> PACHINKO_BALL = projectile("pachinko_ball", PachinkoBallEntity::new, 0.3f, 0.3f);
    public static final RegistryObject<EntityType<ShutterDoorEntity>> SHUTTER_DOOR = ENTITIES.register("shutter_door",
            () -> EntityType.Builder.<ShutterDoorEntity>of(ShutterDoorEntity::new, MobCategory.MISC).sized(1.0f, 2.5f).clientTrackingRange(10).updateInterval(1).build("shutter_door"));
    public static final RegistryObject<EntityType<MalevolentShrineEntity>> MALEVOLENT_SHRINE = ENTITIES.register("malevolent_shrine",
            () -> EntityType.Builder.<MalevolentShrineEntity>of(MalevolentShrineEntity::new, MobCategory.MISC).sized(4.0f, 6.0f).clientTrackingRange(16).updateInterval(20).fireImmune().build("malevolent_shrine"));

    private static <T extends Entity> RegistryObject<EntityType<T>> projectile(String name, EntityType.EntityFactory<T> factory, float w, float h) {
        return ENTITIES.register(name, () -> EntityType.Builder.of(factory, MobCategory.MISC).sized(w, h)
                .clientTrackingRange(10).updateInterval(1).fireImmune().build(name));
    }

    private ModEntities() {
    }
}

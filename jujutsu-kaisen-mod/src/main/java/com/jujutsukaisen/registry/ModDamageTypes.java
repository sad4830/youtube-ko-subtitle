package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageType;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

/** Data-driven damage types (data/jujutsukaisen/damage_type/*.json). */
public final class ModDamageTypes {
    public static final ResourceKey<DamageType> LIMITLESS = key("limitless");
    public static final ResourceKey<DamageType> HOLLOW_PURPLE = key("hollow_purple");
    public static final ResourceKey<DamageType> DISMANTLE = key("dismantle");
    public static final ResourceKey<DamageType> CLEAVE = key("cleave");
    public static final ResourceKey<DamageType> FUGA = key("fuga");
    public static final ResourceKey<DamageType> WORLD_SLASH = key("world_slash");
    public static final ResourceKey<DamageType> MALEVOLENT_SHRINE = key("malevolent_shrine");
    public static final ResourceKey<DamageType> INFINITE_VOID = key("infinite_void");
    public static final ResourceKey<DamageType> BLACK_FLASH = key("black_flash");
    public static final ResourceKey<DamageType> ROUGH_ENERGY = key("rough_energy");
    public static final ResourceKey<DamageType> SHUTTER_DOOR = key("shutter_door");
    public static final ResourceKey<DamageType> EXTERMINATION = key("sword_of_extermination");
    public static final ResourceKey<DamageType> SPACE_CUT = key("space_cut");

    private ModDamageTypes() {
    }

    private static ResourceKey<DamageType> key(String name) {
        return ResourceKey.create(Registries.DAMAGE_TYPE, JujutsuKaisen.id(name));
    }

    public static DamageSource source(Level level, ResourceKey<DamageType> key, @Nullable Entity direct, @Nullable Entity causing) {
        return new DamageSource(level.registryAccess().registryOrThrow(Registries.DAMAGE_TYPE).getHolderOrThrow(key), direct, causing);
    }

    public static DamageSource source(Level level, ResourceKey<DamageType> key, @Nullable Entity causing) {
        return source(level, key, causing, causing);
    }
}

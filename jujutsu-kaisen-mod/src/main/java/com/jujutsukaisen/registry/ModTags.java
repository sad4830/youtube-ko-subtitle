package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.core.registries.Registries;
import net.minecraft.tags.TagKey;
import net.minecraft.world.damagesource.DamageType;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.block.Block;

public final class ModTags {
    /** Damage that reaches a target through Infinity (domain sure-hits, World-Cutting Slash). */
    public static final TagKey<DamageType> BYPASSES_INFINITY = TagKey.create(Registries.DAMAGE_TYPE, JujutsuKaisen.id("bypasses_infinity"));
    /** Sure-hit attacks of Domain Expansions. */
    public static final TagKey<DamageType> DOMAIN_SURE_HIT = TagKey.create(Registries.DAMAGE_TYPE, JujutsuKaisen.id("domain_sure_hit"));
    /** Cutting phenomena; Mahoraga adapts to them as one family (Dismantle → Cleave). */
    public static final TagKey<DamageType> SLASHING = TagKey.create(Registries.DAMAGE_TYPE, JujutsuKaisen.id("slashing"));
    /** Cursed spirits: the Sword of Extermination's positive energy exorcises them. */
    public static final TagKey<EntityType<?>> CURSED_SPIRITS = TagKey.create(Registries.ENTITY_TYPE, JujutsuKaisen.id("cursed_spirits"));
    /** Blocks no technique may destroy. */
    public static final TagKey<Block> TECHNIQUE_IMMUNE = TagKey.create(Registries.BLOCK, JujutsuKaisen.id("technique_immune"));

    private ModTags() {
    }
}

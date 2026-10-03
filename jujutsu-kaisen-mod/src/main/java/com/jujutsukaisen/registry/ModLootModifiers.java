package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.loot.AddItemModifier;
import com.mojang.serialization.Codec;
import net.minecraftforge.common.loot.IGlobalLootModifier;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModLootModifiers {
    public static final DeferredRegister<Codec<? extends IGlobalLootModifier>> SERIALIZERS =
            DeferredRegister.create(ForgeRegistries.Keys.GLOBAL_LOOT_MODIFIER_SERIALIZERS, JujutsuKaisen.MODID);

    public static final RegistryObject<Codec<AddItemModifier>> ADD_ITEM = SERIALIZERS.register("add_item", AddItemModifier.CODEC);

    private ModLootModifiers() {
    }
}

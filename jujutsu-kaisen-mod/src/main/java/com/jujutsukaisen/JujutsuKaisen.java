package com.jujutsukaisen;

import com.jujutsukaisen.config.JJKConfig;
import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.registry.ModBlocks;
import com.jujutsukaisen.registry.ModCreativeTabs;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.registry.ModItems;
import com.jujutsukaisen.registry.ModLootModifiers;
import com.mojang.logging.LogUtils;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.ModLoadingContext;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.event.lifecycle.FMLCommonSetupEvent;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import org.slf4j.Logger;

/**
 * 주술회전 (Jujutsu Kaisen) for Forge 1.20.1 — Satoru Gojo, Ryomen Sukuna, Kinji Hakari and
 * Eight-Handled Sword Divergent Sila Divine General Mahoraga.
 */
@Mod(JujutsuKaisen.MODID)
public class JujutsuKaisen {
    public static final String MODID = "jujutsukaisen";
    public static final Logger LOGGER = LogUtils.getLogger();

    public JujutsuKaisen() {
        IEventBus modBus = FMLJavaModLoadingContext.get().getModEventBus();
        ModBlocks.BLOCKS.register(modBus);
        ModItems.ITEMS.register(modBus);
        ModEntities.ENTITIES.register(modBus);
        ModEffects.EFFECTS.register(modBus);
        ModCreativeTabs.TABS.register(modBus);
        ModLootModifiers.SERIALIZERS.register(modBus);
        modBus.addListener(this::commonSetup);
        ModLoadingContext.get().registerConfig(ModConfig.Type.COMMON, JJKConfig.SPEC);
    }

    private void commonSetup(FMLCommonSetupEvent event) {
        event.enqueueWork(ModNetwork::register);
    }

    public static ResourceLocation id(String path) {
        return new ResourceLocation(MODID, path);
    }
}

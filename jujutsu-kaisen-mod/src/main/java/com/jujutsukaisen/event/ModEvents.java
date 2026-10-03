package com.jujutsukaisen.event;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.entity.GojoEntity;
import com.jujutsukaisen.entity.HakariEntity;
import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.entity.SukunaEntity;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraftforge.common.capabilities.RegisterCapabilitiesEvent;
import net.minecraftforge.event.entity.EntityAttributeCreationEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = JujutsuKaisen.MODID, bus = Mod.EventBusSubscriber.Bus.MOD)
public final class ModEvents {
    private ModEvents() {
    }

    @SubscribeEvent
    public static void attributes(EntityAttributeCreationEvent event) {
        event.put(ModEntities.SATORU_GOJO.get(), GojoEntity.createAttributes().build());
        event.put(ModEntities.RYOMEN_SUKUNA.get(), SukunaEntity.createAttributes().build());
        event.put(ModEntities.KINJI_HAKARI.get(), HakariEntity.createAttributes().build());
        event.put(ModEntities.MAHORAGA.get(), MahoragaEntity.createAttributes().build());
    }

    @SubscribeEvent
    public static void capabilities(RegisterCapabilitiesEvent event) {
        event.register(SorcererData.class);
    }
}

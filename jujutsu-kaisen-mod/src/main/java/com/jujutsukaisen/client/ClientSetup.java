package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.hud.CursedEnergyHud;
import com.jujutsukaisen.client.hud.InfiniteVoidOverlay;
import com.jujutsukaisen.client.hud.SlotMachineHud;
import com.jujutsukaisen.client.model.MahoragaModel;
import com.jujutsukaisen.client.model.MalevolentShrineModel;
import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.client.model.ShutterDoorModel;
import com.jujutsukaisen.client.model.SukunaModel;
import com.jujutsukaisen.client.render.DharmaWheelLayer;
import com.jujutsukaisen.client.render.FugaRenderer;
import com.jujutsukaisen.client.render.MahoragaRenderer;
import com.jujutsukaisen.client.render.MalevolentShrineRenderer;
import com.jujutsukaisen.client.render.OrbRenderer;
import com.jujutsukaisen.client.render.ShutterDoorRenderer;
import com.jujutsukaisen.client.render.SlashRenderer;
import com.jujutsukaisen.client.render.SorcererRenderer;
import com.jujutsukaisen.registry.ModEntities;
import net.minecraft.client.renderer.entity.ThrownItemRenderer;
import net.minecraft.client.renderer.entity.player.PlayerRenderer;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.RegisterGuiOverlaysEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.client.gui.overlay.VanillaGuiOverlay;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = JujutsuKaisen.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientSetup {
    private ClientSetup() {
    }

    @SubscribeEvent
    public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.SATORU_GOJO.get(),
                ctx -> SorcererRenderer.human(ctx, JujutsuKaisen.id("textures/entity/satoru_gojo.png"), 1.04f));
        event.registerEntityRenderer(ModEntities.KINJI_HAKARI.get(),
                ctx -> SorcererRenderer.human(ctx, JujutsuKaisen.id("textures/entity/kinji_hakari.png"), 1.03f));
        event.registerEntityRenderer(ModEntities.RYOMEN_SUKUNA.get(),
                ctx -> new SorcererRenderer<>(ctx, new SukunaModel(ctx.bakeLayer(ModLayers.SUKUNA)),
                        JujutsuKaisen.id("textures/entity/ryomen_sukuna.png"), 1.18f));
        event.registerEntityRenderer(ModEntities.MAHORAGA.get(), MahoragaRenderer::new);

        event.registerEntityRenderer(ModEntities.BLUE.get(), ctx -> new OrbRenderer<>(ctx, OrbRenderer.Kind.BLUE));
        event.registerEntityRenderer(ModEntities.RED.get(), ctx -> new OrbRenderer<>(ctx, OrbRenderer.Kind.RED));
        event.registerEntityRenderer(ModEntities.HOLLOW_PURPLE.get(), ctx -> new OrbRenderer<>(ctx, OrbRenderer.Kind.PURPLE));
        event.registerEntityRenderer(ModEntities.DISMANTLE.get(), SlashRenderer::new);
        event.registerEntityRenderer(ModEntities.WORLD_SLASH.get(), SlashRenderer::new);
        event.registerEntityRenderer(ModEntities.FUGA.get(), FugaRenderer::new);
        event.registerEntityRenderer(ModEntities.PACHINKO_BALL.get(), ctx -> new ThrownItemRenderer<>(ctx, 0.7f, true));
        event.registerEntityRenderer(ModEntities.SHUTTER_DOOR.get(), ShutterDoorRenderer::new);
        event.registerEntityRenderer(ModEntities.MALEVOLENT_SHRINE.get(), MalevolentShrineRenderer::new);
    }

    @SubscribeEvent
    public static void registerLayers(EntityRenderersEvent.RegisterLayerDefinitions event) {
        event.registerLayerDefinition(ModLayers.SUKUNA, SukunaModel::createBodyLayer);
        event.registerLayerDefinition(ModLayers.MAHORAGA, MahoragaModel::createBodyLayer);
        event.registerLayerDefinition(ModLayers.DHARMA_WHEEL, MahoragaModel::createWheelLayer);
        event.registerLayerDefinition(ModLayers.MALEVOLENT_SHRINE, MalevolentShrineModel::createBodyLayer);
        event.registerLayerDefinition(ModLayers.SHUTTER_DOOR, ShutterDoorModel::createBodyLayer);
    }

    @SubscribeEvent
    public static void addLayers(EntityRenderersEvent.AddLayers event) {
        for (String skin : event.getSkins()) {
            if (event.getSkin(skin) instanceof PlayerRenderer renderer) {
                renderer.addLayer(new DharmaWheelLayer(renderer, event.getEntityModels()));
            }
        }
    }

    @SubscribeEvent
    public static void registerKeys(RegisterKeyMappingsEvent event) {
        event.register(KeyBindings.USE);
        event.register(KeyBindings.CYCLE);
        event.register(KeyBindings.DOMAIN);
        event.register(KeyBindings.RCT);
        event.register(KeyBindings.INFINITY);
    }

    @SubscribeEvent
    public static void registerOverlays(RegisterGuiOverlaysEvent event) {
        event.registerBelow(VanillaGuiOverlay.HOTBAR.id(), "infinite_void", InfiniteVoidOverlay.INSTANCE);
        event.registerAbove(VanillaGuiOverlay.HOTBAR.id(), "cursed_energy", CursedEnergyHud.INSTANCE);
        event.registerAboveAll("slot_machine", SlotMachineHud.INSTANCE);
    }
}

package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.network.C2SKeyAction;
import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.client.hud.CursedEnergyHud;
import com.jujutsukaisen.client.render.CharacterPlayerRenderer;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.util.Mth;
import net.minecraftforge.client.event.CustomizeGuiOverlayEvent;
import net.minecraftforge.client.event.RenderArmEvent;
import net.minecraftforge.client.event.RenderGuiEvent;
import net.minecraftforge.client.event.RenderPlayerEvent;
import net.minecraft.client.gui.screens.Screen;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = JujutsuKaisen.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public final class ClientForgeEvents {
    private static boolean rctHeld;

    private ClientForgeEvents() {
    }

    @SubscribeEvent
    public static void clientTick(TickEvent.ClientTickEvent event) {
        if (event.phase != TickEvent.Phase.END) return;
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.level == null) return;
        while (KeyBindings.USE.consumeClick()) send(C2SKeyAction.Action.USE);
        while (KeyBindings.CYCLE.consumeClick()) send(Screen.hasShiftDown() ? C2SKeyAction.Action.PREVIOUS : C2SKeyAction.Action.NEXT);
        while (KeyBindings.DOMAIN.consumeClick()) send(C2SKeyAction.Action.DOMAIN);
        while (KeyBindings.INFINITY.consumeClick()) send(C2SKeyAction.Action.TOGGLE_INFINITY);
        while (KeyBindings.APPEARANCE.consumeClick()) send(C2SKeyAction.Action.TOGGLE_APPEARANCE);
        boolean held = KeyBindings.RCT.isDown() && mc.screen == null;
        if (held != rctHeld) {
            rctHeld = held;
            send(held ? C2SKeyAction.Action.RCT_START : C2SKeyAction.Action.RCT_STOP);
        }
    }

    /**
     * Players who became a character are drawn by the character renderer. Highest priority, so listeners that
     * do not receive canceled events only ever see that renderer's balanced Pre/Post pair.
     */
    @SubscribeEvent(priority = EventPriority.HIGHEST)
    public static void renderPlayer(RenderPlayerEvent.Pre event) {
        if (event.getRenderer() instanceof CharacterPlayerRenderer) return;
        if (!(event.getEntity() instanceof AbstractClientPlayer player)) return;
        CharacterPlayerRenderer renderer = CharacterRenderers.pick(player);
        if (renderer == null) return;
        event.setCanceled(true);
        float yaw = Mth.lerp(event.getPartialTick(), player.yRotO, player.getYRot());
        renderer.render(player, yaw, event.getPartialTick(), event.getPoseStack(), event.getMultiBufferSource(), event.getPackedLight());
    }

    /** First-person bare hands in the character's skin (and in a neutral pose while casting). */
    @SubscribeEvent
    public static void renderArm(RenderArmEvent event) {
        AbstractClientPlayer player = event.getPlayer();
        CharacterPlayerRenderer renderer = CharacterRenderers.pickHand(player);
        if (renderer == null) return;
        event.setCanceled(true);
        renderer.renderCharacterHand(event.getPoseStack(), event.getMultiBufferSource(), event.getPackedLight(), player, event.getArm());
    }

    @SubscribeEvent
    public static void bossBar(CustomizeGuiOverlayEvent.BossEventProgress event) {
        CursedEnergyHud.bossBarAt(event.getY());
    }

    @SubscribeEvent
    public static void guiFrame(RenderGuiEvent.Pre event) {
        CursedEnergyHud.frameStart();
    }

    private static void send(C2SKeyAction.Action action) {
        ModNetwork.CHANNEL.sendToServer(new C2SKeyAction(action));
    }
}

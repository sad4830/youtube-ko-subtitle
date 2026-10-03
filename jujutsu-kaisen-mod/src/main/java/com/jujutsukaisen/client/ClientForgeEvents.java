package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.network.C2SKeyAction;
import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.client.render.CharacterPlayerRenderer;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.util.Mth;
import net.minecraftforge.client.event.RenderArmEvent;
import net.minecraftforge.client.event.RenderPlayerEvent;
import net.minecraft.client.gui.screens.Screen;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.event.TickEvent;
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

    /** Players who became a character (or are mid-cast) are drawn by the character renderer. */
    @SubscribeEvent
    public static void renderPlayer(RenderPlayerEvent.Pre event) {
        if (event.getRenderer() instanceof CharacterPlayerRenderer) return;
        if (!(event.getEntity() instanceof AbstractClientPlayer player)) return;
        CharacterPlayerRenderer renderer = CharacterRenderers.pick(player);
        if (renderer == null) return;
        event.setCanceled(true);
        float yaw = Mth.lerp(event.getPartialTick(), player.yRotO, player.getYRot());
        renderer.render(player, yaw, event.getPartialTick(), event.getPoseStack(), event.getMultiBufferSource(), event.getPackedLight());
    }

    /** First-person bare hands in the character's skin. */
    @SubscribeEvent
    public static void renderArm(RenderArmEvent event) {
        AbstractClientPlayer player = event.getPlayer();
        SorcererData data = JJK.get(player);
        if (data == null || !data.hasAppearance()) return;
        CharacterPlayerRenderer renderer = CharacterRenderers.forCharacter(data.getTechnique());
        if (renderer == null) return;
        event.setCanceled(true);
        renderer.renderCharacterHand(event.getPoseStack(), event.getMultiBufferSource(), event.getPackedLight(), player, event.getArm());
    }

    private static void send(C2SKeyAction.Action action) {
        ModNetwork.CHANNEL.sendToServer(new C2SKeyAction(action));
    }
}

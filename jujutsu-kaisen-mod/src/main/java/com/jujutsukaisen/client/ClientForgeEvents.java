package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.network.C2SKeyAction;
import com.jujutsukaisen.network.ModNetwork;
import net.minecraft.client.Minecraft;
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
        boolean held = KeyBindings.RCT.isDown() && mc.screen == null;
        if (held != rctHeld) {
            rctHeld = held;
            send(held ? C2SKeyAction.Action.RCT_START : C2SKeyAction.Action.RCT_STOP);
        }
    }

    private static void send(C2SKeyAction.Action action) {
        ModNetwork.CHANNEL.sendToServer(new C2SKeyAction(action));
    }
}

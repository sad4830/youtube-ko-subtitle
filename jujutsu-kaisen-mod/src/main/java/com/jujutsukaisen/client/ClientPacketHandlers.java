package com.jujutsukaisen.client;

import com.jujutsukaisen.client.hud.SlotMachineHud;
import com.jujutsukaisen.network.S2CSlotSpin;
import com.jujutsukaisen.network.S2CSyncSorcerer;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.Level;

/** Client side of the S2C packets; only ever loaded on the physical client. */
public final class ClientPacketHandlers {
    private ClientPacketHandlers() {
    }

    public static void syncSorcerer(S2CSyncSorcerer message) {
        Level level = Minecraft.getInstance().level;
        if (level == null) return;
        Entity entity = level.getEntity(message.entityId);
        SorcererData data = JJK.get(entity);
        if (data != null) data.loadSync(message.tag);
    }

    public static void slotSpin(S2CSlotSpin message) {
        if (message.ticks == S2CSlotSpin.STOP) SlotMachineHud.stop();
        else SlotMachineHud.start(message);
    }
}

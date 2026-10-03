package com.jujutsukaisen.network;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraft.world.entity.LivingEntity;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.NetworkRegistry;
import net.minecraftforge.network.PacketDistributor;
import net.minecraftforge.network.simple.SimpleChannel;

public final class ModNetwork {
    private static final String VERSION = "1";
    public static final SimpleChannel CHANNEL = NetworkRegistry.newSimpleChannel(JujutsuKaisen.id("main"),
            () -> VERSION, VERSION::equals, VERSION::equals);

    private ModNetwork() {
    }

    public static void register() {
        int id = 0;
        CHANNEL.messageBuilder(C2SKeyAction.class, id++, NetworkDirection.PLAY_TO_SERVER)
                .encoder(C2SKeyAction::encode).decoder(C2SKeyAction::new).consumerMainThread(C2SKeyAction::handle).add();
        CHANNEL.messageBuilder(S2CSyncSorcerer.class, id++, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(S2CSyncSorcerer::encode).decoder(S2CSyncSorcerer::new).consumerMainThread(S2CSyncSorcerer::handle).add();
        CHANNEL.messageBuilder(S2CSlotSpin.class, id++, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(S2CSlotSpin::encode).decoder(S2CSlotSpin::new).consumerMainThread(S2CSlotSpin::handle).add();
    }

    /** Sends the entity's jujutsu state to itself (if a player) and everyone tracking it. */
    public static void sync(LivingEntity entity, SorcererData data) {
        CHANNEL.send(PacketDistributor.TRACKING_ENTITY_AND_SELF.with(() -> entity), new S2CSyncSorcerer(entity.getId(), data.saveSync()));
    }
}

package com.jujutsukaisen.network;

import com.jujutsukaisen.client.ClientPacketHandlers;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

public class S2CSyncSorcerer {
    public final int entityId;
    public final CompoundTag tag;

    public S2CSyncSorcerer(int entityId, CompoundTag tag) {
        this.entityId = entityId;
        this.tag = tag;
    }

    public S2CSyncSorcerer(FriendlyByteBuf buf) {
        this.entityId = buf.readVarInt();
        this.tag = buf.readNbt();
    }

    public void encode(FriendlyByteBuf buf) {
        buf.writeVarInt(entityId);
        buf.writeNbt(tag);
    }

    public void handle(Supplier<NetworkEvent.Context> context) {
        DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () -> ClientPacketHandlers.syncSorcerer(this));
    }
}

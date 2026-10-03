package com.jujutsukaisen.network;

import com.jujutsukaisen.client.ClientPacketHandlers;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

/** Idle Death Gamble: the reels spin for everyone in and around the domain. */
public class S2CSlotSpin {
    public final int[] reels;
    public final int indicator;
    public final int riichi;
    public final boolean win;
    public final int ticks;
    public final int spin;

    public S2CSlotSpin(int[] reels, int indicator, int riichi, boolean win, int ticks, int spin) {
        this.reels = reels;
        this.indicator = indicator;
        this.riichi = riichi;
        this.win = win;
        this.ticks = ticks;
        this.spin = spin;
    }

    public S2CSlotSpin(FriendlyByteBuf buf) {
        this.reels = buf.readVarIntArray();
        this.indicator = buf.readByte();
        this.riichi = buf.readByte();
        this.win = buf.readBoolean();
        this.ticks = buf.readVarInt();
        this.spin = buf.readVarInt();
    }

    public void encode(FriendlyByteBuf buf) {
        buf.writeVarIntArray(reels);
        buf.writeByte(indicator);
        buf.writeByte(riichi);
        buf.writeBoolean(win);
        buf.writeVarInt(ticks);
        buf.writeVarInt(spin);
    }

    public void handle(Supplier<NetworkEvent.Context> context) {
        DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () -> ClientPacketHandlers.slotSpin(this));
    }
}

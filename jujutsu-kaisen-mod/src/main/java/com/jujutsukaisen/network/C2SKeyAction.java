package com.jujutsukaisen.network;

import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.domain.DomainType;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.AbilityHandler;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.ChatFormatting;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

/** A jujutsu key was pressed on the client. */
public class C2SKeyAction {
    public enum Action {
        USE, NEXT, PREVIOUS, DOMAIN, RCT_START, RCT_STOP, TOGGLE_INFINITY
    }

    private final Action action;

    public C2SKeyAction(Action action) {
        this.action = action;
    }

    public C2SKeyAction(FriendlyByteBuf buf) {
        this.action = buf.readEnum(Action.class);
    }

    public void encode(FriendlyByteBuf buf) {
        buf.writeEnum(action);
    }

    public void handle(Supplier<NetworkEvent.Context> context) {
        ServerPlayer player = context.get().getSender();
        if (player == null || player.isSpectator()) return;
        SorcererData data = JJK.get(player);
        if (data == null) return;
        Technique technique = data.getTechnique();
        switch (action) {
            case USE -> {
                Ability ability = data.getSelectedAbility();
                if (ability == null) {
                    tell(player, "message.jujutsukaisen.no_technique");
                } else {
                    AbilityHandler.tryUse(player, data, ability);
                }
            }
            case NEXT -> data.cycle(1);
            case PREVIOUS -> data.cycle(-1);
            case DOMAIN -> {
                if (DomainManager.cancel(player)) return;
                DomainType type = technique.domain();
                if (type == null) {
                    tell(player, "message.jujutsukaisen.no_domain");
                } else {
                    AbilityHandler.tryUse(player, data, type.ability());
                }
            }
            case RCT_START -> {
                if (technique.canUseRct()) {
                    data.setRctActive(true);
                } else if (!data.isJackpot()) {
                    tell(player, "message.jujutsukaisen.no_rct");
                }
            }
            case RCT_STOP -> data.setRctActive(false);
            case TOGGLE_INFINITY -> {
                if (technique == Technique.LIMITLESS) {
                    data.setInfinityEnabled(!data.isInfinityEnabled());
                    player.displayClientMessage(Component.translatable(data.isInfinityEnabled()
                            ? "message.jujutsukaisen.infinity_on" : "message.jujutsukaisen.infinity_off").withStyle(ChatFormatting.AQUA), true);
                }
            }
        }
    }

    private static void tell(ServerPlayer player, String key) {
        player.displayClientMessage(Component.translatable(key).withStyle(ChatFormatting.RED), true);
    }
}

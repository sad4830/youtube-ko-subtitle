package com.jujutsukaisen.item;

import com.jujutsukaisen.sorcery.Adaptation;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;
import java.util.Map;

/**
 * 법진 — Mahoraga's eight-handled wheel. As Sukuna did in Shinjuku, whoever bears the wheel (hold it in
 * the off hand) carries the burden of adaptation: each turn hardens them against a phenomenon.
 */
public class DharmaWheelItem extends Item {
    public DharmaWheelItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (!level.isClientSide) {
            SorcererData data = JJK.get(player);
            if (data != null) {
                player.sendSystemMessage(Component.translatable("message.jujutsukaisen.wheel_status").withStyle(ChatFormatting.GOLD));
                if (data.adaptationView().isEmpty()) {
                    player.sendSystemMessage(Component.translatable("message.jujutsukaisen.wheel_none").withStyle(ChatFormatting.GRAY));
                }
                for (Map.Entry<String, Integer> entry : data.adaptationView().entrySet()) {
                    player.sendSystemMessage(Component.literal(" • ").append(Component.translatable("adaptation.jujutsukaisen." + entry.getKey()))
                            .append(Component.literal(" " + Math.min(entry.getValue(), Adaptation.MAX) + "/" + Adaptation.MAX)).withStyle(ChatFormatting.YELLOW));
                }
            }
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.jujutsukaisen.dharma_wheel.desc1").withStyle(ChatFormatting.GOLD));
        tooltip.add(Component.translatable("item.jujutsukaisen.dharma_wheel.desc2").withStyle(ChatFormatting.GRAY));
    }
}

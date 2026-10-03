package com.jujutsukaisen.item;

import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * A cursed technique engraved into a talisman, taken from a defeated sorcerer. Using it engraves the
 * technique into your own brain (replacing any other).
 */
public class TechniqueImprintItem extends Item {
    private final Technique technique;

    public TechniqueImprintItem(Technique technique, Properties properties) {
        super(properties);
        this.technique = technique;
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (!level.isClientSide && player instanceof ServerPlayer serverPlayer) {
            SorcererData data = JJK.get(player);
            if (data == null) return InteractionResultHolder.fail(stack);
            if (data.getTechnique() == technique) {
                player.displayClientMessage(Component.translatable("message.jujutsukaisen.already_technique").withStyle(ChatFormatting.GRAY), true);
                return InteractionResultHolder.fail(stack);
            }
            data.setTechnique(technique);
            data.setCursedEnergy(data.getMaxCursedEnergy());
            // Taking the technique of a sorcerer you defeated, you also take on their look (toggle with the key).
            data.setAppearance(true);
            ModNetwork.sync(player, data);
            player.sendSystemMessage(Component.translatable("message.jujutsukaisen.technique_gained", technique.displayName()).withStyle(ChatFormatting.GOLD));
            player.sendSystemMessage(Component.translatable("message.jujutsukaisen.appearance_hint",
                    Component.translatable("entity.jujutsukaisen." + technique.character())).withStyle(ChatFormatting.GRAY));
            Fx.burst(level, technique == Technique.LIMITLESS ? Fx.BLUE : Fx.GOLD, player.position().add(0, 1, 0), 60, 0.6, 0.1);
            Fx.sound(player, SoundEvents.PLAYER_LEVELUP, 1.0f, 0.6f);
            Advancements.award(serverPlayer, technique == Technique.LIMITLESS ? "limitless" : "idle_death_gamble");
            if (!player.getAbilities().instabuild) stack.shrink(1);
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    @Override
    public boolean isFoil(ItemStack stack) {
        return true;
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(technique.displayName());
        tooltip.add(Component.translatable("item.jujutsukaisen.technique_imprint.desc").withStyle(ChatFormatting.GRAY));
    }
}

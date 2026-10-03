package com.jujutsukaisen.item;

import com.jujutsukaisen.entity.SukunaEntity;
import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.npc.AbstractVillager;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * 스쿠나의 손가락 — one of the twenty mummified fingers of Ryomen Sukuna, a special-grade cursed object.
 * It is deadly poison to ordinary people; a vessel who eats it gains Sukuna's power (and his Shrine).
 * Fed to a villager, it becomes the vessel through which the King of Curses incarnates.
 */
public class SukunaFingerItem extends Item {
    public SukunaFingerItem(Properties properties) {
        super(properties);
    }

    @Override
    public ItemStack finishUsingItem(ItemStack stack, Level level, LivingEntity entity) {
        if (!level.isClientSide && entity instanceof ServerPlayer player) {
            SorcererData data = JJK.get(player);
            if (data != null) consume(player, data);
        }
        return super.finishUsingItem(stack, level, entity);
    }

    private static void consume(ServerPlayer player, SorcererData data) {
        Technique technique = data.getTechnique();
        if (technique != Technique.NONE && technique != Technique.SHRINE) {
            // Not a vessel: the finger is poison.
            player.addEffect(new MobEffectInstance(MobEffects.WITHER, 20 * 12, 1));
            player.addEffect(new MobEffectInstance(MobEffects.CONFUSION, 20 * 10, 0));
            player.addEffect(new MobEffectInstance(MobEffects.POISON, 20 * 12, 2));
            player.sendSystemMessage(Component.translatable("message.jujutsukaisen.finger_poison").withStyle(ChatFormatting.DARK_RED));
            return;
        }
        if (technique == Technique.NONE) {
            data.setTechnique(Technique.SHRINE);
            player.sendSystemMessage(Component.translatable("message.jujutsukaisen.vessel").withStyle(ChatFormatting.RED, ChatFormatting.BOLD));
            Advancements.award(player, "vessel");
        }
        if (data.getFingers() >= SorcererData.MAX_FINGERS) {
            player.displayClientMessage(Component.translatable("message.jujutsukaisen.finger_max").withStyle(ChatFormatting.GRAY), true);
            return;
        }
        data.setFingers(data.getFingers() + 1);
        data.setCursedEnergy(data.getMaxCursedEnergy());
        player.displayClientMessage(Component.translatable("message.jujutsukaisen.finger_eaten", data.getFingers(), SorcererData.MAX_FINGERS)
                .withStyle(ChatFormatting.DARK_RED), true);
        Fx.burst(player.level(), Fx.BLACK, player.position().add(0, 1, 0), 40, 0.5, 0.05);
        Fx.burst(player.level(), Fx.CRIMSON, player.position().add(0, 1, 0), 30, 0.6, 0.05);
        Fx.sound(player, SoundEvents.WITHER_AMBIENT, 1.0f, 0.6f);
        if (data.getFingers() >= SorcererData.MAX_FINGERS) Advancements.award(player, "twenty_fingers");
        ModNetwork.sync(player, data);
    }

    @Override
    public InteractionResult interactLivingEntity(ItemStack stack, Player player, LivingEntity target, InteractionHand hand) {
        return target instanceof AbstractVillager villager ? incarnate(stack, player, villager) : InteractionResult.PASS;
    }

    /**
     * Feeding a finger to a villager makes Sukuna incarnate in them. Called from PlayerInteractEvent.EntityInteract,
     * because villagers and wandering traders take the right-click for trading before the item ever sees it.
     */
    public static InteractionResult incarnate(ItemStack stack, Player player, AbstractVillager villager) {
        if (player.level() instanceof ServerLevel server) {
            SukunaEntity sukuna = ModEntities.RYOMEN_SUKUNA.get().create(server);
            if (sukuna == null) return InteractionResult.PASS;
            sukuna.moveTo(villager.getX(), villager.getY(), villager.getZ(), villager.getYRot(), 0);
            sukuna.finalizeSpawn(server, server.getCurrentDifficultyAt(villager.blockPosition()), MobSpawnType.TRIGGERED, null, null);
            villager.discard();
            server.addFreshEntity(sukuna);
            sukuna.setTarget(player);
            Fx.burst(server, Fx.BLACK, sukuna.position().add(0, 1, 0), 150, 1.0, 0.1);
            Fx.burst(server, ParticleTypes.SOUL, sukuna.position().add(0, 1, 0), 60, 0.8, 0.05);
            Fx.sound(server, sukuna.position(), SoundEvents.WITHER_SPAWN, 2.0f, 0.7f);
            Fx.sound(server, sukuna.position(), SoundEvents.LIGHTNING_BOLT_THUNDER, 2.0f, 0.6f);
            Fx.title(server, sukuna.position(), 48, Component.translatable("entity.jujutsukaisen.ryomen_sukuna").withStyle(ChatFormatting.DARK_RED, ChatFormatting.BOLD),
                    Component.translatable("message.jujutsukaisen.incarnation").withStyle(ChatFormatting.RED));
            if (!player.getAbilities().instabuild) stack.shrink(1);
        }
        return InteractionResult.sidedSuccess(player.level().isClientSide);
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.jujutsukaisen.sukuna_finger.desc1").withStyle(ChatFormatting.DARK_RED));
        tooltip.add(Component.translatable("item.jujutsukaisen.sukuna_finger.desc2").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("item.jujutsukaisen.sukuna_finger.desc3").withStyle(ChatFormatting.GRAY));
    }
}

package com.jujutsukaisen.item;

import com.jujutsukaisen.entity.GojoEntity;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/** 옥문강 — the Prison Realm that sealed Satoru Gojo. Open it and the strongest walks out. */
public class PrisonRealmItem extends Item {
    public PrisonRealmItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (level instanceof ServerLevel server) {
            GojoEntity gojo = ModEntities.SATORU_GOJO.get().create(server);
            if (gojo == null) return InteractionResultHolder.fail(stack);
            Vec3 pos = player.position().add(Vec3.directionFromRotation(0, player.getYRot()).scale(3.0));
            gojo.moveTo(pos.x, pos.y, pos.z, player.getYRot() + 180, 0);
            gojo.finalizeSpawn(server, server.getCurrentDifficultyAt(player.blockPosition()), MobSpawnType.MOB_SUMMONED, null, null);
            server.addFreshEntity(gojo);
            Fx.burst(server, Fx.BLUE, pos.add(0, 1, 0), 120, 0.8, 0.1);
            Fx.burst(server, ParticleTypes.FLASH, pos.add(0, 1, 0), 1, 0, 0);
            Fx.sound(server, pos, SoundEvents.END_PORTAL_SPAWN, 1.5f, 1.4f);
            Fx.title(server, pos, 48, Component.translatable("entity.jujutsukaisen.satoru_gojo").withStyle(ChatFormatting.AQUA, ChatFormatting.BOLD),
                    Component.translatable("message.jujutsukaisen.prison_realm_open").withStyle(ChatFormatting.WHITE));
            Fx.say(gojo, "line.jujutsukaisen.gojo.released", 32);
            if (!player.getAbilities().instabuild) stack.shrink(1);
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.jujutsukaisen.prison_realm.desc").withStyle(ChatFormatting.GRAY));
    }
}

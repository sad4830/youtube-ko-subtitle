package com.jujutsukaisen.item;

import com.jujutsukaisen.domain.Indicator;
import com.jujutsukaisen.entity.projectile.PachinkoBallEntity;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;

/** A silver pachinko ball. Throw it. */
public class PachinkoBallItem extends Item {
    public PachinkoBallItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        level.playSound(null, player.getX(), player.getY(), player.getZ(), SoundEvents.SNOWBALL_THROW, SoundSource.PLAYERS, 0.5f, 1.6f);
        if (!level.isClientSide) {
            PachinkoBallEntity ball = new PachinkoBallEntity(level, player, Indicator.roll(level.random, false), 2.5f);
            ball.setItem(stack);
            ball.shootFromRotation(player, player.getXRot(), player.getYRot(), 0.0f, 1.7f, 1.0f);
            level.addFreshEntity(ball);
        }
        player.getCooldowns().addCooldown(this, 4);
        if (!player.getAbilities().instabuild) stack.shrink(1);
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }
}

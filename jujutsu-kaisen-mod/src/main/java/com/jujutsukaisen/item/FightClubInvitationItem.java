package com.jujutsukaisen.item;

import com.jujutsukaisen.entity.HakariEntity;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
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

/** An invitation to Hakari's underground fight club at Jujutsu High. He loves the fever of a real fight. */
public class FightClubInvitationItem extends Item {
    public FightClubInvitationItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (level instanceof ServerLevel server) {
            HakariEntity hakari = ModEntities.KINJI_HAKARI.get().create(server);
            if (hakari == null) return InteractionResultHolder.fail(stack);
            Vec3 pos = arenaSpot(server, hakari, player);
            hakari.moveTo(pos.x, pos.y, pos.z, player.getYRot() + 180, 0);
            hakari.finalizeSpawn(server, server.getCurrentDifficultyAt(player.blockPosition()), MobSpawnType.MOB_SUMMONED, null, null);
            hakari.setXpReward(60); // an invitation costs a few ingots: not a 250-XP farm
            server.addFreshEntity(hakari);
            hakari.setChallenger(player);
            Fx.burst(server, Fx.GOLD, pos.add(0, 1, 0), 80, 0.8, 0.1);
            Fx.burst(server, ParticleTypes.FIREWORK, pos.add(0, 1, 0), 40, 0.6, 0.15);
            Fx.sound(server, pos, SoundEvents.NOTE_BLOCK_BELL.value(), 2.0f, 1.2f);
            Fx.title(server, pos, 48, Component.translatable("entity.jujutsukaisen.kinji_hakari").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD),
                    Component.translatable("message.jujutsukaisen.fight_club").withStyle(ChatFormatting.YELLOW));
            if (!player.getAbilities().instabuild) stack.shrink(1);
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    /** Up to 6 blocks in front of the player, on solid ground with room to stand; else right beside them. */
    private static Vec3 arenaSpot(ServerLevel level, HakariEntity hakari, Player player) {
        Vec3 forward = Vec3.directionFromRotation(0, player.getYRot());
        for (int distance = 6; distance >= 2; distance--) {
            for (int dy : new int[]{0, 1, -1, 2, -2}) {
                Vec3 pos = player.position().add(forward.scale(distance)).add(0, dy, 0);
                BlockPos feet = BlockPos.containing(pos);
                pos = new Vec3(pos.x, feet.getY(), pos.z);
                BlockPos below = feet.below();
                if (!level.getBlockState(below).isFaceSturdy(level, below, Direction.UP)) continue;
                if (level.noCollision(hakari, hakari.getType().getAABB(pos.x, pos.y, pos.z))) return pos;
            }
        }
        return player.position();
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.jujutsukaisen.fight_club_invitation.desc").withStyle(ChatFormatting.GRAY));
    }
}

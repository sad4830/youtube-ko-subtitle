package com.jujutsukaisen.item;

import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.registry.ModEntities;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
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

/**
 * 십종영법술 — a Ten Shadows talisman. 「布瑠部由良由良」 (후루베 유라유라): an untamed Mahoraga starts the
 * taming ritual and attacks everyone dragged into it, summoner included. Defeat it alone, by your own
 * hand, and it is yours to summon.
 */
public class TenShadowsTalismanItem extends Item {
    private static final float SUMMON_COST = 400f;
    private static final int TAMED_LIFETIME = 20 * 90;

    public TenShadowsTalismanItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (!(level instanceof ServerLevel server) || !(player instanceof ServerPlayer serverPlayer)) {
            return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
        }
        SorcererData data = JJK.get(player);
        if (data == null) return InteractionResultHolder.fail(stack);
        MahoragaEntity mahoraga = ModEntities.MAHORAGA.get().create(server);
        if (mahoraga == null) return InteractionResultHolder.fail(stack);

        Vec3 forward = Vec3.directionFromRotation(0, player.getYRot());
        Vec3 pos = player.position().add(forward.scale(data.isMahoragaTamed() ? -2.0 : 6.0));
        mahoraga.moveTo(pos.x, pos.y, pos.z, player.getYRot() + (data.isMahoragaTamed() ? 0 : 180), 0);
        mahoraga.finalizeSpawn(server, server.getCurrentDifficultyAt(player.blockPosition()), MobSpawnType.MOB_SUMMONED, null, null);

        if (data.isMahoragaTamed()) {
            if (!data.consume(SUMMON_COST)) {
                player.displayClientMessage(Component.translatable("message.jujutsukaisen.no_energy", Component.translatable("entity.jujutsukaisen.mahoraga"))
                        .withStyle(ChatFormatting.RED), true);
                return InteractionResultHolder.fail(stack);
            }
            mahoraga.setOwner(player, TAMED_LIFETIME);
            server.addFreshEntity(mahoraga);
            player.getCooldowns().addCooldown(this, 20 * 120);
        } else {
            server.addFreshEntity(mahoraga);
            mahoraga.startRitual(serverPlayer);
            Fx.title(server, pos, 48, Component.translatable("entity.jujutsukaisen.mahoraga").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD),
                    Component.translatable("message.jujutsukaisen.ritual_start").withStyle(ChatFormatting.RED));
            Advancements.award(serverPlayer, "furube_yura_yura");
            if (!player.getAbilities().instabuild) stack.shrink(1);
        }
        com.jujutsukaisen.util.Fx.say(player, "line.jujutsukaisen.summon_mahoraga", 48);
        Fx.burst(server, ParticleTypes.SQUID_INK, pos.add(0, 0.2, 0), 140, 1.6, 0.05);
        Fx.burst(server, Fx.BLACK, pos.add(0, 1.5, 0), 80, 1.0, 0.0);
        Fx.sound(server, pos, SoundEvents.WARDEN_EMERGE, 2.5f, 0.8f);
        Fx.sound(server, pos, SoundEvents.BELL_RESONATE, 2.5f, 0.5f);
        return InteractionResultHolder.sidedSuccess(stack, false);
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.jujutsukaisen.ten_shadows_talisman.desc1").withStyle(ChatFormatting.DARK_PURPLE));
        tooltip.add(Component.translatable("item.jujutsukaisen.ten_shadows_talisman.desc2").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("item.jujutsukaisen.ten_shadows_talisman.desc3").withStyle(ChatFormatting.GRAY));
    }
}

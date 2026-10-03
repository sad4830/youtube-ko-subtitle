package com.jujutsukaisen.event;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.command.JJKCommand;
import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.item.SwordOfExterminationItem;
import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.network.S2CSyncSorcerer;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.smoke.SmokeTest;
import com.jujutsukaisen.sorcery.Adaptation;
import com.jujutsukaisen.sorcery.BlackFlash;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererCapability;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.SorcererLogic;
import com.jujutsukaisen.util.Fx;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageTypes;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.event.AttachCapabilitiesEvent;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.living.LivingAttackEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.living.LivingEvent;
import net.minecraftforge.event.entity.living.LivingHurtEvent;
import net.minecraftforge.event.entity.player.AttackEntityEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.entity.player.PlayerInteractEvent;
import net.minecraftforge.event.server.ServerStartedEvent;
import net.minecraftforge.event.server.ServerStoppingEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.network.PacketDistributor;

@Mod.EventBusSubscriber(modid = JujutsuKaisen.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE)
public final class CommonEvents {
    private CommonEvents() {
    }

    // ───────────────────────────── capability lifecycle ──────────────────

    @SubscribeEvent
    public static void attachCapabilities(AttachCapabilitiesEvent<Entity> event) {
        if (event.getObject() instanceof Player) {
            SorcererCapability.Provider provider = new SorcererCapability.Provider();
            event.addCapability(SorcererCapability.ID, provider);
            event.addListener(provider::invalidate);
        }
    }

    @SubscribeEvent
    public static void clone(PlayerEvent.Clone event) {
        Player original = event.getOriginal();
        original.reviveCaps();
        SorcererData from = JJK.get(original);
        SorcererData to = JJK.get(event.getEntity());
        if (from != null && to != null) to.copyFrom(from, event.isWasDeath());
        original.invalidateCaps();
    }

    @SubscribeEvent
    public static void login(PlayerEvent.PlayerLoggedInEvent event) {
        resync(event.getEntity());
    }

    @SubscribeEvent
    public static void respawn(PlayerEvent.PlayerRespawnEvent event) {
        resync(event.getEntity());
    }

    @SubscribeEvent
    public static void changedDimension(PlayerEvent.PlayerChangedDimensionEvent event) {
        resync(event.getEntity());
    }

    private static void resync(Player player) {
        SorcererData data = JJK.get(player);
        if (data != null && player instanceof ServerPlayer) {
            data.setRctActive(false);
            ModNetwork.sync(player, data);
            data.clearDirty();
        }
    }

    @SubscribeEvent
    public static void startTracking(PlayerEvent.StartTracking event) {
        if (event.getTarget() instanceof Player target && event.getEntity() instanceof ServerPlayer tracker) {
            SorcererData data = JJK.get(target);
            if (data != null) {
                ModNetwork.CHANNEL.send(PacketDistributor.PLAYER.with(() -> tracker), new S2CSyncSorcerer(target.getId(), data.saveSync()));
            }
        }
    }

    // ───────────────────────────── ticking ───────────────────────────────

    @SubscribeEvent
    public static void playerTick(TickEvent.PlayerTickEvent event) {
        if (event.phase != TickEvent.Phase.END || event.player.level().isClientSide) return;
        Player player = event.player;
        SorcererData data = JJK.get(player);
        if (data == null) return;
        SorcererLogic.tick(player, data);
        if (data.isDirty() && player.tickCount % 3 == 0) {
            ModNetwork.sync(player, data);
            data.clearDirty();
        }
    }

    @SubscribeEvent
    public static void levelTick(TickEvent.LevelTickEvent event) {
        if (event.phase != TickEvent.Phase.END || !(event.level instanceof ServerLevel level)) return;
        DomainManager.tick(level);
        if (level.getGameTime() % 20 == 0) SorcererLogic.releaseFrozen(level);
    }

    @SubscribeEvent
    public static void livingTick(LivingEvent.LivingTickEvent event) {
        LivingEntity entity = event.getEntity();
        if (entity.level().isClientSide || !entity.hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) return;
        // Unlimited Void: perceiving anything at all becomes an endless loop.
        if (entity instanceof Mob mob) mob.getNavigation().stop();
        Vec3 v = entity.getDeltaMovement();
        entity.setDeltaMovement(0, Math.min(v.y, 0), 0);
        if (entity.tickCount % 10 == 0 && entity.level() instanceof ServerLevel server) {
            Vec3 head = entity.getEyePosition();
            server.sendParticles(ParticleTypes.END_ROD, head.x, head.y + 0.3, head.z, 2, 0.3, 0.2, 0.3, 0.01);
        }
    }

    // ───────────────────────────── combat ────────────────────────────────

    @SubscribeEvent(priority = EventPriority.HIGH)
    public static void livingAttack(LivingAttackEvent event) {
        LivingEntity target = event.getEntity();
        if (target.level().isClientSide) return;
        DamageSource source = event.getSource();
        Entity attacker = source.getEntity();

        if (attacker instanceof LivingEntity living && source.getDirectEntity() == attacker
                && living.hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) {
            event.setCanceled(true);
            return;
        }
        if (SorcererLogic.infinityBlocks(target, source)) {
            event.setCanceled(true);
            SorcererLogic.infinityFeedback(target, source);
            // Mahoraga (or a wheel bearer) adapts to Infinity by being stopped by it.
            if (attacker instanceof LivingEntity living && Adaptation.bearsWheel(living)) {
                SorcererData data = JJK.get(living);
                if (data != null) Adaptation.expose(living, data, Adaptation.INFINITY, 0f);
            }
        }
    }

    @SubscribeEvent
    public static void livingHurt(LivingHurtEvent event) {
        LivingEntity target = event.getEntity();
        if (target.level().isClientSide) return;
        DamageSource source = event.getSource();
        float amount = event.getAmount();

        if (source.getEntity() instanceof LivingEntity attacker) {
            amount = BlackFlash.apply(attacker, target, source, amount);
            if (source.getDirectEntity() == attacker && attacker.getMainHandItem().getItem() instanceof SwordOfExterminationItem
                    && (source.is(DamageTypes.PLAYER_ATTACK) || source.is(DamageTypes.MOB_ATTACK))) {
                amount *= MahoragaEntity.exterminationBonus(target);
            }
            if (attacker instanceof MahoragaEntity mahoraga && SorcererLogic.hasInfinity(target)
                    && mahoraga.getSorcererData().getAdaptation(Adaptation.INFINITY) >= Adaptation.SPACE_CUT) {
                amount *= 1.5f; // the slash aimed at space itself
            }
        }

        if (!(target instanceof MahoragaEntity) && Adaptation.bearsWheel(target)) {
            SorcererData data = JJK.get(target);
            if (data != null) amount = Adaptation.onHurt(target, data, source, amount);
        }
        event.setAmount(amount);
    }

    @SubscribeEvent
    public static void livingDeath(LivingDeathEvent event) {
        LivingEntity entity = event.getEntity();
        if (entity.level().isClientSide) return;
        SorcererData data = JJK.get(entity);
        // Jackpot: fully automatic Reverse Cursed Technique. Unkillable unless destroyed outright.
        if (data != null && data.isJackpot() && !event.getSource().is(DamageTypeTags.BYPASSES_INVULNERABILITY)) {
            event.setCanceled(true);
            entity.setHealth(entity.getMaxHealth() * 0.4f);
            Fx.burst(entity.level(), ParticleTypes.TOTEM_OF_UNDYING, entity.getBoundingBox().getCenter(), 60, 0.6, 0.5);
            Fx.sound(entity, SoundEvents.TOTEM_USE, 1.0f, 1.3f);
        }
    }

    @SubscribeEvent
    public static void attackEntity(AttackEntityEvent event) {
        Player player = event.getEntity();
        if (player.hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) {
            event.setCanceled(true);
            return;
        }
        BlackFlash.markStrike(player);
    }

    @SubscribeEvent
    public static void rightClickItem(PlayerInteractEvent.RightClickItem event) {
        if (event.getEntity().hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) event.setCanceled(true);
    }

    @SubscribeEvent
    public static void rightClickBlock(PlayerInteractEvent.RightClickBlock event) {
        if (event.getEntity().hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) event.setCanceled(true);
    }

    @SubscribeEvent
    public static void leftClickBlock(PlayerInteractEvent.LeftClickBlock event) {
        if (event.getEntity().hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) event.setCanceled(true);
    }

    @SubscribeEvent
    public static void entityInteract(PlayerInteractEvent.EntityInteract event) {
        if (event.getEntity().hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) event.setCanceled(true);
    }

    @SubscribeEvent
    public static void jump(LivingEvent.LivingJumpEvent event) {
        LivingEntity entity = event.getEntity();
        if (entity.hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) {
            Vec3 v = entity.getDeltaMovement();
            entity.setDeltaMovement(v.x, 0, v.z);
        }
    }

    // ───────────────────────────── server ────────────────────────────────

    @SubscribeEvent
    public static void registerCommands(RegisterCommandsEvent event) {
        JJKCommand.register(event.getDispatcher());
    }

    @SubscribeEvent
    public static void serverStarted(ServerStartedEvent event) {
        if (SmokeTest.enabled()) SmokeTest.start(event.getServer());
    }

    @SubscribeEvent
    public static void serverStopping(ServerStoppingEvent event) {
        DomainManager.shutdown(event.getServer());
    }
}

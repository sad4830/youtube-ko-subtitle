package com.jujutsukaisen.domain;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.config.JJKConfig;
import com.jujutsukaisen.entity.MahoragaEntity;
import com.jujutsukaisen.entity.SorcererEntity;
import com.jujutsukaisen.entity.misc.MalevolentShrineEntity;
import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.network.S2CSlotSpin;
import com.jujutsukaisen.registry.ModDamageTypes;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.sorcery.Adaptation;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.util.Advancements;
import com.jujutsukaisen.util.Blast;
import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.network.PacketDistributor;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Domain Expansion (영역전개): builds barriers, applies sure-hit effects, resolves domain clashes,
 * runs Idle Death Gamble's slot machine and burns techniques out when a domain closes.
 */
public final class DomainManager {
    private static final Map<ResourceKey<Level>, List<ActiveDomain>> DOMAINS = new HashMap<>();
    private static final int SPIN_TICKS = 56;
    private static final int TIME_SHORT_SPIN_TICKS = 34;

    private DomainManager() {
    }

    // ───────────────────────────── queries ───────────────────────────────

    private static List<ActiveDomain> in(Level level) {
        return DOMAINS.computeIfAbsent(level.dimension(), k -> new ArrayList<>());
    }

    /** The caster's open domain in any dimension (one caster, one domain). */
    @Nullable
    public static ActiveDomain find(LivingEntity caster) {
        if (caster.level().isClientSide) return null;
        for (List<ActiveDomain> list : DOMAINS.values()) {
            for (ActiveDomain domain : list) {
                if (!domain.closed && domain.casterId().equals(caster.getUUID())) return domain;
            }
        }
        return null;
    }

    public static List<ActiveDomain> at(Level level, Vec3 pos) {
        List<ActiveDomain> result = new ArrayList<>();
        for (ActiveDomain domain : in(level)) if (!domain.closed && domain.contains(pos)) result.add(domain);
        return result;
    }

    public static boolean ownsBarrier(ServerLevel level, BlockPos pos) {
        for (ActiveDomain domain : in(level)) if (!domain.closed && domain.barrier.containsKey(pos)) return true;
        return false;
    }

    // ───────────────────────────── expansion ─────────────────────────────

    /** Hand-sign wind-up particles. */
    public static void chargeFx(LivingEntity caster, DomainType type, int elapsed) {
        Vec3 c = caster.position().add(0, caster.getBbHeight() * 0.6, 0);
        switch (type) {
            case INFINITE_VOID -> Fx.ring(caster.level(), Fx.BLUE_SMALL, caster.position().add(0, 0.1, 0), 1.2 + elapsed * 0.25, 20);
            case MALEVOLENT_SHRINE -> Fx.ring(caster.level(), Fx.CRIMSON, caster.position().add(0, 0.1, 0), 1.2 + elapsed * 0.25, 20);
            case IDLE_DEATH_GAMBLE -> Fx.ring(caster.level(), Fx.GOLD, caster.position().add(0, 0.1, 0), 1.2 + elapsed * 0.4, 20);
        }
        Fx.burst(caster.level(), Fx.BLACK, c, 6, 0.4, 0.0);
    }

    public static void expand(LivingEntity caster, SorcererData data, DomainType type) {
        if (!(caster.level() instanceof ServerLevel level) || find(caster) != null) return;
        int duration = JJKConfig.DOMAIN_DURATION_SECONDS.get() * 20;
        if (caster instanceof SorcererEntity sorcerer) duration = (int) (duration * sorcerer.domainDurationMultiplier());
        if (type == DomainType.IDLE_DEATH_GAMBLE) duration *= 2;
        Vec3 center = caster.position();
        data.setPseudoStreak(0);
        ActiveDomain domain = new ActiveDomain(type, caster.getUUID(), level.dimension(), center, type.radius(), duration);

        // The call: 영역전개 + name.
        Fx.title(level, center, domain.radius() * 2 + 24, Component.translatable("domain.jujutsukaisen.expansion").withStyle(ChatFormatting.WHITE, ChatFormatting.BOLD),
                type.displayName());
        Fx.say(caster, "domain.jujutsukaisen.call." + type.id(), domain.radius() * 2 + 24);
        Fx.sound(level, center, SoundEvents.WARDEN_SONIC_BOOM, 3.0f, 0.5f);
        Fx.sound(level, center, SoundEvents.BELL_RESONATE, 3.0f, 0.5f);
        Fx.sphere(level, Fx.BLACK, center, 2.5, 120);
        if (caster instanceof ServerPlayer player) Advancements.award(player, "domain_expansion");

        // Domain clash: the more refined domain overwhelms the other.
        for (ActiveDomain other : new ArrayList<>(in(level))) {
            if (other.closed || other.casterId().equals(caster.getUUID())) continue;
            if (other.center().distanceTo(center) > other.radius() + domain.radius()) continue;
            LivingEntity rival = casterOf(level, other);
            float mine = clashPower(caster, data, type);
            float theirs = rival == null ? 0f : clashPower(rival, JJK.get(rival), other.type());
            Fx.title(level, center, domain.radius() * 3 + 24, Component.translatable("domain.jujutsukaisen.clash").withStyle(ChatFormatting.RED, ChatFormatting.BOLD),
                    Component.translatable("domain.jujutsukaisen.clash.vs", type.displayName(), other.type().displayName()));
            Fx.sound(level, center, SoundEvents.GLASS_BREAK, 3.0f, 0.4f);
            if (mine >= theirs) {
                close(level, other, CloseReason.CLASH_LOST);
            } else {
                Fx.say(caster, "domain.jujutsukaisen.clash_lost_self", 48);
                in(level).add(domain);
                close(level, domain, CloseReason.CLASH_LOST);
                return;
            }
        }

        if (type.hasBarrier()) buildBarrier(level, domain, type.barrierBlock().defaultBlockState());
        if (type == DomainType.MALEVOLENT_SHRINE) {
            Vec3 back = Vec3.directionFromRotation(0, caster.getYRot()).scale(-3.5);
            MalevolentShrineEntity shrine = new MalevolentShrineEntity(level, center.x + back.x, center.y, center.z + back.z, caster.getYRot(), duration + 40);
            level.addFreshEntity(shrine);
            domain.shrine = shrine;
            data.setLastShrineDomain(level.getGameTime());
        }
        if (type == DomainType.IDLE_DEATH_GAMBLE) {
            transmitRules(level, caster, domain);
            domain.idleTimer = 30;
        }
        in(level).add(domain);
    }

    private static float clashPower(LivingEntity caster, @Nullable SorcererData data, DomainType type) {
        float power = type.refinement();
        if (data != null) power *= 0.6f + 0.4f * data.energyRatio();
        if (caster instanceof SorcererEntity sorcerer) power *= sorcerer.domainMastery();
        return power + caster.getRandom().nextFloat() * 0.25f;
    }

    private static void buildBarrier(ServerLevel level, ActiveDomain domain, BlockState barrier) {
        double r = domain.radius();
        int ri = (int) Math.ceil(r) + 1;
        BlockPos origin = BlockPos.containing(domain.center());
        BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos();
        for (int x = -ri; x <= ri; x++) {
            for (int y = -ri; y <= ri; y++) {
                for (int z = -ri; z <= ri; z++) {
                    double d = Math.sqrt(x * x + y * y + z * z);
                    if (d < r - 0.5 || d >= r + 0.5) continue;
                    pos.set(origin.getX() + x, origin.getY() + y, origin.getZ() + z);
                    if (!level.isInWorldBounds(pos)) continue;
                    BlockState state = level.getBlockState(pos);
                    boolean replaceable = state.isAir() || (state.canBeReplaced() && state.getFluidState().isEmpty() && !state.hasBlockEntity());
                    if (!replaceable) continue;
                    BlockPos immutable = pos.immutable();
                    domain.barrier.put(immutable, state);
                    level.setBlock(immutable, barrier, Block.UPDATE_CLIENTS);
                    level.scheduleTick(immutable, barrier.getBlock(), domain.duration() + 100);
                }
            }
        }
    }

    private static void removeBarrier(ServerLevel level, ActiveDomain domain) {
        Block barrier = domain.type().barrierBlock();
        for (Map.Entry<BlockPos, BlockState> entry : domain.barrier.entrySet()) {
            if (barrier != null && level.getBlockState(entry.getKey()).is(barrier)) {
                level.setBlock(entry.getKey(), entry.getValue(), Block.UPDATE_ALL);
            }
        }
        domain.barrier.clear();
    }

    // ───────────────────────────── ticking ───────────────────────────────

    public static void tick(ServerLevel level) {
        List<ActiveDomain> domains = DOMAINS.get(level.dimension());
        if (domains == null || domains.isEmpty()) return;
        for (Iterator<ActiveDomain> it = domains.iterator(); it.hasNext(); ) {
            ActiveDomain domain = it.next();
            if (domain.closed) {
                it.remove();
                continue;
            }
            LivingEntity caster = casterOf(level, domain);
            if (caster == null || !caster.isAlive()) {
                close(level, domain, CloseReason.CASTER_GONE);
                it.remove();
                continue;
            }
            domain.age++;
            switch (domain.type()) {
                case INFINITE_VOID -> tickInfiniteVoid(level, domain, caster);
                case MALEVOLENT_SHRINE -> tickMalevolentShrine(level, domain, caster);
                case IDLE_DEATH_GAMBLE -> tickIdleDeathGamble(level, domain, caster);
            }
            if (!domain.closed && domain.age >= domain.duration() && !domain.isSpinning()) {
                close(level, domain, CloseReason.EXPIRED);
            }
            if (domain.closed) it.remove();
        }
    }

    /** The caster if it is still in the domain's dimension. */
    @Nullable
    private static LivingEntity casterOf(ServerLevel level, ActiveDomain domain) {
        Entity entity = level.getEntity(domain.casterId());
        return entity instanceof LivingEntity living ? living : null;
    }

    /** The caster wherever it is (another dimension, or a player still online). */
    @Nullable
    private static LivingEntity casterAnywhere(ServerLevel level, ActiveDomain domain) {
        LivingEntity here = casterOf(level, domain);
        if (here != null) return here;
        return level.getServer().getPlayerList().getPlayer(domain.casterId());
    }

    private static List<LivingEntity> victims(ServerLevel level, ActiveDomain domain, LivingEntity caster) {
        double r = domain.radius();
        AABB box = new AABB(domain.center(), domain.center()).inflate(r);
        return level.getEntitiesOfClass(LivingEntity.class, box, e -> domain.contains(e.getBoundingBox().getCenter()) && JJK.canHit(caster, e));
    }

    /** 무량공처 — the sure-hit pours infinite information into everyone inside. */
    private static void tickInfiniteVoid(ServerLevel level, ActiveDomain domain, LivingEntity caster) {
        AABB touch = caster.getBoundingBox().inflate(0.35);
        for (LivingEntity victim : victims(level, domain, caster)) {
            if (victim.getBoundingBox().intersects(touch)) continue; // whoever touches Gojo is spared
            if (victim instanceof MahoragaEntity mahoraga) {
                SorcererData md = mahoraga.getSorcererData();
                if (md.getAdaptation(Adaptation.UNLIMITED_VOID) >= Adaptation.MAX) {
                    Fx.say(mahoraga, "message.jujutsukaisen.mahoraga_breaks_void", 64);
                    Fx.sound(level, mahoraga.position(), SoundEvents.GLASS_BREAK, 3.0f, 0.5f);
                    close(level, domain, CloseReason.SHATTERED);
                    return;
                }
            }
            if (domain.age % 5 == 0) {
                victim.addEffect(new MobEffectInstance(ModEffects.INFORMATION_OVERLOAD.get(), 30, 0, false, false, true));
            }
            if (domain.age % 20 == 0) {
                victim.hurt(ModDamageTypes.source(level, ModDamageTypes.INFINITE_VOID, caster), 2.0f);
            }
        }
        if (domain.age % 2 == 0) {
            RandomSource random = level.random;
            for (int i = 0; i < 6; i++) {
                Vec3 p = domain.center().add(random.nextGaussian() * domain.radius() * 0.4, random.nextDouble() * domain.radius() * 0.7,
                        random.nextGaussian() * domain.radius() * 0.4);
                level.sendParticles(i % 2 == 0 ? ParticleTypes.END_ROD : Fx.BLUE_SMALL, p.x, p.y, p.z, 1, 0, 0, 0, 0.01);
            }
        }
        if (domain.age % 40 == 1) Fx.sound(level, domain.center(), SoundEvents.AMETHYST_BLOCK_RESONATE, 3.0f, 0.5f);
    }

    /**
     * 복마어주자 — no barrier. Dismantle cuts everything without cursed energy (blocks), Cleave cuts
     * everything with cursed energy (living beings), until only dust remains.
     */
    private static void tickMalevolentShrine(ServerLevel level, ActiveDomain domain, LivingEntity caster) {
        RandomSource random = level.random;
        double r = domain.radius();
        if (domain.age % 4 == 0) {
            for (LivingEntity victim : victims(level, domain, caster)) {
                float damage = 2.5f + victim.getMaxHealth() * 0.035f;
                if (victim.hurt(ModDamageTypes.source(level, ModDamageTypes.MALEVOLENT_SHRINE, caster), damage)) {
                    Vec3 c = victim.getBoundingBox().getCenter();
                    level.sendParticles(ParticleTypes.SWEEP_ATTACK, c.x, c.y, c.z, 2, 0.4, 0.5, 0.4, 0);
                    level.sendParticles(Fx.CRIMSON, c.x, c.y, c.z, 8, 0.4, 0.6, 0.4, 0);
                }
            }
        }

        if (JJK.canGrief(caster, true)) {
            int budget = JJKConfig.SHRINE_BLOCKS_PER_TICK.get();
            BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos();
            for (int i = 0; i < budget; i++) {
                double dx = (random.nextDouble() * 2 - 1) * r, dy = random.nextDouble() * r, dz = (random.nextDouble() * 2 - 1) * r;
                if (dx * dx + dy * dy + dz * dz > r * r) continue;
                pos.set(domain.center().x + dx, domain.center().y - 2 + dy, domain.center().z + dz);
                if (pos.closerToCenterThan(caster.position(), 2.5)) continue;
                Blast.cut(level, caster, pos, 50f, random.nextInt(6) == 0);
            }
        }

        for (int i = 0; i < 8; i++) {
            double a = random.nextDouble() * Math.PI * 2, d = random.nextDouble() * r;
            level.sendParticles(ParticleTypes.SWEEP_ATTACK, domain.center().x + Math.cos(a) * d, domain.center().y + random.nextDouble() * 6,
                    domain.center().z + Math.sin(a) * d, 1, 0, 0, 0, 0);
        }
        if (domain.age % 3 == 0) {
            double a = random.nextDouble() * Math.PI * 2, d = random.nextDouble() * r;
            Fx.sound(level, domain.center().add(Math.cos(a) * d, 1, Math.sin(a) * d), SoundEvents.PLAYER_ATTACK_SWEEP, 1.5f, 0.8f + random.nextFloat() * 0.6f);
        }
    }

    /** 좌살박도 — the sure-hit only transmits the rules; then the reels spin. */
    private static void tickIdleDeathGamble(ServerLevel level, ActiveDomain domain, LivingEntity caster) {
        SorcererData data = JJK.get(caster);
        if (data == null) return;
        if (domain.age % 3 == 0) {
            RandomSource random = level.random;
            Vec3 p = domain.center().add(random.nextGaussian() * domain.radius() * 0.4, random.nextDouble() * domain.radius() * 0.6,
                    random.nextGaussian() * domain.radius() * 0.4);
            level.sendParticles(Fx.GOLD, p.x, p.y, p.z, 2, 0.2, 0.2, 0.2, 0);
        }

        if (domain.isSpinning()) {
            domain.spinTimer--;
            if (domain.spinTimer <= 0) {
                domain.spinTimer = -1;
                if (domain.spinWins) {
                    jackpot(level, domain, caster, data);
                } else {
                    Fx.title(level, domain.center(), domain.radius() + 8, Component.empty(),
                            Component.translatable("gamble.jujutsukaisen.miss").withStyle(ChatFormatting.GRAY));
                    Fx.sound(level, domain.center(), SoundEvents.NOTE_BLOCK_BASS.value(), 2.0f, 0.5f);
                    domain.idleTimer = 50;
                }
            }
            return;
        }

        // Without a notice for a while the machine keeps playing on its own.
        if (domain.queuedIndicator == null && --domain.idleTimer <= 0) {
            domain.queuedIndicator = Indicator.roll(level.random, data.isProbabilityUp());
        }
        if (domain.queuedIndicator != null) {
            startSpin(level, domain, caster, data, domain.queuedIndicator, domain.guaranteed);
            domain.queuedIndicator = null;
            domain.guaranteed = false;
        }
    }

    private static void transmitRules(ServerLevel level, LivingEntity caster, ActiveDomain domain) {
        for (LivingEntity victim : victims(level, domain, caster)) {
            if (victim instanceof ServerPlayer player) {
                player.sendSystemMessage(Component.translatable("gamble.jujutsukaisen.rules").withStyle(ChatFormatting.GOLD));
            }
        }
        Fx.title(level, domain.center(), domain.radius() + 8, DomainType.IDLE_DEATH_GAMBLE.displayName(),
                Component.translatable("gamble.jujutsukaisen.rules_transmitted").withStyle(ChatFormatting.YELLOW));
    }

    /** A notice effect was used inside the domain: it leads into a riichi. */
    public static void onGambleIndicator(LivingEntity caster, com.jujutsukaisen.sorcery.Ability ability) {
        ActiveDomain domain = find(caster);
        SorcererData data = JJK.get(caster);
        if (domain == null || data == null || domain.type() != DomainType.IDLE_DEATH_GAMBLE || domain.isSpinning()) return;
        domain.queuedIndicator = data.getLastIndicator();
        // Four pseudo-consecutives in a row guarantee the jackpot.
        if (data.getPseudoStreak() >= 4) {
            domain.guaranteed = true;
            data.setPseudoStreak(0);
        }
    }

    private static void startSpin(ServerLevel level, ActiveDomain domain, LivingEntity caster, SorcererData data, Indicator indicator, boolean guaranteed) {
        RandomSource random = level.random;
        Riichi riichi = Riichi.roll(random, indicator);
        float chance = riichi.expectation() + indicator.expectation() * 0.35f;
        if (data.isProbabilityUp()) chance += 0.12f;
        boolean win = guaranteed || indicator == Indicator.RAINBOW || random.nextFloat() < Mth.clamp(chance, 0f, 0.95f);

        int number = 1 + random.nextInt(7);
        int third = number;
        if (!win) {
            while (third == number) third = 1 + random.nextInt(7);
        }
        int[] reels = {number, number, third};
        domain.spins++;
        domain.spinWins = win;
        int ticks = data.getJackpotCount() > 0 && data.getJackpotCount() % 2 == 0 ? TIME_SHORT_SPIN_TICKS : SPIN_TICKS;
        domain.spinTimer = ticks;

        S2CSlotSpin packet = new S2CSlotSpin(reels, indicator.ordinal(), riichi.ordinal(), win, ticks, domain.spins);
        for (ServerPlayer player : level.players()) {
            if (player.position().distanceTo(domain.center()) <= domain.radius() + 16) {
                ModNetwork.CHANNEL.send(PacketDistributor.PLAYER.with(() -> player), packet);
            }
        }
        Fx.title(level, domain.center(), domain.radius() + 8, Component.translatable("gamble.jujutsukaisen.riichi").withStyle(ChatFormatting.RED, ChatFormatting.BOLD),
                riichi.displayName());
        Fx.say(caster, "gamble.jujutsukaisen.riichi_call", domain.radius() + 16);
        Fx.sound(level, domain.center(), SoundEvents.NOTE_BLOCK_BELL.value(), 2.5f, 1.0f + indicator.ordinal() * 0.25f);
    }

    /**
     * 대박 — the domain closes and, for exactly 4 minutes 11 seconds, Hakari's cursed energy is unlimited
     * and his body performs Reverse Cursed Technique automatically. His burnt-out technique recovers.
     */
    private static void jackpot(ServerLevel level, ActiveDomain domain, LivingEntity caster, SorcererData data) {
        grantJackpot(caster, data);
        close(level, domain, CloseReason.JACKPOT);
    }

    /** Starts the 4:11 jackpot round for any sorcerer (also used by {@code /jjk jackpot}). */
    public static void grantJackpot(LivingEntity caster, SorcererData data) {
        if (!(caster.level() instanceof ServerLevel level)) return;
        data.setPseudoStreak(0);
        // A jackpot during a jackpot round does not restart the song: the round still ends on time.
        int round = data.isJackpot() ? data.getJackpot() : SorcererData.JACKPOT_TICKS;
        data.setJackpot(round);
        data.setJackpotCount(data.getJackpotCount() + 1);
        // Odd jackpot → increased probability (확변) for the next expansion; even → time-shortening (시단).
        data.setProbabilityUp(data.getJackpotCount() % 2 == 1);
        data.setBurnout(0);
        caster.removeEffect(ModEffects.TECHNIQUE_BURNOUT.get());
        caster.addEffect(new MobEffectInstance(ModEffects.JACKPOT.get(), round, 0, false, true, true));
        caster.addEffect(new MobEffectInstance(MobEffects.DAMAGE_BOOST, round, 1, false, false, true));
        caster.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SPEED, round, 1, false, false, true));
        caster.addEffect(new MobEffectInstance(MobEffects.DAMAGE_RESISTANCE, round, 0, false, false, true));
        caster.setHealth(caster.getMaxHealth());

        Vec3 c = caster.position().add(0, 1, 0);
        Fx.title(level, c, 40, Component.translatable("gamble.jujutsukaisen.jackpot").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD),
                Component.translatable("gamble.jujutsukaisen.jackpot.sub").withStyle(ChatFormatting.YELLOW));
        Fx.say(caster, "gamble.jujutsukaisen.jackpot_call", 40);
        Fx.burst(level, ParticleTypes.FIREWORK, c, 120, 1.5, 0.35);
        Fx.burst(level, ParticleTypes.TOTEM_OF_UNDYING, c, 80, 1.0, 0.6);
        Fx.sound(level, c, SoundEvents.UI_TOAST_CHALLENGE_COMPLETE, 3.0f, 1.0f);
        Fx.sound(level, c, SoundEvents.FIREWORK_ROCKET_LARGE_BLAST, 3.0f, 1.0f);
        if (caster instanceof ServerPlayer player) Advancements.award(player, "jackpot");
    }

    // ───────────────────────────── closing ───────────────────────────────

    public enum CloseReason {
        EXPIRED, CASTER_GONE, CLASH_LOST, CANCELLED, SHATTERED, JACKPOT, SHUTDOWN
    }

    public static void close(ServerLevel level, ActiveDomain domain, CloseReason reason) {
        if (domain.closed) return;
        domain.closed = true;
        removeBarrier(level, domain);
        if (domain.shrine != null) {
            domain.shrine.collapse();
            domain.shrine = null;
        }
        Fx.sound(level, domain.center(), SoundEvents.GLASS_BREAK, 2.5f, 0.6f);
        Fx.sphere(level, ParticleTypes.CLOUD, domain.center(), Math.min(domain.radius(), 12), 60);

        LivingEntity caster = casterAnywhere(level, domain);
        SorcererData data = JJK.get(caster);
        if (caster == null || data == null || reason == CloseReason.SHUTDOWN) return;
        data.setPseudoStreak(0);
        if (domain.type() == DomainType.MALEVOLENT_SHRINE) data.setLastShrineDomain(level.getGameTime());
        if (reason == CloseReason.CLASH_LOST) {
            Fx.title(level, domain.center(), domain.radius() + 16, Component.empty(),
                    Component.translatable("domain.jujutsukaisen.clash_lost", caster.getDisplayName()).withStyle(ChatFormatting.GRAY));
        }
        // Technique burnout (術式の焼き切れ). A jackpot repairs it on the spot.
        if (reason != CloseReason.JACKPOT && !data.isJackpot()) {
            int burnout = caster instanceof SorcererEntity sorcerer ? sorcerer.burnoutTicks() : JJKConfig.PLAYER_BURNOUT_SECONDS.get() * 20;
            if (burnout > 0) {
                data.setBurnout(burnout);
                data.clearCast();
                caster.addEffect(new MobEffectInstance(ModEffects.TECHNIQUE_BURNOUT.get(), burnout, 0, false, false, true));
                if (caster instanceof Player player) {
                    player.displayClientMessage(Component.translatable("message.jujutsukaisen.burnout_start").withStyle(ChatFormatting.DARK_RED), true);
                }
            }
        }
    }

    /** Closes the caster's own domain (pressing the domain key again). */
    public static boolean cancel(LivingEntity caster) {
        ActiveDomain domain = find(caster);
        if (domain == null || !(caster.level() instanceof ServerLevel here)) return false;
        ServerLevel level = here.getServer().getLevel(domain.dimension());
        close(level != null ? level : here, domain, CloseReason.CANCELLED);
        return true;
    }

    public static void shutdown(MinecraftServer server) {
        for (ServerLevel level : server.getAllLevels()) {
            List<ActiveDomain> domains = DOMAINS.get(level.dimension());
            if (domains == null) continue;
            for (ActiveDomain domain : domains) close(level, domain, CloseReason.SHUTDOWN);
        }
        DOMAINS.clear();
        JujutsuKaisen.LOGGER.debug("Closed all domains for shutdown");
    }
}

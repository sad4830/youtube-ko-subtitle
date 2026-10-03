package com.jujutsukaisen.domain;

import com.jujutsukaisen.config.JJKConfig;
import com.jujutsukaisen.registry.ModBlocks;
import com.jujutsukaisen.sorcery.Ability;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.world.level.block.Block;
import org.jetbrains.annotations.Nullable;

import java.util.Locale;

public enum DomainType {
    /** 무량공처 — Unlimited Void. Closed barrier; infinite information paralyses everyone inside. */
    INFINITE_VOID(Ability.DOMAIN_INFINITE_VOID, true, 1.2f, ChatFormatting.AQUA),
    /** 복마어주자 — Malevolent Shrine. No barrier: drawn on reality itself, with an escape route. */
    MALEVOLENT_SHRINE(Ability.DOMAIN_MALEVOLENT_SHRINE, false, 1.3f, ChatFormatting.DARK_RED),
    /** 좌살박도 — Idle Death Gamble. The sure-hit is harmless: it only transmits the rules. */
    IDLE_DEATH_GAMBLE(Ability.DOMAIN_IDLE_DEATH_GAMBLE, true, 1.15f, ChatFormatting.GOLD);

    private final Ability ability;
    private final boolean barrier;
    private final float refinement;
    private final ChatFormatting format;

    DomainType(Ability ability, boolean barrier, float refinement, ChatFormatting format) {
        this.ability = ability;
        this.barrier = barrier;
        this.refinement = refinement;
        this.format = format;
    }

    public Ability ability() {
        return ability;
    }

    public boolean hasBarrier() {
        return barrier;
    }

    /** Domain clash weight: the more refined domain overwhelms the other. */
    public float refinement() {
        return refinement;
    }

    public ChatFormatting format() {
        return format;
    }

    public double radius() {
        return switch (this) {
            case INFINITE_VOID -> JJKConfig.INFINITE_VOID_RADIUS.get();
            case MALEVOLENT_SHRINE -> JJKConfig.MALEVOLENT_SHRINE_RADIUS.get();
            case IDLE_DEATH_GAMBLE -> JJKConfig.IDLE_DEATH_GAMBLE_RADIUS.get();
        };
    }

    @Nullable
    public Block barrierBlock() {
        return switch (this) {
            case INFINITE_VOID -> ModBlocks.INFINITE_VOID_BARRIER.get();
            case IDLE_DEATH_GAMBLE -> ModBlocks.IDLE_DEATH_GAMBLE_BARRIER.get();
            case MALEVOLENT_SHRINE -> null;
        };
    }

    public String id() {
        return name().toLowerCase(Locale.ROOT);
    }

    public Component displayName() {
        return Component.translatable("domain.jujutsukaisen." + id()).withStyle(format, ChatFormatting.BOLD);
    }

    @Nullable
    public static DomainType forAbility(Ability ability) {
        for (DomainType type : values()) if (type.ability == ability) return type;
        return null;
    }
}

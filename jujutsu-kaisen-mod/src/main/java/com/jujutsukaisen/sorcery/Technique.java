package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.domain.DomainType;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import org.jetbrains.annotations.Nullable;

import java.util.List;
import java.util.Locale;

/**
 * Innate cursed techniques (生得術式) a sorcerer can carry.
 */
public enum Technique {
    NONE(0x8A8A8A, ChatFormatting.GRAY, null, false, List.of()),
    /** 무하한 주술 — Satoru Gojo. Requires (and grants) the Six Eyes. */
    LIMITLESS(0x4FB8FF, ChatFormatting.AQUA, DomainType.INFINITE_VOID, true,
            List.of(Ability.BLUE, Ability.RED, Ability.HOLLOW_PURPLE)),
    /** 어주자 — Ryomen Sukuna (and his vessels). */
    SHRINE(0xD3253B, ChatFormatting.RED, DomainType.MALEVOLENT_SHRINE, true,
            List.of(Ability.DISMANTLE, Ability.CLEAVE, Ability.FUGA, Ability.WORLD_SLASH)),
    /** 사철순애열차 / 좌살박도 — Kinji Hakari. RCT only happens automatically during a jackpot. */
    IDLE_DEATH_GAMBLE(0x46D16A, ChatFormatting.GREEN, DomainType.IDLE_DEATH_GAMBLE, false,
            List.of(Ability.RESERVE_BALLS, Ability.SHUTTER_DOORS, Ability.PSEUDO_CONSECUTIVE));

    private final int color;
    private final ChatFormatting format;
    @Nullable
    private final DomainType domain;
    private final boolean canUseRct;
    private final List<Ability> abilities;

    Technique(int color, ChatFormatting format, @Nullable DomainType domain, boolean canUseRct, List<Ability> abilities) {
        this.color = color;
        this.format = format;
        this.domain = domain;
        this.canUseRct = canUseRct;
        this.abilities = abilities;
    }

    public int color() {
        return color;
    }

    public ChatFormatting format() {
        return format;
    }

    @Nullable
    public DomainType domain() {
        return domain;
    }

    /** Whether this sorcerer can manually perform Reverse Cursed Technique (반전술식). */
    public boolean canUseRct() {
        return canUseRct;
    }

    public List<Ability> abilities() {
        return abilities;
    }

    public String id() {
        return name().toLowerCase(Locale.ROOT);
    }

    public Component displayName() {
        return Component.translatable("technique.jujutsukaisen." + id()).withStyle(format);
    }

    /** Base maximum cursed energy for a player holding this technique. */
    public float baseMaxEnergy() {
        return switch (this) {
            case NONE -> 100f;
            case LIMITLESS -> 1500f;
            case SHRINE -> 800f;
            case IDLE_DEATH_GAMBLE -> 1200f;
        };
    }

    public static Technique byId(String id) {
        for (Technique t : values()) {
            if (t.id().equals(id)) return t;
        }
        return NONE;
    }
}

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
    NONE(0x8A8A8A, ChatFormatting.GRAY, false),
    /** 무하한 주술 — Satoru Gojo. Requires (and grants) the Six Eyes. */
    LIMITLESS(0x4FB8FF, ChatFormatting.AQUA, true),
    /** 어주자 — Ryomen Sukuna (and his vessels). */
    SHRINE(0xD3253B, ChatFormatting.RED, true),
    /** 사철순애열차 / 좌살박도 — Kinji Hakari. RCT only happens automatically during a jackpot. */
    IDLE_DEATH_GAMBLE(0x46D16A, ChatFormatting.GREEN, false);

    // Ability and DomainType both refer back to Technique in their constructors, so this enum must not
    // touch them during its own class initialisation (that cycle left Ability.technique() null).
    private final int color;
    private final ChatFormatting format;
    private final boolean canUseRct;

    Technique(int color, ChatFormatting format, boolean canUseRct) {
        this.color = color;
        this.format = format;
        this.canUseRct = canUseRct;
    }

    public int color() {
        return color;
    }

    public ChatFormatting format() {
        return format;
    }

    @Nullable
    public DomainType domain() {
        return switch (this) {
            case LIMITLESS -> DomainType.INFINITE_VOID;
            case SHRINE -> DomainType.MALEVOLENT_SHRINE;
            case IDLE_DEATH_GAMBLE -> DomainType.IDLE_DEATH_GAMBLE;
            case NONE -> null;
        };
    }

    /** Whether this sorcerer can manually perform Reverse Cursed Technique (반전술식). */
    public boolean canUseRct() {
        return canUseRct;
    }

    public List<Ability> abilities() {
        return switch (this) {
            case LIMITLESS -> LIMITLESS_ABILITIES.get();
            case SHRINE -> SHRINE_ABILITIES.get();
            case IDLE_DEATH_GAMBLE -> GAMBLE_ABILITIES.get();
            case NONE -> List.of();
        };
    }

    private static final java.util.function.Supplier<List<Ability>> LIMITLESS_ABILITIES =
            com.google.common.base.Suppliers.memoize(() -> List.of(Ability.BLUE, Ability.RED, Ability.HOLLOW_PURPLE));
    private static final java.util.function.Supplier<List<Ability>> SHRINE_ABILITIES =
            com.google.common.base.Suppliers.memoize(() -> List.of(Ability.DISMANTLE, Ability.CLEAVE, Ability.FUGA, Ability.WORLD_SLASH));
    private static final java.util.function.Supplier<List<Ability>> GAMBLE_ABILITIES =
            com.google.common.base.Suppliers.memoize(() -> List.of(Ability.RESERVE_BALLS, Ability.SHUTTER_DOORS, Ability.PSEUDO_CONSECUTIVE));

    public String id() {
        return name().toLowerCase(Locale.ROOT);
    }

    /** The character whose look a player may take on with this technique (entity id), or null. */
    @Nullable
    public String character() {
        return switch (this) {
            case LIMITLESS -> "satoru_gojo";
            case SHRINE -> "ryomen_sukuna";
            case IDLE_DEATH_GAMBLE -> "kinji_hakari";
            case NONE -> null;
        };
    }

    @Nullable
    public static Technique ofCharacter(String character) {
        for (Technique t : values()) {
            if (character.equals(t.character())) return t;
        }
        return null;
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

package com.jujutsukaisen.domain;

import com.jujutsukaisen.util.Fx;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.DustParticleOptions;
import net.minecraft.network.chat.Component;
import net.minecraft.util.RandomSource;

import java.util.Locale;

/**
 * Notice effects (予告演出) of Private Pure Love Train come in colours of rising expectation:
 * green &lt; red &lt; gold, and rainbow guarantees the jackpot. Hakari chooses the indicator,
 * luck chooses the colour.
 */
public enum Indicator {
    GREEN(ChatFormatting.GREEN, 0x46D16A, 1.0f, 0.12f),
    RED(ChatFormatting.RED, 0xE8333D, 1.35f, 0.3f),
    GOLD(ChatFormatting.GOLD, 0xF2C230, 1.8f, 0.55f),
    RAINBOW(ChatFormatting.LIGHT_PURPLE, 0xFF7AF5, 2.5f, 1.0f);

    private final ChatFormatting format;
    private final int color;
    private final float power;
    private final float expectation;

    Indicator(ChatFormatting format, int color, float power, float expectation) {
        this.format = format;
        this.color = color;
        this.power = power;
        this.expectation = expectation;
    }

    public ChatFormatting format() {
        return format;
    }

    public int color() {
        return color;
    }

    /** Damage multiplier when the indicator is used as an attack. */
    public float power() {
        return power;
    }

    /** Bonus to the jackpot expectation of the riichi it leads into (rainbow = guaranteed). */
    public float expectation() {
        return expectation;
    }

    public DustParticleOptions dust() {
        return switch (this) {
            case GREEN -> Fx.GREEN;
            case RED -> Fx.RED;
            case GOLD -> Fx.GOLD;
            case RAINBOW -> Fx.PURPLE;
        };
    }

    public Component displayName() {
        return Component.translatable("indicator.jujutsukaisen." + name().toLowerCase(Locale.ROOT)).withStyle(format, ChatFormatting.BOLD);
    }

    /** Luck decides the colour. With increased probability (확변) better colours appear more often. */
    public static Indicator roll(RandomSource random, boolean probabilityUp) {
        float r = random.nextFloat();
        float rainbow = probabilityUp ? 0.05f : 0.02f;
        float gold = probabilityUp ? 0.22f : 0.12f;
        float red = probabilityUp ? 0.35f : 0.30f;
        if (r < rainbow) return RAINBOW;
        if (r < rainbow + gold) return GOLD;
        if (r < rainbow + gold + red) return RED;
        return GREEN;
    }

    public static Indicator byOrdinal(int ordinal) {
        Indicator[] values = values();
        return ordinal >= 0 && ordinal < values.length ? values[ordinal] : GREEN;
    }
}

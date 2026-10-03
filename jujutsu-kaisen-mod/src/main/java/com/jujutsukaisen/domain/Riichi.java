package com.jujutsukaisen.domain;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.util.RandomSource;

import java.util.Locale;

/**
 * The four riichi actions of CR Private Pure Love Train, from lowest to highest expectation.
 * The stage changes and the opponent cannot interfere; only killing Hakari stops it.
 */
public enum Riichi {
    /** ★☆☆ — Yuki must get through the ticket gate in time. */
    TRANSIT_CARD(1, 0.10f, ChatFormatting.GREEN),
    /** ★★☆ — the struggle for a seat on the commuter train. */
    SEAT_STRUGGLE(2, 0.24f, ChatFormatting.AQUA),
    /** ★★☆ — Hiro must hold it until Shin-Yurigaoka. */
    POTTY_EMERGENCY(2, 0.32f, ChatFormatting.YELLOW),
    /** ★★★ — Yume must not board the opposite train. Over 80% expectation. */
    FRIDAY_NIGHT_FINAL_TRAIN(3, 0.82f, ChatFormatting.LIGHT_PURPLE);

    private final int stars;
    private final float expectation;
    private final ChatFormatting format;

    Riichi(int stars, float expectation, ChatFormatting format) {
        this.stars = stars;
        this.expectation = expectation;
        this.format = format;
    }

    public int stars() {
        return stars;
    }

    public float expectation() {
        return expectation;
    }

    public Component displayName() {
        return Component.translatable("riichi.jujutsukaisen." + name().toLowerCase(Locale.ROOT)).withStyle(format, ChatFormatting.BOLD);
    }

    /** Better notice colours lead into better riichi actions. */
    public static Riichi roll(RandomSource random, Indicator indicator) {
        float[] weights = switch (indicator) {
            case GREEN -> new float[]{0.55f, 0.27f, 0.15f, 0.03f};
            case RED -> new float[]{0.33f, 0.33f, 0.22f, 0.12f};
            case GOLD -> new float[]{0.12f, 0.28f, 0.30f, 0.30f};
            case RAINBOW -> new float[]{0.25f, 0.25f, 0.25f, 0.25f};
        };
        float r = random.nextFloat();
        float acc = 0;
        for (int i = 0; i < weights.length; i++) {
            acc += weights[i];
            if (r < acc) return values()[i];
        }
        return TRANSIT_CARD;
    }

    public static Riichi byOrdinal(int ordinal) {
        Riichi[] values = values();
        return ordinal >= 0 && ordinal < values.length ? values[ordinal] : TRANSIT_CARD;
    }
}

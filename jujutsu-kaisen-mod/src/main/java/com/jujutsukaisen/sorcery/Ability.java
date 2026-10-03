package com.jujutsukaisen.sorcery;

import net.minecraft.network.chat.Component;

import java.util.Locale;

/**
 * Every castable action. Domain Expansions are abilities too so that they share the
 * cost / cooldown / wind-up (hand sign) pipeline, but they are bound to their own key.
 *
 * @param-like fields: cursed energy cost, cooldown (ticks), wind-up (ticks), pose shown while winding up.
 */
public enum Ability {
    // ── Limitless (무하한 주술) ────────────────────────────────────────────────
    /** 술식순전 「창」 — point of attraction. */
    BLUE(Technique.LIMITLESS, 70, 30, 0, CastPose.POINT),
    /** 술식반전 「혁」 — repulsion. */
    RED(Technique.LIMITLESS, 130, 70, 8, CastPose.POINT),
    /** 허식 「자」 — imaginary mass that erases everything in its path. */
    HOLLOW_PURPLE(Technique.LIMITLESS, 550, 500, 36, CastPose.PURPLE),

    // ── Shrine (어주자) ───────────────────────────────────────────────────────
    /** 해 — invisible ranged slash, weaker with distance. */
    DISMANTLE(Technique.SHRINE, 35, 12, 0, CastPose.SLASH),
    /** 팔 — adjusts to the target's toughness and cursed energy; needs contact outside a domain. */
    CLEAVE(Technique.SHRINE, 80, 40, 0, CastPose.SLASH),
    /** 「竈」開 — divine flame arrow; only after Dismantle and Cleave have both landed. */
    FUGA(Technique.SHRINE, 320, 300, 22, CastPose.BOW),
    /** 세계를 가르는 참격 — Dismantle aimed at space itself; needs the chant. */
    WORLD_SLASH(Technique.SHRINE, 720, 1200, 45, CastPose.HAND_SIGN),

    // ── Private Pure Love Train (사철순애열차) ─────────────────────────────────
    /** 보류 구슬 — reserve balls; an offensive indicator. */
    RESERVE_BALLS(Technique.IDLE_DEATH_GAMBLE, 35, 16, 0, CastPose.POINT),
    /** 셔터 — shutter doors slam shut on the target; an offensive indicator. */
    SHUTTER_DOORS(Technique.IDLE_DEATH_GAMBLE, 90, 70, 0, CastPose.POINT),
    /** 유사연속 — pseudo-consecutive; a defensive indicator that replays and reverts damage taken. */
    PSEUDO_CONSECUTIVE(Technique.IDLE_DEATH_GAMBLE, 120, 160, 0, CastPose.HAND_SIGN),

    // ── Domain Expansions (영역전개) ──────────────────────────────────────────
    DOMAIN_INFINITE_VOID(Technique.LIMITLESS, 700, 400, 16, CastPose.HAND_SIGN),
    DOMAIN_MALEVOLENT_SHRINE(Technique.SHRINE, 800, 400, 16, CastPose.HAND_SIGN),
    DOMAIN_IDLE_DEATH_GAMBLE(Technique.IDLE_DEATH_GAMBLE, 600, 300, 6, CastPose.HAND_SIGN);

    private final Technique technique;
    private final float cost;
    private final int cooldown;
    private final int windup;
    private final CastPose pose;

    Ability(Technique technique, float cost, int cooldown, int windup, CastPose pose) {
        this.technique = technique;
        this.cost = cost;
        this.cooldown = cooldown;
        this.windup = windup;
        this.pose = pose;
    }

    public Technique technique() {
        return technique;
    }

    public float cost() {
        return cost;
    }

    public int cooldown() {
        return cooldown;
    }

    public int windup() {
        return windup;
    }

    public CastPose pose() {
        return pose;
    }

    public boolean isDomain() {
        return this == DOMAIN_INFINITE_VOID || this == DOMAIN_MALEVOLENT_SHRINE || this == DOMAIN_IDLE_DEATH_GAMBLE;
    }

    public String id() {
        return name().toLowerCase(Locale.ROOT);
    }

    public Component displayName() {
        return Component.translatable("ability.jujutsukaisen." + id());
    }

    public static Ability byOrdinal(int ordinal) {
        Ability[] values = values();
        return ordinal >= 0 && ordinal < values.length ? values[ordinal] : null;
    }

    /** Body poses rendered on casters while winding up / casting. */
    public enum CastPose {
        NONE, POINT, PURPLE, SLASH, BOW, HAND_SIGN, SUMMON;

        public static CastPose byOrdinal(int ordinal) {
            CastPose[] values = values();
            return ordinal >= 0 && ordinal < values.length ? values[ordinal] : NONE;
        }
    }
}

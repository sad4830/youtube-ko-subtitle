package com.jujutsukaisen.config;

import net.minecraftforge.common.ForgeConfigSpec;

public final class JJKConfig {
    public static final ForgeConfigSpec SPEC;

    public static final ForgeConfigSpec.BooleanValue TECHNIQUE_BLOCK_DESTRUCTION;
    public static final ForgeConfigSpec.BooleanValue DOMAIN_BLOCK_DESTRUCTION;
    public static final ForgeConfigSpec.BooleanValue HOLLOW_PURPLE_BLOCK_DESTRUCTION;
    public static final ForgeConfigSpec.IntValue SHRINE_BLOCKS_PER_TICK;

    public static final ForgeConfigSpec.IntValue INFINITE_VOID_RADIUS;
    public static final ForgeConfigSpec.IntValue MALEVOLENT_SHRINE_RADIUS;
    public static final ForgeConfigSpec.IntValue IDLE_DEATH_GAMBLE_RADIUS;
    public static final ForgeConfigSpec.IntValue DOMAIN_DURATION_SECONDS;
    public static final ForgeConfigSpec.IntValue PLAYER_BURNOUT_SECONDS;

    public static final ForgeConfigSpec.DoubleValue BLACK_FLASH_CHANCE;
    public static final ForgeConfigSpec.DoubleValue BLACK_FLASH_ZONE_CHANCE;
    public static final ForgeConfigSpec.DoubleValue BLACK_FLASH_MULTIPLIER;

    public static final ForgeConfigSpec.BooleanValue TAMED_MAHORAGA_LOST_ON_DEATH;

    static {
        ForgeConfigSpec.Builder b = new ForgeConfigSpec.Builder();

        b.comment("World damage done by cursed techniques").push("destruction");
        TECHNIQUE_BLOCK_DESTRUCTION = b.comment("Techniques (Blue, Red, Dismantle, Fuga, World-Cutting Slash...) can break blocks. Mobs also need the mobGriefing gamerule.")
                .define("techniqueBlockDestruction", true);
        DOMAIN_BLOCK_DESTRUCTION = b.comment("Malevolent Shrine's Dismantle cuts apart everything without cursed energy inside its range (blocks).")
                .define("domainBlockDestruction", true);
        HOLLOW_PURPLE_BLOCK_DESTRUCTION = b.comment("Hollow Purple erases the blocks in its path.")
                .define("hollowPurpleBlockDestruction", true);
        SHRINE_BLOCKS_PER_TICK = b.comment("How many blocks Malevolent Shrine may dismantle per tick (performance limit).")
                .defineInRange("shrineBlocksPerTick", 48, 0, 1024);
        b.pop();

        b.comment("Domain Expansion (영역전개)").push("domain");
        INFINITE_VOID_RADIUS = b.comment("Radius of Unlimited Void's barrier.").defineInRange("infiniteVoidRadius", 14, 6, 48);
        MALEVOLENT_SHRINE_RADIUS = b.comment("Sure-hit radius of Malevolent Shrine (barrierless; canon is up to ~200 m).")
                .defineInRange("malevolentShrineRadius", 26, 8, 200);
        IDLE_DEATH_GAMBLE_RADIUS = b.comment("Radius of Idle Death Gamble's barrier.").defineInRange("idleDeathGambleRadius", 13, 6, 48);
        DOMAIN_DURATION_SECONDS = b.comment("How long a Domain Expansion lasts before it collapses.").defineInRange("domainDurationSeconds", 15, 3, 120);
        PLAYER_BURNOUT_SECONDS = b.comment("Technique burnout after a player's domain closes (Reverse Cursed Technique repairs it 3x faster).")
                .defineInRange("playerBurnoutSeconds", 12, 0, 300);
        b.pop();

        b.comment("Black Flash (흑섬)").push("black_flash");
        BLACK_FLASH_CHANCE = b.comment("Chance that a fully charged cursed-energy melee hit becomes a Black Flash. It cannot be done at will.")
                .defineInRange("chance", 0.04, 0.0, 1.0);
        BLACK_FLASH_ZONE_CHANCE = b.comment("Chance while in 'the zone' right after a Black Flash.").defineInRange("zoneChance", 0.2, 0.0, 1.0);
        BLACK_FLASH_MULTIPLIER = b.comment("Damage multiplier of a Black Flash (canon: the hit's power raised to the 2.5th; balanced as x2.5).")
                .defineInRange("multiplier", 2.5, 1.0, 10.0);
        b.pop();

        b.push("ten_shadows");
        TAMED_MAHORAGA_LOST_ON_DEATH = b.comment("Canon: if a tamed Mahoraga is destroyed the shikigami is lost and must be tamed again.")
                .define("tamedMahoragaLostOnDeath", true);
        b.pop();

        SPEC = b.build();
    }

    private JJKConfig() {
    }
}

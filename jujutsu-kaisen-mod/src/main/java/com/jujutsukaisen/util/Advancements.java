package com.jujutsukaisen.util;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.advancements.Advancement;
import net.minecraft.advancements.AdvancementProgress;
import net.minecraft.server.level.ServerPlayer;

public final class Advancements {
    private Advancements() {
    }

    /** Grants every remaining criterion of {@code jujutsukaisen:<name>}. */
    public static void award(ServerPlayer player, String name) {
        Advancement advancement = player.server.getAdvancements().getAdvancement(JujutsuKaisen.id(name));
        if (advancement == null) return;
        AdvancementProgress progress = player.getAdvancements().getOrStartProgress(advancement);
        if (progress.isDone()) return;
        for (String criterion : progress.getRemainingCriteria()) {
            player.getAdvancements().award(advancement, criterion);
        }
    }
}

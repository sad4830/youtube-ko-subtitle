package com.jujutsukaisen.client.hud;

import com.jujutsukaisen.client.KeyBindings;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.AbilityHandler;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.network.chat.Component;
import net.minecraft.util.Mth;
import net.minecraftforge.client.gui.overlay.ForgeGui;
import net.minecraftforge.client.gui.overlay.IGuiOverlay;

import java.util.List;

/** Cursed energy (주력) bar, technique list with cooldowns, status and the wind-up bar. */
public final class CursedEnergyHud implements IGuiOverlay {
    public static final CursedEnergyHud INSTANCE = new CursedEnergyHud();
    private float shownEnergy = -1;

    private CursedEnergyHud() {
    }

    @Override
    public void render(ForgeGui gui, GuiGraphics g, float partialTick, int width, int height) {
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        if (player == null || mc.options.hideGui || player.isSpectator()) return;
        SorcererData data = JJK.get(player);
        if (data == null) return;
        Technique technique = data.getTechnique();
        if (technique == Technique.NONE && data.getFingers() == 0) return;
        Font font = mc.font;

        int x = 6;
        int y = height - 66 - technique.abilities().size() * 11;
        int barW = 112;

        // Technique name.
        g.drawString(font, technique.displayName().copy().withStyle(ChatFormatting.BOLD), x, y, 0xFFFFFF, true);
        y += 11;

        // Cursed energy bar.
        float target = data.getCursedEnergy();
        shownEnergy = shownEnergy < 0 ? target : Mth.lerp(0.25f, shownEnergy, target);
        float ratio = data.getMaxCursedEnergy() <= 0 ? 0 : Mth.clamp(shownEnergy / data.getMaxCursedEnergy(), 0, 1);
        int color = data.isJackpot() ? rainbow(player.tickCount + partialTick) : technique.color();
        g.fill(x - 1, y - 1, x + barW + 1, y + 7, 0xC0000000);
        g.fill(x, y, x + (int) (barW * ratio), y + 6, 0xFF000000 | color);
        g.fill(x, y, x + (int) (barW * ratio), y + 2, 0x40FFFFFF);
        String ce = data.isJackpot() ? "∞" : (int) data.getCursedEnergy() + " / " + (int) data.getMaxCursedEnergy();
        g.drawString(font, Component.translatable("hud.jujutsukaisen.cursed_energy", ce), x + barW + 5, y - 1, 0xE0E0E0, true);
        y += 11;

        // Abilities.
        List<Ability> abilities = technique.abilities();
        for (int i = 0; i < abilities.size(); i++) {
            Ability ability = abilities.get(i);
            boolean selected = i == data.getSelected();
            int cd = data.getCooldown(ability);
            boolean affordable = data.isJackpot() || data.getCursedEnergy() >= AbilityHandler.costOf(player, data, ability);
            int textColor = cd > 0 ? 0x777777 : affordable ? (selected ? 0xFFFFFF : 0xB8B8B8) : 0xAA4444;
            if (selected) g.fill(x - 2, y - 1, x + barW + 2, y + 9, 0x60000000 | (technique.color() & 0xFFFFFF));
            String prefix = selected ? "▶ " : "  ";
            g.drawString(font, Component.literal(prefix).append(ability.displayName()), x, y, textColor, true);
            if (cd > 0) {
                String s = String.format("%.1fs", cd / 20f);
                g.drawString(font, s, x + barW - font.width(s), y, 0xAAAAAA, true);
            }
            y += 11;
        }

        // Status line.
        StringBuilder status = new StringBuilder();
        if (technique == Technique.LIMITLESS) status.append(data.isInfinityEnabled() && !data.isBurntOut() ? "§b∞ " : "§8∞ ");
        if (data.isRctActive()) status.append("§f✚ ");
        if (data.getZone() > 0) status.append("§4◆ ");
        if (data.getFingers() > 0) status.append("§c✋").append(data.getFingers()).append("/20 ");
        if (data.isMahoragaTamed()) status.append("§6☸ ");
        if (data.clientAdaptCount() > 0) status.append("§e⟳").append(data.clientAdaptCount()).append(' ');
        if (status.length() > 0) g.drawString(font, status.toString().trim(), x, y, 0xFFFFFF, true);
        y += 10;
        if (data.isBurntOut()) {
            g.drawString(font, Component.translatable("hud.jujutsukaisen.burnout", String.format("%.1f", data.getBurnout() / 20f))
                    .withStyle(ChatFormatting.DARK_RED), x, y, 0xFFFFFF, true);
        }

        // Keys hint.
        g.drawString(font, Component.translatable("hud.jujutsukaisen.keys", KeyBindings.USE.getTranslatedKeyMessage(),
                KeyBindings.CYCLE.getTranslatedKeyMessage(), KeyBindings.DOMAIN.getTranslatedKeyMessage()).withStyle(ChatFormatting.DARK_GRAY),
                x, height - 12, 0xFFFFFF, false);

        // Jackpot timer: 4:11 counting down.
        if (data.isJackpot()) {
            int seconds = data.getJackpot() / 20;
            String time = String.format("%d:%02d", seconds / 60, seconds % 60);
            Component jackpot = Component.translatable("hud.jujutsukaisen.jackpot", time).withStyle(ChatFormatting.BOLD);
            g.drawCenteredString(font, jackpot, width / 2, 4, rainbow(player.tickCount + partialTick));
        }

        // Wind-up bar under the crosshair.
        Ability casting = data.getCasting();
        if (casting != null && data.getCastTotal() > 0) {
            float progress = 1f - data.getCastTicks() / (float) data.getCastTotal();
            int w = 80, cx = width / 2 - w / 2, cy = height / 2 + 14;
            g.fill(cx - 1, cy - 1, cx + w + 1, cy + 4, 0xA0000000);
            g.fill(cx, cy, cx + (int) (w * Mth.clamp(progress, 0, 1)), cy + 3, 0xFF000000 | technique.color());
            g.drawCenteredString(font, casting.displayName(), width / 2, cy + 6, 0xFFFFFF);
        }
    }

    private static int rainbow(float t) {
        return Mth.hsvToRgb((t * 0.01f) % 1f, 0.7f, 1f);
    }
}

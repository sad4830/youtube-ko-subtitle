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

/**
 * Cursed energy (주력) bar, technique list with cooldowns, status and the wind-up bar. The block sits at the top
 * left: the bottom left belongs to chat, which would be drawn over it. It moves below the boss bars when they
 * would overlap it.
 */
public final class CursedEnergyHud implements IGuiOverlay {
    public static final CursedEnergyHud INSTANCE = new CursedEnergyHud();
    private float shownEnergy = -1;
    /** Bottom of the boss-bar stack in the last frame (0 if none), and the one being collected now. */
    private static int bossBottom, bossBottomNow;
    /** Right edge of this block in the current frame (0 if hidden): the slot machine keeps clear of it. */
    private static int blockRight;

    private CursedEnergyHud() {
    }

    /** CustomizeGuiOverlayEvent.BossEventProgress: a boss bar at this y (bars are 5 px tall). */
    public static void bossBarAt(int y) {
        bossBottomNow = Math.max(bossBottomNow, y + 5);
    }

    /** RenderGuiEvent.Pre: boss bars are drawn after this overlay, so it uses the previous frame's stack. */
    public static void frameStart() {
        bossBottom = bossBottomNow;
        bossBottomNow = 0;
        blockRight = 0;
    }

    /** Top y for elements centred at the top of the screen (below any boss bars). */
    public static int topBelowBossBars() {
        return bossBottom > 0 ? bossBottom + 4 : 4;
    }

    public static int blockRight() {
        return blockRight;
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

        // The top-left block gives way to the F3 screen; the wind-up bar below still shows.
        if (!mc.options.renderDebug) {
            drawBlock(g, font, player, data, technique, partialTick, width);
        } else if (data.isJackpot()) {
            int seconds = data.getJackpot() / 20;
            Component jackpot = Component.translatable("hud.jujutsukaisen.jackpot", String.format("%d:%02d", seconds / 60, seconds % 60))
                    .withStyle(ChatFormatting.BOLD);
            g.drawCenteredString(font, jackpot, width / 2, height / 2 + 36, rainbow(player.tickCount + partialTick));
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

    /** Technique name, cursed energy, abilities and status in the top-left corner (below boss bars if they overlap). */
    private void drawBlock(GuiGraphics g, Font font, LocalPlayer player, SorcererData data, Technique technique, float partialTick, int width) {
        int x = 6;
        int barW = 112;
        Component keys = Component.translatable("hud.jujutsukaisen.keys", KeyBindings.USE.getTranslatedKeyMessage(),
                KeyBindings.CYCLE.getTranslatedKeyMessage(), KeyBindings.DOMAIN.getTranslatedKeyMessage());
        if (technique.character() != null) {
            keys = keys.copy().append(Component.translatable("hud.jujutsukaisen.keys_appearance", KeyBindings.APPEARANCE.getTranslatedKeyMessage()));
        }
        String ce = data.isJackpot() ? "∞" : (int) data.getCursedEnergy() + " / " + (int) data.getMaxCursedEnergy();
        Component ceText = Component.translatable("hud.jujutsukaisen.cursed_energy", ce);
        int right = x + Math.max(font.width(keys), barW + 5 + font.width(ceText));
        blockRight = right + 4;
        // Below the boss bars only if it would run into them (they are centred, 182 px wide).
        int top = bossBottom > 0 && right > width / 2 - 91 ? bossBottom + 4 : 4;
        int y = top + 11;

        // Keys hint, then the technique name.
        g.drawString(font, keys.copy().withStyle(ChatFormatting.GRAY), x, y - 11, 0xFFFFFF, true);
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
        g.drawString(font, ceText, x + barW + 5, y - 1, 0xE0E0E0, true);
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
        } else if (data.isJackpot()) {
            // Jackpot timer: 4:11 counting down.
            int seconds = data.getJackpot() / 20;
            String time = String.format("%d:%02d", seconds / 60, seconds % 60);
            Component jackpot = Component.translatable("hud.jujutsukaisen.jackpot", time).withStyle(ChatFormatting.BOLD);
            g.drawString(font, jackpot, x, y, rainbow(player.tickCount + partialTick), true);
        }
    }

    private static int rainbow(float t) {
        return Mth.hsvToRgb((t * 0.01f) % 1f, 0.7f, 1f);
    }
}

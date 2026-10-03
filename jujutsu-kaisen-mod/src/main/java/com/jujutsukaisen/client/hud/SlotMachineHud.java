package com.jujutsukaisen.client.hud;

import com.jujutsukaisen.domain.Indicator;
import com.jujutsukaisen.domain.Riichi;
import com.jujutsukaisen.network.S2CSlotSpin;
import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;
import net.minecraft.util.Mth;
import net.minecraftforge.client.gui.overlay.ForgeGui;
import net.minecraftforge.client.gui.overlay.IGuiOverlay;

/**
 * The pachinko reels of CR Private Pure Love Train shown to everyone in Idle Death Gamble:
 * three reels, the notice colour, the riichi action, and the result.
 */
public final class SlotMachineHud implements IGuiOverlay {
    public static final SlotMachineHud INSTANCE = new SlotMachineHud();
    private static final int HOLD_AFTER = 50;

    private static int[] reels = {7, 7, 7};
    private static Indicator indicator = Indicator.GREEN;
    private static Riichi riichi = Riichi.TRANSIT_CARD;
    private static boolean win;
    private static int total;
    private static int spin;
    private static long startTick = -1000;

    private SlotMachineHud() {
    }

    public static void start(S2CSlotSpin message) {
        reels = message.reels.clone();
        indicator = Indicator.byOrdinal(message.indicator);
        riichi = Riichi.byOrdinal(message.riichi);
        win = message.win;
        total = message.ticks;
        spin = message.spin;
        Minecraft mc = Minecraft.getInstance();
        startTick = mc.level == null ? 0 : mc.level.getGameTime();
    }

    /** Hides the machine immediately. */
    public static void stop() {
        startTick = -100000;
    }

    @Override
    public void render(ForgeGui gui, GuiGraphics graphics, float partialTick, int width, int height) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.level == null || mc.options.hideGui) return;
        float elapsed = mc.level.getGameTime() - startTick + partialTick;
        if (elapsed < 0 || elapsed > total + HOLD_AFTER) return;
        Font font = mc.font;

        int boxW = 168, boxH = 74;
        // Centred below the boss bars, nudged right if the cursed-energy block (top left) is in the way.
        int x = Math.max((width - boxW) / 2, CursedEnergyHud.blockRight() + 4);
        if (x + boxW > width - 2) x = Math.max(2, width - 2 - boxW);
        int y = CursedEnergyHud.topBelowBossBars() + 14;
        int mid = x + boxW / 2;
        float fade = elapsed > total + HOLD_AFTER - 10 ? (total + HOLD_AFTER - elapsed) / 10f : 1f;
        int alpha = (int) (Mth.clamp(fade, 0, 1) * 220) << 24;

        graphics.fill(x - 2, y - 2, x + boxW + 2, y + boxH + 2, alpha | (indicator.color() & 0xFFFFFF));
        graphics.fill(x, y, x + boxW, y + boxH, alpha | 0x14101C);
        graphics.drawCenteredString(font, Component.translatable("gamble.jujutsukaisen.machine").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD),
                mid, y + 4, 0xFFFFFF);

        // Reels: the first two stop together (riichi), the third keeps spinning until the end.
        int reelW = 40, reelH = 34, gap = 12;
        int rx = mid - (reelW * 3 + gap * 2) / 2;
        int ry = y + 16;
        float stopTwo = total * 0.35f;
        for (int i = 0; i < 3; i++) {
            int cx = rx + i * (reelW + gap);
            graphics.fill(cx, ry, cx + reelW, ry + reelH, alpha | 0xF4F0E6);
            graphics.fill(cx + 1, ry + 1, cx + reelW - 1, ry + reelH - 1, alpha | 0xFFFFFF);
            boolean stopped = i < 2 ? elapsed >= stopTwo : elapsed >= total;
            int number = stopped ? reels[i] : 1 + (int) ((elapsed * 1.7f + i * 3) % 7);
            int color = stopped ? (win && elapsed >= total ? rainbow(elapsed) : 0xC0182C) : 0x555555;
            graphics.pose().pushPose();
            graphics.pose().translate(cx + reelW / 2f, ry + reelH / 2f - 7, 0);
            graphics.pose().scale(2.2f, 2.2f, 1f);
            graphics.drawCenteredString(font, String.valueOf(number), 0, 0, color);
            graphics.pose().popPose();
        }

        Component line;
        if (elapsed < stopTwo) {
            line = Component.translatable("gamble.jujutsukaisen.spin", spin).withStyle(ChatFormatting.GRAY);
        } else if (elapsed < total) {
            line = Component.translatable("gamble.jujutsukaisen.riichi").append(" ").append(riichi.displayName())
                    .append(Component.literal(" " + "★".repeat(riichi.stars()) + "☆".repeat(3 - riichi.stars())).withStyle(ChatFormatting.YELLOW));
        } else {
            line = win ? Component.translatable("gamble.jujutsukaisen.jackpot").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD)
                    : Component.translatable("gamble.jujutsukaisen.miss").withStyle(ChatFormatting.GRAY);
        }
        graphics.drawCenteredString(font, line, mid, ry + reelH + 6, 0xFFFFFF);
        graphics.drawString(font, indicator.displayName(), x + 4, y + boxH - 10, 0xFFFFFF);
    }

    private static int rainbow(float t) {
        float hue = (t * 0.03f) % 1f;
        return Mth.hsvToRgb(hue, 0.8f, 1f);
    }
}

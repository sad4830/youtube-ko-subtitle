package com.jujutsukaisen.client.hud;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.registry.ModEffects;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraftforge.client.gui.overlay.ForgeGui;
import net.minecraftforge.client.gui.overlay.IGuiOverlay;

/**
 * 무량공처 — what the victim perceives: the void of the universe and an endless torrent of
 * information that never finishes arriving.
 */
public final class InfiniteVoidOverlay implements IGuiOverlay {
    public static final InfiniteVoidOverlay INSTANCE = new InfiniteVoidOverlay();
    private static final ResourceLocation TEXTURE = JujutsuKaisen.id("textures/gui/infinite_void.png");
    private final RandomSource random = RandomSource.create();

    private InfiniteVoidOverlay() {
    }

    @Override
    public void render(ForgeGui gui, GuiGraphics g, float partialTick, int width, int height) {
        Minecraft mc = Minecraft.getInstance();
        LocalPlayer player = mc.player;
        if (player == null || !player.hasEffect(ModEffects.INFORMATION_OVERLOAD.get())) return;
        float t = player.tickCount + partialTick;
        float alpha = 0.78f + Mth.sin(t * 0.21f) * 0.08f;

        RenderSystem.enableBlend();
        RenderSystem.defaultBlendFunc();
        g.setColor(1f, 1f, 1f, alpha);
        g.blit(TEXTURE, 0, 0, 0, 0, width, height, width, height);
        g.setColor(1f, 1f, 1f, 1f);

        // Streams of information, endlessly.
        random.setSeed((long) (t / 2));
        for (int i = 0; i < 70; i++) {
            int x = random.nextInt(Math.max(1, width));
            int y = random.nextInt(Math.max(1, height));
            int len = 6 + random.nextInt(60);
            int a = 40 + random.nextInt(150);
            g.fill(x, y, x + len, y + 1, (a << 24) | 0xE8F6FF);
        }
        for (int i = 0; i < 24; i++) {
            int x = random.nextInt(Math.max(1, width));
            int y = random.nextInt(Math.max(1, height));
            g.drawString(mc.font, random.nextBoolean() ? "∞" : String.valueOf((char) ('ア' + random.nextInt(40))), x, y,
                    (random.nextInt(120) + 80) << 24 | 0x9FE6FF, false);
        }
        RenderSystem.disableBlend();
    }
}

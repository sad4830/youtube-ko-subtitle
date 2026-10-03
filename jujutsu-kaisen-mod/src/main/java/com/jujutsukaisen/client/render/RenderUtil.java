package com.jujutsukaisen.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import org.joml.Matrix3f;
import org.joml.Matrix4f;

/** Quad helpers for the glowing technique visuals. */
public final class RenderUtil {
    public static final int FULL_BRIGHT = 0xF000F0;

    private RenderUtil() {
    }

    /** A camera-independent quad in the local XY plane, centred, both sides. */
    public static void quad(VertexConsumer vc, PoseStack.Pose pose, float halfW, float halfH, int color, int alpha, int light) {
        quad(vc, pose, -halfW, -halfH, halfW, halfH, 0f, 0f, 1f, 1f, color, alpha, light);
    }

    public static void quad(VertexConsumer vc, PoseStack.Pose pose, float x0, float y0, float x1, float y1,
                            float u0, float v0, float u1, float v1, int color, int alpha, int light) {
        Matrix4f m = pose.pose();
        Matrix3f n = pose.normal();
        int r = (color >> 16) & 0xFF, g = (color >> 8) & 0xFF, b = color & 0xFF;
        vertex(vc, m, n, x0, y0, u0, v1, r, g, b, alpha, light, 1);
        vertex(vc, m, n, x1, y0, u1, v1, r, g, b, alpha, light, 1);
        vertex(vc, m, n, x1, y1, u1, v0, r, g, b, alpha, light, 1);
        vertex(vc, m, n, x0, y1, u0, v0, r, g, b, alpha, light, 1);
        // back face
        vertex(vc, m, n, x0, y1, u0, v0, r, g, b, alpha, light, -1);
        vertex(vc, m, n, x1, y1, u1, v0, r, g, b, alpha, light, -1);
        vertex(vc, m, n, x1, y0, u1, v1, r, g, b, alpha, light, -1);
        vertex(vc, m, n, x0, y0, u0, v1, r, g, b, alpha, light, -1);
    }

    private static void vertex(VertexConsumer vc, Matrix4f m, Matrix3f n, float x, float y, float u, float v,
                               int r, int g, int b, int a, int light, int nz) {
        vc.vertex(m, x, y, 0f).color(r, g, b, a).uv(u, v).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(n, 0f, 0f, nz).endVertex();
    }
}

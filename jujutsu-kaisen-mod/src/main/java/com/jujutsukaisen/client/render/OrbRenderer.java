package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.entity.projectile.BlueEntity;
import com.jujutsukaisen.entity.projectile.HollowPurpleEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;

/**
 * Glowing spheres of Limitless: Blue (attraction), Red (repulsion) and Hollow Purple
 * (imaginary mass) — a dark core, additive glow shells and a turning swirl.
 */
public class OrbRenderer<T extends Entity> extends EntityRenderer<T> {
    public static final ResourceLocation GLOW = JujutsuKaisen.id("textures/entity/orb_glow.png");
    public static final ResourceLocation CORE = JujutsuKaisen.id("textures/entity/orb_core.png");
    public static final ResourceLocation SWIRL = JujutsuKaisen.id("textures/entity/orb_swirl.png");

    public enum Kind {BLUE, RED, PURPLE}

    private final Kind kind;

    public OrbRenderer(EntityRendererProvider.Context context, Kind kind) {
        super(context);
        this.kind = kind;
        this.shadowRadius = 0f;
    }

    @Override
    public void render(T entity, float yaw, float partialTick, PoseStack poseStack, MultiBufferSource buffers, int light) {
        float t = entity.tickCount + partialTick;
        float size = switch (kind) {
            case BLUE -> 1.4f + Mth.sin(t * 0.35f) * 0.12f;
            case RED -> 1.0f + Mth.sin(t * 0.6f) * 0.1f;
            case PURPLE -> (entity instanceof HollowPurpleEntity purple ? purple.getRadius() : 2.6f) * 2.0f;
        };
        if (kind == Kind.BLUE && entity instanceof BlueEntity blue) size *= 0.85f + blue.getRadius() * 0.03f;
        int glow = switch (kind) {
            case BLUE -> 0x3FA8FF;
            case RED -> 0xFF2A1C;
            case PURPLE -> 0xA040FF;
        };
        int core = switch (kind) {
            case BLUE -> 0xD8F4FF;
            case RED -> 0xFFE0D0;
            case PURPLE -> 0x14001E;
        };

        poseStack.pushPose();
        poseStack.translate(0, entity.getBbHeight() * 0.5, 0);
        poseStack.mulPose(entityRenderDispatcher.cameraOrientation());

        // Outer glow shells (additive).
        poseStack.pushPose();
        poseStack.mulPose(Axis.ZP.rotationDegrees(t * 4f));
        RenderUtil.quad(buffers.getBuffer(RenderType.eyes(GLOW)), poseStack.last(), size * 1.25f, size * 1.25f, glow, 200, RenderUtil.FULL_BRIGHT);
        poseStack.popPose();
        poseStack.pushPose();
        poseStack.mulPose(Axis.ZP.rotationDegrees(-t * (kind == Kind.PURPLE ? 9f : 6f)));
        RenderUtil.quad(buffers.getBuffer(RenderType.eyes(SWIRL)), poseStack.last(), size * 0.95f, size * 0.95f, glow, 255, RenderUtil.FULL_BRIGHT);
        poseStack.popPose();

        // Core.
        float coreSize = kind == Kind.PURPLE ? size * 0.62f : size * 0.42f;
        RenderType coreType = kind == Kind.PURPLE ? RenderType.entityTranslucent(CORE) : RenderType.eyes(CORE);
        RenderUtil.quad(buffers.getBuffer(coreType), poseStack.last(), coreSize, coreSize, core, kind == Kind.PURPLE ? 235 : 255, RenderUtil.FULL_BRIGHT);
        if (kind == Kind.PURPLE) {
            poseStack.mulPose(Axis.ZP.rotationDegrees(t * 12f));
            RenderUtil.quad(buffers.getBuffer(RenderType.eyes(SWIRL)), poseStack.last(), size * 0.7f, size * 0.7f, 0xFF66FF, 180, RenderUtil.FULL_BRIGHT);
        }
        poseStack.popPose();
        super.render(entity, yaw, partialTick, poseStack, buffers, light);
    }

    @Override
    public ResourceLocation getTextureLocation(T entity) {
        return GLOW;
    }
}

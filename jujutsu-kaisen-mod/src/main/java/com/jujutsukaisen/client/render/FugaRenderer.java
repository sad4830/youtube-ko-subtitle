package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.entity.projectile.FugaEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;

/** 「竈」開 — the flame arrow: crossed blazing planes along its flight. */
public class FugaRenderer extends EntityRenderer<FugaEntity> {
    public static final ResourceLocation TEXTURE = JujutsuKaisen.id("textures/entity/fuga.png");

    public FugaRenderer(EntityRendererProvider.Context context) {
        super(context);
        this.shadowRadius = 0f;
    }

    @Override
    public void render(FugaEntity entity, float yaw, float partialTick, PoseStack poseStack, MultiBufferSource buffers, int light) {
        poseStack.pushPose();
        poseStack.translate(0, entity.getBbHeight() * 0.5, 0);
        poseStack.mulPose(Axis.YP.rotationDegrees(Mth.lerp(partialTick, entity.yRotO, entity.getYRot()) - 90f));
        poseStack.mulPose(Axis.ZP.rotationDegrees(Mth.lerp(partialTick, entity.xRotO, entity.getXRot())));
        float t = entity.tickCount + partialTick;
        float flicker = 1f + Mth.sin(t * 1.7f) * 0.08f;
        for (int i = 0; i < 3; i++) {
            poseStack.pushPose();
            poseStack.mulPose(Axis.XP.rotationDegrees(i * 60f + t * 8f));
            RenderUtil.quad(buffers.getBuffer(RenderType.eyes(TEXTURE)), poseStack.last(),
                    -2.4f * flicker, -0.45f * flicker, 0.6f, 0.45f * flicker, 0, 0, 1, 1, 0xFFB040, 255, RenderUtil.FULL_BRIGHT);
            poseStack.popPose();
        }
        poseStack.popPose();
        super.render(entity, yaw, partialTick, poseStack, buffers, light);
    }

    @Override
    public ResourceLocation getTextureLocation(FugaEntity entity) {
        return TEXTURE;
    }
}

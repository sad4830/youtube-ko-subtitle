package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.entity.projectile.DismantleEntity;
import com.jujutsukaisen.entity.projectile.WorldSlashEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;

/** Crescent slashes: Dismantle (thin, pale, nearly invisible) and the World-Cutting Slash (huge, black-crimson). */
public class SlashRenderer<T extends Entity> extends EntityRenderer<T> {
    public static final ResourceLocation SLASH = JujutsuKaisen.id("textures/entity/slash.png");
    public static final ResourceLocation WORLD_SLASH = JujutsuKaisen.id("textures/entity/world_slash.png");

    public SlashRenderer(EntityRendererProvider.Context context) {
        super(context);
        this.shadowRadius = 0f;
    }

    @Override
    public void render(T entity, float yaw, float partialTick, PoseStack poseStack, MultiBufferSource buffers, int light) {
        boolean world = entity instanceof WorldSlashEntity;
        float roll = entity instanceof DismantleEntity d ? d.getRoll() : entity instanceof WorldSlashEntity w ? w.getRoll() : 0f;
        float scale = entity instanceof DismantleEntity d ? d.getScale() : 1f;
        float length = world ? (float) WorldSlashEntity.HALF_WIDTH * 2f : 2.6f * scale;
        float depth = world ? 2.2f : 0.7f * scale;

        poseStack.pushPose();
        poseStack.translate(0, entity.getBbHeight() * 0.5, 0);
        poseStack.mulPose(Axis.YP.rotationDegrees(Mth.lerp(partialTick, entity.yRotO, entity.getYRot()) - 90f));
        poseStack.mulPose(Axis.ZP.rotationDegrees(Mth.lerp(partialTick, entity.xRotO, entity.getXRot())));
        poseStack.mulPose(Axis.XP.rotationDegrees(roll));
        int age = entity.tickCount;
        int alpha = world ? 255 : Mth.clamp(220 - age * 6, 60, 220);
        if (world) {
            RenderUtil.quad(buffers.getBuffer(RenderType.entityTranslucent(WORLD_SLASH)), poseStack.last(),
                    -depth, -length / 2f, depth, length / 2f, 0, 0, 1, 1, 0x0A0006, 245, RenderUtil.FULL_BRIGHT);
            RenderUtil.quad(buffers.getBuffer(RenderType.eyes(SLASH)), poseStack.last(),
                    -depth * 1.15f, -length / 2f * 1.05f, depth * 1.15f, length / 2f * 1.05f, 0, 0, 1, 1, 0xFF2030, 255, RenderUtil.FULL_BRIGHT);
        } else {
            RenderUtil.quad(buffers.getBuffer(RenderType.eyes(SLASH)), poseStack.last(),
                    -depth, -length / 2f, depth, length / 2f, 0, 0, 1, 1, RenderUtil.premultiply(0xFFF4F4, alpha), 255, RenderUtil.FULL_BRIGHT);
        }
        poseStack.popPose();
        super.render(entity, yaw, partialTick, poseStack, buffers, light);
    }

    @Override
    public ResourceLocation getTextureLocation(T entity) {
        return SLASH;
    }
}

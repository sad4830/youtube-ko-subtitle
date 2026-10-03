package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.client.model.ShutterDoorModel;
import com.jujutsukaisen.entity.misc.ShutterDoorEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;

public class ShutterDoorRenderer extends EntityRenderer<ShutterDoorEntity> {
    public static final ResourceLocation TEXTURE = JujutsuKaisen.id("textures/entity/shutter_door.png");
    private final ShutterDoorModel model;

    public ShutterDoorRenderer(EntityRendererProvider.Context context) {
        super(context);
        this.model = new ShutterDoorModel(context.bakeLayer(ModLayers.SHUTTER_DOOR));
    }

    @Override
    public void render(ShutterDoorEntity entity, float yaw, float partialTick, PoseStack poseStack, MultiBufferSource buffers, int light) {
        poseStack.pushPose();
        poseStack.mulPose(Axis.YP.rotationDegrees(180f - entity.getYRot()));
        poseStack.scale(-1f, -1f, 1f);
        poseStack.translate(0, -1.501f, 0);
        model.setupAnim(entity, 0, 0, entity.tickCount + partialTick, 0, 0);
        int color = entity.getIndicator().color();
        float tint = 0.35f;
        float r = 1f - tint + tint * ((color >> 16) & 0xFF) / 255f;
        float g = 1f - tint + tint * ((color >> 8) & 0xFF) / 255f;
        float b = 1f - tint + tint * (color & 0xFF) / 255f;
        model.renderToBuffer(poseStack, buffers.getBuffer(RenderType.entityCutoutNoCull(TEXTURE)), light, OverlayTexture.NO_OVERLAY, r, g, b, 1f);
        poseStack.popPose();
        super.render(entity, yaw, partialTick, poseStack, buffers, light);
    }

    @Override
    public ResourceLocation getTextureLocation(ShutterDoorEntity entity) {
        return TEXTURE;
    }
}

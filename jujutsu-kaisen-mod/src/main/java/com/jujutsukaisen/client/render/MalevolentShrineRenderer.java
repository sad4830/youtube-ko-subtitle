package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.model.MalevolentShrineModel;
import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.entity.misc.MalevolentShrineEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;

/** Malevolent Shrine rising from the ground behind Sukuna. */
public class MalevolentShrineRenderer extends EntityRenderer<MalevolentShrineEntity> {
    public static final ResourceLocation TEXTURE = JujutsuKaisen.id("textures/entity/malevolent_shrine.png");
    private static final float SCALE = 3.0f;
    private final MalevolentShrineModel model;

    public MalevolentShrineRenderer(EntityRendererProvider.Context context) {
        super(context);
        this.model = new MalevolentShrineModel(context.bakeLayer(ModLayers.MALEVOLENT_SHRINE));
        this.shadowRadius = 4.0f;
    }

    @Override
    public void render(MalevolentShrineEntity entity, float yaw, float partialTick, PoseStack poseStack, MultiBufferSource buffers, int light) {
        poseStack.pushPose();
        float rise = entity.rise(partialTick);
        poseStack.translate(0, -(1f - rise) * 7f, 0);
        poseStack.mulPose(Axis.YP.rotationDegrees(180f - entity.getYRot()));
        poseStack.scale(SCALE, SCALE, SCALE);
        poseStack.scale(-1f, -1f, 1f);
        poseStack.translate(0, -1.501f, 0);
        model.setupAnim(entity, 0, 0, entity.tickCount + partialTick, 0, 0);
        model.renderToBuffer(poseStack, buffers.getBuffer(RenderType.entityCutoutNoCull(TEXTURE)), light, OverlayTexture.NO_OVERLAY, 1f, 1f, 1f, 1f);
        poseStack.popPose();
        super.render(entity, yaw, partialTick, poseStack, buffers, light);
    }

    @Override
    public boolean shouldRender(MalevolentShrineEntity entity, net.minecraft.client.renderer.culling.Frustum frustum, double x, double y, double z) {
        return true;
    }

    @Override
    public ResourceLocation getTextureLocation(MalevolentShrineEntity entity) {
        return TEXTURE;
    }
}

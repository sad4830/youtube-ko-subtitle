package com.jujutsukaisen.client.render;

import com.jujutsukaisen.entity.SorcererEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.model.EntityModel;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.RenderLayerParent;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;

/**
 * Visible cursed energy: a flowing aura in the technique's colour while winding up a technique,
 * white while Reverse Cursed Technique heals, and gold during Hakari's jackpot.
 */
public class CursedAuraLayer<T extends SorcererEntity, M extends EntityModel<T>> extends RenderLayer<T, M> {
    private static final ResourceLocation SWIRL = new ResourceLocation("textures/entity/creeper/creeper_armor.png");

    public CursedAuraLayer(RenderLayerParent<T, M> parent) {
        super(parent);
    }

    @Override
    public void render(PoseStack poseStack, MultiBufferSource buffers, int light, T entity, float limbSwing, float limbSwingAmount,
                       float partialTick, float ageInTicks, float netHeadYaw, float headPitch) {
        int color;
        if (entity.hasFlag(SorcererEntity.FLAG_JACKPOT)) color = 0xFFC830;
        else if (entity.hasFlag(SorcererEntity.FLAG_CASTING)) color = entity.technique().color();
        else if (entity.hasFlag(SorcererEntity.FLAG_RCT)) color = 0xE8F0FF;
        else return;
        float t = ageInTicks * 0.01f;
        VertexConsumer vc = buffers.getBuffer(RenderType.energySwirl(SWIRL, (t * 3f) % 1f, (t * 2f) % 1f));
        poseStack.pushPose();
        poseStack.scale(1.07f, 1.04f, 1.07f);
        poseStack.translate(0, -0.03f, 0);
        getParentModel().renderToBuffer(poseStack, vc, light, OverlayTexture.NO_OVERLAY,
                ((color >> 16) & 0xFF) / 255f, ((color >> 8) & 0xFF) / 255f, (color & 0xFF) / 255f, 1f);
        poseStack.popPose();
    }
}

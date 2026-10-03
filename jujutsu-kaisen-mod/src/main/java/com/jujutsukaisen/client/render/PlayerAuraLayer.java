package com.jujutsukaisen.client.render;

import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.RenderLayerParent;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;

/** Visible cursed energy on players: technique colour while casting, white during RCT, gold in a jackpot. */
public class PlayerAuraLayer extends RenderLayer<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>> {
    private static final ResourceLocation SWIRL = new ResourceLocation("textures/entity/creeper/creeper_armor.png");

    public PlayerAuraLayer(RenderLayerParent<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>> parent) {
        super(parent);
    }

    @Override
    public void render(PoseStack poseStack, MultiBufferSource buffers, int light, AbstractClientPlayer player, float limbSwing,
                       float limbSwingAmount, float partialTick, float ageInTicks, float netHeadYaw, float headPitch) {
        SorcererData data = JJK.get(player);
        if (data == null || player.isInvisible()) return;
        int color;
        if (data.isJackpot()) color = 0xFFC830;
        else if (data.getCasting() != null) color = data.getTechnique().color();
        else if (data.isRctActive()) color = 0xE8F0FF;
        else return;
        float t = ageInTicks * 0.01f;
        VertexConsumer vc = buffers.getBuffer(RenderType.energySwirl(SWIRL, (t * 3f) % 1f, (t * 2f) % 1f));
        float pulse = 0.42f + 0.12f * Mth.sin(ageInTicks * 0.25f);
        poseStack.pushPose();
        poseStack.scale(1.07f, 1.04f, 1.07f);
        poseStack.translate(0, -0.03f, 0);
        getParentModel().renderToBuffer(poseStack, vc, light, OverlayTexture.NO_OVERLAY,
                ((color >> 16) & 0xFF) / 255f * pulse, ((color >> 8) & 0xFF) / 255f * pulse, (color & 0xFF) / 255f * pulse, 1f);
        poseStack.popPose();
    }
}

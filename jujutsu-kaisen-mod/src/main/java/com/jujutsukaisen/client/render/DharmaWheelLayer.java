package com.jujutsukaisen.client.render;

import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.sorcery.Adaptation;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.EntityModelSet;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.RenderLayerParent;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.util.Mth;

import java.util.Map;
import java.util.UUID;
import java.util.WeakHashMap;

/** Whoever bears the Dharma Wheel carries it above their head, as Sukuna did in Shinjuku. */
public class DharmaWheelLayer extends RenderLayer<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>> {
    private final ModelPart wheel;
    /** Shared by every renderer's copy of this layer: a player switches renderers when casting or changing look. */
    private static final Map<UUID, float[]> angles = new WeakHashMap<>();

    public DharmaWheelLayer(RenderLayerParent<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>> parent, EntityModelSet models) {
        super(parent);
        this.wheel = models.bakeLayer(ModLayers.DHARMA_WHEEL).getChild("wheel");
    }

    @Override
    public void render(PoseStack poseStack, MultiBufferSource buffers, int light, AbstractClientPlayer player, float limbSwing,
                       float limbSwingAmount, float partialTick, float ageInTicks, float netHeadYaw, float headPitch) {
        if (!Adaptation.bearsWheel(player) || player.isInvisible()) return;
        SorcererData data = JJK.get(player);
        int turns = data == null ? 0 : data.getWheelTurns();
        float[] angle = angles.computeIfAbsent(player.getUUID(), k -> new float[]{turns * 45f});
        angle[0] += (turns * 45f - angle[0]) * 0.12f;

        poseStack.pushPose();
        getParentModel().head.translateAndRotate(poseStack);
        poseStack.translate(0, -0.95f + Mth.sin(ageInTicks * 0.08f) * 0.03f, 0);
        poseStack.scale(0.42f, 0.42f, 0.42f);
        wheel.zRot = -angle[0] * Mth.DEG_TO_RAD;
        wheel.render(poseStack, buffers.getBuffer(RenderType.entityCutoutNoCull(MahoragaRenderer.TEXTURE)), light, OverlayTexture.NO_OVERLAY);
        poseStack.popPose();
    }
}

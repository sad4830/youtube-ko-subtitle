package com.jujutsukaisen.client.render;

import com.jujutsukaisen.client.model.CastingPlayerModel;
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.player.PlayerRenderer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.entity.player.PlayerModelPart;
import org.jetbrains.annotations.Nullable;

/**
 * Renders a player as Gojo / Hakari / Sukuna (or with their own skin) on a model that strikes the
 * technique poses. Keeps every vanilla player layer (armor, held items, cape, elytra...).
 */
public class CharacterPlayerRenderer extends PlayerRenderer {
    @Nullable
    private final ResourceLocation texture;

    public CharacterPlayerRenderer(EntityRendererProvider.Context context, CastingPlayerModel model, boolean slim, @Nullable ResourceLocation texture) {
        super(context, slim);
        this.model = model;
        this.texture = texture;
        addLayer(new PlayerAuraLayer(this));
        addLayer(new DharmaWheelLayer(this, context.getModelSet()));
    }

    @Override
    public ResourceLocation getTextureLocation(AbstractClientPlayer player) {
        return texture != null ? texture : player.getSkinTextureLocation();
    }

    /** First-person bare hand in the character's skin. */
    public void renderCharacterHand(PoseStack poseStack, MultiBufferSource buffers, int light, AbstractClientPlayer player, HumanoidArm side) {
        PlayerModel<AbstractClientPlayer> m = getModel();
        CastingPlayerModel casting = m instanceof CastingPlayerModel c ? c : null;
        if (casting != null) casting.firstPersonHand = true;
        m.attackTime = 0.0f;
        m.crouching = false;
        m.swimAmount = 0.0f;
        m.setupAnim(player, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
        if (casting != null) casting.firstPersonHand = false;
        boolean right = side == HumanoidArm.RIGHT;
        ModelPart arm = right ? m.rightArm : m.leftArm;
        ModelPart sleeve = right ? m.rightSleeve : m.leftSleeve;
        arm.visible = true;
        sleeve.visible = player.isModelPartShown(right ? PlayerModelPart.RIGHT_SLEEVE : PlayerModelPart.LEFT_SLEEVE);
        ResourceLocation tex = getTextureLocation(player);
        arm.xRot = 0.0f;
        arm.render(poseStack, buffers.getBuffer(RenderType.entitySolid(tex)), light, OverlayTexture.NO_OVERLAY);
        sleeve.xRot = 0.0f;
        sleeve.render(poseStack, buffers.getBuffer(RenderType.entityTranslucent(tex)), light, OverlayTexture.NO_OVERLAY);
    }
}

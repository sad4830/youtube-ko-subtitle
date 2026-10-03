package com.jujutsukaisen.client.render;

import com.jujutsukaisen.client.model.CastingPlayerModel;
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.entity.player.PlayerRenderer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.entity.player.PlayerModelPart;
import org.jetbrains.annotations.Nullable;

import java.util.List;
import java.util.Set;

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

    /**
     * Adds the layers other mods attached to the vanilla skin renderer (backpacks, curios, cosmetics...), so they
     * do not vanish while a player wears a character look. Those layers draw against the vanilla model, which
     * {@link CastingPlayerModel#mirror} keeps in this model's pose.
     *
     * @param builtIn the vanilla renderer's own layers (plus this mod's), which this renderer already has
     */
    public void adoptForeignLayers(@Nullable PlayerRenderer vanilla, Set<Object> builtIn) {
        if (vanilla == null || vanilla == this) return;
        List<?> theirs = RendererAccess.layers(vanilla);
        if (theirs == null) return;
        int adopted = 0;
        for (Object layer : theirs) {
            if (builtIn.contains(layer) || !(layer instanceof RenderLayer<?, ?>)) continue;
            @SuppressWarnings("unchecked")
            RenderLayer<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>> foreign =
                    (RenderLayer<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>>) layer;
            layers.add(foreign);
            adopted++;
        }
        if (adopted > 0 && getModel() instanceof CastingPlayerModel casting) casting.mirror = vanilla.getModel();
    }

    /** First-person bare hand in the character's skin. */
    public void renderCharacterHand(PoseStack poseStack, MultiBufferSource buffers, int light, AbstractClientPlayer player, HumanoidArm side) {
        PlayerModel<AbstractClientPlayer> m = getModel();
        CastingPlayerModel casting = m instanceof CastingPlayerModel c ? c : null;
        if (casting != null) casting.firstPersonHand = true;
        // Vanilla's renderHand first runs setModelProperties for the local player. This model is shared by every
        // player with the same look, so reset what the last third-person render left on it (bow, crossbow,
        // shield and spyglass arm poses would otherwise twist the bare arm).
        m.rightArmPose = HumanoidModel.ArmPose.EMPTY;
        m.leftArmPose = HumanoidModel.ArmPose.EMPTY;
        m.riding = false;
        m.young = false;
        m.attackTime = 0.0f;
        m.crouching = false;
        m.swimAmount = 0.0f;
        m.setupAnim(player, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
        if (casting != null) casting.firstPersonHand = false;
        boolean right = side == HumanoidArm.RIGHT;
        ModelPart arm = right ? m.rightArm : m.leftArm;
        ModelPart sleeve = right ? m.rightSleeve : m.leftSleeve;
        arm.visible = true;
        sleeve.visible = (casting != null && casting.forceOverlays)
                || player.isModelPartShown(right ? PlayerModelPart.RIGHT_SLEEVE : PlayerModelPart.LEFT_SLEEVE);
        ResourceLocation tex = getTextureLocation(player);
        arm.xRot = 0.0f;
        arm.render(poseStack, buffers.getBuffer(RenderType.entitySolid(tex)), light, OverlayTexture.NO_OVERLAY);
        sleeve.xRot = 0.0f;
        sleeve.render(poseStack, buffers.getBuffer(RenderType.entityTranslucent(tex)), light, OverlayTexture.NO_OVERLAY);
    }
}

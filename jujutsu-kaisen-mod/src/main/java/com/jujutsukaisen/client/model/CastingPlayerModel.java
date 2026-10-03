package com.jujutsukaisen.client.model;

import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.player.AbstractClientPlayer;
import org.jetbrains.annotations.Nullable;

/** A player model that strikes the technique poses (hand signs, Purple, Fuga...) while casting. */
public class CastingPlayerModel extends PlayerModel<AbstractClientPlayer> {
    /** Set while drawing first-person hands, which must stay in their neutral pose. */
    public boolean firstPersonHand;
    /**
     * The character skins paint hair, blindfold and costume on the overlay layers, so those layers are always
     * shown instead of following the transformed player's own Skin Customization settings.
     */
    public boolean forceOverlays;
    /**
     * The vanilla skin renderer's model. Layers other mods attached to that renderer (and which this renderer
     * adopted) draw against it, so it is kept in this model's pose.
     */
    @Nullable
    public PlayerModel<AbstractClientPlayer> mirror;

    public CastingPlayerModel(ModelPart root, boolean slim) {
        super(root, slim);
    }

    @Override
    public void setupAnim(AbstractClientPlayer player, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        super.setupAnim(player, limbSwing, limbSwingAmount, ageInTicks, netHeadYaw, headPitch);
        if (forceOverlays && !player.isSpectator()) {
            hat.visible = true;
            jacket.visible = true;
            leftSleeve.visible = true;
            rightSleeve.visible = true;
            leftPants.visible = true;
            rightPants.visible = true;
        }
        if (firstPersonHand) return;
        SorcererData data = JJK.get(player);
        if (data != null && data.getCasting() != null) {
            CastPoses.apply(this, data.currentPose(), ageInTicks);
            rightSleeve.copyFrom(rightArm);
            leftSleeve.copyFrom(leftArm);
        }
        if (mirror != null && mirror != this) mirrorPose(mirror);
    }

    private void mirrorPose(PlayerModel<AbstractClientPlayer> to) {
        copyPropertiesTo(to); // attack, riding, young, arm poses, crouching, head/hat/body/arms/legs
        to.swimAmount = swimAmount;
        to.jacket.copyFrom(jacket);
        to.leftSleeve.copyFrom(leftSleeve);
        to.rightSleeve.copyFrom(rightSleeve);
        to.leftPants.copyFrom(leftPants);
        to.rightPants.copyFrom(rightPants);
        to.head.visible = head.visible;
        to.hat.visible = hat.visible;
        to.body.visible = body.visible;
        to.jacket.visible = jacket.visible;
        to.rightArm.visible = rightArm.visible;
        to.leftArm.visible = leftArm.visible;
        to.rightSleeve.visible = rightSleeve.visible;
        to.leftSleeve.visible = leftSleeve.visible;
        to.rightLeg.visible = rightLeg.visible;
        to.leftLeg.visible = leftLeg.visible;
        to.rightPants.visible = rightPants.visible;
        to.leftPants.visible = leftPants.visible;
    }
}

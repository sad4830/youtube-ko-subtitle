package com.jujutsukaisen.client.model;

import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.player.AbstractClientPlayer;

/** A player model that strikes the technique poses (hand signs, Purple, Fuga...) while casting. */
public class CastingPlayerModel extends PlayerModel<AbstractClientPlayer> {
    /** Set while drawing first-person hands, which must stay in their neutral pose. */
    public boolean firstPersonHand;

    public CastingPlayerModel(ModelPart root, boolean slim) {
        super(root, slim);
    }

    @Override
    public void setupAnim(AbstractClientPlayer player, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        super.setupAnim(player, limbSwing, limbSwingAmount, ageInTicks, netHeadYaw, headPitch);
        if (firstPersonHand) return;
        SorcererData data = JJK.get(player);
        if (data != null && data.getCasting() != null) {
            CastPoses.apply(this, data.currentPose(), ageInTicks);
            rightSleeve.copyFrom(rightArm);
            leftSleeve.copyFrom(leftArm);
        }
    }
}

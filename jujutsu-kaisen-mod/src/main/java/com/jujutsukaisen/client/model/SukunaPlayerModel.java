package com.jujutsukaisen.client.model;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.Iterables;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.util.Mth;

/** A player who has become Ryomen Sukuna: the Heian form's second pair of arms and second face. */
public class SukunaPlayerModel extends CastingPlayerModel {
    private final ModelPart lowerRightArm;
    private final ModelPart lowerLeftArm;

    /** Built from the {@link ModLayers#SUKUNA} mesh (player parts + extra arms + mask, 128x64). */
    public SukunaPlayerModel(ModelPart root) {
        super(root, false);
        this.lowerRightArm = root.getChild("lower_right_arm");
        this.lowerLeftArm = root.getChild("lower_left_arm");
    }

    @Override
    protected Iterable<ModelPart> bodyParts() {
        return Iterables.concat(super.bodyParts(), ImmutableList.of(lowerRightArm, lowerLeftArm));
    }

    @Override
    public void setupAnim(AbstractClientPlayer player, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        super.setupAnim(player, limbSwing, limbSwingAmount, ageInTicks, netHeadYaw, headPitch);
        float walk = Mth.cos(limbSwing * 0.6662f + Mth.PI) * 0.5f * limbSwingAmount;
        float idle = Mth.cos(ageInTicks * 0.09f) * 0.05f;
        lowerRightArm.xRot = -walk * 0.8f + rightArm.xRot * 0.3f + idle;
        lowerRightArm.yRot = 0.1f;
        lowerRightArm.zRot = 0.34f + Mth.sin(ageInTicks * 0.067f) * 0.04f;
        lowerLeftArm.xRot = walk * 0.8f + leftArm.xRot * 0.3f - idle;
        lowerLeftArm.yRot = -0.1f;
        lowerLeftArm.zRot = -0.34f - Mth.sin(ageInTicks * 0.067f) * 0.04f;
        if (attackTime > 0) {
            float swing = Mth.sin(Mth.sqrt(attackTime) * Mth.PI);
            lowerLeftArm.xRot -= swing * 1.4f;
            lowerRightArm.xRot -= swing * 0.6f;
        }
        if (crouching) {
            lowerRightArm.y = 10.7f;
            lowerLeftArm.y = 10.7f;
        } else {
            lowerRightArm.y = 7.5f;
            lowerLeftArm.y = 7.5f;
        }
        lowerRightArm.visible = rightArm.visible;
        lowerLeftArm.visible = leftArm.visible;
    }
}

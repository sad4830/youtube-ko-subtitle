package com.jujutsukaisen.client.model;

import com.jujutsukaisen.entity.SorcererEntity;
import com.jujutsukaisen.sorcery.Ability;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;

/**
 * Player-shaped model for the human sorcerers with technique poses: pointing for Blue/Red/Dismantle,
 * both hands drawing Blue and Red together for Purple, a bow draw for Fuga, and hand signs for
 * Domain Expansion and World-Cutting Slash.
 */
public class SorcererModel<T extends SorcererEntity> extends PlayerModel<T> {
    public SorcererModel(ModelPart root) {
        super(root, false);
    }

    @Override
    public void setupAnim(T entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        super.setupAnim(entity, limbSwing, limbSwingAmount, ageInTicks, netHeadYaw, headPitch);
        applyPose(entity.getCastPose(), ageInTicks);
        rightSleeve.copyFrom(rightArm);
        leftSleeve.copyFrom(leftArm);
    }

    protected void applyPose(Ability.CastPose pose, float age) {
        CastPoses.apply(this, pose, age);
    }
}

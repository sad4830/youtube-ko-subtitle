package com.jujutsukaisen.client.model;

import com.jujutsukaisen.entity.SorcererEntity;
import com.jujutsukaisen.sorcery.Ability;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.util.Mth;

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
        switch (pose) {
            case POINT -> {
                rightArm.xRot = -Mth.HALF_PI + head.xRot;
                rightArm.yRot = head.yRot - 0.1f;
                rightArm.zRot = 0f;
            }
            case PURPLE -> {
                float pulse = Mth.sin(age * 0.3f) * 0.05f;
                rightArm.xRot = -1.45f + pulse;
                rightArm.yRot = -0.35f;
                rightArm.zRot = 0.1f;
                leftArm.xRot = -1.45f - pulse;
                leftArm.yRot = 0.35f;
                leftArm.zRot = -0.1f;
            }
            case SLASH -> {
                rightArm.xRot = -2.3f;
                rightArm.yRot = -0.3f;
                rightArm.zRot = 0.5f;
            }
            case BOW -> {
                rightArm.yRot = -0.1f + head.yRot;
                leftArm.yRot = 0.1f + head.yRot + 0.4f;
                rightArm.xRot = -Mth.HALF_PI + head.xRot;
                leftArm.xRot = -Mth.HALF_PI + head.xRot;
            }
            case HAND_SIGN -> {
                rightArm.xRot = -1.2f;
                rightArm.yRot = -0.6f;
                rightArm.zRot = 0f;
                leftArm.xRot = -1.2f;
                leftArm.yRot = 0.6f;
                leftArm.zRot = 0f;
            }
            case SUMMON -> {
                rightArm.xRot = -1.7f;
                leftArm.xRot = -1.7f;
                rightArm.yRot = -0.15f;
                leftArm.yRot = 0.15f;
            }
            default -> {
            }
        }
    }
}

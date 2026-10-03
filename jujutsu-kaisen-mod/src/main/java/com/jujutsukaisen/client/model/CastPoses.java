package com.jujutsukaisen.client.model;

import com.jujutsukaisen.sorcery.Ability;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.util.Mth;

/**
 * Technique poses shared by the character entities and players: pointing for Blue/Red/Dismantle,
 * both hands drawing Blue and Red together for Purple, a bow draw for Fuga, hand signs for
 * Domain Expansion and the World-Cutting Slash.
 */
public final class CastPoses {
    private CastPoses() {
    }

    public static void apply(HumanoidModel<?> m, Ability.CastPose pose, float age) {
        switch (pose) {
            case POINT -> {
                m.rightArm.xRot = -Mth.HALF_PI + m.head.xRot;
                m.rightArm.yRot = m.head.yRot - 0.1f;
                m.rightArm.zRot = 0f;
            }
            case PURPLE -> {
                float pulse = Mth.sin(age * 0.3f) * 0.05f;
                m.rightArm.xRot = -1.45f + pulse;
                m.rightArm.yRot = -0.35f;
                m.rightArm.zRot = 0.1f;
                m.leftArm.xRot = -1.45f - pulse;
                m.leftArm.yRot = 0.35f;
                m.leftArm.zRot = -0.1f;
            }
            case SLASH -> {
                m.rightArm.xRot = -2.3f;
                m.rightArm.yRot = -0.3f;
                m.rightArm.zRot = 0.5f;
            }
            case BOW -> {
                m.rightArm.yRot = -0.1f + m.head.yRot;
                m.leftArm.yRot = 0.1f + m.head.yRot + 0.4f;
                m.rightArm.xRot = -Mth.HALF_PI + m.head.xRot;
                m.leftArm.xRot = -Mth.HALF_PI + m.head.xRot;
            }
            case HAND_SIGN -> {
                m.rightArm.xRot = -1.2f;
                m.rightArm.yRot = -0.6f;
                m.rightArm.zRot = 0f;
                m.leftArm.xRot = -1.2f;
                m.leftArm.yRot = 0.6f;
                m.leftArm.zRot = 0f;
            }
            case SUMMON -> {
                m.rightArm.xRot = -1.7f;
                m.leftArm.xRot = -1.7f;
                m.rightArm.yRot = -0.15f;
                m.leftArm.yRot = 0.15f;
            }
            default -> {
            }
        }
    }
}

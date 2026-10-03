package com.jujutsukaisen.client.model;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.Iterables;
import com.jujutsukaisen.entity.SukunaEntity;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeDeformation;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.util.Mth;

/**
 * Ryomen Sukuna's true Heian form: a second pair of arms below the first, and the bony mask of a
 * second face with two more eyes on the right side of his head.
 */
public class SukunaModel extends SorcererModel<SukunaEntity> {
    private final ModelPart lowerRightArm;
    private final ModelPart lowerLeftArm;

    public SukunaModel(ModelPart root) {
        super(root);
        this.lowerRightArm = root.getChild("lower_right_arm");
        this.lowerLeftArm = root.getChild("lower_left_arm");
    }

    public static LayerDefinition createBodyLayer() {
        MeshDefinition mesh = PlayerModel.createMesh(CubeDeformation.NONE, false);
        PartDefinition root = mesh.getRoot();
        root.addOrReplaceChild("lower_right_arm", CubeListBuilder.create()
                        .texOffs(64, 0).addBox(-3.0f, -2.0f, -2.0f, 4, 11, 4)
                        .texOffs(64, 32).addBox(-3.0f, -2.0f, -2.0f, 4, 11, 4, new CubeDeformation(0.25f)),
                PartPose.offset(-5.0f, 7.5f, 1.0f));
        root.addOrReplaceChild("lower_left_arm", CubeListBuilder.create()
                        .texOffs(80, 0).addBox(-1.0f, -2.0f, -2.0f, 4, 11, 4)
                        .texOffs(80, 32).addBox(-1.0f, -2.0f, -2.0f, 4, 11, 4, new CubeDeformation(0.25f)),
                PartPose.offset(5.0f, 7.5f, 1.0f));
        root.getChild("head").addOrReplaceChild("mask", CubeListBuilder.create()
                .texOffs(64, 16).addBox(-4.6f, -7.2f, -4.9f, 3, 4, 1), PartPose.ZERO);
        // PlayerModel's cape and ears map the cape (64x32) and skin (64x64) textures assuming a 64-pixel-wide
        // layer. This layer is 128 wide, so halve their U scale to keep player capes and ears drawn correctly.
        root.addOrReplaceChild("ear", CubeListBuilder.create().texOffs(24, 0)
                .addBox(-3.0f, -6.0f, -1.0f, 6.0f, 6.0f, 1.0f, CubeDeformation.NONE, 0.5f, 1.0f), PartPose.ZERO);
        root.addOrReplaceChild("cloak", CubeListBuilder.create().texOffs(0, 0)
                .addBox(-5.0f, 0.0f, -1.0f, 10.0f, 16.0f, 1.0f, CubeDeformation.NONE, 0.5f, 0.5f), PartPose.ZERO);
        return LayerDefinition.create(mesh, 128, 64);
    }

    @Override
    protected Iterable<ModelPart> bodyParts() {
        return Iterables.concat(super.bodyParts(), ImmutableList.of(lowerRightArm, lowerLeftArm));
    }

    @Override
    public void setupAnim(SukunaEntity entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        super.setupAnim(entity, limbSwing, limbSwingAmount, ageInTicks, netHeadYaw, headPitch);
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
    }
}

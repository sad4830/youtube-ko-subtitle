package com.jujutsukaisen.client.model;

import com.jujutsukaisen.entity.misc.MalevolentShrineEntity;
import net.minecraft.client.model.HierarchicalModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.util.Mth;

/**
 * 복마어주자 — a Buddhist shrine standing on a mound of skulls, its hall split open by a huge
 * fanged mouth, horned bull skulls on the roof. Rendered at 3x scale (≈ 10 blocks wide).
 * Texture: 256 x 256.
 */
public class MalevolentShrineModel extends HierarchicalModel<MalevolentShrineEntity> {
    private final ModelPart root;
    private final ModelPart jaw;

    public MalevolentShrineModel(ModelPart root) {
        this.root = root;
        this.jaw = root.getChild("hall").getChild("jaw");
    }

    public static LayerDefinition createBodyLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();

        // Mound of skulls.
        root.addOrReplaceChild("mound", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-26.0f, -6.0f, -18.0f, 52, 6, 36)
                .texOffs(0, 42).addBox(-21.0f, -10.0f, -14.0f, 42, 4, 28), PartPose.offset(0, 24, 0));
        // Front stairs.
        root.addOrReplaceChild("stairs", CubeListBuilder.create()
                .texOffs(176, 28).addBox(-7.0f, -2.0f, -24.0f, 14, 2, 6)
                .texOffs(216, 28).addBox(-7.0f, -4.0f, -21.0f, 14, 2, 3)
                .texOffs(216, 34).addBox(-7.0f, -6.0f, -18.0f, 14, 2, 3), PartPose.offset(0, 24, 0));
        // Deck and pillars.
        PartDefinition deck = root.addOrReplaceChild("deck", CubeListBuilder.create()
                .texOffs(0, 74).addBox(-19.0f, -2.0f, -13.0f, 38, 2, 26), PartPose.offset(0, 14, 0));
        float[][] pillars = {{-17, -11}, {17, -11}, {-17, 11}, {17, 11}, {-8, -11}, {8, -11}};
        for (int i = 0; i < pillars.length; i++) {
            deck.addOrReplaceChild("pillar_" + i, CubeListBuilder.create().texOffs(176, 0).addBox(-1.5f, -22.0f, -1.5f, 3, 22, 3),
                    PartPose.offset(pillars[i][0], -2, pillars[i][1]));
        }

        // The hall with its gaping mouth.
        PartDefinition hall = root.addOrReplaceChild("hall", CubeListBuilder.create()
                .texOffs(0, 102).addBox(-14.0f, -20.0f, -9.0f, 28, 20, 18), PartPose.offset(0, 12, 0));
        hall.addOrReplaceChild("upper_teeth", CubeListBuilder.create()
                .texOffs(208, 0).addBox(-10.0f, 0.0f, -0.5f, 20, 3, 1), PartPose.offset(0, -13, -9.4f));
        PartDefinition jaw = hall.addOrReplaceChild("jaw", CubeListBuilder.create()
                .texOffs(208, 6).addBox(-10.0f, -3.0f, -0.5f, 20, 3, 1), PartPose.offset(0, -3, -9.4f));
        jaw.addOrReplaceChild("tongue", CubeListBuilder.create().texOffs(208, 12).addBox(-4.0f, -1.0f, -3.0f, 8, 1, 4), PartPose.ZERO);

        // Tiered roof with upturned eaves.
        PartDefinition roof = root.addOrReplaceChild("roof", CubeListBuilder.create()
                .texOffs(0, 140).addBox(-23.0f, -3.0f, -16.0f, 46, 3, 32)
                .texOffs(0, 175).addBox(-17.0f, -6.0f, -12.0f, 34, 3, 24)
                .texOffs(140, 42).addBox(-12.0f, -9.0f, -2.0f, 24, 3, 4), PartPose.offset(0, -8, 0));
        roof.addOrReplaceChild("eave_left", CubeListBuilder.create().texOffs(140, 50).addBox(0.0f, -1.0f, -16.0f, 6, 2, 32),
                PartPose.offsetAndRotation(22.0f, -1.0f, 0.0f, 0, 0, -0.35f));
        roof.addOrReplaceChild("eave_right", CubeListBuilder.create().texOffs(140, 50).mirror().addBox(-6.0f, -1.0f, -16.0f, 6, 2, 32),
                PartPose.offsetAndRotation(-22.0f, -1.0f, 0.0f, 0, 0, 0.35f));

        // Bull skulls with horns on the ridge.
        for (int side = -1; side <= 1; side += 2) {
            PartDefinition skull = roof.addOrReplaceChild("skull_" + (side < 0 ? "r" : "l"), CubeListBuilder.create()
                    .texOffs(188, 0).addBox(-2.5f, -5.0f, -2.5f, 5, 5, 5), PartPose.offset(side * 9.0f, -9.0f, 0));
            skull.addOrReplaceChild("horn", CubeListBuilder.create().texOffs(188, 12).addBox(side < 0 ? -7.0f : 0.0f, -1.0f, -1.0f, 7, 2, 2),
                    PartPose.offsetAndRotation(side * 2.5f, -4.0f, 0, 0, 0, side * -0.6f));
        }
        return LayerDefinition.create(mesh, 256, 256);
    }

    @Override
    public ModelPart root() {
        return root;
    }

    @Override
    public void setupAnim(MalevolentShrineEntity entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        jaw.xRot = 0.15f + Mth.sin(ageInTicks * 0.08f) * 0.12f;
    }
}

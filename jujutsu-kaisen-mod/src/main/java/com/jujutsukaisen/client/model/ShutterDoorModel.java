package com.jujutsukaisen.client.model;

import com.jujutsukaisen.entity.misc.ShutterDoorEntity;
import net.minecraft.client.model.HierarchicalModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.util.Mth;

/** Two train shutter panels that slide shut. Texture: 64 x 64. */
public class ShutterDoorModel extends HierarchicalModel<ShutterDoorEntity> {
    private final ModelPart root;
    private final ModelPart left;
    private final ModelPart right;

    public ShutterDoorModel(ModelPart root) {
        this.root = root;
        this.left = root.getChild("left");
        this.right = root.getChild("right");
    }

    public static LayerDefinition createBodyLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        root.addOrReplaceChild("left", CubeListBuilder.create().texOffs(0, 0).addBox(0.0f, -38.0f, -1.0f, 12, 38, 2), PartPose.offset(0, 24, 0));
        root.addOrReplaceChild("right", CubeListBuilder.create().texOffs(28, 0).addBox(-12.0f, -38.0f, -1.0f, 12, 38, 2), PartPose.offset(0, 24, 0));
        return LayerDefinition.create(mesh, 64, 64);
    }

    @Override
    public ModelPart root() {
        return root;
    }

    @Override
    public void setupAnim(ShutterDoorEntity entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        float closing = Mth.clamp(ageInTicks / ShutterDoorEntity.SLAM_TICK, 0f, 1f);
        float eased = closing * closing * closing;
        float open = (1f - eased) * 30f;
        left.x = open;
        right.x = -open;
    }
}

package com.jujutsukaisen.client.model;

import com.jujutsukaisen.entity.MahoragaEntity;
import net.minecraft.client.model.HierarchicalModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeDeformation;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.util.Mth;

/**
 * Mahoraga: ~3.5 m of muscle, no eyes but two pairs of feather-like wings where they would be, a
 * serpent-like tail from the back of the head, black hakama with a white sash, bandaged forearms,
 * the Sword of Extermination fused to the right wrist, and the eight-handled wheel above its head.
 * Texture: 256 x 128.
 */
public class MahoragaModel extends HierarchicalModel<MahoragaEntity> {
    private final ModelPart root;
    private final ModelPart head;
    private final ModelPart body;
    private final ModelPart rightArm;
    private final ModelPart leftArm;
    private final ModelPart rightLeg;
    private final ModelPart leftLeg;
    private final ModelPart wheel;
    private final ModelPart[] wings;

    public MahoragaModel(ModelPart root) {
        this.root = root;
        this.body = root.getChild("body");
        this.head = root.getChild("head");
        this.rightArm = root.getChild("right_arm");
        this.leftArm = root.getChild("left_arm");
        this.rightLeg = root.getChild("right_leg");
        this.leftLeg = root.getChild("left_leg");
        this.wheel = head.getChild("wheel");
        this.wings = new ModelPart[]{head.getChild("right_wing_upper"), head.getChild("left_wing_upper"),
                head.getChild("right_wing_lower"), head.getChild("left_wing_lower")};
    }

    public static LayerDefinition createBodyLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();

        PartDefinition body = root.addOrReplaceChild("body", CubeListBuilder.create()
                        .texOffs(0, 0).addBox(-9.0f, -22.0f, -5.0f, 18, 22, 10)
                        .texOffs(56, 0).addBox(-8.5f, -21.0f, -6.0f, 17, 7, 1)
                        .texOffs(56, 84).addBox(-3.5f, -25.0f, -3.5f, 7, 3, 7),
                PartPose.offset(0.0f, -2.0f, 0.0f));
        body.addOrReplaceChild("hakama", CubeListBuilder.create()
                        .texOffs(0, 32).addBox(-9.5f, 0.0f, -5.5f, 19, 9, 11)
                        .texOffs(60, 32).addBox(-9.5f, -1.5f, -5.5f, 19, 3, 11, new CubeDeformation(0.3f)),
                PartPose.ZERO);

        PartDefinition head = root.addOrReplaceChild("head", CubeListBuilder.create()
                        .texOffs(120, 0).addBox(-5.0f, -10.0f, -5.0f, 10, 10, 10)
                        .texOffs(160, 0).addBox(-3.5f, -3.5f, -5.6f, 7, 3, 1),
                PartPose.offset(0.0f, -26.0f, 0.0f));
        // Two pairs of wings grow from where the eyes would be.
        head.addOrReplaceChild("right_wing_upper", CubeListBuilder.create().texOffs(180, 0).addBox(-9.0f, -1.5f, 0.0f, 9, 3, 1),
                PartPose.offsetAndRotation(-3.0f, -7.0f, -5.2f, 0.0f, -0.55f, 0.35f));
        head.addOrReplaceChild("left_wing_upper", CubeListBuilder.create().texOffs(180, 0).mirror().addBox(0.0f, -1.5f, 0.0f, 9, 3, 1),
                PartPose.offsetAndRotation(3.0f, -7.0f, -5.2f, 0.0f, 0.55f, -0.35f));
        head.addOrReplaceChild("right_wing_lower", CubeListBuilder.create().texOffs(180, 6).addBox(-8.0f, -1.0f, 0.0f, 8, 2, 1),
                PartPose.offsetAndRotation(-3.0f, -5.0f, -5.2f, 0.0f, -0.45f, -0.12f));
        head.addOrReplaceChild("left_wing_lower", CubeListBuilder.create().texOffs(180, 6).mirror().addBox(0.0f, -1.0f, 0.0f, 8, 2, 1),
                PartPose.offsetAndRotation(3.0f, -5.0f, -5.2f, 0.0f, 0.45f, 0.12f));
        head.addOrReplaceChild("tail", CubeListBuilder.create().texOffs(200, 0).addBox(-1.5f, 0.0f, 0.0f, 3, 10, 3),
                PartPose.offsetAndRotation(0.0f, -6.0f, 4.0f, 0.45f, 0.0f, 0.0f));
        addWheel(head, 0.0f, -18.0f, 0.0f);

        PartDefinition rightArm = root.addOrReplaceChild("right_arm", CubeListBuilder.create()
                        .texOffs(0, 52).addBox(-6.0f, -2.0f, -3.5f, 7, 24, 7)
                        .texOffs(56, 52).addBox(-6.0f, 10.0f, -3.5f, 7, 10, 7, new CubeDeformation(0.3f)),
                PartPose.offset(-10.0f, -22.0f, 0.0f));
        // The Sword of Extermination, fused to the right wrist.
        rightArm.addOrReplaceChild("sword", CubeListBuilder.create()
                        .texOffs(112, 52).addBox(-0.5f, 0.0f, -1.5f, 1, 22, 3)
                        .texOffs(120, 52).addBox(-1.5f, -1.0f, -2.5f, 3, 2, 5),
                PartPose.offsetAndRotation(-2.5f, 19.0f, -1.0f, -0.25f, 0.0f, 0.0f));
        root.addOrReplaceChild("left_arm", CubeListBuilder.create()
                        .texOffs(28, 52).addBox(-1.0f, -2.0f, -3.5f, 7, 24, 7)
                        .texOffs(84, 52).addBox(-1.0f, 10.0f, -3.5f, 7, 10, 7, new CubeDeformation(0.3f)),
                PartPose.offset(10.0f, -22.0f, 0.0f));

        root.addOrReplaceChild("right_leg", CubeListBuilder.create().texOffs(0, 84).addBox(-3.5f, 0.0f, -3.5f, 7, 17, 7),
                PartPose.offset(-4.5f, 7.0f, 0.0f));
        root.addOrReplaceChild("left_leg", CubeListBuilder.create().texOffs(28, 84).addBox(-3.5f, 0.0f, -3.5f, 7, 17, 7),
                PartPose.offset(4.5f, 7.0f, 0.0f));
        return LayerDefinition.create(mesh, 256, 128);
    }

    /** The eight-handled wheel (법진): a rim, eight spokes reaching past it and a knob on each handle. */
    public static PartDefinition addWheel(PartDefinition parent, float x, float y, float z) {
        PartDefinition wheel = parent.addOrReplaceChild("wheel", CubeListBuilder.create()
                .texOffs(176, 52).addBox(-2.0f, -2.0f, -1.0f, 4, 4, 2), PartPose.offset(x, y, z));
        for (int i = 0; i < 8; i++) {
            float angle = i * Mth.PI / 4f;
            wheel.addOrReplaceChild("spoke_" + i, CubeListBuilder.create()
                    .texOffs(160, 52).addBox(-0.5f, -14.0f, -0.5f, 1, 12, 1)
                    .texOffs(166, 52).addBox(-1.0f, -16.0f, -1.0f, 2, 2.5f, 2), PartPose.rotation(0, 0, angle));
            wheel.addOrReplaceChild("rim_" + i, CubeListBuilder.create()
                    .texOffs(140, 52).addBox(-3.75f, -9.75f, -0.75f, 7.5f, 1.5f, 1.5f), PartPose.rotation(0, 0, angle + Mth.PI / 8f));
        }
        return wheel;
    }

    /** Standalone wheel (Dharma Wheel item worn by a player), same texture. */
    public static LayerDefinition createWheelLayer() {
        MeshDefinition mesh = new MeshDefinition();
        addWheel(mesh.getRoot(), 0, 0, 0);
        return LayerDefinition.create(mesh, 256, 128);
    }

    @Override
    public ModelPart root() {
        return root;
    }

    @Override
    public void setupAnim(MahoragaEntity entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        root().getAllParts().forEach(ModelPart::resetPose);
        head.yRot = netHeadYaw * Mth.DEG_TO_RAD;
        head.xRot = headPitch * Mth.DEG_TO_RAD;

        float walk = limbSwing * 0.55f;
        rightLeg.xRot = Mth.cos(walk) * 1.1f * limbSwingAmount;
        leftLeg.xRot = Mth.cos(walk + Mth.PI) * 1.1f * limbSwingAmount;
        rightArm.xRot = Mth.cos(walk + Mth.PI) * 0.7f * limbSwingAmount;
        leftArm.xRot = Mth.cos(walk) * 0.7f * limbSwingAmount;
        float breath = Mth.sin(ageInTicks * 0.06f);
        rightArm.zRot = 0.08f + breath * 0.03f;
        leftArm.zRot = -0.08f - breath * 0.03f;
        body.xRot = 0.05f + breath * 0.01f;

        float partial = ageInTicks - (float) entity.tickCount;
        float anim = entity.getAttackAnim();
        if (anim > 0) {
            float progress = 1f - Mth.clamp((anim - partial) / MahoragaEntity.ATTACK_ANIM_TICKS, 0f, 1f);
            if (entity.isSwordAttack()) {
                rightArm.xRot = -2.7f + progress * 2.4f;
                rightArm.yRot = 0.9f - progress * 1.6f;
                body.yRot = -0.4f + progress * 0.7f;
            } else {
                float punch = Mth.sin(progress * Mth.PI);
                rightArm.xRot = -0.4f - punch * 1.25f;
                body.yRot = -punch * 0.3f;
                leftArm.xRot = punch * 0.4f;
            }
        }

        for (int i = 0; i < wings.length; i++) {
            wings[i].zRot += Mth.sin(ageInTicks * 0.1f + i) * 0.04f;
        }
        wheel.zRot = -entity.wheelAngle(partial) * Mth.DEG_TO_RAD;
        wheel.y += Mth.sin(ageInTicks * 0.08f) * 0.6f;
    }
}

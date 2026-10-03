package com.jujutsukaisen.client.render;

import com.jujutsukaisen.client.model.SorcererModel;
import com.jujutsukaisen.entity.SorcererEntity;
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.HumanoidMobRenderer;
import net.minecraft.client.renderer.entity.layers.HumanoidArmorLayer;
import net.minecraft.resources.ResourceLocation;

/** Renders a human sorcerer with its skin, armor, held items and cursed energy aura. */
public class SorcererRenderer<T extends SorcererEntity, M extends SorcererModel<T>> extends HumanoidMobRenderer<T, M> {
    private final ResourceLocation texture;
    private final float scale;

    public SorcererRenderer(EntityRendererProvider.Context context, M model, ResourceLocation texture, float scale) {
        super(context, model, 0.5f * scale);
        this.texture = texture;
        this.scale = scale;
        addLayer(new HumanoidArmorLayer<>(this, new HumanoidModel<>(context.bakeLayer(ModelLayers.PLAYER_INNER_ARMOR)),
                new HumanoidModel<>(context.bakeLayer(ModelLayers.PLAYER_OUTER_ARMOR)), context.getModelManager()));
        addLayer(new CursedAuraLayer<>(this));
    }

    public static <T extends SorcererEntity> SorcererRenderer<T, SorcererModel<T>> human(EntityRendererProvider.Context context,
                                                                                           ResourceLocation texture, float scale) {
        return new SorcererRenderer<>(context, new SorcererModel<>(context.bakeLayer(ModelLayers.PLAYER)), texture, scale);
    }

    @Override
    protected void scale(T entity, PoseStack poseStack, float partialTick) {
        poseStack.scale(scale, scale, scale);
    }

    @Override
    public ResourceLocation getTextureLocation(T entity) {
        return texture;
    }
}

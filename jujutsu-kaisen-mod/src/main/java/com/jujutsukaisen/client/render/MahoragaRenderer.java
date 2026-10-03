package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.model.MahoragaModel;
import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.entity.MahoragaEntity;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.client.renderer.entity.layers.EyesLayer;
import net.minecraft.resources.ResourceLocation;

public class MahoragaRenderer extends MobRenderer<MahoragaEntity, MahoragaModel> {
    public static final ResourceLocation TEXTURE = JujutsuKaisen.id("textures/entity/mahoraga.png");
    private static final RenderType GLOW = RenderType.eyes(JujutsuKaisen.id("textures/entity/mahoraga_glow.png"));

    public MahoragaRenderer(EntityRendererProvider.Context context) {
        super(context, new MahoragaModel(context.bakeLayer(ModLayers.MAHORAGA)), 1.1f);
        // Positive energy of the Sword of Extermination and the gleam of the wheel.
        addLayer(new EyesLayer<>(this) {
            @Override
            public RenderType renderType() {
                return GLOW;
            }
        });
    }

    @Override
    public ResourceLocation getTextureLocation(MahoragaEntity entity) {
        return TEXTURE;
    }
}

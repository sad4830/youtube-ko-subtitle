package com.jujutsukaisen.client.model;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.client.model.geom.ModelLayerLocation;

public final class ModLayers {
    public static final ModelLayerLocation SUKUNA = layer("ryomen_sukuna");
    public static final ModelLayerLocation MAHORAGA = layer("mahoraga");
    public static final ModelLayerLocation DHARMA_WHEEL = layer("dharma_wheel");
    public static final ModelLayerLocation MALEVOLENT_SHRINE = layer("malevolent_shrine");
    public static final ModelLayerLocation SHUTTER_DOOR = layer("shutter_door");

    private static ModelLayerLocation layer(String name) {
        return new ModelLayerLocation(JujutsuKaisen.id(name), "main");
    }

    private ModLayers() {
    }
}

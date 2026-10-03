package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.client.model.EntityModel;
import net.minecraft.client.renderer.entity.LivingEntityRenderer;
import org.jetbrains.annotations.Nullable;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.List;

/**
 * Reads and replaces {@link LivingEntityRenderer}'s model and layer list on renderers this mod did not build
 * (the vanilla skin renderers). The fields are found by type, so this works under dev and production names alike.
 */
public final class RendererAccess {
    @Nullable
    private static final Field MODEL = find(EntityModel.class);
    @Nullable
    private static final Field LAYERS = find(List.class);

    private RendererAccess() {
    }

    @Nullable
    private static Field find(Class<?> type) {
        Field found = null;
        for (Field field : LivingEntityRenderer.class.getDeclaredFields()) {
            if (Modifier.isStatic(field.getModifiers()) || field.getType() != type) continue;
            if (found != null) return null; // ambiguous: better to do nothing than to write the wrong field
            found = field;
        }
        try {
            if (found != null) found.setAccessible(true);
            return found;
        } catch (RuntimeException e) {
            JujutsuKaisen.LOGGER.warn("Cannot access LivingEntityRenderer.{}", found.getName(), e);
            return null;
        }
    }

    /** Swaps the renderer's model. Returns false (and changes nothing) if that is not possible. */
    public static boolean setModel(LivingEntityRenderer<?, ?> renderer, EntityModel<?> model) {
        if (MODEL == null || Modifier.isFinal(MODEL.getModifiers())) return false;
        try {
            MODEL.set(renderer, model);
            return true;
        } catch (IllegalAccessException | RuntimeException e) {
            JujutsuKaisen.LOGGER.warn("Cannot replace the model of {}", renderer, e);
            return false;
        }
    }

    /** The renderer's live layer list, or null if it cannot be read. */
    @Nullable
    public static List<?> layers(LivingEntityRenderer<?, ?> renderer) {
        if (LAYERS == null) return null;
        try {
            return (List<?>) LAYERS.get(renderer);
        } catch (IllegalAccessException | RuntimeException e) {
            JujutsuKaisen.LOGGER.warn("Cannot read the layers of {}", renderer, e);
            return null;
        }
    }
}

package com.jujutsukaisen.client.render;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.client.renderer.entity.LivingEntityRenderer;
import org.jetbrains.annotations.Nullable;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.List;

/**
 * Reads {@link LivingEntityRenderer}'s layer list on renderers this mod did not build (the vanilla skin renderers).
 * The field is found by type, so this works under dev and production names alike.
 */
public final class RendererAccess {
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

package com.jujutsukaisen.client;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import org.lwjgl.glfw.GLFW;

public final class KeyBindings {
    public static final String CATEGORY = "key.categories.jujutsukaisen";
    public static final KeyMapping USE = new KeyMapping("key.jujutsukaisen.use", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_R, CATEGORY);
    public static final KeyMapping CYCLE = new KeyMapping("key.jujutsukaisen.cycle", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_C, CATEGORY);
    public static final KeyMapping DOMAIN = new KeyMapping("key.jujutsukaisen.domain", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_V, CATEGORY);
    public static final KeyMapping RCT = new KeyMapping("key.jujutsukaisen.rct", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_G, CATEGORY);
    public static final KeyMapping INFINITY = new KeyMapping("key.jujutsukaisen.infinity", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_H, CATEGORY);

    private KeyBindings() {
    }
}

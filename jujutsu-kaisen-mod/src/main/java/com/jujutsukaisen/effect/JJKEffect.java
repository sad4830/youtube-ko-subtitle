package com.jujutsukaisen.effect;

import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.effect.MobEffectCategory;
import net.minecraft.world.item.ItemStack;

import java.util.ArrayList;
import java.util.List;

/** A plain status effect. Effects caused by jujutsu cannot be washed away with milk. */
public class JJKEffect extends MobEffect {
    private final boolean curable;

    public JJKEffect(MobEffectCategory category, int color, boolean curable) {
        super(category, color);
        this.curable = curable;
    }

    @Override
    public List<ItemStack> getCurativeItems() {
        return curable ? super.getCurativeItems() : new ArrayList<>();
    }
}

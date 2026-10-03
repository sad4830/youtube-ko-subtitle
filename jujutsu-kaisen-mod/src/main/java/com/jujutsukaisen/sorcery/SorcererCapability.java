package com.jujutsukaisen.sorcery;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.common.capabilities.Capability;
import net.minecraftforge.common.capabilities.CapabilityManager;
import net.minecraftforge.common.capabilities.CapabilityToken;
import net.minecraftforge.common.capabilities.ICapabilitySerializable;
import net.minecraftforge.common.util.LazyOptional;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

public final class SorcererCapability {
    public static final Capability<SorcererData> SORCERER = CapabilityManager.get(new CapabilityToken<>() {
    });
    public static final ResourceLocation ID = JujutsuKaisen.id("sorcerer");

    private SorcererCapability() {
    }

    public static class Provider implements ICapabilitySerializable<CompoundTag> {
        private final SorcererData data = new SorcererData();
        private final LazyOptional<SorcererData> optional = LazyOptional.of(() -> data);

        @Override
        public @NotNull <T> LazyOptional<T> getCapability(@NotNull Capability<T> cap, @Nullable Direction side) {
            return SORCERER.orEmpty(cap, optional);
        }

        @Override
        public CompoundTag serializeNBT() {
            return data.save();
        }

        @Override
        public void deserializeNBT(CompoundTag tag) {
            data.load(tag);
        }

        public void invalidate() {
            optional.invalidate();
        }
    }
}

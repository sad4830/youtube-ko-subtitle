package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.block.DomainBarrierBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.minecraft.world.level.material.PushReaction;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModBlocks {
    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, JujutsuKaisen.MODID);

    public static final RegistryObject<Block> INFINITE_VOID_BARRIER = BLOCKS.register("infinite_void_barrier",
            () -> new DomainBarrierBlock(barrier(MapColor.COLOR_BLACK, 10)));
    public static final RegistryObject<Block> IDLE_DEATH_GAMBLE_BARRIER = BLOCKS.register("idle_death_gamble_barrier",
            () -> new DomainBarrierBlock(barrier(MapColor.GOLD, 14)));

    private static BlockBehaviour.Properties barrier(MapColor color, int light) {
        return BlockBehaviour.Properties.of()
                .mapColor(color)
                .strength(-1.0F, 3600000.0F)
                .noLootTable()
                .lightLevel(state -> light)
                .sound(SoundType.AMETHYST)
                .pushReaction(PushReaction.BLOCK)
                .isValidSpawn((state, level, pos, type) -> false);
    }

    private ModBlocks() {
    }
}

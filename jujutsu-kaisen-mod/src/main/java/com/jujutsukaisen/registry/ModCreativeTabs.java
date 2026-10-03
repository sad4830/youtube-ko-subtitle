package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.RegistryObject;

public final class ModCreativeTabs {
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, JujutsuKaisen.MODID);

    public static final RegistryObject<CreativeModeTab> MAIN = TABS.register("main", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.jujutsukaisen"))
            .icon(() -> new ItemStack(ModItems.SUKUNA_FINGER.get()))
            .displayItems((params, output) -> {
                output.accept(ModItems.SUKUNA_FINGER.get());
                output.accept(ModItems.LIMITLESS_IMPRINT.get());
                output.accept(ModItems.IDLE_DEATH_GAMBLE_IMPRINT.get());
                output.accept(ModItems.GOJO_BLINDFOLD.get());
                output.accept(ModItems.PACHINKO_BALL.get());
                output.accept(ModItems.SWORD_OF_EXTERMINATION.get());
                output.accept(ModItems.DHARMA_WHEEL.get());
                output.accept(ModItems.TEN_SHADOWS_TALISMAN.get());
                output.accept(ModItems.PRISON_REALM.get());
                output.accept(ModItems.FIGHT_CLUB_INVITATION.get());
                output.accept(ModItems.SATORU_GOJO_SPAWN_EGG.get());
                output.accept(ModItems.RYOMEN_SUKUNA_SPAWN_EGG.get());
                output.accept(ModItems.KINJI_HAKARI_SPAWN_EGG.get());
                output.accept(ModItems.MAHORAGA_SPAWN_EGG.get());
            })
            .build());

    private ModCreativeTabs() {
    }
}

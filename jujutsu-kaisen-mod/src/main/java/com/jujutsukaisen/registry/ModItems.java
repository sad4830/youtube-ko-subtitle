package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.item.DharmaWheelItem;
import com.jujutsukaisen.item.FightClubInvitationItem;
import com.jujutsukaisen.item.GojoBlindfoldItem;
import com.jujutsukaisen.item.PachinkoBallItem;
import com.jujutsukaisen.item.PrisonRealmItem;
import com.jujutsukaisen.item.SukunaFingerItem;
import com.jujutsukaisen.item.SwordOfExterminationItem;
import com.jujutsukaisen.item.TechniqueImprintItem;
import com.jujutsukaisen.item.TenShadowsTalismanItem;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.world.food.FoodProperties;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Rarity;
import net.minecraftforge.common.ForgeSpawnEggItem;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModItems {
    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, JujutsuKaisen.MODID);

    public static final RegistryObject<Item> SUKUNA_FINGER = ITEMS.register("sukuna_finger",
            () -> new SukunaFingerItem(new Item.Properties().stacksTo(20).rarity(Rarity.EPIC).fireResistant()
                    .food(new FoodProperties.Builder().nutrition(1).saturationMod(0.1f).alwaysEat().build())));
    public static final RegistryObject<Item> LIMITLESS_IMPRINT = ITEMS.register("limitless_imprint",
            () -> new TechniqueImprintItem(Technique.LIMITLESS, new Item.Properties().stacksTo(1).rarity(Rarity.EPIC)));
    public static final RegistryObject<Item> IDLE_DEATH_GAMBLE_IMPRINT = ITEMS.register("idle_death_gamble_imprint",
            () -> new TechniqueImprintItem(Technique.IDLE_DEATH_GAMBLE, new Item.Properties().stacksTo(1).rarity(Rarity.EPIC)));
    public static final RegistryObject<Item> SWORD_OF_EXTERMINATION = ITEMS.register("sword_of_extermination",
            () -> new SwordOfExterminationItem(new Item.Properties().rarity(Rarity.EPIC).fireResistant()));
    public static final RegistryObject<Item> DHARMA_WHEEL = ITEMS.register("dharma_wheel",
            () -> new DharmaWheelItem(new Item.Properties().stacksTo(1).rarity(Rarity.EPIC).fireResistant()));
    public static final RegistryObject<Item> TEN_SHADOWS_TALISMAN = ITEMS.register("ten_shadows_talisman",
            () -> new TenShadowsTalismanItem(new Item.Properties().stacksTo(1).rarity(Rarity.RARE)));
    public static final RegistryObject<Item> PRISON_REALM = ITEMS.register("prison_realm",
            () -> new PrisonRealmItem(new Item.Properties().stacksTo(1).rarity(Rarity.EPIC).fireResistant()));
    public static final RegistryObject<Item> FIGHT_CLUB_INVITATION = ITEMS.register("fight_club_invitation",
            () -> new FightClubInvitationItem(new Item.Properties().stacksTo(16).rarity(Rarity.RARE)));
    public static final RegistryObject<Item> GOJO_BLINDFOLD = ITEMS.register("gojo_blindfold",
            () -> new GojoBlindfoldItem(new Item.Properties().rarity(Rarity.EPIC)));
    public static final RegistryObject<Item> PACHINKO_BALL = ITEMS.register("pachinko_ball",
            () -> new PachinkoBallItem(new Item.Properties().stacksTo(64)));

    public static final RegistryObject<Item> SATORU_GOJO_SPAWN_EGG = ITEMS.register("satoru_gojo_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.SATORU_GOJO, 0x1C2236, 0xF4F6FA, new Item.Properties()));
    public static final RegistryObject<Item> RYOMEN_SUKUNA_SPAWN_EGG = ITEMS.register("ryomen_sukuna_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.RYOMEN_SUKUNA, 0xE8899A, 0x0D0D0D, new Item.Properties()));
    public static final RegistryObject<Item> KINJI_HAKARI_SPAWN_EGG = ITEMS.register("kinji_hakari_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.KINJI_HAKARI, 0x1C2130, 0xE3C04A, new Item.Properties()));
    public static final RegistryObject<Item> MAHORAGA_SPAWN_EGG = ITEMS.register("mahoraga_spawn_egg",
            () -> new ForgeSpawnEggItem(ModEntities.MAHORAGA, 0xE6E2DA, 0xC8A04A, new Item.Properties()));

    private ModItems() {
    }
}

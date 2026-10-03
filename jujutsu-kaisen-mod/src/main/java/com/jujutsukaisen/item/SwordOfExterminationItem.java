package com.jujutsukaisen.item;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.SwordItem;
import net.minecraft.world.item.Tier;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * 퇴마의 검 — the Sword of Extermination fused to Mahoraga's right arm. Imbued with positive energy,
 * the same nature as Reverse Cursed Technique: one clean slash would exorcise a pure curse.
 */
public class SwordOfExterminationItem extends SwordItem {
    public static final Tier TIER = new Tier() {
        @Override
        public int getUses() {
            return 3000;
        }

        @Override
        public float getSpeed() {
            return 10f;
        }

        @Override
        public float getAttackDamageBonus() {
            return 6f;
        }

        @Override
        public int getLevel() {
            return 4;
        }

        @Override
        public int getEnchantmentValue() {
            return 18;
        }

        @Override
        public Ingredient getRepairIngredient() {
            return Ingredient.of(Items.NETHERITE_INGOT);
        }
    };

    public SwordOfExterminationItem(Properties properties) {
        super(TIER, 4, -2.6f, properties);
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.jujutsukaisen.sword_of_extermination.desc1").withStyle(ChatFormatting.YELLOW));
        tooltip.add(Component.translatable("item.jujutsukaisen.sword_of_extermination.desc2").withStyle(ChatFormatting.GRAY));
    }
}

package com.jujutsukaisen.item;

import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.crafting.Ingredient;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * Gojo's black blindfold. It dampens the flood of information from the Six Eyes, yet he still sees
 * everything through it: the wearer sees in darkness and cannot be blinded.
 */
public class GojoBlindfoldItem extends ArmorItem {
    public static final ArmorMaterial MATERIAL = new ArmorMaterial() {
        @Override
        public int getDurabilityForType(Type type) {
            return 400;
        }

        @Override
        public int getDefenseForType(Type type) {
            return 2;
        }

        @Override
        public int getEnchantmentValue() {
            return 15;
        }

        @Override
        public SoundEvent getEquipSound() {
            return SoundEvents.ARMOR_EQUIP_LEATHER;
        }

        @Override
        public Ingredient getRepairIngredient() {
            return Ingredient.of(Items.BLACK_WOOL);
        }

        @Override
        public String getName() {
            return "jujutsukaisen:gojo_blindfold";
        }

        @Override
        public float getToughness() {
            return 0f;
        }

        @Override
        public float getKnockbackResistance() {
            return 0f;
        }
    };

    public GojoBlindfoldItem(Properties properties) {
        super(MATERIAL, Type.HELMET, properties);
    }

    @Override
    public void inventoryTick(ItemStack stack, Level level, Entity entity, int slot, boolean selected) {
        if (level.isClientSide || !(entity instanceof Player player) || player.getItemBySlot(EquipmentSlot.HEAD) != stack) return;
        if (player.tickCount % 40 != 0) return;
        player.addEffect(new MobEffectInstance(MobEffects.NIGHT_VISION, 260, 0, true, false, false));
        player.removeEffect(MobEffects.BLINDNESS);
        player.removeEffect(MobEffects.DARKNESS);
        SorcererData data = JJK.get(player);
        if (data != null && data.getTechnique() == Technique.LIMITLESS) {
            player.addEffect(new MobEffectInstance(ModEffects.SIX_EYES.get(), 60, 0, true, false, true));
        }
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level level, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.jujutsukaisen.gojo_blindfold.desc").withStyle(ChatFormatting.AQUA));
    }
}

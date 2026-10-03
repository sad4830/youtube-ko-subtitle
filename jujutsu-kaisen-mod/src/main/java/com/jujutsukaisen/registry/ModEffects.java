package com.jujutsukaisen.registry;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.effect.JJKEffect;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.effect.MobEffectCategory;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModEffects {
    public static final DeferredRegister<MobEffect> EFFECTS = DeferredRegister.create(ForgeRegistries.MOB_EFFECTS, JujutsuKaisen.MODID);

    /** Unlimited Void: endless information, the victim cannot act. */
    public static final RegistryObject<MobEffect> INFORMATION_OVERLOAD = EFFECTS.register("information_overload",
            () -> new JJKEffect(MobEffectCategory.HARMFUL, 0x9FE6FF, false)
                    .addAttributeModifier(Attributes.MOVEMENT_SPEED, "7107DE5E-7CE8-4030-940E-514C1F160890", -1.0, AttributeModifier.Operation.MULTIPLY_TOTAL)
                    .addAttributeModifier(Attributes.FLYING_SPEED, "1E8E4C2A-3F0B-4D27-9F5B-6C1C2B6E0A11", -1.0, AttributeModifier.Operation.MULTIPLY_TOTAL)
                    .addAttributeModifier(Attributes.ATTACK_SPEED, "2B7C3D19-58A4-4F7E-8E1D-0A9B6C5D4E33", -1.0, AttributeModifier.Operation.MULTIPLY_TOTAL));
    /** The technique burned out after a Domain Expansion. */
    public static final RegistryObject<MobEffect> TECHNIQUE_BURNOUT = EFFECTS.register("technique_burnout",
            () -> new JJKEffect(MobEffectCategory.HARMFUL, 0x5A1E12, false));
    /** Hakari's jackpot: unlimited cursed energy and automatic Reverse Cursed Technique for 4:11. */
    public static final RegistryObject<MobEffect> JACKPOT = EFFECTS.register("jackpot",
            () -> new JJKEffect(MobEffectCategory.BENEFICIAL, 0xFFD54A, false));
    /** "The zone" after a Black Flash. */
    public static final RegistryObject<MobEffect> THE_ZONE = EFFECTS.register("the_zone",
            () -> new JJKEffect(MobEffectCategory.BENEFICIAL, 0x2A0008, false));
    /** Six Eyes: perceives cursed energy perfectly, even through a blindfold. */
    public static final RegistryObject<MobEffect> SIX_EYES = EFFECTS.register("six_eyes",
            () -> new JJKEffect(MobEffectCategory.BENEFICIAL, 0x5BC8F5, false));

    private ModEffects() {
    }
}

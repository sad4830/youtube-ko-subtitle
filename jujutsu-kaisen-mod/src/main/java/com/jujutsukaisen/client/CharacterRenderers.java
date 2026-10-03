package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.model.CastingPlayerModel;
import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.client.model.SukunaPlayerModel;
import com.jujutsukaisen.client.render.CharacterPlayerRenderer;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import org.jetbrains.annotations.Nullable;

/** The renderers used for players who became a character, or who are mid-cast with their own skin. */
public final class CharacterRenderers {
    @Nullable
    private static CharacterPlayerRenderer gojo, hakari, sukuna, ownWide, ownSlim;

    private CharacterRenderers() {
    }

    /** Rebuilt on every resource reload (EntityRenderersEvent.AddLayers). */
    public static void rebuild(EntityRendererProvider.Context ctx) {
        gojo = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), false,
                JujutsuKaisen.id("textures/entity/satoru_gojo.png"));
        hakari = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), false,
                JujutsuKaisen.id("textures/entity/kinji_hakari.png"));
        sukuna = new CharacterPlayerRenderer(ctx, new SukunaPlayerModel(ctx.bakeLayer(ModLayers.SUKUNA)), false,
                JujutsuKaisen.id("textures/entity/ryomen_sukuna.png"));
        ownWide = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), false, null);
        ownSlim = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER_SLIM), true), true, null);
    }

    @Nullable
    public static CharacterPlayerRenderer forCharacter(Technique technique) {
        return switch (technique) {
            case LIMITLESS -> gojo;
            case IDLE_DEATH_GAMBLE -> hakari;
            case SHRINE -> sukuna;
            case NONE -> null;
        };
    }

    /** Which renderer should draw this player, or null for the vanilla one. */
    @Nullable
    public static CharacterPlayerRenderer pick(AbstractClientPlayer player) {
        SorcererData data = JJK.get(player);
        if (data == null) return null;
        if (data.hasAppearance()) {
            CharacterPlayerRenderer renderer = forCharacter(data.getTechnique());
            if (renderer != null) return renderer;
        }
        if (data.getCasting() != null) return "slim".equals(player.getModelName()) ? ownSlim : ownWide;
        return null;
    }
}

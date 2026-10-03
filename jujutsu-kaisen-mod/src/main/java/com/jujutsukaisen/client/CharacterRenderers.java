package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.model.CastingPlayerModel;
import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.client.model.SukunaPlayerModel;
import com.jujutsukaisen.client.render.CharacterPlayerRenderer;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.client.Minecraft;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.player.PlayerRenderer;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.player.Player;
import org.jetbrains.annotations.Nullable;

import java.util.Map;

/**
 * The renderers used for players who became a character (Gojo / Hakari / Sukuna), or who are mid-cast with their
 * own skin (to strike the cast poses). Each adopts the layers other mods attached to the vanilla skin renderer.
 */
public final class CharacterRenderers {
    @Nullable
    private static CharacterPlayerRenderer gojo, hakari, sukuna, ownWide, ownSlim;
    /** Whether the current renderers already adopted other mods' layers (done on first use after a reload). */
    private static boolean adopted;

    private CharacterRenderers() {
    }

    /** Rebuilt on every resource reload (EntityRenderersEvent.AddLayers). */
    public static void rebuild(EntityRendererProvider.Context ctx) {
        gojo = character(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), "satoru_gojo");
        hakari = character(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), "kinji_hakari");
        sukuna = character(ctx, new SukunaPlayerModel(ctx.bakeLayer(ModLayers.SUKUNA)), "ryomen_sukuna");
        ownWide = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), false, null);
        ownSlim = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER_SLIM), true), true, null);
        adopted = false;
    }

    private static CharacterPlayerRenderer character(EntityRendererProvider.Context ctx, CastingPlayerModel model, String id) {
        model.forceOverlays = true;
        ResourceLocation texture = JujutsuKaisen.id("textures/entity/" + id + ".png");
        return new CharacterPlayerRenderer(ctx, model, false, texture);
    }

    /**
     * AddLayers reaches each mod's event bus in turn, so while it runs some mods have not added their layers yet.
     * By the first render after the reload they all have.
     */
    private static void adoptForeignLayers() {
        if (adopted) return;
        adopted = true;
        Map<String, EntityRenderer<? extends Player>> skins = Minecraft.getInstance().getEntityRenderDispatcher().getSkinMap();
        PlayerRenderer wide = skins.get("default") instanceof PlayerRenderer r ? r : null;
        PlayerRenderer slim = skins.get("slim") instanceof PlayerRenderer r ? r : null;
        for (CharacterPlayerRenderer renderer : new CharacterPlayerRenderer[]{gojo, hakari, sukuna, ownWide}) {
            if (renderer != null) renderer.adoptForeignLayers(wide);
        }
        if (ownSlim != null) ownSlim.adoptForeignLayers(slim);
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
        adoptForeignLayers();
        if (data.hasAppearance()) {
            CharacterPlayerRenderer renderer = forCharacter(data.getTechnique());
            if (renderer != null) return renderer;
        }
        if (data.getCasting() != null) return "slim".equals(player.getModelName()) ? ownSlim : ownWide;
        return null;
    }

    /** Which renderer should draw this player's first-person hand, or null for the vanilla one. */
    @Nullable
    public static CharacterPlayerRenderer pickHand(AbstractClientPlayer player) {
        SorcererData data = JJK.get(player);
        if (data == null || !data.hasAppearance()) return null;
        return forCharacter(data.getTechnique());
    }
}

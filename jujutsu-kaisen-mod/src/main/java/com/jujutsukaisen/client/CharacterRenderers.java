package com.jujutsukaisen.client;

import com.jujutsukaisen.JujutsuKaisen;
import com.jujutsukaisen.client.model.CastingPlayerModel;
import com.jujutsukaisen.client.model.ModLayers;
import com.jujutsukaisen.client.model.SukunaPlayerModel;
import com.jujutsukaisen.client.render.CharacterPlayerRenderer;
import com.jujutsukaisen.client.render.DharmaWheelLayer;
import com.jujutsukaisen.client.render.PlayerAuraLayer;
import com.jujutsukaisen.client.render.RendererAccess;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.player.PlayerRenderer;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.client.event.EntityRenderersEvent;
import org.jetbrains.annotations.Nullable;

import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Set;

/**
 * Player rendering for techniques and character looks.
 * <ul>
 *   <li>Own skin, mid-cast: the vanilla skin renderers draw the cast poses themselves, because their model is
 *   replaced with a {@link CastingPlayerModel}; every layer other mods gave them keeps working.</li>
 *   <li>Character look (Gojo / Hakari / Sukuna): drawn by a dedicated renderer with the character's texture and
 *   model, which adopts the layers other mods attached to the vanilla renderer.</li>
 * </ul>
 */
public final class CharacterRenderers {
    @Nullable
    private static CharacterPlayerRenderer gojo, hakari, sukuna, ownWide, ownSlim;
    @Nullable
    private static PlayerRenderer vanillaWide, vanillaSlim;
    private static boolean widePosed, slimPosed;
    /** The vanilla renderers' layers before other mods added theirs (plus this mod's own). */
    private static final Set<Object> builtInLayers = Collections.newSetFromMap(new IdentityHashMap<>());

    private CharacterRenderers() {
    }

    /** First pass of EntityRenderersEvent.AddLayers (highest priority, before other mods add layers). */
    public static void prepareVanilla(EntityRenderersEvent.AddLayers event) {
        EntityRendererProvider.Context ctx = event.getContext();
        builtInLayers.clear();
        vanillaWide = event.getSkin("default") instanceof PlayerRenderer r ? r : null;
        vanillaSlim = event.getSkin("slim") instanceof PlayerRenderer r ? r : null;
        widePosed = prepare(vanillaWide, ctx, ModelLayers.PLAYER, false);
        slimPosed = prepare(vanillaSlim, ctx, ModelLayers.PLAYER_SLIM, true);
        for (String skin : event.getSkins()) {
            if (event.getSkin(skin) instanceof PlayerRenderer renderer && renderer != vanillaWide && renderer != vanillaSlim) {
                renderer.addLayer(new DharmaWheelLayer(renderer, event.getEntityModels()));
                renderer.addLayer(new PlayerAuraLayer(renderer));
            }
        }
    }

    /** Gives a vanilla skin renderer this mod's layers and, if nobody else replaced it, a model that can cast. */
    private static boolean prepare(@Nullable PlayerRenderer renderer, EntityRendererProvider.Context ctx, ModelLayerLocation layer, boolean slim) {
        if (renderer == null) return false;
        renderer.addLayer(new DharmaWheelLayer(renderer, ctx.getModelSet()));
        renderer.addLayer(new PlayerAuraLayer(renderer));
        List<?> layers = RendererAccess.layers(renderer);
        if (layers != null) builtInLayers.addAll(layers);
        PlayerModel<AbstractClientPlayer> current = renderer.getModel();
        if (current instanceof CastingPlayerModel) return true;
        if (current.getClass() != PlayerModel.class) return false; // another mod swapped it: leave theirs alone
        return RendererAccess.setModel(renderer, new CastingPlayerModel(ctx.bakeLayer(layer), slim));
    }

    /** Second pass of EntityRenderersEvent.AddLayers (lowest priority, after other mods added their layers). */
    public static void rebuild(EntityRenderersEvent.AddLayers event) {
        EntityRendererProvider.Context ctx = event.getContext();
        gojo = character(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), "satoru_gojo");
        hakari = character(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), "kinji_hakari");
        sukuna = character(ctx, new SukunaPlayerModel(ctx.bakeLayer(ModLayers.SUKUNA)), "ryomen_sukuna");
        // Own skin: first-person hands while casting, and third person if a vanilla model could not be replaced.
        ownWide = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER), false), false, null);
        ownSlim = new CharacterPlayerRenderer(ctx, new CastingPlayerModel(ctx.bakeLayer(ModelLayers.PLAYER_SLIM), true), true, null);
        if (!widePosed) ownWide.adoptForeignLayers(vanillaWide, builtInLayers);
        if (!slimPosed) ownSlim.adoptForeignLayers(vanillaSlim, builtInLayers);
    }

    private static CharacterPlayerRenderer character(EntityRendererProvider.Context ctx, CastingPlayerModel model, String id) {
        model.forceOverlays = true;
        ResourceLocation texture = JujutsuKaisen.id("textures/entity/" + id + ".png");
        CharacterPlayerRenderer renderer = new CharacterPlayerRenderer(ctx, model, false, texture);
        renderer.adoptForeignLayers(vanillaWide, builtInLayers);
        return renderer;
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

    private static boolean slim(AbstractClientPlayer player) {
        return "slim".equals(player.getModelName());
    }

    /** The own-skin renderer for this player's arm type. */
    @Nullable
    public static CharacterPlayerRenderer ownSkin(AbstractClientPlayer player) {
        return slim(player) ? ownSlim : ownWide;
    }

    /**
     * Which renderer should draw this player's first-person hand, or null for the vanilla one. A caster with
     * their own skin is routed here too when the vanilla model strikes cast poses, which a hand must not.
     */
    @Nullable
    public static CharacterPlayerRenderer pickHand(AbstractClientPlayer player) {
        SorcererData data = JJK.get(player);
        if (data == null) return null;
        if (data.hasAppearance()) {
            CharacterPlayerRenderer renderer = forCharacter(data.getTechnique());
            if (renderer != null) return renderer;
        }
        if (data.getCasting() != null && (slim(player) ? slimPosed : widePosed)) return ownSkin(player);
        return null;
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
        if (data.getCasting() != null && !(slim(player) ? slimPosed : widePosed)) return ownSkin(player);
        return null;
    }
}

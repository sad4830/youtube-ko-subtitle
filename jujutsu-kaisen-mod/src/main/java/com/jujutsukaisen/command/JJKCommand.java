package com.jujutsukaisen.command;

import com.jujutsukaisen.domain.DomainManager;
import com.jujutsukaisen.network.ModNetwork;
import com.jujutsukaisen.registry.ModEffects;
import com.jujutsukaisen.sorcery.Adaptation;
import com.jujutsukaisen.sorcery.Ability;
import com.jujutsukaisen.sorcery.JJK;
import com.jujutsukaisen.sorcery.SorcererData;
import com.jujutsukaisen.sorcery.Technique;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.FloatArgumentType;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import com.mojang.brigadier.builder.RequiredArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.EntityArgument;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;

import java.util.Collection;
import java.util.function.BiConsumer;

/**
 * {@code /jjk} — technique, cursed energy, fingers, taming and test utilities (operators only).
 */
public final class JJKCommand {
    private JJKCommand() {
    }

    public static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
        dispatcher.register(Commands.literal("jjk")
                .requires(source -> source.hasPermission(2))
                .then(Commands.literal("technique").then(techniqueTargets()))
                .then(Commands.literal("become")
                        .then(Commands.argument("targets", EntityArgument.players())
                                .then(become("satoru_gojo"))
                                .then(become("kinji_hakari"))
                                .then(become("ryomen_sukuna"))
                                .then(become("none"))))
                .then(Commands.literal("energy")
                        .then(Commands.argument("targets", EntityArgument.players())
                                .then(Commands.argument("amount", FloatArgumentType.floatArg(0))
                                        .executes(ctx -> {
                                            float amount = FloatArgumentType.getFloat(ctx, "amount");
                                            return apply(ctx, (player, data) -> data.setCursedEnergy(amount),
                                                    "command.jujutsukaisen.energy", Component.literal(String.valueOf((int) amount)));
                                        }))))
                .then(Commands.literal("fingers")
                        .then(Commands.argument("targets", EntityArgument.players())
                                .then(Commands.argument("count", IntegerArgumentType.integer(0, SorcererData.MAX_FINGERS))
                                        .executes(ctx -> {
                                            int count = IntegerArgumentType.getInteger(ctx, "count");
                                            return apply(ctx, (player, data) -> {
                                                if (count > 0 && data.getTechnique() == Technique.NONE) data.setTechnique(Technique.SHRINE);
                                                data.setFingers(count);
                                            }, "command.jujutsukaisen.fingers", Component.literal(String.valueOf(count)));
                                        }))))
                .then(Commands.literal("tame_mahoraga")
                        .then(Commands.argument("targets", EntityArgument.players())
                                .executes(ctx -> apply(ctx, (player, data) -> data.setMahoragaTamed(true),
                                        "command.jujutsukaisen.tamed", Component.empty()))))
                .then(Commands.literal("jackpot")
                        .then(Commands.argument("targets", EntityArgument.players())
                                .executes(ctx -> apply(ctx, (player, data) -> DomainManager.grantJackpot(player, data),
                                        "command.jujutsukaisen.jackpot", Component.empty()))))
                .then(Commands.literal("reset")
                        .then(Commands.argument("targets", EntityArgument.players())
                                .executes(ctx -> apply(ctx, (player, data) -> {
                                    for (Ability ability : Ability.values()) data.setCooldown(ability, 0);
                                    data.setBurnout(0);
                                    data.clearAdaptation();
                                    data.setWheelTurns(0);
                                    data.setCursedEnergy(data.getMaxCursedEnergy());
                                    player.removeEffect(ModEffects.TECHNIQUE_BURNOUT.get());
                                }, "command.jujutsukaisen.reset", Component.empty()))))
                .then(Commands.literal("info")
                        .executes(ctx -> info(ctx.getSource(), ctx.getSource().getPlayerOrException()))
                        .then(Commands.argument("target", EntityArgument.player())
                                .executes(ctx -> info(ctx.getSource(), EntityArgument.getPlayer(ctx, "target"))))));
    }

    /** {@code /jjk technique <targets> <id>}, one literal per technique so a typo cannot wipe it. */
    private static RequiredArgumentBuilder<CommandSourceStack, ?> techniqueTargets() {
        RequiredArgumentBuilder<CommandSourceStack, ?> targets = Commands.argument("targets", EntityArgument.players());
        for (Technique technique : Technique.values()) {
            targets.then(Commands.literal(technique.id()).executes(ctx -> apply(ctx, (player, data) -> {
                data.setTechnique(technique);
                data.setCursedEnergy(data.getMaxCursedEnergy());
            }, "command.jujutsukaisen.technique", technique.displayName())));
        }
        return targets;
    }

    /** One literal per character, so a typo is a syntax error instead of silently taking the technique away. */
    private static LiteralArgumentBuilder<CommandSourceStack> become(String character) {
        Technique technique = Technique.ofCharacter(character);
        Technique result = technique == null ? Technique.NONE : technique;
        Component name = technique == null ? Component.translatable("technique.jujutsukaisen.none")
                : Component.translatable("entity.jujutsukaisen." + character);
        return Commands.literal(character).executes(ctx -> apply(ctx, (player, data) -> {
            data.setTechnique(result);
            data.setAppearance(technique != null);
            if (result == Technique.SHRINE && data.getFingers() == 0) data.setFingers(1);
            data.setCursedEnergy(data.getMaxCursedEnergy());
        }, "command.jujutsukaisen.become", name));
    }

    private static int apply(CommandContext<CommandSourceStack> ctx, BiConsumer<ServerPlayer, SorcererData> action,
                             String key, Component value) throws CommandSyntaxException {
        Collection<ServerPlayer> players = EntityArgument.getPlayers(ctx, "targets");
        int count = 0;
        for (ServerPlayer player : players) {
            SorcererData data = JJK.get(player);
            if (data == null) continue;
            action.accept(player, data);
            ModNetwork.sync(player, data);
            count++;
        }
        int done = count;
        ctx.getSource().sendSuccess(() -> Component.translatable(key, done, value), true);
        return count;
    }

    private static int info(CommandSourceStack source, ServerPlayer player) {
        SorcererData data = JJK.get(player);
        if (data == null) return 0;
        source.sendSuccess(() -> Component.translatable("command.jujutsukaisen.info.header", player.getDisplayName()).withStyle(ChatFormatting.GOLD), false);
        source.sendSuccess(() -> Component.translatable("command.jujutsukaisen.info.technique", data.getTechnique().displayName()), false);
        source.sendSuccess(() -> Component.translatable("command.jujutsukaisen.info.energy",
                (int) data.getCursedEnergy(), (int) data.getMaxCursedEnergy()), false);
        source.sendSuccess(() -> Component.translatable("command.jujutsukaisen.info.fingers", data.getFingers(), SorcererData.MAX_FINGERS), false);
        source.sendSuccess(() -> Component.translatable("command.jujutsukaisen.info.mahoraga",
                Component.translatable(data.isMahoragaTamed() ? "gui.yes" : "gui.no")), false);
        data.adaptationView().forEach((key, level) -> source.sendSuccess(() -> Component.literal(" • ")
                .append(Component.translatable("adaptation.jujutsukaisen." + key))
                .append(" " + Math.min(level, Adaptation.MAX) + "/" + Adaptation.MAX), false));
        return 1;
    }
}

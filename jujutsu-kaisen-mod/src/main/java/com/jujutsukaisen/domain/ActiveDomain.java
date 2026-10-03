package com.jujutsukaisen.domain;

import com.jujutsukaisen.entity.misc.MalevolentShrineEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** One Domain Expansion currently open in the world. */
public class ActiveDomain {
    private final DomainType type;
    private final UUID casterId;
    private final ResourceKey<Level> dimension;
    private final Vec3 center;
    private final double radius;
    private final int duration;
    final Map<BlockPos, BlockState> barrier = new HashMap<>();
    @Nullable
    MalevolentShrineEntity shrine;
    int age;
    boolean closed;

    // Idle Death Gamble state
    int spinTimer = -1;
    int idleTimer;
    boolean spinWins;
    int spins;
    @Nullable
    Indicator queuedIndicator;
    boolean guaranteed;

    public ActiveDomain(DomainType type, UUID casterId, ResourceKey<Level> dimension, Vec3 center, double radius, int duration) {
        this.type = type;
        this.casterId = casterId;
        this.dimension = dimension;
        this.center = center;
        this.radius = radius;
        this.duration = duration;
    }

    public DomainType type() {
        return type;
    }

    public UUID casterId() {
        return casterId;
    }

    public ResourceKey<Level> dimension() {
        return dimension;
    }

    public Vec3 center() {
        return center;
    }

    public double radius() {
        return radius;
    }

    public int duration() {
        return duration;
    }

    public int age() {
        return age;
    }

    public boolean isClosed() {
        return closed;
    }

    public boolean contains(Vec3 pos) {
        return pos.distanceToSqr(center) <= radius * radius;
    }

    public boolean isSpinning() {
        return spinTimer >= 0;
    }
}

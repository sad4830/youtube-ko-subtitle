package com.jujutsukaisen.sorcery;

/** Implemented by entities that own their jujutsu state directly (the characters, Mahoraga). */
public interface SorcererHolder {
    SorcererData getSorcererData();
}

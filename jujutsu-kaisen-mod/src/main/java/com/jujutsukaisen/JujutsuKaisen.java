package com.jujutsukaisen;

import com.mojang.logging.LogUtils;
import net.minecraftforge.fml.common.Mod;
import org.slf4j.Logger;

@Mod(JujutsuKaisen.MODID)
public class JujutsuKaisen {
    public static final String MODID = "jujutsukaisen";
    public static final Logger LOGGER = LogUtils.getLogger();

    public JujutsuKaisen() {
        LOGGER.info("Jujutsu Kaisen loading");
    }
}

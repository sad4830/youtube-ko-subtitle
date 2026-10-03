"""Generates every texture of the mod into src/main/resources/assets/jujutsukaisen/textures.

Run:  python3 tools/gen_textures.py   (requires Pillow)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_misc as misc  # noqa: E402
import gen_skins as skins  # noqa: E402
from gen_mahoraga import mahoraga  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'jujutsukaisen', 'textures')


def d(*parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(path, exist_ok=True)
    return path


def main():
    ent, item, eff, block, gui, armor = d('entity'), d('item'), d('mob_effect'), d('block'), d('gui'), d('models', 'armor')
    skins.gojo(f'{ent}/satoru_gojo.png')
    skins.hakari(f'{ent}/kinji_hakari.png')
    skins.sukuna(f'{ent}/ryomen_sukuna.png')
    mahoraga(f'{ent}/mahoraga.png', f'{ent}/mahoraga_glow.png')
    misc.shrine(f'{ent}/malevolent_shrine.png')
    misc.shutter(f'{ent}/shutter_door.png')
    misc.orbs(ent)
    misc.crescent(f'{ent}/slash.png', 32, 64, 0.16)
    misc.crescent(f'{ent}/world_slash.png', 32, 64, 0.22, dark=True)
    misc.fuga(f'{ent}/fuga.png')

    misc.finger(f'{item}/sukuna_finger.png')
    misc.talisman(f'{item}/limitless_imprint.png', (40, 120, 230, 255), (200, 30, 40, 255),
                  ['.#..#.', '#.##.#', '#.##.#', '.#..#.', '......', '.+..+.', '..++..', '......', '..##..'])
    misc.talisman(f'{item}/idle_death_gamble_imprint.png', (40, 170, 80, 255), (200, 160, 50, 255),
                  ['..++..', '.+oo+.', '.+oo+.', '..++..', '......', '#####.', '...#..', '..#...', '..#...'])
    misc.talisman(f'{item}/ten_shadows_talisman.png', (30, 10, 40, 255), (110, 40, 160, 255),
                  ['#.#.#.', '.###..', '##o##.', '.###..', '#.#.#.', '......', '.+..+.', '..++..', '.+..+.'])
    misc.sword_item(f'{item}/sword_of_extermination.png')
    misc.wheel_item(f'{item}/dharma_wheel.png')
    misc.prison_realm(f'{item}/prison_realm.png')
    misc.ticket(f'{item}/fight_club_invitation.png')
    misc.blindfold(f'{item}/gojo_blindfold.png')
    misc.pachinko(f'{item}/pachinko_ball.png')
    misc.armor_blindfold(f'{armor}/gojo_blindfold_layer_1.png')

    misc.effect_icons(eff)
    misc.void_barrier(f'{block}/infinite_void_barrier.png')
    misc.gamble_barrier(f'{block}/idle_death_gamble_barrier.png')
    for name, frametime in (('infinite_void_barrier', 4), ('idle_death_gamble_barrier', 3)):
        with open(f'{block}/{name}.png.mcmeta', 'w') as f:
            json.dump({'animation': {'frametime': frametime}}, f, indent=2)
    misc.void_overlay(f'{gui}/infinite_void.png')
    print('textures written to', os.path.normpath(ROOT))


if __name__ == '__main__':
    main()

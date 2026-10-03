"""Writes the data pack side: damage types, tags, loot tables, loot modifiers, recipes, advancements."""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'data')
M = 'jujutsukaisen'


def write(rel, obj):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def ids(*names):
    return [f'{M}:{n}' for n in names]


# ── Damage types ──────────────────────────────────────────────────────────
damage = {
    'limitless': {}, 'hollow_purple': {}, 'dismantle': {}, 'cleave': {}, 'fuga': {'effects': 'burning'},
    'world_slash': {}, 'malevolent_shrine': {}, 'infinite_void': {}, 'black_flash': {}, 'rough_energy': {},
    'shutter_door': {}, 'sword_of_extermination': {}, 'space_cut': {},
}
for name, extra in damage.items():
    write(f'{M}/damage_type/{name}.json', {'message_id': f'{M}.{name}', 'exhaustion': 0.1, 'scaling': 'never', **extra})

write('minecraft/tags/damage_type/bypasses_armor.json',
      {'replace': False, 'values': ids('hollow_purple', 'cleave', 'world_slash', 'malevolent_shrine', 'infinite_void', 'space_cut')})
write('minecraft/tags/damage_type/bypasses_shield.json',
      {'replace': False, 'values': ids('hollow_purple', 'world_slash', 'malevolent_shrine', 'infinite_void', 'space_cut')})
# Not in minecraft:is_fire (Fire Resistance would cancel Fuga outright; Adaptation files it under fire itself), and no
# minecraft:no_knockback tag (1.20.2+; DomainManager.sureHit keeps victims in place instead).
write('minecraft/tags/damage_type/is_projectile.json', {'replace': False, 'values': ids('rough_energy')})
write(f'{M}/tags/damage_type/bypasses_infinity.json',
      {'values': ids('malevolent_shrine', 'infinite_void', 'world_slash', 'space_cut')})
write(f'{M}/tags/damage_type/domain_sure_hit.json', {'values': ids('malevolent_shrine', 'infinite_void')})
write(f'{M}/tags/damage_type/slashing.json',
      {'values': ids('dismantle', 'cleave', 'malevolent_shrine', 'sword_of_extermination')})
write(f'{M}/tags/entity_types/cursed_spirits.json', {'values': []})
write(f'{M}/tags/blocks/technique_immune.json',
      {'values': ['#minecraft:wither_immune', 'minecraft:bedrock', 'minecraft:end_portal_frame', 'minecraft:reinforced_deepslate',
                  f'{M}:infinite_void_barrier', f'{M}:idle_death_gamble_barrier']})


# ── Loot tables ───────────────────────────────────────────────────────────
def entry(item, mn=1, mx=1, chance=None, by_player=False):
    e = {'type': 'minecraft:item', 'name': item}
    if mn != 1 or mx != 1:
        e['functions'] = [{'function': 'minecraft:set_count', 'count': {'type': 'minecraft:uniform', 'min': mn, 'max': mx}}]
    pool = {'rolls': 1, 'entries': [e]}
    conditions = []
    if by_player:
        conditions.append({'condition': 'minecraft:killed_by_player'})
    if chance is not None:
        conditions.append({'condition': 'minecraft:random_chance', 'chance': chance})
    if conditions:
        pool['conditions'] = conditions
    return pool


def entity_loot(name, pools):
    write(f'{M}/loot_tables/entities/{name}.json', {'type': 'minecraft:entity', 'pools': pools})


entity_loot('satoru_gojo', [entry(f'{M}:limitless_imprint'), entry(f'{M}:gojo_blindfold')])
# Feeding a finger to a villager costs one: beating Sukuna yourself gains about half a finger, a trap gains nothing.
entity_loot('ryomen_sukuna', [entry(f'{M}:sukuna_finger', 1, 2, by_player=True)])
entity_loot('kinji_hakari', [entry(f'{M}:idle_death_gamble_imprint'), entry(f'{M}:pachinko_ball', 8, 16),
                             entry(f'{M}:fight_club_invitation', 1, 1, 0.25, by_player=True)])
entity_loot('mahoraga', [entry(f'{M}:sword_of_extermination'), entry(f'{M}:dharma_wheel')])

# Sukuna's fingers are scattered and sealed away in ancient places.
chests = {
    'ancient_city': 0.25, 'stronghold_library': 0.30, 'stronghold_corridor': 0.12, 'desert_pyramid': 0.10,
    'jungle_temple': 0.15, 'bastion_treasure': 0.35, 'woodland_mansion': 0.25, 'end_city_treasure': 0.20,
    'nether_bridge': 0.10, 'buried_treasure': 0.15, 'simple_dungeon': 0.06, 'pillager_outpost': 0.08,
}
entries = []
for table, chance in chests.items():
    name = f'finger_in_{table}'
    write(f'{M}/loot_modifiers/{name}.json', {
        'type': f'{M}:add_item',
        'conditions': [{'condition': 'forge:loot_table_id', 'loot_table_id': f'minecraft:chests/{table}'},
                       {'condition': 'minecraft:random_chance', 'chance': chance}],
        'item': f'{M}:sukuna_finger',
    })
    entries.append(f'{M}:{name}')
write(f'{M}/loot_modifiers/talisman_in_ancient_city.json', {
    'type': f'{M}:add_item',
    'conditions': [{'condition': 'forge:loot_table_id', 'loot_table_id': 'minecraft:chests/ancient_city'},
                   {'condition': 'minecraft:random_chance', 'chance': 0.1}],
    'item': f'{M}:ten_shadows_talisman',
})
entries.append(f'{M}:talisman_in_ancient_city')
write('forge/loot_modifiers/global_loot_modifiers.json', {'replace': False, 'entries': entries})


# ── Recipes ───────────────────────────────────────────────────────────────
def shaped(name, pattern, key, result, count=1):
    write(f'{M}/recipes/{name}.json', {
        'type': 'minecraft:crafting_shaped', 'category': 'misc', 'pattern': pattern,
        'key': {k: {'item': v} for k, v in key.items()}, 'result': {'item': result, 'count': count}})


def shapeless(name, ingredients, result, count=1):
    write(f'{M}/recipes/{name}.json', {
        'type': 'minecraft:crafting_shapeless', 'category': 'misc',
        'ingredients': [{'item': i} for i in ingredients], 'result': {'item': result, 'count': count}})


# Eight swords around a shard of darkness: the eight-handled sword.
shaped('ten_shadows_talisman', ['SSS', 'SES', 'SSS'], {'S': 'minecraft:iron_sword', 'E': 'minecraft:echo_shard'}, f'{M}:ten_shadows_talisman')
shaped('prison_realm', ['OEO', 'EDE', 'OEO'], {'O': 'minecraft:crying_obsidian', 'E': 'minecraft:ender_eye', 'D': 'minecraft:diamond_block'},
       f'{M}:prison_realm')
shapeless('fight_club_invitation', ['minecraft:paper', 'minecraft:gold_ingot', 'minecraft:iron_ingot'], f'{M}:fight_club_invitation')
shapeless('pachinko_ball', ['minecraft:iron_ingot', 'minecraft:gold_nugget'], f'{M}:pachinko_ball', 8)
shaped('gojo_blindfold', ['WWW', 'W W'], {'W': 'minecraft:black_wool'}, f'{M}:gojo_blindfold')


# ── Advancements ──────────────────────────────────────────────────────────
def advancement(name, icon, parent, frame='task', criteria=None, hidden=False, background=None):
    display = {
        'icon': {'item': icon},
        'title': {'translate': f'advancements.{M}.{name}.title'},
        'description': {'translate': f'advancements.{M}.{name}.description'},
        'frame': frame, 'show_toast': True, 'announce_to_chat': True, 'hidden': hidden,
    }
    if background:
        display['background'] = background
    obj = {'display': display, 'criteria': criteria or {'granted': {'trigger': 'minecraft:impossible'}}}
    if parent:
        obj['parent'] = f'{M}:{parent}'
    write(f'{M}/advancements/{name}.json', obj)


mod_items = ids('sukuna_finger', 'limitless_imprint', 'idle_death_gamble_imprint', 'ten_shadows_talisman', 'prison_realm',
                'fight_club_invitation', 'dharma_wheel', 'sword_of_extermination', 'gojo_blindfold', 'pachinko_ball')
advancement('root', f'{M}:sukuna_finger', None,
            criteria={'has_item': {'trigger': 'minecraft:inventory_changed', 'conditions': {'items': [{'items': mod_items}]}}},
            background='minecraft:textures/block/crying_obsidian.png')
advancement('vessel', f'{M}:sukuna_finger', 'root')
advancement('twenty_fingers', f'{M}:sukuna_finger', 'vessel', 'challenge')
advancement('fuga', 'minecraft:fire_charge', 'vessel', 'goal')
advancement('world_slash', 'minecraft:netherite_sword', 'fuga', 'challenge')
advancement('limitless', f'{M}:limitless_imprint', 'root')
advancement('hollow_purple', 'minecraft:amethyst_cluster', 'limitless', 'goal')
advancement('idle_death_gamble', f'{M}:idle_death_gamble_imprint', 'root')
advancement('jackpot', 'minecraft:gold_block', 'idle_death_gamble', 'goal')
advancement('black_flash', 'minecraft:coal', 'root', 'goal')
advancement('domain_expansion', 'minecraft:end_crystal', 'root', 'goal')
advancement('furube_yura_yura', f'{M}:ten_shadows_talisman', 'root')
advancement('tame_mahoraga', f'{M}:dharma_wheel', 'furube_yura_yura', 'challenge')
print('data written')

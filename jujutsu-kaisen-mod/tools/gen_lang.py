"""Writes en_us.json and ko_kr.json. Korean follows the official Korean JJK terms where they exist."""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'jujutsukaisen', 'lang')

# key: (english, korean)
T = {}


def add(key, en, ko):
    T[key] = (en, ko)


M = 'jujutsukaisen'

# ── Creative tab / keys ────────────────────────────────────────────────────
add('itemGroup.jujutsukaisen', 'Jujutsu Kaisen', '주술회전')
add('key.categories.jujutsukaisen', 'Jujutsu Kaisen', '주술회전')
add('key.jujutsukaisen.use', 'Use Cursed Technique', '술식 사용')
add('key.jujutsukaisen.cycle', 'Cycle Technique (Shift: back)', '술식 전환 (Shift: 이전)')
add('key.jujutsukaisen.domain', 'Domain Expansion', '영역전개')
add('key.jujutsukaisen.rct', 'Reverse Cursed Technique (hold)', '반전술식 (누르고 있기)')
add('key.jujutsukaisen.infinity', 'Toggle Infinity', '무한 켜기/끄기')
add('key.jujutsukaisen.appearance', 'Toggle Character Appearance', '캐릭터 모습 전환')

# ── Entities ───────────────────────────────────────────────────────────────
add(f'entity.{M}.satoru_gojo', 'Satoru Gojo', '고죠 사토루')
add(f'entity.{M}.ryomen_sukuna', 'Ryomen Sukuna', '료멘 스쿠나')
add(f'entity.{M}.kinji_hakari', 'Kinji Hakari', '하카리 킨지')
add(f'entity.{M}.mahoraga', 'Eight-Handled Sword Divergent Sila Divine General Mahoraga', '팔악검 이계신장 마허라')
add(f'entity.{M}.blue', 'Blue', '창')
add(f'entity.{M}.red', 'Red', '혁')
add(f'entity.{M}.hollow_purple', 'Hollow Purple', '허식 「자」')
add(f'entity.{M}.dismantle', 'Dismantle', '해')
add(f'entity.{M}.world_slash', 'World-Cutting Slash', '세계를 가르는 참격')
add(f'entity.{M}.fuga', 'Divine Flame', '「竈」 開')
add(f'entity.{M}.pachinko_ball', 'Reserve Ball', '보류 구슬')
add(f'entity.{M}.shutter_door', 'Shutter Doors', '셔터')
add(f'entity.{M}.malevolent_shrine', 'Malevolent Shrine', '복마어주자')

# ── Items / blocks ─────────────────────────────────────────────────────────
add(f'item.{M}.sukuna_finger', "Sukuna's Finger", '료멘 스쿠나의 손가락')
add(f'item.{M}.sukuna_finger.desc1', 'Special Grade Cursed Object — one of twenty', '특급 주물 — 스무 개 중 하나')
add(f'item.{M}.sukuna_finger.desc2', "A vessel who eats it gains Sukuna's power (Shrine). Deadly poison to anyone else.",
    '그릇이 먹으면 스쿠나의 힘(어주자)을 얻는다. 그 외에게는 맹독.')
add(f'item.{M}.sukuna_finger.desc3', 'Feed it to a villager and the King of Curses incarnates.', '주민에게 먹이면 저주의 왕이 수육한다.')
add(f'item.{M}.limitless_imprint', 'Technique Imprint: Limitless', '술식 각인: 무하한 주술')
add(f'item.{M}.idle_death_gamble_imprint', 'Technique Imprint: Private Pure Love Train', '술식 각인: 사철순애열차')
add(f'item.{M}.technique_imprint.desc', 'Use to engrave this technique into your brain (replaces your current one).',
    '사용하면 이 술식이 뇌에 새겨진다 (기존 술식을 대체).')
add(f'item.{M}.sword_of_extermination', 'Sword of Extermination', '퇴마의 검')
add(f'item.{M}.sword_of_extermination.desc1', 'Imbued with positive energy: devastating to cursed spirits and the undead.',
    '정의 에너지가 깃든 칼날 — 저주령과 언데드에게 막대한 피해.')
add(f'item.{M}.sword_of_extermination.desc2', "Once fused to Mahoraga's right arm.", '마허라의 오른팔에 붙어 있던 검.')
add(f'item.{M}.dharma_wheel', "Mahoraga's Wheel", '마허라의 법진')
add(f'item.{M}.dharma_wheel.desc1', 'Bear it in your off hand: adapt to every phenomenon that hurts you.',
    '보조 손에 들면 법진을 짊어진다 — 나를 해친 현상에 적응한다.')
add(f'item.{M}.dharma_wheel.desc2', 'Each turn of the wheel builds resistance and heals part of that damage. Use: show adaptations.',
    '법진이 돌 때마다 그 현상에 대한 내성이 쌓이고 피해 일부가 회복된다. 사용: 적응 현황.')
add(f'item.{M}.ten_shadows_talisman', 'Ten Shadows Talisman', '십종영법술 부적')
add(f'item.{M}.ten_shadows_talisman.desc1', '"With this treasure, I summon..."', '「후루베 유라유라」')
add(f'item.{M}.ten_shadows_talisman.desc2', 'Starts the taming ritual: Mahoraga attacks everyone involved, the summoner included.',
    '조복의 의식을 시작한다 — 마허라는 소환자를 포함해 의식에 끌려온 모두를 공격한다.')
add(f'item.{M}.ten_shadows_talisman.desc3', 'Defeat it alone, by your own hand, to tame it. Tamed: summon for 400 cursed energy (at most 80% of yours), every 2 minutes.',
    '혼자서, 자신의 손으로 쓰러뜨리면 조복. 조복 후: 주력 400(최대 주력의 80%까지)으로 2분마다 소환.')
add(f'item.{M}.prison_realm', 'Prison Realm', '옥문강')
add(f'item.{M}.prison_realm.desc', 'The cursed object that sealed Satoru Gojo. Open it, and the strongest walks free.',
    '고죠 사토루를 봉인했던 주물. 열면 최강이 풀려난다.')
add(f'item.{M}.fight_club_invitation', "Hakari's Fight Club Invitation", '하카리의 지하 격투장 초대장')
add(f'item.{M}.fight_club_invitation.desc', 'Use it and Kinji Hakari challenges you to a real fight.', '사용하면 하카리 킨지가 진짜 싸움을 걸어온다.')
add(f'item.{M}.gojo_blindfold', "Gojo's Blindfold", '고죠의 안대')
add(f'item.{M}.gojo_blindfold.desc', 'The Six Eyes see through it: night vision, immune to blindness and darkness.',
    '육안은 안대 너머도 꿰뚫어 본다 — 야간 투시, 실명·어둠 면역.')
add(f'item.{M}.pachinko_ball', 'Pachinko Ball', '파친코 구슬')
add(f'item.{M}.satoru_gojo_spawn_egg', 'Satoru Gojo Spawn Egg', '고죠 사토루 생성 알')
add(f'item.{M}.ryomen_sukuna_spawn_egg', 'Ryomen Sukuna Spawn Egg', '료멘 스쿠나 생성 알')
add(f'item.{M}.kinji_hakari_spawn_egg', 'Kinji Hakari Spawn Egg', '하카리 킨지 생성 알')
add(f'item.{M}.mahoraga_spawn_egg', 'Mahoraga Spawn Egg', '마허라 생성 알')
add(f'block.{M}.infinite_void_barrier', 'Unlimited Void Barrier', '무량공처 결계')
add(f'block.{M}.idle_death_gamble_barrier', 'Idle Death Gamble Barrier', '좌살박도 결계')

# ── Effects ────────────────────────────────────────────────────────────────
add(f'effect.{M}.information_overload', 'Information Overload', '정보 과부하')
add(f'effect.{M}.technique_burnout', 'Technique Burnout', '술식 타버림')
add(f'effect.{M}.jackpot', 'Jackpot', '대박')
add(f'effect.{M}.the_zone', 'The Zone', '존')
add(f'effect.{M}.six_eyes', 'Six Eyes', '육안')

# ── Techniques / abilities / domains ───────────────────────────────────────
add(f'technique.{M}.none', 'No Cursed Technique', '술식 없음')
add(f'technique.{M}.limitless', 'Limitless', '무하한 주술')
add(f'technique.{M}.shrine', 'Shrine', '어주자')
add(f'technique.{M}.idle_death_gamble', 'Private Pure Love Train', '사철순애열차')
add(f'ability.{M}.blue', 'Cursed Technique Lapse: Blue', '술식순전 「창」')
add(f'ability.{M}.red', 'Cursed Technique Reversal: Red', '술식반전 「혁」')
add(f'ability.{M}.hollow_purple', 'Hollow Technique: Purple', '허식 「자」')
add(f'ability.{M}.dismantle', 'Dismantle', '해(解)')
add(f'ability.{M}.cleave', 'Cleave', '팔(捌)')
add(f'ability.{M}.fuga', 'Divine Flame: Open', '「竈」 開 (푸가)')
add(f'ability.{M}.world_slash', 'World-Cutting Slash', '세계를 가르는 참격')
add(f'ability.{M}.reserve_balls', 'Reserve Balls', '보류 구슬')
add(f'ability.{M}.shutter_doors', 'Shutter Doors', '셔터')
add(f'ability.{M}.pseudo_consecutive', 'Pseudo-Consecutive', '유사연속')
add(f'ability.{M}.domain_infinite_void', 'Domain Expansion: Unlimited Void', '영역전개 「무량공처」')
add(f'ability.{M}.domain_malevolent_shrine', 'Domain Expansion: Malevolent Shrine', '영역전개 「복마어주자」')
add(f'ability.{M}.domain_idle_death_gamble', 'Domain Expansion: Idle Death Gamble', '영역전개 「좌살박도」')
add(f'domain.{M}.infinite_void', 'Unlimited Void', '무량공처')
add(f'domain.{M}.malevolent_shrine', 'Malevolent Shrine', '복마어주자')
add(f'domain.{M}.idle_death_gamble', 'Idle Death Gamble', '좌살박도')
add(f'domain.{M}.expansion', 'Domain Expansion', '영역전개')
add(f'domain.{M}.call.infinite_void', 'Domain Expansion... Unlimited Void.', '영역전개... 「무량공처」.')
add(f'domain.{M}.call.malevolent_shrine', 'Domain Expansion... Malevolent Shrine.', '영역전개... 「복마어주자」.')
add(f'domain.{M}.call.idle_death_gamble', 'Domain Expansion... Idle Death Gamble.', '영역전개... 「좌살박도」.')
add(f'domain.{M}.clash', 'Domain Clash!', '영역 싸움!')
add(f'domain.{M}.clash.vs', '%s  ⟷  %s', '%s  ⟷  %s')
add(f'domain.{M}.clash_lost', "%s's domain was overwhelmed", '%s의 영역이 밀려 무너졌다')
add(f'domain.{M}.clash_lost_self', 'Tch... my domain was pushed back.', '쳇... 영역이 밀렸나.')

# ── Chants and lines ───────────────────────────────────────────────────────
add(f'chant.{M}.hollow_purple', 'Nine Ropes. Polarized Light. Crow and Shomyo. Between Front and Back. Hollow Technique: Purple.',
    '구강. 편광. 까마귀와 성명. 표리의 틈새. 허식 「자」.')
add(f'chant.{M}.fuga', '「竈」... Open.', '「竈」... 開 (푸가).')
add(f'chant.{M}.world_slash.1', 'Dragon Scales.', '용린(龍鱗).')
add(f'chant.{M}.world_slash.2', 'Recoil.', '반발(反発).')
add(f'chant.{M}.world_slash.3', 'Twin Meteors.', '한 쌍의 유성(番いの流星).')
add(f'line.{M}.gojo.engage', "Don't worry. I'm the strongest.", '괜찮아. 난 최강이니까.')
add(f'line.{M}.gojo.honored_one', 'Throughout heaven and earth, I alone am the honored one.', '천상천하 유아독존.')
add(f'line.{M}.gojo.rct', 'Reverse Cursed Technique.', '반전술식.')
add(f'line.{M}.gojo.released', 'Yo! Sorry to keep you waiting.', '여~ 오래 기다렸지?')
add(f'line.{M}.sukuna.engage', 'Know your place, fool.', '네 주제를 알아라, 멍청한 놈.')
add(f'line.{M}.sukuna.praise', 'Be proud. You are strong.', '자랑스러워해라. 너는 강하다.')
add(f'line.{M}.summon_mahoraga', 'With this treasure, I summon... Eight-Handled Sword Divergent Sila Divine General Mahoraga.',
    '후루베 유라유라 — 팔악검 이계신장 마허라.')
add(f'line.{M}.hakari.engage', 'I love the fever!', '난 「열기」를 사랑한다!')
add(f'line.{M}.hakari.challenge', "Welcome to my fight club. There's no gamble you can enjoy in moderation!",
    '내 지하 격투장에 잘 왔다. 적당히 즐길 수 있는 도박 따윈 없어!')

# ── Idle Death Gamble ──────────────────────────────────────────────────────
add(f'gamble.{M}.machine', 'CR Private Pure Love Train  Ver.1/239', 'CR 사철순애열차  Ver.1/239')
add(f'gamble.{M}.spin', 'Spin #%s', '%s번째 회전')
add(f'gamble.{M}.riichi', 'Riichi!', '리치!')
add(f'gamble.{M}.riichi_call', 'Riichi!!', '리치!!')
add(f'gamble.{M}.miss', 'Miss... back to the normal stage', '꽝... 통상 스테이지로')
add(f'gamble.{M}.jackpot', 'JACKPOT!!', '대박!!')
add(f'gamble.{M}.jackpot.sub', '4:11 of unlimited cursed energy and automatic Reverse Cursed Technique',
    '4분 11초 동안 무한한 주력, 자동 반전술식')
add(f'gamble.{M}.jackpot_call', 'JACKPOT!!', '대박이다!!')
add(f'gamble.{M}.rules_transmitted', 'Sure-hit: the rules have been transmitted into your brain', '필중 — 규칙이 뇌에 전달되었다')
add(f'gamble.{M}.rules',
    '[Idle Death Gamble] The sure-hit is not damage but the rules. When Hakari uses a notice (Shutter Doors, Reserve Balls, '
    'Pseudo-Consecutive) a riichi starts; three matching numbers is a jackpot. On a jackpot, for 4 minutes 11 seconds his '
    'cursed energy is unlimited and his body performs Reverse Cursed Technique automatically. The only way to stop it is to defeat Hakari.',
    '[좌살박도의 규칙] 이 영역의 필중은 피해가 아니라 「규칙」이다. 하카리가 예고 연출(셔터·보류 구슬·유사연속)을 쓰면 리치가 '
    '걸리고, 세 숫자가 맞으면 대박. 대박이 나면 4분 11초 동안 하카리의 주력은 무한해지고 몸이 자동으로 반전술식을 돌린다. '
    '막을 방법은 하카리를 쓰러뜨리는 것뿐.')
add(f'riichi.{M}.transit_card', 'Transit Card Riichi', '교통 IC 카드 리치')
add(f'riichi.{M}.seat_struggle', 'Seat Struggle Riichi', '좌석 쟁탈 통근 리치')
add(f'riichi.{M}.potty_emergency', 'Potty Emergency Riichi', '급행열차 화장실 참기 리치')
add(f'riichi.{M}.friday_night_final_train', 'Friday Night Final Train Riichi', '불금 막차 리치')
add(f'indicator.{M}.green', 'Green', '초록')
add(f'indicator.{M}.red', 'Red', '빨강')
add(f'indicator.{M}.gold', 'Gold', '금색')
add(f'indicator.{M}.rainbow', 'RAINBOW (guaranteed!)', '무지개 (확정!)')
add(f'notice.{M}.reserve_balls', 'Reserve Balls', '보류 구슬')
add(f'notice.{M}.shutter_doors', 'Shutter Doors', '셔터')
add(f'notice.{M}.pseudo_consecutive', 'Pseudo-Consecutive', '유사연속')

# ── Messages ───────────────────────────────────────────────────────────────
msgs = {
    'overloaded': ('Your brain is drowning in information... you cannot act.', '끝없는 정보가 뇌를 덮친다... 아무것도 할 수 없다.'),
    'burnt_out': ('Your technique is burnt out (%ss). Reverse Cursed Technique repairs it faster.', '술식이 타버렸다 (%s초). 반전술식으로 더 빨리 회복된다.'),
    'cooldown': ('%s is not ready (%ss)', '%s 재사용 대기 중 (%s초)'),
    'no_energy': ('Not enough cursed energy for %s', '%s에 필요한 주력이 부족하다'),
    'no_energy_rct': ('Out of cursed energy: Reverse Cursed Technique stops', '주력이 바닥나 반전술식이 멈췄다'),
    'cleave_contact': ('Cleave needs contact with the target outside a domain', '영역 밖에서 「팔」은 대상과 접촉해야 한다'),
    'fuga_order': ('「竈」 can only be drawn after Dismantle and Cleave have both landed (or around Malevolent Shrine)',
                   '「竈」는 「해」와 「팔」을 모두 맞힌 뒤에만 쓸 수 있다 (또는 복마어주자 전후)'),
    'world_slash_locked': ('You have not yet grasped how to cut the world itself (tame Mahoraga or eat all 20 fingers)',
                           '아직 세계 자체를 베는 법을 모른다 (마허라를 길들이거나 손가락 20개를 모두 먹을 것)'),
    'no_technique': ('You have no cursed technique', '술식이 없다'),
    'no_domain': ('Your technique has no Domain Expansion', '이 술식에는 영역전개가 없다'),
    'no_rct': ('You cannot perform Reverse Cursed Technique (Hakari only heals automatically during a jackpot)',
               '반전술식을 쓸 수 없다 (하카리는 대박 중에만 자동으로 발동)'),
    'infinity_on': ('Infinity: ON', '무한: 켜짐'),
    'infinity_off': ('Infinity: OFF', '무한: 꺼짐'),
    'technique_restored': ('Your technique has recovered', '술식이 회복되었다'),
    'burnout_start': ('The domain closes — your technique burns out', '영역이 닫히고 술식이 타버렸다'),
    'jackpot_end': ('The song ends. The jackpot round is over.', '노래가 끝났다. 대박 라운드 종료.'),
    'jackpot_no_domain': ('The jackpot round is still playing: no new domain until it ends', '대박 라운드 중에는 영역을 다시 펼칠 수 없다'),
    'black_flash': ('BLACK FLASH!', '흑섬!!'),
    'wheel_turn': ('The wheel turns — adapting to %s (%s)', '법진이 돈다 — %s에 적응 (%s단계)'),
    'wheel_status': ('Adaptations borne by the wheel:', '법진이 짊어진 적응:'),
    'wheel_none': (' (none yet)', ' (아직 없음)'),
    'mahoraga_adapt': ('Mahoraga has adapted to %s (%s/%s)', '마허라가 %s에 적응했다 (%s/%s)'),
    'mahoraga_infinity': ('Mahoraga has adapted to Infinity! Its blows now neutralise it on contact.',
                          '마허라가 「무한」에 적응했다! 이제 접촉하는 순간 무한을 무효화한다.'),
    'mahoraga_space': ('One more turn... Mahoraga now cuts the space itself.', '법진이 한 번 더 돌았다... 마허라는 이제 공간 자체를 벤다.'),
    'mahoraga_breaks_void': ('*The Sword of Extermination shatters Unlimited Void*', '*퇴마의 검이 무량공처를 깨부순다*'),
    'mahoraga_lost': ('Your tamed Mahoraga was destroyed. The shikigami is lost.', '길들인 마허라가 파괴되었다. 식신을 잃었다.'),
    'ritual_start': ('The taming ritual begins. Everyone here has been dragged in.', '조복의 의식이 시작되었다. 이곳의 모두가 끌려 들어왔다.'),
    'ritual_tamed': ('The taming ritual is complete. Mahoraga is yours.', '조복의 의식 완료. 마허라를 길들였다.'),
    'ritual_void': ('The taming ritual was voided (outside help, or someone else struck the final blow).',
                    '조복의 의식이 무효가 되었다 (외부의 도움, 혹은 다른 자가 마무리했다).'),
    'ritual_over': ('No participants remain. Mahoraga sinks back into the shadows.', '의식의 참가자가 없다. 마허라가 그림자로 돌아간다.'),
    'finger_poison': ('The finger is poison to anyone but a vessel...', '그릇이 아닌 자에게 손가락은 맹독이다...'),
    'vessel': ('You survived. You are a vessel for Ryomen Sukuna.', '살아남았다. 당신은 료멘 스쿠나의 그릇이다.'),
    'finger_eaten': ("Sukuna's power grows inside you (%s/%s fingers)", '스쿠나의 힘이 몸속에서 커진다 (손가락 %s/%s)'),
    'finger_max': ('All twenty fingers are already inside you', '이미 손가락 스무 개를 모두 품고 있다'),
    'incarnation': ('The King of Curses incarnates', '저주의 왕이 수육했다'),
    'prison_realm_open': ('The Prison Realm opens', '옥문강이 열렸다'),
    'fight_club': ('Underground fight club — Let it ride!', '지하 격투장 — 판돈을 걸어라!'),
    'technique_gained': ('Engraved into your brain: %s', '뇌에 술식이 새겨졌다: %s'),
    'already_technique': ('That technique is already engraved in you', '이미 새겨진 술식이다'),
    'indicator': ('[Notice] %s — %s', '[예고] %s — %s'),
    'appearance_on': ('You look like %s', '%s의 모습이 되었다'),
    'appearance_off': ('You look like yourself again', '원래 모습으로 돌아왔다'),
    'appearance_hint': ('You took on the look of %s. Toggle it with the "Toggle Character Appearance" key (default J).',
                        '%s의 모습이 되었다. 「캐릭터 모습 전환」 키(기본 J)로 켜고 끌 수 있다.'),
    'no_character': ('Your technique has no character look', '이 술식에는 캐릭터 모습이 없다'),
}
for k, (en, ko) in msgs.items():
    add(f'message.{M}.{k}', en, ko)

# ── HUD ────────────────────────────────────────────────────────────────────
add(f'hud.{M}.cursed_energy', 'CE %s', '주력 %s')
add(f'hud.{M}.burnout', 'Technique burnt out: %ss', '술식 타버림: %s초')
add(f'hud.{M}.jackpot', 'JACKPOT  %s', '대박  %s')
add(f'hud.{M}.keys', '[%s] Technique  [%s] Cycle  [%s] Domain', '[%s] 술식  [%s] 전환  [%s] 영역전개')
add(f'hud.{M}.keys_appearance', '  [%s] Look', '  [%s] 모습')

# ── Adaptation (phenomena) ─────────────────────────────────────────────────
adapt = {
    'slashing': ('slashes', '참격'), 'fire': ('fire', '화염'), 'explosion': ('explosions', '폭발'),
    'projectile': ('projectiles', '투사체'), 'lightning': ('lightning', '번개'), 'freezing': ('cold', '냉기'),
    'physical': ('blows', '타격'), 'infinity': ('Infinity', '무한'), 'infinite_void': ('Unlimited Void', '무량공처'),
    'limitless': ('Limitless', '무하한 주술'), 'hollow_purple': ('Hollow Purple', '허식 「자」'),
    'world_slash': ('World-Cutting Slash', '세계를 가르는 참격'), 'black_flash': ('Black Flash', '흑섬'),
    'rough_energy': ('rough cursed energy', '까칠까칠한 주력'), 'shutter_door': ('shutter doors', '셔터'),
    'sword_of_extermination': ('the Sword of Extermination', '퇴마의 검'), 'space_cut': ('cut space', '공간 절단'),
    'magic': ('magic', '마법'), 'indirect_magic': ('magic', '마법'), 'wither': ('withering', '위더'),
    'sonic_boom': ('sonic booms', '음파'), 'fall': ('falls', '낙하'), 'cactus': ('thorns', '가시'),
    'thorns': ('thorns', '가시'), 'drown': ('drowning', '익사'), 'in_wall': ('suffocation', '질식'),
    'generic': ('damage', '피해'), 'unknown': ('the unknown', '미지의 현상'),
}
for k, (en, ko) in adapt.items():
    add(f'adaptation.{M}.{k}', en, ko)

# ── Death messages ─────────────────────────────────────────────────────────
deaths = {
    'limitless': ('%1$s was crushed by Limitless', '%1$s은(는) 무하한 주술에 짓눌렸다'),
    'hollow_purple': ('%1$s was erased by Hollow Purple', '%1$s은(는) 허식 「자」에 지워졌다'),
    'dismantle': ('%1$s was dismantled', '%1$s은(는) 「해」에 해체되었다'),
    'cleave': ('%1$s was cleaved in one blow', '%1$s은(는) 「팔」에 단번에 갈라졌다'),
    'fuga': ('%1$s was cooked by the Divine Flame', '%1$s은(는) 「竈」의 불길에 타버렸다'),
    'world_slash': ('%1$s was cut along with the world', '%1$s은(는) 세계째로 베였다'),
    'malevolent_shrine': ('%1$s was reduced to dust in Malevolent Shrine', '%1$s은(는) 복마어주자 안에서 가루가 되었다'),
    'infinite_void': ('%1$s drowned in infinite information', '%1$s은(는) 무한한 정보에 익사했다'),
    'black_flash': ('%1$s was struck by a Black Flash', '%1$s은(는) 흑섬을 맞았다'),
    'rough_energy': ('%1$s was battered by rough cursed energy', '%1$s은(는) 까칠까칠한 주력에 얻어맞았다'),
    'shutter_door': ('%1$s was caught between the shutter doors', '%1$s은(는) 셔터 사이에 끼었다'),
    'sword_of_extermination': ('%1$s was exorcised by the Sword of Extermination', '%1$s은(는) 퇴마의 검에 퇴치되었다'),
    'space_cut': ('%1$s was cut through space', '%1$s은(는) 공간째로 베였다'),
}
for k, (en, ko) in deaths.items():
    add(f'death.attack.{M}.{k}', en + ' by %2$s', ko.replace('%1$s은(는)', '%1$s은(는) %2$s의 손에'))
    add(f'death.attack.{M}.{k}.player', en + ' while fighting %2$s', ko.replace('%1$s은(는)', '%1$s은(는) %2$s와 싸우다'))
    add(f'death.attack.{M}.{k}.item', en + ' by %2$s using %3$s', ko.replace('%1$s은(는)', '%1$s은(는) %3$s을(를) 쓴 %2$s에게'))

# ── Commands ───────────────────────────────────────────────────────────────
add(f'command.{M}.technique', 'Set the technique of %s player(s) to %s', '플레이어 %s명의 술식을 %s(으)로 설정')
add(f'command.{M}.become', '%s player(s) became %s', '플레이어 %s명이 %s(이)가 되었다')
add(f'command.{M}.energy', 'Set the cursed energy of %s player(s) to %s', '플레이어 %s명의 주력을 %s(으)로 설정')
add(f'command.{M}.fingers', "Set Sukuna's fingers of %s player(s) to %s", '플레이어 %s명의 스쿠나 손가락을 %s개로 설정')
add(f'command.{M}.tamed', '%s player(s) now have a tamed Mahoraga%s', '플레이어 %s명이 마허라를 길들였다%s')
add(f'command.{M}.jackpot', 'JACKPOT for %s player(s)%s', '플레이어 %s명 대박%s')
add(f'command.{M}.reset', 'Reset cooldowns, burnout and adaptation of %s player(s)%s', '플레이어 %s명의 재사용 대기·술식 타버림·적응 초기화%s')
add(f'command.{M}.info.header', '— %s —', '— %s —')
add(f'command.{M}.info.technique', 'Technique: %s', '술식: %s')
add(f'command.{M}.info.energy', 'Cursed energy: %s / %s', '주력: %s / %s')
add(f'command.{M}.info.fingers', "Sukuna's fingers: %s / %s", '스쿠나의 손가락: %s / %s')
add(f'command.{M}.info.mahoraga', 'Mahoraga tamed: %s', '마허라 조복: %s')

# ── Advancements ───────────────────────────────────────────────────────────
adv = {
    'root': ('Jujutsu Kaisen', 'Step into the world of cursed energy', '주술회전', '주력의 세계에 발을 들였다'),
    'vessel': ('Vessel', "Eat Sukuna's finger and survive", '그릇', '스쿠나의 손가락을 먹고 살아남아라'),
    'twenty_fingers': ('King of Curses', 'Carry all twenty of Sukuna\'s fingers', '저주의 왕', '스쿠나의 손가락 스무 개를 모두 품어라'),
    'limitless': ('The Strongest', 'Engrave Limitless into your brain', '최강', '무하한 주술을 뇌에 새겨라'),
    'idle_death_gamble': ('I Love the Fever', 'Engrave Private Pure Love Train', '열기를 사랑한다', '사철순애열차를 뇌에 새겨라'),
    'black_flash': ('Black Flash', 'Within 0.000001 seconds of the blow... the space distorts', '흑섬',
                    '타격과 주력의 오차 0.000001초 이내 — 공간이 일그러진다'),
    'domain_expansion': ('Domain Expansion', 'Reach the pinnacle of jujutsu', '영역전개', '주술의 정점에 도달하라'),
    'hollow_purple': ('Hollow Technique: Purple', 'Collide Blue and Red', '허식 「자」', '창과 혁을 충돌시켜라'),
    'fuga': ('Cut, Then Cook', 'Draw the Divine Flame after Dismantle and Cleave', '썰고, 굽는다', '「해」와 「팔」 뒤에 「竈」를 당겨라'),
    'world_slash': ('Cut the World', 'Unleash the World-Cutting Slash', '세계를 가르는 참격', '세계 자체를 베어라'),
    'jackpot': ('JACKPOT!', 'Hit the jackpot in Idle Death Gamble', '대박!', '좌살박도에서 대박을 터뜨려라'),
    'furube_yura_yura': ('With This Treasure, I Summon...', 'Begin the taming ritual of Mahoraga', '후루베 유라유라', '마허라 조복의 의식을 시작하라'),
    'tame_mahoraga': ('The Strongest and Worst Shikigami', 'Defeat Mahoraga alone, by your own hand', '최강 최악의 식신', '홀로, 자신의 손으로 마허라를 쓰러뜨려라'),
}
for k, (en_t, en_d, ko_t, ko_d) in adv.items():
    add(f'advancements.{M}.{k}.title', en_t, ko_t)
    add(f'advancements.{M}.{k}.description', en_d, ko_d)


def main():
    os.makedirs(OUT, exist_ok=True)
    en = {k: v[0] for k, v in T.items()}
    ko = {k: v[1] for k, v in T.items()}
    with open(os.path.join(OUT, 'en_us.json'), 'w', encoding='utf-8') as f:
        json.dump(en, f, ensure_ascii=False, indent=2)
    with open(os.path.join(OUT, 'ko_kr.json'), 'w', encoding='utf-8') as f:
        json.dump(ko, f, ensure_ascii=False, indent=2)
    print(len(T), 'keys')


if __name__ == '__main__':
    main()

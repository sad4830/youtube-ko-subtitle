--!strict
-- 로블록스에 업로드한 오디오 에셋 ID를 여기에 넣으세요. 0이면 내장(fallback) 사운드를 씁니다.
-- tools/upload_sounds.py 를 실행하면 자동으로 채워집니다.
local SoundIds = {
	sprite = 134663231674985, -- assets/sounds/sfx_sprite.ogg
	music_lobby = 111046668251139,
	music_battle = 80658809987715,
	music_lin_awaken = 104313745849476,
	music_ren_awaken = 126912006306557,
}
return SoundIds

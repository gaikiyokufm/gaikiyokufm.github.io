local_url = "localhost"

NEWEST_EP_NUM := $(shell ls -1 _posts/[0-9]* | tail -1 | awk -F- '{print $$4}' | awk -F. '{print $$1}')
NEXT_EP_NUM := $(shell expr $(NEWEST_EP_NUM) + 1)
NEXT_EP_NUM_PAD := $(shell printf "%04d" $(NEXT_EP_NUM))
NEWEST_AUDIO_FILE := $(shell ls -1 audio/gaikiyokufm* | tail -1)
NEWEST_POST := $(shell ls -1 _posts/[0-9]* | tail -1)
AUDIO_FILES := $(wildcard audio/gaikiyokufm*.mp3)
TRANSCRIPT_FILES := $(patsubst audio/%.mp3,audio/transcript/%.mp3.json,$(AUDIO_FILES))

help:
	@echo make split ARG=hoge.wav: split stereo to mono
	@echo make mp3 ARG=hoge.wav  : convert wav to mp3
	@echo make post              : create post for new mp3
	@echo make local             : local test
	@echo make twitter           : create twitter post
	@echo make whisper           : create transcript
	@echo make algolia           : create algolia index

post:
	$(eval TODAY := $(shell date +%Y-%m-%d))
	$(eval NEW_FILENAME := _posts/$(TODAY)-$(NEXT_EP_NUM).md)
	$(eval AUDIO_FILENAME := audio/gaikiyokufm-$(NEXT_EP_NUM_PAD).mp3)
	$(eval DURATION := $(shell sox --i -d $(AUDIO_FILENAME) | sed -e "s/\.[0-9]*//"))
	$(eval FILESIZE := $(shell ls -l $(AUDIO_FILENAME) | awk '{print $$5}'))
	$(eval TITLE := $(shell ffprobe $(AUDIO_FILENAME) 2>&1 | grep title | head -1 | awk '{for(i = 4; i <= NF - 1; i++) printf "%s ", $$i; print $$NF}'))
	$(eval DESCRIPTION := $(shell ffprobe $(AUDIO_FILENAME) 2>&1 | grep comment | head -1 | sed 's/^[[:space:]]*comment[[:space:]]*:[[:space:]]*//1'))
	@cp template.md $(NEW_FILENAME)
	@sed -i '' -e 's/NEXT_EP_NUM_PAD/$(NEXT_EP_NUM_PAD)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/NEXT_EP_NUM/$(NEXT_EP_NUM)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/DATE/$(TODAY)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/DURATION/$(DURATION)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/FILESIZE/$(FILESIZE)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/TITLE/$(TITLE)/g' $(NEW_FILENAME)
	@sed -i '' -e 's#DESCRIPTION#$(DESCRIPTION)#g' $(NEW_FILENAME)
	nvim $(NEW_FILENAME)

split:
	@sox ${ARG} -c 1 ${ARG:.wav=}-left.wav remix 1
	@sox ${ARG} -c 1 ${ARG:.wav=}-right.wav remix 2

mp3:
	lame --noreplaygain -q 2 --cbr -b 64 -m m --resample 44.1 --add-id3v2 ${ARG} audio/gaikiyokufm-$(NEXT_EP_NUM_PAD).mp3
	eyeD3 --add-image images/artwork.jpg:FRONT_COVER --title "$(NEXT_EP_NUM). " --comment "//について話しました。" --album "gaikiyoku.fm" audio/gaikiyokufm-$(NEXT_EP_NUM_PAD).mp3

local:
	open http://localhost:4000/
	bundle exec jekyll serve -I

algolia:
	for i in audio/transcript/*.json; do\
		echo "\n## 文字起こし\n" >> `(echo $${i} | xargs basename | sed -e 's/gaikiyokufm-//g' -e 's/\.mp3\.json//g' | bc  | while read line; do echo _posts/*-$${line}.md; done)`;\
		cat $${i} |\
			jq -rc '[.segments[] | {seek, text}] | group_by(.seek) | .[] |\
					    reduce .[] as $$seek ({"seek": .[0].seek, "text": ""}; .text += $$seek.text + "\n") |\
							(.seek/100/60/60%24|tostring) + ":" + (.seek/100/60%60|tostring) + ":" + (.seek/100%60|tostring),.text'\
			>> `(echo $${i} | xargs basename | sed -e 's/gaikiyokufm-//g' -e 's/\.mp3\.json//g' | bc  | while read line; do echo _posts/*-$${line}.md; done)`;\
	done
	bundle exec jekyll algolia
	git co _posts/20*.md

whisper: $(TRANSCRIPT_FILES)

audio/transcript/%.mp3.json: audio/%.mp3
	whisper --model large --language Japanese --output_dir audio/transcript $<

twitter:
	$(eval TITLE := $(shell ffprobe $(NEWEST_AUDIO_FILE) 2>&1 | grep title | head -1 | awk '{for (i=4; i<=NF; i++) print $$i}'))
	@echo $(NEWEST_EP_NUM). $(TITLE)
	@echo
	@cat $(NEWEST_POST) | grep description | awk '{sub(/description: /, ""); print}'
	@echo
	@echo https://gaikiyoku.fm/episode/$(NEWEST_EP_NUM)
	@echo -n \#gaikiyokufm


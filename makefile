local_url = "localhost"

NEWEST_EP_NUM := $(shell ls -1 _posts/[0-9]* | tail -1 | awk -F- '{print $$4}' | awk -F. '{print $$1}')
NEXT_EP_NUM := $(shell expr $(NEWEST_EP_NUM) + 1)
NEXT_EP_NUM_PAD := $(shell printf "%04d" $(NEXT_EP_NUM))

help:
	@echo make split ARG=hoge.wav: split stereo to mono
	@echo make mp3 ARG=hoge.wav  : convert wav to mp3
	@echo make post              : create post for new mp3
	@echo make local             : local test
	@echo make algolia           : create algolia index

post:
	$(eval TODAY := $(shell date +%Y-%m-%d))
	$(eval NEW_FILENAME := _posts/$(TODAY)-$(NEXT_EP_NUM).md)
	$(eval AUDIO_FILENAME := audio/gaikiyokufm-$(NEXT_EP_NUM_PAD).mp3)
	$(eval DURATION := $(shell sox --i -d $(AUDIO_FILENAME) | sed -e "s/\.[0-9]*//"))
	$(eval FILESIZE := $(shell ls -l $(AUDIO_FILENAME) | awk '{print $$5}'))
	@cp _posts/template.md $(NEW_FILENAME)
	@sed -i '' -e 's/NEXT_EP_NUM_PAD/$(NEXT_EP_NUM_PAD)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/NEXT_EP_NUM/$(NEXT_EP_NUM)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/DATE/$(TODAY)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/DURATION/$(DURATION)/g' $(NEW_FILENAME)
	@sed -i '' -e 's/FILESIZE/$(FILESIZE)/g' $(NEW_FILENAME)
	nvim $(NEW_FILENAME)

split:
	@sox ${ARG} -c 1 ${ARG:.wav=}-left.wav remix 1
	@sox ${ARG} -c 1 ${ARG:.wav=}-right.wav remix 2

mp3:
	lame --noreplaygain -q 2 --cbr -b 64 -m m --resample 44.1 --add-id3v2 ${ARG} audio/gaikiyokufm-$(NEXT_EP_NUM_PAD).mp3

local:
	bundle exec jekyll serve

algolia:
	bundle exec jekyll algolia

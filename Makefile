# Simple Makefile to make new releases of pisg

VERSION = 0.22

DIRNAME = pisg-$(VERSION)

TARFILE = pisg-$(VERSION).tar.gz
ZIPFILE = pisg-$(VERSION).zip

FILES = pisg.pl \
	 Changelog \
	 COPYING \
	 CREDITS \
	 README \
	 CONFIG-README \
	 FORMATS \
	 pisg.cfg \
	 lang.txt


GFX = gfx/green-h.png \
	 gfx/green-v.png \
	 gfx/blue-h.png \
	 gfx/blue-v.png \
	 gfx/yellow-h.png \
	 gfx/yellow-v.png \
	 gfx/red-h.png \
	 gfx/red-v.png \

SCRIPTS = scripts/crontab \
	   scripts/dropegg.pl \
	   scripts/egg2mirc.awk

ADDALIAS = scripts/addalias/addalias.htm \
	    scripts/addalias/addalias.pl \
	    scripts/addalias/README

pisg:
	mkdir -p newrelease
	mkdir $(DIRNAME)
	cp $(FILES) $(DIRNAME)
	mkdir $(DIRNAME)/scripts
	cp $(SCRIPTS) $(DIRNAME)/scripts
	mkdir $(DIRNAME)/gfx
	cp $(GFX) $(DIRNAME)/gfx
	mkdir $(DIRNAME)/scripts/addalias
	cp $(ADDALIAS) $(DIRNAME)/scripts/addalias
	tar zcfv newrelease/pisg-$(VERSION).tar.gz $(DIRNAME)
	zip -r pisg $(DIRNAME)
	mv pisg.zip newrelease/$(ZIPFILE)
	mv $(DIRNAME) newrelease
clean:
	rm -r newrelease/

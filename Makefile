# Simple Makefile to make new releases of pisg (newreleases dir must exist)

VERSION = 0.20

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
	 gfx/pipe-purple.png \
	 gfx/pipe-blue.png \
	 pisg.cfg \
	 lang.txt

SCRIPTS = scripts/crontab \
	   scripts/dropegg.pl \
	   scripts/egg2mirc.awk

ADDALIAS = scripts/addalias/addalias.htm \
	    scripts/addalias/addalias.pl \
	    scripts/addalias/README

pisg:
	mkdir $(DIRNAME)
	cp $(FILES) $(DIRNAME)
	mkdir $(DIRNAME)/scripts
	cp $(SCRIPTS) $(DIRNAME)/scripts
	mkdir $(DIRNAME)/scripts/addalias
	cp $(ADDALIAS) $(DIRNAME)/scripts/addalias
	tar zcfv newrelease/pisg-$(VERSION).tar.gz $(DIRNAME)
	zip -r pisg $(DIRNAME)
	mv pisg.zip newrelease/$(ZIPFILE)
	mv $(DIRNAME) newrelease
clean:
	rm -r newrelease/$(DIRNAME)
	rm newrelease/$(TARFILE)
	rm newrelease/$(ZIPFILE)

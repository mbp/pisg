# Simple Makefile to make new releases of pisg (newreleases dir must exist)

VERSION = 0.16a

DIRNAME = pisg-$(VERSION)

TARFILE = pisg-$(VERSION).tar.gz
ZIPFILE = pisg-$(VERSION).zip

pisg:
	mkdir $(DIRNAME)
	cp pisg.pl $(DIRNAME)
	cp CREDITS $(DIRNAME)
	cp gfx/pipe-purple.png $(DIRNAME)
	cp gfx/pipe-blue.png $(DIRNAME)
	cp COPYING $(DIRNAME)
	cp users.cfg $(DIRNAME)
	cp README $(DIRNAME)
	cp FORMATS $(DIRNAME)
	cp Changelog $(DIRNAME)
	cp -r scripts $(DIRNAME)
	tar zcfv newrelease/pisg-$(VERSION).tar.gz $(DIRNAME)
	zip -r pisg $(DIRNAME)
	mv pisg.zip newrelease/$(ZIPFILE)
	mv $(DIRNAME) newrelease
clean:
	rm -r newrelease/$(DIRNAME)
	rm newrelease/$(TARFILE)
	rm newrelease/$(ZIPFILE)

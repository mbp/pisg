# Bloated Makefile to make new releases of pisg

# Ugly hack to get the version number from Pisg.pm
VERSION = `grep "version =>" modules/Pisg.pm | mawk '{ gsub(/.*"v/, ""); gsub(/".*/, ""); print}'`

DIRNAME = pisg-$(VERSION)

TARFILE = pisg-$(VERSION).tar.gz
ZIPFILE = pisg-$(VERSION).zip

FILES = pisg.pl \
	 COPYING \
	 README \
	 pisg.cfg \
	 lang.txt

DOCS = docs/CONFIG-README \
	 docs/FORMATS \
	 docs/Changelog \
	 docs/CREDITS \

DEVDOCS = docs/dev/API

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

ADDALIAS = scripts/addalias/addalias.pl \
	    scripts/addalias/README

MODULESDIR = modules

MAIN_MODULE = $(MODULESDIR)/Pisg.pm

PISG_MODULES = $(MODULESDIR)/Pisg/Common.pm \
	       $(MODULESDIR)/Pisg/HTMLGenerator.pm

PARSER_MODULES = $(MODULESDIR)/Pisg/Parser/Logfile.pm

FORMAT_MODULES = $(MODULESDIR)/Pisg/Parser/Format/axur.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/bxlog.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/bobot.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/eggdrop.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/grufti.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/ircle.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/infobot.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/irssi.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/mbot.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/mIRC.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/psybnc.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/Trillian.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/Template.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/xchat.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/winbot.pm \
		 $(MODULESDIR)/Pisg/Parser/Format/zcbot.pm \

pisg:
	mkdir -p newrelease

	mkdir $(DIRNAME)
	cp $(FILES) $(DIRNAME)

	mkdir $(DIRNAME)/scripts
	cp $(SCRIPTS) $(DIRNAME)/scripts

	mkdir $(DIRNAME)/gfx
	cp $(GFX) $(DIRNAME)/gfx

	mkdir $(DIRNAME)/docs
	cp $(DOCS) $(DIRNAME)/docs

	mkdir $(DIRNAME)/docs/dev
	cp $(DEVDOCS) $(DIRNAME)/docs/dev

	mkdir $(DIRNAME)/scripts/addalias
	cp $(ADDALIAS) $(DIRNAME)/scripts/addalias

	mkdir $(DIRNAME)/$(MODULESDIR)

	mkdir $(DIRNAME)/$(MODULESDIR)/Pisg
	mkdir $(DIRNAME)/$(MODULESDIR)/Pisg/Parser
	mkdir $(DIRNAME)/$(MODULESDIR)/Pisg/Parser/Format
	cp $(MAIN_MODULE) $(DIRNAME)/$(MODULESDIR)/
	cp $(PISG_MODULES) $(DIRNAME)/$(MODULESDIR)/Pisg/
	cp $(PARSER_MODULES) $(DIRNAME)/$(MODULESDIR)/Pisg/Parser
	cp $(FORMAT_MODULES) $(DIRNAME)/$(MODULESDIR)/Pisg/Parser/Format

	tar zcfv newrelease/pisg-$(VERSION).tar.gz $(DIRNAME)
	zip -r pisg $(DIRNAME)
	mv pisg.zip newrelease/$(ZIPFILE)
	mv $(DIRNAME) newrelease
clean:
	rm -rf newrelease/
	rm -rf $(DIRNAME)

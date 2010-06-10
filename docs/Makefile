TARGETS := pisg-doc.txt pisg-doc.html pisg-faq.html pisg-formats.html pisg.1
VERSION := $(shell grep "version =>" ../modules/Pisg.pm | sed 's/[^"]*"\([^"]*\)+CVS".*/\1/')

all: $(TARGETS)

pisg-doc.xml: .version
.version: ../modules/Pisg.pm
	perl -i -pe 's/(<title>pisg ).*(documentation<\/title>)/$${1}$(VERSION) $${2}/' pisg-doc.xml
	touch .version

pisg-doc.txt: pisg-doc.xml
	docbook2txt pisg-doc.xml
	mv pisg-doc.txt pisg-tmp.txt
	cat pisg-tmp.txt | ./modifytxt.pl > pisg-doc.txt
	rm -f pisg-tmp.txt

pisg-doc.html: pisg-doc.xml
	docbook2html pisg-doc.xml -V "%use-id-as-filename%" -V nochunks

pisg-faq.html: pisg-faq.txt
	a2x -f xhtml pisg-faq.txt

pisg-formats.html: FORMATS
	a2x -f xhtml FORMATS
	mv FORMATS.html pisg-formats.html

pisg.1: pisg.sgml
	docbook-to-man $< > $@

clean:
	rm -f $(TARGETS) .version

.PHONY: all clean

# vim:noexpandtab:

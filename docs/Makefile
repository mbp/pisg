DOCBOOK_UTILS=/usr/share/docbook-utils

all:
	jade -i html -t sgml -V nochunks -d $(DOCBOOK_UTILS)/docbook-utils.dsl\#html pisg-doc.sgml | w3m -dump -T text/html > pisg-tmp.txt
	cat pisg-tmp.txt | ./modifytxt.pl > pisg-doc.txt
	docbook2html pisg-doc.sgml -o html

clean:
	rm -rf html
	rm -f pisg-doc.txt
	rm -f pisg-tmp.txt

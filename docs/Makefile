# Dummy script to generate documentation, probably only works on my system
# for now.  - mbp / 2002

all:
	jade -i html -t sgml -V nochunks -d /usr/share/sgml/docbook/utils-0.6.9/docbook-utils.dsl\#html pisg-doc.sgml | w3m -dump -T text/html > pisg-doc.txt
	vim -c 'echo AddSpacers()' -c ':wq' pisg-doc.txt
	docbook2html pisg-doc.sgml -o html

clean:
	rm -rf html
	rm -f pisg-doc.txt

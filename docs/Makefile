all: pisg-doc.txt pisg-doc.html

pisg-doc.txt: pisg-doc.xml
	docbook2txt pisg-doc.xml
	mv pisg-doc.txt pisg-tmp.txt
	cat pisg-tmp.txt | ./modifytxt.pl > pisg-doc.txt
	rm -f pisg-tmp.txt

pisg-doc.html: pisg-doc.xml
	docbook2html pisg-doc.xml -V "%use-id-as-filename%" -V nochunks

clean:
	rm -f pisg-doc.txt pisg-doc.html

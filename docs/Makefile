all: pisg-doc.txt html/index.html

pisg-doc.txt: pisg-doc.xml
	docbook2txt pisg-doc.xml
	mv pisg-doc.txt pisg-tmp.txt
	cat pisg-tmp.txt | ./modifytxt.pl > pisg-doc.txt
	rm -f pisg-tmp.txt

html/index.html: pisg-doc.xml
	-rm -f html/*
	docbook2html pisg-doc.xml -V "%use-id-as-filename%" -o html

clean:
	rm -rf html
	rm -f pisg-doc.txt

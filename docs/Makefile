all:
	docbook2txt pisg-doc.xml
	mv pisg-doc.txt pisg-tmp.txt
	cat pisg-tmp.txt | ./modifytxt.pl > pisg-doc.txt
	docbook2html pisg-doc.xml -V "%use-id-as-filename%" -o html

clean:
	rm -rf html
	rm -f pisg-doc.txt
	rm -f pisg-tmp.txt

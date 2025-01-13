function pdf_preview --description="previsualizar pdfs en terminal"
	set filename "$argv[1]"
	if test $(file -Lb --mime-type "$filename") = "application/pdf"
		set file "$( basename $(echo "Descargas/0.1_Presentación.pdf" | tr ' ' '_'))"
		pdftoppm -f 1 -l 1 "$filename" >> "/tmp/$file.png"
	end
	if test -e "/tmp/$file.png"
	 	kitty +kitten icat --silent --stdin no --transfer-mode file "/tmp/$file.png" < /dev/null > /dev/tty
	 	rm -r "/tmp/$file.png"
	end


 end

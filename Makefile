prefix=~/packages/labl

install: labl Labl.pm
	mkdir -p ${prefix}/bin
	cp labl ${prefix}/bin/
	mkdir -p ${prefix}/perl5/lib/perl5
	cp Labl.pm ${prefix}/perl5/lib/perl5/

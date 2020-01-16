#!/usr/bin/perl 
#Author : Harold Mouchère / IRCCyN / Universtié de Nantes

$GRAM = "GramCROHMEpart2.xml";

$fileToTest = "listeTest.txt";

$fileOutAccepted = "emAccepted.txt";

$withLog = "";
$tempTokenFile = "tempToken.txt";
$withLogRej = "";

if($#ARGV == -1){
	print "options : tokenAndParse.pl G=grammar.xml F=listOfEmToTest.txt  [O=AcceptedEm.txt] [T=tempTokenFile.txt] [-L]\n-L : log failed parsing or multiple parsing\nG= grammar file, should be in gram directory\nT= used temp file, useful for multiple instance of the same script";
	exit(-1);
}
foreach $p (@ARGV){
	if($p =~ /G=(.*)/){
		$GRAM = $1;
	}
	if($p =~ /F=(.*)/){
		$fileToTest = $1;
	}
	if($p =~ /T=(.*)/){
		$tempTokenFile = $1;
	}
	if($p =~ /O=(.*)/){
		$fileOutAccepted = $1;
	}	
	if($p =~ /-L/){
		$withLog = "\>\> emParse.log";
	}
	if($p =~ /-LR/){
		$withLogRej = 1;
	}	
}

print " used grammar : $GRAM\n";
print " used list of EM : $fileToTest\n";
print " used output file : $fileOutAccepted\n";

open(EMLISTE,$fileToTest) || die "Impossible d'ouvrir le fichier source $1 : $!";
open(OUTEMACC,">$fileOutAccepted");
open(OUTEMREJ,">emRejected.txt");
while($ligne = <EMLISTE>){ # pour chaque ligne
	if(not ($ligne =~ /^%/)){
		$original = $ligne;
		$ligne =~ s/[\r\n]//g; #chomp($ligne);
		#suppression des trucs encombrants
		$ligne =~ s/(\\ |\\,|\\;|\\>|\\!)/ /g; #supprime tous les espaces spéciaux	
		$ligne =~ s/\$/ /g; #les balises $ $ 
		$ligne =~ s/([^\\])([\}\{])/$1 $2 /g; #des acolades de priorité et fonctions spéciales mais différentes des \{ et \}
		$ligne =~ s/([^\\])([\}\{])/$1 $2 /g; #twice to deal with {{{{}}}} strings
		$ligne =~ s/^\{/\{ /; # to deal with strings starting with an {
		# séparations des symboles
		$ligne =~ s/(&lt;)/ < /g; # lower than
		$ligne =~ s/(&gt;)/ > /g; # lower than
		$ligne =~ s/([_\^+\-\*0-9=\/~,';:!\.><])/ $1 /g;#séparation des principaux symbole de 1 caractère
		$ligne =~ s/(\\?\|)/ $1 /g; #séparation des | et \|
		$ligne =~ s/(\\?[\[\]])/ $1 /g; #séparation des | et \|
		$ligne =~ s/(\\?[\(\)])/ $1 /g; #séparation des () et \(\)
		$ligne =~ s/\\mbox/ /g; #remove mbox
		$ligne =~ s/\\mathrm/ /g; #remove mbox
		$ligne =~ s/(\\[A-Za-z]+)/ $1 /g; #séparation des macro
		$ligne =~ s/(\\[\}\{\(\)])/ $1 /g; #séparation des parenthèses spéciales
		$ligne =~ s/^([A-Za-z])([A-Za-z])/$1 $2 /g; #séparation lettres qui ne sont pas des macro au début de la chaine
		while($ligne =~ / [A-Za-z][A-Za-z]+/){ # while there are consecutive letters not starting  by a macro
			$ligne =~ s/ ([A-Za-z])([A-Za-z])/ $1 $2 /g; #séparation lettres qui ne sont pas des macro
			#print  $ligne."\n";
		}
		open(TEMPEM,">$tempTokenFile");
		print TEMPEM $ligne;
		#print  $ligne."\n";
		close(TEMPEM);
		$res = `java -jar pep.jar -g gram/$GRAM -s S -v 0 - < $tempTokenFile`;
		print $res;
		if($res =~/ACCEPT/){
			print OUTEMACC $original;
			if($withLog && not $withLogRej){
				$res =~/\(([0-9]*)\)/;
				if($1 gt 1){
					`java -jar pep.jar -g gram/$GRAM -s S -v 2 - < $tempTokenFile $withLog`;
				}
			}
		}elsif($res =~/REJECT/){
			print OUTEMREJ $original;
			if($withLog || $withLogRej){
				`java -jar pep.jar -g gram/$GRAM -s S -v 2 - < $tempTokenFile $withLog`;
			}
		}else{
			print OUTEMREJ "ERROR :".$original."\n>>>".$res;
		}
	}
}

close(OUTEMACC);
close(OUTEMREJ);
close(EMLISTE);

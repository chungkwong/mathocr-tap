#! /bin/perl
use XML::LibXML;
use Data::Dumper;
use strict;  

if($#ARGV == -1){
print "usage: 
	evalInkml.pl fileReference.inkml fileToTest.inkml [-W] [-V] [-R] [-C] [-M] [-csv]
		to compare two files
OR	evalInkml.pl -L listOfCouples.txt [-W] [-V] [-H] [-R] [-C] [-M] [-cvs] 
		to use a list couples of files and accumulate comparisons
		the list file contains one couple per line, the two file names split by a comma: 
		----- example of file list ---
		fileRef1.inkml, fileTest1.inkml
		../dir/fileRef2.inkml, ../dir2/fileTest2.inkml
		../dir/fileRef2.inkml, fileTest2b.inkml
		-------
OR	evalInkml.pl filecheck.inkml
		to check file format
	evalInkml.pl -S listOfFiles.txt [-H]
		compute and print stats, the list file contains one inkml filename per line
Options : 
	-W : no warning on unmatched UI and MathML format
	-V : Verbose. Shows results for each file of list, and total in plain text
	-R : shows recognition rates instead of error rates
	-C : shows rates class by class
	-M : shows class confusion matrix for stroke and symbol recognition and MathML matching 
	-H : shows histograms of ((not) recognized) expressions depending of stroke/symbols number
	-cvs : shows all statistic on one csv line
Version : 1.7
Author: Harold Mouchère (LUNAM/University of Nantes/IRCCyN/IVC)
Apr 2012
";
exit();
}
### check options ####
my $list = 0;
my $onlyStat = 0;
my $warning = 1;
my $verbose  = 0;
my $byClass  = 0;
my $confMat = 0;
my $withHistogram = 0;
my $affRate = "err";
my $affExactMatch = "exactMatch";
my $csvOption = 0;
foreach my $arg (@ARGV){
	if($arg =~ /-L/){
		$list = 1;
	}
	if($arg =~ /-S/){
		$onlyStat = 1;
	}
	if($arg =~ /-W/){
		$warning  = 0;
	}
	if($arg =~ /-V/){
		$verbose  = "verb";
	}
	if($arg =~ /-R/){
		$affRate  = "reco";
	}
	if($arg =~ /-C/){
		$byClass  = 1;
	}
	if($arg =~ /-M/){
		$confMat  = 1;
	}
	if($arg =~ /-H/){
		$withHistogram  = 1;
	}
	if($arg =~ /-csv/){
		$csvOption  = 1;
	}

}
#define the global parser and its options (uses 'recover' because some xml:id do not respect NCName)
my $parser = XML::LibXML->new();
$parser->set_options({no_network=>1,recover=>2,validation=>0, suppress_warnings=>1,suppress_errors=>1});

my $errors = {};
my $stat = {};

if($#ARGV == 0){
	my $t1 = &Load_From_INKML($ARGV[0]);
	#print "Normalization:\n";
	&norm_mathMLNorm($t1->{XML_GT});
	#print "Checking:\n";
	&check_mathMLNorm($t1->{XML_GT});
	#print Dumper($t1);
	exit(0);
}

if($onlyStat){
	my $refFile;
	open(FILELIST,"<",$ARGV[1]) or die "$ARGV[1]:$!";
	while(<FILELIST>){
		chomp;
		unless ($_ =~ "%"){
			if(/\s*(\S.*\S)\s*/){
				$refFile = $1;
				my $t1 = &Load_From_INKML($refFile);
				&norm_mathMLNorm($t1->{XML_GT});
				if($warning){
					&check_mathMLNorm($t1->{XML_GT});
				}
				&addInkStat($stat,$t1);#acumulate
			}
		}
	}
close(FILELIST);
#print Dumper($stat);
&showStats($stat);

	exit(0);
}
if($list){ ### LIST MODE ####
	my $refFile;
	my $testFile;
	open(COUPLELIST,"<",$ARGV[1]) or die $!;
	while(<COUPLELIST>){
		chomp;
		if(/\s*(\S.*\S)\s*,\s*(\S.*\S)/){
			$refFile = $1;
			$testFile = $2;
			my $t1 = &Load_From_INKML($refFile);
			my $t2 = &Load_From_INKML($testFile);
			&norm_mathMLNorm($t2->{XML_GT});
			if($warning){
				&check_mathMLNorm($t2->{XML_GT});
			}
			my $locErrors = {};
			my $locStat = {};
			&addInkStat($stat,$t1);#acumulate
			&addInkStat($locStat,$t1);# for local use
			if(not $t1->{UI} eq $t2->{UI}){
				if($warning){
					print $testFile ." : UI warning : ".$t1->{UI} . " <> " . $t2->{UI} ."\n";
				}
				$t2 = &newTruthStruct();
			}
			&addErrors($locErrors, &Compare_strk_labels($t1,$t2));
			&addErrors($locErrors, &Compare_symbols($t1,$t2));
			&addErrors($locErrors, &exactGTmatch($t1->{XML_GT}, $t2->{XML_GT}));
			if($withHistogram){
				if(exists $locErrors->{match}->{structure} or (keys %{$locErrors->{match}}) > 0){ # there is atlest  one error
					# add it in histogram
					my $nbStrk = (keys %{$locStat->{EMsizeSTRK}})[0];
					my $nbSymb = (keys %{$locStat->{EMsizeSYMB}})[0];
					#print " NB STRK : $nbStrk   NB SYMB : $nbSymb\n";
					my $temp1 = 1;
					$locErrors->{histErrSYMB}->{$nbSymb} = \$temp1; # create a ref to a scalar to allows sumValues to detect it
					my $temp2 = 1;
					$locErrors->{histErrSTRK}->{$nbStrk} = \$temp2; # create a ref to a scalar to allows sumValues to detect it
				}
			}
			&addErrors($errors,$locErrors); #acumulate
			if($verbose){
				print $testFile; 
				if($csvOption){
					print ", ";
					&showErrorsLine($locErrors,$locStat);
				}else{
					print " :\t";
					&showErrors($locErrors,$locStat,$affRate,$affExactMatch);
				}
			}
		}
	}
	close(COUPLELIST);
}else{ ### 2 FILES MODE #####
	my $t1 = &Load_From_INKML($ARGV[0]);
	my $t2 = &Load_From_INKML($ARGV[1]);
	print "Normalization:\n";
	&norm_mathMLNorm($t2->{XML_GT});
	if($warning){
		print "Checking:\n";
		&check_mathMLNorm($t2->{XML_GT});
	}
	if(not $t1->{UI} eq $t2->{UI}){
		if($warning){
			print "  UI warning : ".$t1->{UI} . " <> " . $t2->{UI} ."\n";
		}
		$t2 = &newTruthStruct();
	}	#print Dumper($t2);
	&addInkStat($stat,$t1);
	&addErrors($errors, &Compare_strk_labels($t1,$t2));
	&addErrors($errors, &Compare_symbols($t1,$t2));
	&addErrors($errors, &exactGTmatch($t1->{XML_GT}, $t2->{XML_GT}));
	#print "REF:[".ref($errors->{seg}->{"text"})."]\n";
}

### show results ####
	#print "All errors : \n".Dumper($errors);
if($csvOption){
	print "total, ";
	&showErrorsLine($errors,$stat);
}else{
	if($stat->{GT}){
		$affExactMatch = "exactMatchPlus";
	}else{
		$affExactMatch = "";
	}
	&showErrors($errors,$stat,$verbose,$affRate,$affExactMatch);
	if($byClass){
		print "\n";
		&showClassErrors($errors,$stat,$affRate);
	}
	if($confMat){
		print "\n";
		&showClassErrorsMatrix($errors,$stat);
	}
	if($withHistogram){
		print "\n";
		&showHistogram($errors,$stat);
	}
}
exit();

########## SUB definitions ###########

## create the truth structure ###
sub newTruthStruct {
        my $self  = {};
        $self->{UI}   = "";
        $self->{STRK} = {};
        $self->{SYMB} = {};
        $self->{NBSYMB} = 0;
        $self->{XML_GT} = [];
        bless($self);           
        return $self;
}
############################
#### Load struct from an inkml file         ####
#### param : xml file name                    ####
#### out : truth struct                          ####
############################
sub Load_From_INKML {
	my $fileName = @_[0];
	my $truth = &newTruthStruct();
	if ( not ((-e $fileName) && (-r $fileName) ))
	{
		warn ("[$fileName] : file not found or not readable !\n"); 
		return $truth;
	} 
	if(-z $fileName){
		warn ("[$fileName] : empty file !\n"); 
		return $truth;
	}
	my $doc  = $parser->parse_file($fileName);
	my $ink;
	unless(defined eval {$ink = $doc->documentElement()}){
		warn ("[$fileName] : no xml !\n"); 
		return $truth;
	}
	my $xc = XML::LibXML::XPathContext->new( $doc );
	$xc->registerNs('ns', 'http://www.w3.org/2003/InkML');
	#print Dumper($data); 
	my @xmlAnn = $xc->findnodes('/ns:ink/ns:annotationXML');
	if($#xmlAnn > -1){ # there are at least one xml annotation
		if($#xmlAnn > 0 and $warning){
			print $fileName.": several annotationXML ($#xmlAnn) in this file, last is kept\n";
		}
		
		#print "Ann XML : ".Dumper($xmlAnn[0]); 
		&Load_xml_truth($truth->{XML_GT}, $xmlAnn[$#xmlAnn]->firstNonBlankChild);
		#print "XML : ".Dumper($truth->{XML_GT}); 
	}
	my $seg;
	my @groups = $xc->findnodes('/ns:ink/ns:traceGroup');
	if($#groups > 0 and $warning){
			print $fileName.": several segmentations ($#groups traceGroup) in this file, last is kept\n";
		}
	$seg = $groups[$#groups];
	
	$truth->{UI} = $xc->findvalue("/ns:ink/ns:annotation[\@type='UI']");
	#print "  UI = ".$truth->{UI}."\n";
	#print "\n";
	my $symbID = 0; #symbol ID, to distinguish the different symb with same label, if symbol without any annotationXML
	
	foreach my $group ($xc->findnodes('ns:traceGroup',$seg)){
		my $lab;
		my $id = $symbID;
		#print "SEG : ";
		$lab = ($group->getElementsByTagName('annotation')) [0]->textContent;
		if($lab eq "" and $warning){
			print STDERR " !! ".$fileName.": empty label in one symbol\n";
		}

		my @annXml = $group->getElementsByTagName('annotationXML');
		if($#annXml > -1){
			$id = $annXml[0]->getAttribute('href');
			if($#annXml > 0 and $warning){
				print STDERR $fileName.": several xml href in one symbol ($#annXml), first is kept ($id)\n";
			}
			if($id eq "" and $warning){
				print STDERR " !! ".$fileName.": empty xml href in one symbol\n";
			}
		}

		my @strList = (); #list of strokes in the symbol
		foreach my $stroke ($xc->findnodes('ns:traceView/@traceDataRef',$group)){
			#print STDERR $stroke->textContent." ";
			my $errorSeg = undef;
			if(defined $truth->{STRK}->{$stroke->textContent}){
				print STDERR " !! ".$fileName.": not a valid segmentation (same stroke '".$stroke->textContent."' used several time) \n";
				$errorSeg =  $truth->{STRK}->{$stroke->textContent}->{id};
			}
			$truth->{STRK}->{$stroke->textContent} = { id => $id, lab => $lab};
			if(defined $errorSeg){
				$truth->{STRK}->{$stroke->textContent}->{errorSeg} = $errorSeg;
			}
			push @strList, $stroke->textContent;
		}
		#foreach $e (@strList){print $e." ";}print "<<<<\n";
		$truth->{SYMB}->{$id} = {lab => $lab, strokes =>[@strList]};
		#next symb
		$symbID++;
	}
	$truth->{NBSYMB} = $symbID;
	#print Dumper($truth);
	return $truth;
}

#############################################
#### Load xml truth from raw data, fill the current xml truth struct	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#### param 2 :  reference to current xml XML::LibXML::Node     	####
#############################################
sub Load_xml_truth {
	my $truth = @_[0];
	my $data = @_[1];
	my $current = {};
	# init current node
	$current->{name} = $data->nodeName;
	$current->{sub} = [];
	$current->{id} = undef;
	push @{$truth}, $current;
	#look for id 
	foreach my $attr ($data->attributes){
		if($attr->nodeName eq 'xml:id'){
			$current->{id} = $attr->nodeValue;
		}
	}
	# look for label and children
	foreach my $subExp ($data->nonBlankChildNodes()){
		if($subExp->nodeType == XML::LibXML::XML_TEXT_NODE){
			#if( =~ /(\S*)/){# non white character
				$current->{lab} = $subExp->nodeValue;
			#}
		}else{
			&Load_xml_truth($current->{sub}, $subExp);
		}	
	}
}

#############################################
#### Use xml truth struct to check CROHME normalization rules	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#############################################
sub check_mathMLNorm {
	my %symbTags = ("mi",1, "mo",1, "mn", 1);
	my %subExpNames = ("msqrt", 1,"mroot", 2,"msub",1,"msup",1, "mfrac",2, "msubsup",3,"munderover",3,"munder",2); 
	my $current = @_[0];
	foreach my $exp (@{$current}){
		#print "-$exp->{name}-:\n";
		#print $symbTags{"mi"};
		#print $subExpNames{"msup"};
		if($exp->{name} eq 'math'){
			#start : check if there is one child
			my $nb = @{$exp->{sub}};
			if($nb > 1){ #to much children => merge remove the fisrt one and process others
				print("math tag problem deteted : not 1 children, nb=".@{$exp->{sub}}."\n");
			}
		}elsif($exp->{name} eq 'mrow'){
			# rule 1 :  no more than 2 symbols in a mrow
			if(@{$exp->{sub}} != 2){
				print("!! mrow problem deteted : not 2 children, nb=".@{$exp->{sub}}."\n");
			}else{
			#rule 2 : use right recursive for mrow , so left child should NOT be mrow
				if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
					print("!! mrow problem deteted : left child is mrow\n");
					#print Dumper($exp);
				}
			}
		}elsif($symbTags{$exp->{name}} == 1){
			#no sub exp in symbols
			if(@{$exp->{sub}} != 0){
				print("!! ".$exp->{name}." problem deteted : at least one child, nb=".@{$exp->{sub}}."\n");
			}
			# we need a label 
			if($exp->{lab} eq ""){
				print("!! ".$exp->{name}." problem deteted : no label\n");
				print Dumper($exp);
			}
		}elsif($subExpNames{$exp->{name}} == 1){#test basic spatial relations
			#no more than 2 children
			if(@{$exp->{sub}} > 2){
				print("!! ".$exp->{name}." problem deteted : more than 2 children, nb=".@{$exp->{sub}}."\n");
			}elsif(@{$exp->{sub}} == 2 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
				# if 2 children with 1 mrow, the mrow should be on right
				print("!! ".$exp->{name}." problem deteted : left child is mrow in a ".$exp->{name}."\n");
			}elsif(@{$exp->{sub}} == 1 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
				print("!! ".$exp->{name}." problem deteted : if only one child it should not be a mrow\n");
			}elsif(@{$exp->{sub}} == 0){
				print("!! ".$exp->{name}." problem deteted : no child !\n");
			}
		}elsif($subExpNames{$exp->{name}} > 1){
			# for special relations with multi sub exp, we should have the exact number of children
			if(@{$exp->{sub}} > $subExpNames{$exp->{name}}){
				print("!! ".$exp->{name}." problem deteted : more than ".$subExpNames{$exp->{name}}." children, nb=".@{$exp->{sub}}."\n");
			}
		}else{
			# reject other tags
			print "!! unknown tag :". $exp->{name}."\n";
		}
		#recursivity : process sub exp
		foreach my $subExp ($exp->{sub}){
			&check_mathMLNorm($subExp);
		}
	}
}

########################################################
#### Normalization of xml truth struct to assume  CROHME normalization rules	####
#### param 1 :  reference to current xml truth struct (ARRAY)  	####
#######################################################
sub norm_mathMLNorm {
	my %symbTags = ("mi",1, "mo",1, "mn", 1);
	my %subExpNames = ("msub",1,"msup",1, "mfrac",2, "mroot",2, "msubsup",3,"munderover",3,"munder",2); 
	my $current = @_[0];
	my $redo = 0;
	my $redoFather = 0;
	my $redoFromChild = 0;
	do{
		$redoFromChild = 0;
		foreach my $exp (@{$current}){
			do{
				$redo = 0;
				#print "-$exp->{name}- :\n";
				#print $symbTags{"mi"};
				#print $subExpNames{"msup"};
				if($exp->{name} eq 'math'){
					#start : check if there is one child
					my $nb = @{$exp->{sub}};
					if($nb > 1){ #to much children => merge remove the fisrt one and process others
						#print("math tag problem deteted : not 1 children, nb=".@{$exp->{sub}}."\n");
						#print Dumper($exp->{sub});
						#print "create new node:\n";
						my $newRow = {};# init new  node
						$newRow->{name} = 'mrow';
						$newRow->{sub} = [];
						$newRow->{id} = undef;
						@{$newRow->{sub}} = @{$exp->{sub}};
						@{$exp->{sub}} = ();
						push @{$exp->{sub}}, $newRow;
						#print "new=".Dumper($exp->{sub})."\n";
						$redo = 1;
					}
				}elsif($exp->{name} eq 'mrow'){
					# rule 1 :  no more than 2 symbols in a mrow
					my $nb = @{$exp->{sub}};
					if($nb > 2){ #to much children => merge remove the fisrt one and process others
						#print("mrow problem deteted : not 2 children, nb=".@{$exp->{sub}}."\n");
						#print Dumper($exp->{sub});
						#print "create new node:\n";
						my $newRow = {};# init new  node
						$newRow->{name} = 'mrow';
						$newRow->{sub} = [];
						$newRow->{id} = undef;
						@{$newRow->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
						pop @{$newRow->{sub}};#reduce size
						#print Dumper($newRow);
						@{$exp->{sub}} = @{$exp->{sub}}[0..0];
						push @{$exp->{sub}}, $newRow;
						#print "new=".Dumper($exp->{sub})."\n";
						$redo = 1;
					}elsif($nb == 1){ #not enought children => replace  the current mrow by its child
						#print "not enought children => replace  the current mrow by its child:\n";
						#print Dumper($exp);
						$exp->{name} = @{$exp->{sub}}[0]->{name};
						$exp->{id} = @{$exp->{sub}}[0]->{id};
						#if(not (@{$exp->{sub}}[0]->{lab}) == ){
							#print "Lab : ".@{$exp->{sub}}[0]->{lab};
							$exp->{lab} =@{$exp->{sub}}[0]->{lab};
						#}
						$exp->{sub} = @{$exp->{sub}}[0]->{sub};
						$redo = 1;
						#print "new=".Dumper($exp)."\n";
					}elsif($nb == 0){
						#print "no  child in mrow !\n";
					}else{
					#rule 2 : use right recursive for mrow , so left child should NOT be mrow
						
						if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
							#print("mrow problem deteted : left child is mrow=> remove it and insert children in\n");
							#print Dumper($exp);
							my $children = @{$exp->{sub}}[0]->{sub};
							@{$exp->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
							pop @{$exp->{sub}};#reduce size
							push (@{$children},@{$exp->{sub}});
							@{$exp->{sub}} = @{$children};
							#print "new=".Dumper($exp)."\n";
							$redo = 1;
						}
					}
				}elsif($exp->{name} eq 'msqrt'){
					# rule 1 :  no more than 2 symbols in a mrow
					my $nb = @{$exp->{sub}};
					if($nb > 2){ #to much children => merge remove the fisrt one and process others
						#print("mrow problem deteted : not 2 children, nb=".@{$exp->{sub}}."\n");
						#print Dumper($exp->{sub});
						#print "create new node:\n";
						my $newRow = {};# init new  node
						$newRow->{name} = 'mrow';
						$newRow->{sub} = [];
						$newRow->{id} = undef;
						@{$newRow->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
						pop @{$newRow->{sub}};#reduce size
						#print Dumper($newRow);
						@{$exp->{sub}} = @{$exp->{sub}}[0..0];
						push @{$exp->{sub}}, $newRow;
						#print "new=".Dumper($exp->{sub})."\n";
						$redo = 1;
					}elsif($nb == 2){
					#rule 2 : use right recursive for mrow , so left child should NOT be mrow
						if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
							#print("mrow problem deteted : left child is mrow=> remove it and insert children in\n");
							#print Dumper($exp);
							my $children = @{$exp->{sub}}[0]->{sub};
							@{$exp->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
							pop @{$exp->{sub}};#reduce size
							push (@{$children},@{$exp->{sub}});
							@{$exp->{sub}} = @{$children};
							#print "new=".Dumper($exp)."\n";
							$redo = 1;
						}
					}elsif($nb == 1){
						if(@{$exp->{sub}}[0]->{name} eq 'mrow'){
							#print("msqrt problem deteted : only child is mrow=> remove it and insert children in\n");
							#print Dumper($exp);
							my $children = @{$exp->{sub}}[0]->{sub};
							@{$exp->{sub}} = @{$exp->{sub}}[1..$nb]; #remove first
							pop @{$exp->{sub}};#reduce size
							push (@{$children},@{$exp->{sub}});
							@{$exp->{sub}} = @{$children};
							#print "new=".Dumper($exp)."\n";
							$redo = 1;
						}
					}
				}elsif($symbTags{$exp->{name}} == 1){
					#nothing to normalise
				}elsif($subExpNames{$exp->{name}} == 1){#test basic spatial relations msup and msub
					#no more than 2 children
					if(@{$exp->{sub}} > 2){
						#print($exp->{name}." problem deteted : more than 2 children, nb=".@{$exp->{sub}}."\n");
					}elsif(@{$exp->{sub}} == 2 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
						# if left child is 1 mrow, the mrow should be removed and the relation is put on the last child of the mrow
						#print($exp->{name}."NORM problem deteted : left child is mrow in a ".$exp->{name}."\n");
						#print Dumper($exp);
						my $theChildren = @{$exp->{sub}}[0]->{sub};
						if(@{$theChildren} > 0){# we can to it
							#built a new msub/msup relation and put it at the end of the mrow
							my $newSR = {};# init new  node => the new SR
							$newSR->{name} = $exp->{name};
							$newSR->{sub} = [];
							$newSR->{id} = $exp->{id};
							push (@{$newSR->{sub}},@{$theChildren}[$#{$theChildren}]); # the base of SR
							push (@{$newSR->{sub}},@{$exp->{sub}}[1]); # the child
							$exp->{name} = 'mrow';
							$exp->{id} = undef;
							$exp->{sub} = @{$exp->{sub}}[0]->{sub};
							pop @{$exp->{sub}}; # remove the last element (old base of SR)
							push  (@{$exp->{sub}},$newSR);# and replace by the new one
							$redo = 1;
							$redoFather = 1;
							#print "Apres:". Dumper($exp);
						}
						
					}elsif(@{$exp->{sub}} == 1 && @{$exp->{sub}}[0]->{name} eq 'mrow'){
						#print($exp->{name}." problem deteted : if only one child it should not be a mrow\n");
						
					}elsif(@{$exp->{sub}} == 0){
						#print($exp->{name}." problem deteted : no child !\n");
					}
				}elsif($subExpNames{$exp->{name}} > 1){
					# for special relations with multi sub exp, we should have the exact number of children
					if(@{$exp->{sub}} > $subExpNames{$exp->{name}}){
						#print($exp->{name}." problem deteted : more than ".$subExpNames{$exp->{name}}." children, nb=".@{$exp->{sub}}."\n");
					}
				}else{
					# reject other tags
					print "unknown tag :". $exp->{name}."\n";
				}
				#print "redo($redo)\n";
			}while($redo);
			unless($redoFather){
			#recursivity : process sub exp 
				foreach my $subExp ($exp->{sub}){
					$redoFromChild |= &norm_mathMLNorm($subExp);
				}
			}
			#print "redoFromChild($redoFromChild)\n";
		}
	}while($redoFromChild);
	#print "redoFather($redoFather)\n";
	return $redoFather;
}

#############################################
#### Compare label of strokes               		####
#### param 1 :  reference truth struct   		####
#### param 2 :  evalated truth struct     		####
#### out : number of errors  of type {strkLab} detailed for each label	####
#############################################

sub Compare_strk_labels {
	my $gdTruth = @_[0];
	my $evTruth = @_[1];
	my $errors = {};
	my $evLab;
	my $strk;
	my $tr;
	
	#print ref($gdTruth->{STRK});
	while (($strk => $tr) = each(%{$gdTruth->{STRK}})){
		$evLab = $evTruth->{STRK}->{$strk}->{lab};
		if((not defined ($evLab)) or ($evLab eq "")){
			$evLab = "unknown";
		}
		if(not ($evLab eq $tr->{lab})){ #test if labels are equal
			#print " ++ :".$errors->{strkLab}->{$tr->{lab}}->{$evLab} . " -> ";
			$errors->{strkLab}->{$tr->{lab}}->{$evLab}++;
			#print $errors->{strkLab}->{$tr->{lab}}->{$evLab};
		}
		#print "\n";
	}
	#print "Compare_strk_labels output : " . Dumper($errors);
	return $errors;
}

#######################################################
#### Compare segmentation and label of symbols 			####
#### param 1 :  reference truth struct   			####
#### param 2 :  evalated truth struct     			####
#### out : 4 types of errors   (seg, segStrk, reco, recoStrk) detailed for each label 	####
#######################################################

sub Compare_symbols {
	my $gdTruth = @_[0];
	my $evTruth = @_[1];
	my $errors = {};
	my $symb;
	my $nbs;
	
	foreach $symb (values(%{$gdTruth->{SYMB}})){
		#find the symb ID in evTruth (use the first stroke)
		my $evSymbID = $evTruth->{STRK}->{$symb->{strokes}[0]}->{id};
		# compute diff of stroke sets
		my $diff = &setDiff($symb->{strokes}, $evTruth->{SYMB}->{$evSymbID}->{strokes});
		my $evLab = $evTruth->{SYMB}->{$evSymbID}->{lab};
		if((not defined ($evLab)) or ($evLab eq "")){
			$evLab = "unknown";
		}
		if(defined $diff and @{$diff} > 0){ # if segmentation error
				$errors->{seg}->{$symb->{lab}}->{$evLab}++;
				$nbs = @{$symb->{strokes}};
				$errors->{segStrk}->{$symb->{lab}}->{$evLab} += $nbs;
		}else{
			if(not ($evLab eq $symb->{lab})){ #test if labels are equal
				#print $evTruth->{SYMB}->{$evSymbID}->{lab}." =!= ". $symb->{lab}."(s".$symb->{strokes}[0].")\n";
				$errors->{reco}->{$symb->{lab}}->{$evLab}++;
				$nbs = @{$symb->{strokes}};
				$errors->{recoStrk}->{$symb->{lab}}->{$evLab}+= $nbs;
			}
		}
	}
	return $errors;
}

#######################################################
#### Add errors of different results respecting the error type		####
#### param 1 :  cumuled errors   				####
#### param 2 :  new errors to add     			####
#######################################################
sub addErrors {
	my ($cumulErr, $err) = @_;
	#print "ADD : \n".Dumper($err);
	foreach my $errType (keys (%{$err})){
		#print "ref : $errType [" . ref({$cumulErr->{$errType}})."]\n";
		foreach my $label (keys (%{$err->{$errType}})){
			#print "  ref lab : $label [" . ref($err->{$errType}->{$label})."]\n";
			if(ref($err->{$errType}->{$label}) eq "HASH"){ #if it is an error matrix
				#print "  foreach : ".$err->{$errType}->{$label}."\n";
				foreach my $labelConf (keys (%{$err->{$errType}->{$label}})){
					#print "cumul $labelConf : ".ref({$cumulErr->{$errType}->{$label}->{$labelConf}})."=".$err->{$errType}->{$label}->{$labelConf}."\n";
					$cumulErr->{$errType}->{$label}->{$labelConf} += $err->{$errType}->{$label}->{$labelConf};
				}
			}else{
				#print "     not HASH : ${$err->{$errType}->{$label}}";
				${$cumulErr->{$errType}->{$label}} += ${$err->{$errType}->{$label}};
				#print " => ${$cumulErr->{$errType}->{$label}}\n";
			}
		}
	}
}


#######################################################
#### count each spatial relation (mathML tag) 			####
#### param 1 :  cumuled stats   				####
#### param 2 :  sub part of MathML tree     			####
#######################################################
sub addInkStatSpatRel {
	my ($stat, $truth) = @_;
	my $nbs;
	my $subExp;
	foreach $subExp (@{$truth}){
		$stat->{SPAREL}->{$subExp->{name}}++;#
		&addInkStatSpatRel($stat, $subExp->{sub});
	}
} 

#######################################################
#### Add stat about number of symbols and strokes 			####
#### param 1 :  cumuled stats   				####
#### param 2 :  one truth	     			####
#######################################################
sub addInkStat {
	my ($stat, $truth) = @_;
	my $nbs;
	my $symbID;
	my $nbTotSymb = 0;
	my $nbTotStrk = 0;
	foreach $symbID (keys(%{$truth->{SYMB}})){
		$stat->{SYMB}->{$truth->{SYMB}->{$symbID}->{lab}}++; ## one more symb of this label
		$nbTotSymb++;
		$nbs = @{$truth->{SYMB}->{$symbID}->{strokes}};
		$stat->{STRK}->{$truth->{SYMB}->{$symbID}->{lab}}+=$nbs; ## more strokes of this label
		$nbTotStrk+= $nbs;
	}
	&addInkStatSpatRel($stat, $truth->{XML_GT});
	$stat->{GT}++;
	$stat->{EMsizeSTRK}->{$nbTotStrk}++;
	$stat->{EMsizeSYMB}->{$nbTotSymb}++;
} 

#######################################################
#### Print errors types		 		####
#### param 1 :  cumuled errors    				####
#### param 2 :  cumuled stats	     			####
#### param 3 : (optionnal) reco rate (if 'reco') or error rate (if 'err',default) 	####
#### param 4 :  (optionnal) verbose if 'verb'     			####
#### param 4 :  (optionnal) shows exact match rate  if 'exactMatch'     		####
#### param 4 :  (optionnal) shows exact match rate s with 1 2 3 error  if 'exactMatchPlus' and not verbose#
#######################################################
sub showErrors {
	my $errors = @_[0];
	my $stats = @_[1];
	my $verb = 0;
	my $eMatch = 0;
	my $eMatchPlus = 0;
	my $affErr = 1;
	my $separator = " \t";
	for(my $p = 2; $p <= $#_ ; $p++){
		if(@_[$p]=~/reco/){
			$affErr = 0;
		}
		if(@_[$p]=~/verb/){
			$verb = 1;
		}
		if(@_[$p]=~/exactMatch/){
			$eMatch = 1;
		}
		if(@_[$p]=~/exactMatchPlus/){
			$eMatchPlus = 1;
		}
	}
	my $numStrk =  &sumValues($stats->{STRK});
	my $numStrkError = &sumValues($errors->{strkLab});
	if($verb){
		 $separator = " %\n";
		if($affErr){
			print "$numStrkError errors on stroke labels on $numStrk strokes : ";
		}else{
			print "".($numStrk - $numStrkError) ." correct labels on $numStrk strokes : ";		
		}
	}
	if($affErr){
		printf "%5.2f", ((100.0*$numStrkError)/$numStrk);
	}else{
		printf "%5.2f",(100.0 - (100.0*$numStrkError)/$numStrk);
	}
	print  $separator;
	
	my $numSymb =  &sumValues($stats->{SYMB});
	my $numSymbErrorSeg = &sumValues($errors->{seg});
	my $numSymbErrorReco = &sumValues($errors->{reco});
	my $numGTErrorMatch = &sumValues($errors->{match});
	my $numGTErrorMatchType = &sumValues($errors->{matchType});
	if($numGTErrorMatchType != $numGTErrorMatch){
		print "WARNING : err type check failed = $numGTErrorMatchType != $numGTErrorMatch\n";
	}
	my $numGT = ($stats->{GT});
	if($verb){
		if($affErr){
			print "$numSymbErrorSeg errors of segmentation on $numSymb symbols: ";
		}else{
			print "".($numSymb - $numSymbErrorSeg)." correct segmentations on $numSymb symbols: ";
		}
	}
	if($affErr){
		printf "%5.2f", ((100.0*$numSymbErrorSeg)/$numSymb);
	}else{
		printf "%5.2f", 100 - ((100.0*$numSymbErrorSeg)/$numSymb); 
	}
	print $separator;
	
	if($numSymb-$numSymbErrorSeg > 0){
		if($verb){
			if($affErr){
				print "$numSymbErrorReco errors of reco on ".($numSymb-$numSymbErrorSeg)." right seg symbols: ";
			}else{
				print "".(($numSymb-$numSymbErrorSeg) - $numSymbErrorReco)." correct reco on ".($numSymb-$numSymbErrorSeg)." right seg symbols: ";			
			}
		}
		if($affErr){
			printf "%5.2f", ((100.0*$numSymbErrorReco)/($numSymb-$numSymbErrorSeg)); 
		}else{
			printf "%5.2f", (100 - (100.0*$numSymbErrorReco)/($numSymb-$numSymbErrorSeg)); 
		}
	}else{
		if($verb){
			print "error of reco is undefined, not enought right segmented symbols...";
		}else{
			printf "%5.2f", 0;
		}
	}
	print $separator;
	if($verb){
		if($affErr){
			print "$numGTErrorMatch match errors on $numGT ground-truths: ";
		}else{
			printf "%d exact matchs on %d ground-truths: ",($numGT-$numGTErrorMatch),$numGT; 
		}
	}
	if($affErr){
		printf "%5.2f", ((100.0*$numGTErrorMatch)/$numGT);
	}else{
		printf "%5.2f", 100 - ((100.0*$numGTErrorMatch)/$numGT); 
	}
	print $separator;
	
	
	
	if($verb){
		my $totME = 0;
		foreach my $nbMatchEr (sort keys(%{$errors->{match}})){
			unless ($nbMatchEr eq "structure"){
				$totME += ${$errors->{match}->{$nbMatchEr}};
				if($affErr){
					printf "   %d match error on $numGT ground-truths if $nbMatchEr label/tag error are allowed : %5.2f\n",($numGTErrorMatch-$totME), ((100.0*($numGTErrorMatch-$totME))/$numGT);
				}else{
					printf "   %d exact match on $numGT ground-truths if $nbMatchEr label/tag error are allowed : %5.2f\n",($numGT - $numGTErrorMatch+$totME), (100.0 - (100.0*($numGTErrorMatch-$totME))/$numGT);
				}
			}
		}
		
		foreach my $typeErr (sort keys(%{$errors->{matchType}})){	
			my $val = ${$errors->{matchType}->{$typeErr}} ;	 
			if($affErr){
				printf "   %d match error of $typeErr on $numGT ground-truths : %5.2f\n",$val, ((100.0*($val))/$numGT);
			}else{
				printf "   %d exact match on $numGT ground-truths if errors of type $typeErr are allowed : %5.2f\n",($numGT - $numGTErrorMatch+$val), (100.0 - (100.0*($numGTErrorMatch-$val))/$numGT);
			}
		}		
		
	}elsif($eMatchPlus){
		my $totME = 0;
		foreach my $nbMatchEr (("1", "2", "3")){
			#print "ne = $nbMatchEr\n";
			if(defined $errors->{match}->{$nbMatchEr}){
				$totME += ${$errors->{match}->{$nbMatchEr}};	
			}
			if($affErr){
				printf "%5.2f", ((100.0*($numGTErrorMatch-$totME))/$numGT);
			}else{
				printf "%5.2f",(100.0 - (100.0*($numGTErrorMatch-$totME))/$numGT);
			}
			print $separator;
		}
		
	}
	my $val = 0;
	if(exists $errors->{matchType}->{errOnlyOnLab}){
		$val = ${$errors->{matchType}->{errOnlyOnLab}};
	}
	if($affErr){
		printf "%5.2f", ((100.0*($val))/$numGT);
	}else{
		printf "%5.2f",(100.0 - (100.0*($numGTErrorMatch-$val))/$numGT);
	}
	print $separator;
	print "\n";
}

#######################################################
#### Print all errors types in one csv line 	 		####
#### param 1 :  cumuled errors    				####
#### param 2 :  cumuled stats	     			####
#######################################################
sub showErrorsLine {
	my $errors = @_[0];
	my $stats = @_[1];
	my $verb = 0;
	my $numStrk =  &sumValues($stats->{STRK});
	my $numStrkError = &sumValues($errors->{strkLab});
	print "numStrk, $numStrk, ";
	print "errLabStrk, $numStrkError, ";
	print "correctLabStrk, ".($numStrk - $numStrkError) .", ";		
	printf "errLabStrk(\%), %5.2f, ", ((100.0*$numStrkError)/$numStrk);
	printf "correctLabStrk(\%), %5.2f, ",(100.0 - (100.0*$numStrkError)/$numStrk);

	my $numSymb =  &sumValues($stats->{SYMB});
	my $numSymbErrorSeg = &sumValues($errors->{seg});
	my $numSymbErrorReco = &sumValues($errors->{reco});
	my $numGTErrorMatch = &sumValues($errors->{match});
	my $numGTErrorMatchType = &sumValues($errors->{matchType});
	if($numGTErrorMatchType != $numGTErrorMatch){
		print "WARNING : err type check failed = $numGTErrorMatchType != $numGTErrorMatch\n";
	}
	my $numGT = ($stats->{GT});
	print "numSymb, $numSymb, ";
	
	print "numSymbErrorSeg, $numSymbErrorSeg, ";
	print "numSymbCorrectSeg, ".($numSymb - $numSymbErrorSeg).", ";
	printf "numSymbErrorSeg(\%), %5.2f, ", ((100.0*$numSymbErrorSeg)/$numSymb);
	printf "numSymbCorrectSeg(\%), %5.2f, ", 100 - ((100.0*$numSymbErrorSeg)/$numSymb); 
	print "numSymbErrorReco, $numSymbErrorReco, ";
	print "numSymbCorrectReco".(($numSymb-$numSymbErrorSeg) - $numSymbErrorReco).", ";
	my $divpar = 1; 
	if($numSymb-$numSymbErrorSeg > 0){$divpar = $numSymb-$numSymbErrorSeg;}
	printf "numSymbErrorReco(\%), %5.2f, ", ((100.0*$numSymbErrorReco)/($divpar)); 
	printf "numSymbCorrectReco(\%), %5.2f, ", (100 - (100.0*$numSymbErrorReco)/($divpar)); 
	print "numGT, $numGT, ";
	print "numGTErrorMatch, $numGTErrorMatch";
	printf "numGTExactMatch, %d, ",($numGT-$numGTErrorMatch); 
	printf "numGTErrorMatch(\%), %5.2f, ", ((100.0*$numGTErrorMatch)/$numGT);
	printf "numGTExactMatch(\%), %5.2f, ", 100 - ((100.0*$numGTErrorMatch)/$numGT); 
	my $totME = 0;
	foreach my $nbMatchEr (("1", "2", "3")){
		if(defined $errors->{match}->{$nbMatchEr}){
			$totME += ${$errors->{match}->{$nbMatchEr}};	
		}
		printf "numGTErrorMatchWith$nbMatchEr, %5.2f, ", ($numGTErrorMatch-$totME);
		printf "numGTExactMatchWith$nbMatchEr, %5.2f, ",($numGT- ($numGTErrorMatch-$totME));
	}
	

	my $val = 0;
	if(exists $errors->{matchType}->{errOnlyOnLab}){
		$val = ${$errors->{matchType}->{errOnlyOnLab}};
	}
	printf "errGTOnlyOnLab, %d", ($val);
	printf "correctGTOnlyOnLab, %d",($numGT-($numGTErrorMatch-$val));
	print "\n";
}


#######################################################
#### Print errors types		 		####
#### param 1 :  cumuled matrix errors    			####
#### param 2 :  cumuled stats	     			####
#### param 3 : (optionnal) reco rate (if 'reco') or error rate (if 'err',default) 	####
#######################################################
sub showClassErrors {
	my $errors = @_[0];
	my $stats = @_[1];
	my $affErr = 1;
	my $lab;
	for(my $p = 2; $p <= $#_ ; $p++){
		if(@_[$p]=~/reco/){
			$affErr = 0;
		}
	}
	my $numStrk =  &sumValues($stats->{STRK});
	my $numSymb =  &sumValues($stats->{SYMB});
	print "$numSymb Symbols and $numStrk Strokes: ";
	if($affErr){
		print "ERROR RATES\n"
	}else{
		print "RECO RATES\n"	
	}
	print "class      (symb/strk):Strk reco|Symb seg | Symb reco\n";
	print "-----------------------------------------------------\n";	
	foreach $lab (sort keys(%{$stats->{SYMB}})){
		printf "%10.10s (%4d/%4d):",$lab,$stats->{SYMB}->{$lab},$stats->{STRK}->{$lab};
		if($affErr){
			printf "%8d |%8d | %8d\n",
				&sumValues($errors->{strkLab}->{$lab}),
				&sumValues($errors->{seg}->{$lab}),
				&sumValues($errors->{reco}->{$lab});
		}else{
			printf "%8d |%8d | %8d\n",
				$stats->{STRK}->{$lab}-&sumValues($errors->{strkLab}->{$lab}),
				$stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}),
				$stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab})-&sumValues($errors->{reco}->{$lab});		
		}
	}
	print "\nclass      ( %symb/ %strk):%Strk reco| %Symb seg| %Symb reco\n";
	print "--------------------------------------------------------\n";	
	foreach $lab (sort keys(%{$stats->{SYMB}})){
		printf "%10.10s (%6.2f/%6.2f):  ",$lab,100.0*$stats->{SYMB}->{$lab}/$numSymb,100.0*$stats->{STRK}->{$lab}/$numStrk;
		if($affErr){
			printf "%6.2f  |  %6.2f  |  %6.2f\n",
				100.0* &sumValues($errors->{strkLab}->{$lab})/$stats->{STRK}->{$lab},
				100.0* &sumValues($errors->{seg}->{$lab})/$stats->{SYMB}->{$lab},
				100.0* &sumValues($errors->{reco}->{$lab})/(($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))||1);
		}else{
			printf "%6.2f  |  %6.2f  |  %6.2f\n",
				100.0*($stats->{STRK}->{$lab}-&sumValues($errors->{strkLab}->{$lab}))/$stats->{STRK}->{$lab},
				100.0*($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))/$stats->{SYMB}->{$lab},
				100.0*(($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))-&sumValues($errors->{reco}->{$lab}))/(($stats->{SYMB}->{$lab}-&sumValues($errors->{seg}->{$lab}))||1);		
		}
	}


}

#######################################################
#### Print errors types		 		####
#### param 1 :  cumuled matrix errors    			####
#### param 2 :  cumuled stats	     			####
#######################################################
sub showClassErrorsMatrix {
	my $errors = @_[0];
	my $stats = @_[1];
	my $lab;
	my @symbList = sort keys(%{$stats->{SYMB}});
	print "Confusion Matrix at Stroke level : \n";
	print "class      (strk):";
	foreach $lab ( @symbList){ printf "%8.8s |",$lab}
	print " unknown\n----------------------------";	
	foreach $lab (@symbList){printf "----------";}print"\n";
	foreach $lab (@symbList){
		printf "%10.10s (%4d):",$lab,$stats->{STRK}->{$lab};
		foreach my $labC (@symbList){
			if($lab eq $labC){
				printf "%8d |", (($lab,$stats->{STRK}->{$lab}) - &sumValues($errors->{strkLab}->{$lab}));
			}else{
				printf "%8d |", ($errors->{strkLab}->{$lab}->{$labC}||0);
			}
		}
		printf "%8d \n", ($errors->{strkLab}->{$lab}->{"unknown"}||0);
	}
	print "\nConfusion Matrix at Symbol level : \n";
	print "class      (symb):";
	foreach $lab (@symbList){ printf "%8.8s |",$lab}
	print " seg Err\n----------------------------";	
	foreach $lab (@symbList){printf "----------";}print"\n";
	foreach $lab (@symbList){
		printf "%10.10s (%4d):",$lab,$stats->{SYMB}->{$lab};
		foreach my $labC (@symbList){
			if($lab eq $labC){
				printf "%8d |", (($lab,$stats->{SYMB}->{$lab}) - &sumValues($errors->{reco}->{$lab})- &sumValues($errors->{seg}->{$lab}));
			}else{
				printf "%8d |", ($errors->{reco}->{$lab}->{$labC}||0);
			}
		}
		printf "%8d \n", &sumValues($errors->{seg}->{$lab});
	}
	print "\nConfusion Matrix of sptatial relation errors in expression matching : \n";
	print "class      (symb):";
	my @allKeys = keys(%{$stats->{SPAREL}});
	push(@allKeys,  keys(%{$errors->{matchSpatRel}}));
	my %tempHash = ();
	foreach $lab (keys(%{$errors->{matchSpatRel}})){
		push(@allKeys,  keys(%{$errors->{matchSpatRel}->{$lab}}));
	}
	@tempHash{@allKeys} = ();
	delete($tempHash{math});
	@allKeys = sort keys %tempHash;
	foreach $lab (@allKeys){ printf "%8.8s |",$lab}
	print "  Err\n----------------------------";	
	foreach $lab (@allKeys){printf "----------";}print"\n";
	foreach $lab (@allKeys){
		printf "%10.10s (%4d):",$lab,$stats->{SPAREL}->{$lab};
		foreach my $labC (@allKeys){
			if($lab eq $labC){
				printf "%8d |", (($lab,$stats->{SPAREL}->{$lab}) - &sumValues($errors->{matchSpatRel}->{$lab}));
			}else{
				printf "%8d |", ($errors->{matchSpatRel}->{$lab}->{$labC}||0);
			}
		}
		printf "%8d \n", &sumValues($errors->{matchSpatRel}->{$lab});
	}
}

#######################################################
#### Print stats		 		####
#### param 1 :  cumuled stats	     			####
#######################################################
sub showStats {
	my $stats = @_[0];
	my $lab;
	my $numStrk =  &sumValues($stats->{STRK});
	my $numSymb =  &sumValues($stats->{SYMB});
	my $numClass = keys(%{$stats->{SYMB}});
	my $numGT = ($stats->{GT});
	print "$numClass classes, $numSymb Symbols and $numStrk Strokes: \n";
	print "class      | Symb (%)  | Strk (%)\n";
	print "-----------------------------------------------------\n";	
	foreach $lab (sort keys(%{$stats->{SYMB}})){
		printf "%10.10s |%4d(%3.3f\%)|%4d(%3.3f\%)\n",$lab,$stats->{SYMB}->{$lab},100.0*$stats->{SYMB}->{$lab}/$numSymb,$stats->{STRK}->{$lab},100.0*$stats->{STRK}->{$lab}/$numStrk;	
	}
	print "--------------------------------------------------------\n";	
	print "Spatial Relations :\n";
	
	print "--------------------------------------------------------\n";	
	foreach $lab (sort keys(%{$stats->{SPAREL}})){
		printf "%10.10s | %4d (%5.2f)\n",$lab,$stats->{SPAREL}->{$lab}, $stats->{SPAREL}->{$lab}/$numGT;
	}
	
	print "--------------------------------------------------------\n";	
	#if($withHistogram){
		print "Histogram of expression sizes (SYMBOL):\n";
		print "--------------------------------------------------------\n";	
		foreach $lab (sort { $a <=> $b } keys(%{$stats->{EMsizeSYMB}})){
			printf "%10.10s | %4d (%5.2f)\n",$lab,$stats->{EMsizeSYMB}->{$lab}, $stats->{EMsizeSYMB}->{$lab}/$numGT;
		}
		print "--------------------------------------------------------\n";
		print "Histogram of expression sizes (STROKE):\n";
		print "--------------------------------------------------------\n";	
		foreach $lab (sort { $a <=> $b } keys(%{$stats->{EMsizeSTRK}})){
			printf "%10.10s | %4d (%5.2f)\n",$lab,$stats->{EMsizeSTRK}->{$lab}, $stats->{EMsizeSTRK}->{$lab}/$numGT;
		}
		print "--------------------------------------------------------\n";
	#}
}

#######################################################
#### Print error histogram		 		####
#### param 1 :  cumuled matrix errors    			####
#### param 2 :  cumuled stats	     			####
#######################################################
sub showHistogram{
	my $errors = @_[0];
	my $stats = @_[1];
	my $lab;
	#print Dumper($errors);
	print "Histogram of expression sizes (SYMBOL):\n";
	print "--------------------------------------------------------\n";	
	foreach $lab (sort { $a <=> $b } keys(%{$stats->{EMsizeSYMB}})){
		if(exists $errors->{histErrSYMB}->{$lab}){
			printf "%10.10s	%4d	%4d	%5.2f\n",$lab,${$errors->{histErrSYMB}->{$lab}},$stats->{EMsizeSYMB}->{$lab}, ${$errors->{histErrSYMB}->{$lab}} / $stats->{EMsizeSYMB}->{$lab};
		}else{
			printf "%10.10s	 0 	%4d	0\n",$lab,$stats->{EMsizeSYMB}->{$lab};
		}
	}
	print "--------------------------------------------------------\n";
	print "Histogram of expression sizes (STROKE):\n";
	print "--------------------------------------------------------\n";	
	foreach $lab (sort { $a <=> $b } keys(%{$stats->{EMsizeSTRK}})){
		if(exists $errors->{histErrSTRK}->{$lab}){
			printf "%10.10s | %4d | %5.2f\n",$lab,${$errors->{histErrSTRK}->{$lab}}, ${$errors->{histErrSTRK}->{$lab}} / $stats->{EMsizeSTRK}->{$lab};
		}else{
			printf "%10.10s |    0 |     0\n",$lab;
		}
	}
	print "--------------------------------------------------------\n";
}

#######################################################
#### Exact match of Ground Truth Graph (recursive)	 		####
#### param 1 :  ref graph				####
#### param 2 :  evaluated graph	     			####
#### return match errors (matchSize, matchLab, matchSpatRel, match)		####
#######################################################
sub exactGTmatch {

	my $errors = {};
	my $nbErrors = 0;
	$errors = &exactGTmatchRecursive( @_[0], @_[1], $errors, 1);
	if(exists($errors->{matchSize}) and keys %{$errors->{matchSize}} > 0){
			if(not exists $errors->{match}->{structure}){
				my $temp = 0;
				$errors->{match}->{structure} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{match}->{structure}} += 1;
			
			if(not exists $errors->{matchType}->{structure}){
				my $temp = 0;
				$errors->{matchType}->{structure} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{matchType}->{structure}} += 1;
	}else{
		if(exists($errors->{matchLab})){		
			$nbErrors += (keys %{$errors->{matchLab}});
		}elsif(exists($errors->{matchSpatRel})){		
			if(not exists $errors->{matchType}->{errOnlyOnSR}){
				my $temp = 0;
				$errors->{matchType}->{errOnlyOnSR} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{matchType}->{errOnlyOnSR}} += 1;
		}
		if(exists($errors->{matchSpatRel})){		
			$nbErrors += (keys %{$errors->{matchSpatRel}});
		}elsif(exists($errors->{matchLab})){		
			if(not exists $errors->{matchType}->{errOnlyOnLab}){
				my $temp = 0;
				$errors->{matchType}->{errOnlyOnLab} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{matchType}->{errOnlyOnLab}} += 1;
		}
		if(exists($errors->{matchSpatRel}) and exists($errors->{matchLab})){		
			if(not exists $errors->{matchType}->{errOnBothLabSR}){
				my $temp = 0;
				$errors->{matchType}->{errOnBothLabSR} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{matchType}->{errOnBothLabSR}} += 1;
		}
		if($nbErrors){
			if(not exists $errors->{match}->{$nbErrors}){
				my $temp = 0;
				$errors->{match}->{$nbErrors} = \$temp; # create a ref to a scalar to allows sumValues to detect it
			}
			${$errors->{match}->{$nbErrors}} += 1;
		}
		
		
	}
	#print " After rec = \n";	
	#print Dumper($errors);
	return $errors;
	}
#######################################################
#### Exact match of Ground Truth Graph (recursive)	 		####
#### param 1 :  ref graph				####
#### param 2 :  evaluated graph	     			####
#### param 3 :  current match error     			####
#### param 4 :  true if it is the root level      			####
#### return cumulative match error	(matchSize, matchLab, matchSpatRel, match)	####
#######################################################
sub exactGTmatchRecursive {
	my $refGT = @_[0];
	my $evalGT = @_[1];
	my $match = 0;
	my $errors = {};
	$errors = @_[2];
	my $root = @_[3];

	#print $sub." IN REF =>".Dumper(@{$refGT});
	#print $sub." IN EVAL =>".Dumper(@{$evalGT});
	my $n = @{$refGT}; # number of children in ref
	my $sub;
	my $res;
	
	if($n == @{$evalGT}){#  ompare number of children 
		$match = 1;
		for ($sub = 0; ($sub < $n); $sub++){ # for each child
			#print @{$refGT}[$sub]->{name} . " ? ". @{$evalGT}[$sub]->{name}." and " . @{$refGT}[$sub]->{lab}  . " ? ".  @{$evalGT}[$sub]->{lab}."\n";
			my $GTName = @{$refGT}[$sub]->{name};# node name test
			if(($GTName eq "mi") or ($GTName eq "mo") or ($GTName eq "mn")){#ignore this kind of error
				$match =  ((@{$evalGT}[$sub]->{name} eq "mi") or (@{$evalGT}[$sub]->{name} eq "mo") or (@{$evalGT}[$sub]->{name} eq "mn")); # node name test
			}else{
				$match =  ($GTName eq @{$evalGT}[$sub]->{name}); # node name test
			}
			unless($match){
				#print "	Add SR error\n";
				$errors->{matchSpatRel}->{@{$refGT}[$sub]->{name}}->{@{$evalGT}[$sub]->{name}} ++; #save node name error
			}
			$match =  (@{$refGT}[$sub]->{lab} eq @{$evalGT}[$sub]->{lab}); #label test
			unless($match){
				#print "	Add Lab error\n";
				$errors->{matchLab}->{@{$refGT}[$sub]->{lab}}->{@{$evalGT}[$sub]->{lab}} ++; #save node label error
			}

			#print "REC  : ";
			#print " left =>".Dumper(@{$refGT}[$sub]->{sub});
			#print " right =>".Dumper(@{$evalGT}[$sub]->{sub});
			
			$res = &exactGTmatchRecursive(@{$refGT}[$sub]->{sub}, @{$evalGT}[$sub]->{sub}, $errors,0);
			
			if(exists($errors->{matchSize}->{"catch"})){# wrong format error in a child
				while ((my $key, my $value) = each(%{$errors->{matchSize}->{"catch"}})){
					#print "	Add size error : $key => $value\n";
					$errors->{matchSize}->{@{$refGT}[$sub]->{name}}->{$key} += $value; #save node name error
				}
				delete($errors->{matchSize}->{"catch"});
			}
		}
	}else{
		 
		my $n2 = @{$evalGT};
		#print "n=$n ; n2=$n2 ; root=$root\n"; 
		
		if($root){
			$match = 0;
			$errors->{matchSize}->{"root"}->{"ChildrenSize:".$n."vs".$n2}++;
		}else{
			$errors->{matchSize}->{"catch"}->{"ChildrenSize:".$n."vs".$n2}++;# let the father memorise the error to know the node name
		}
	}
	#print " RES rec = \n";	
	#print Dumper($errors);
	return $errors;
}

######## Utility sub ##########


sub setDiff {
	my ($first, $second) = @_;
	my %count = ();
	my $res = (); 
	#print "--\n";
	foreach my $element (@$first, @$second) { if(defined $element and not $element eq "") {$count{$element}++ }}
	foreach my $element (keys %count) {
		#print $element.":".$count{$element}."\n" ;
		if($count{$element} < 2){
			push @$res, $element ;
		}
	}
	return $res;
}

sub sumValues {
	my $hash = @_[0];
	my $v = 0;
	my $e;
	#print "SumVal : " . Dumper($hash);
	if(defined($hash)){
		foreach $e (values(%{$hash})){
			#print ref($e). " ";
			if(ref($e) eq "HASH"){
				#print "SumVal REC : ";
				$v += &sumValues($e);
			}elsif(ref($e) eq "SCALAR"){
				#print "SumVal SCALAR : ";
				$v += $$e;
			}else{
				$v += $e;
			}
		}
	}
	#print " sum = ". $v."\n";
	return $v;
}

#! /bin/perl
use Fcntl qw(:DEFAULT :flock);

if($#ARGV < 3){
print "usage: startTestPhase.pl testList destDir outputList goScript [-C]\n";
print "call goScript on each file inkml of the testList and put output file in destDir loging associations in outputList, -C option = continue, ie skip existing results\n";
exit;
}
$testList = $ARGV[0];
$destDir = $ARGV[1];
$outputList = $ARGV[2];
$goScript = $ARGV[3];
$continue = 0;
if($#ARGV == 4 && $ARGV[4] eq "-C"){
	$continue = 1;
}
print "test of $goScript\n";
unless(-d $destDir){
	die "The directory $destDir does not exist !\n";
}
unless(-e $testList){
	die "The file list $testList does not exist !\n";
}
unless(-e $goScript){
	die "The script $goScript does not exist !\n";
}
open(LIST,"<",$testList);
open(COUPLELIST,">",$outputList);
while(<LIST>){
	$f = $_;
	chomp($f);
	if(not($f =~ /^%/)){ #skip comment line
		$f =~ /([a-zA-Z0-9_-]*\.inkml)/;
		$of = $1;
		if($of eq ""){
			die " !! >>>  Bad name file format : $f\n";
		}
		$of = $destDir."/res_".$of;
		$isLocked = 0;
		if($continue and -e $of){
			print "skiping $f\n";
		}else{
			$delete = 0;
			open(SEM, "> $of.lock"); 
			if(flock(SEM, LOCK_EX | LOCK_NB)){
				print "$goScript $f $of\n";
				print `$goScript $f $of`;
				$delete = 1;
			}else{
				print "$f is already under progress\n";
				$isLocked = 1;
			}
			close(SEM);
			if($delete){
				unlink("$of.lock");
			}
		}
		unless(-e $of || $isLocked){
			print " !! >>>  fail to create $of\n";
		}
		print COUPLELIST "$f, $of\n";
	}
}
close(LIST);
close(COUPLELIST);


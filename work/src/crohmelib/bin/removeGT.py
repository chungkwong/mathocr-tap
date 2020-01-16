################################################################
# removeGT.py
#
# Program that reads in inkml ground-truthed files and generate 
# inkml without ground-truth.
#
#
# Author: H. Mouchere, May 2016
# Copyright (c) 2016, Harold Mouchere
################################################################
import sys
from inkml import *
import itertools


	
def main():
	if len(sys.argv) < 3:
		print("Usage: [[python]] removeGT.py <file.inkml> <out.inkml> [SEG] ")
		print("")
		print("Remove the ground-truth from <file.inkml>  and saved to file named <out.inkml>")
		print(" option SEG keeps the segmentation information")
		sys.exit(0)
	withSeg = False
	#print str(len(sys.argv))+ sys.argv[4]
	if("SEG" in sys.argv):
		withSeg = True
	fname = sys.argv[1]
	try:
		fink = Inkml(fname.strip())
		fink.getInkMLwithoutGT(withSeg, sys.argv[2].strip())
	except IOError:
		print "Can not open " + fname.strip()
	except ET.ParseError as ex:
		print "Inkml Parse error " + fname.strip() + " line/col: " + str(ex.position)
	

main()
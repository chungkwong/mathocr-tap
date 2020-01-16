################################################################
# segGenerator.py
#
# Program that reads in inkml ground-truthed files and generate 
# right or wrong segmented symbols.
#
#
# Author: H. Mouchere, Feb. 2014
# Copyright (c) 2014, Harold Mouchere
################################################################
import sys
from inkml import *
import random 
import itertools

def generateRightSeg(ink, segName, k = 0):
	"""generate all one inkml file per symbol. Return the number of generated files."""
	#print "size seg ="+str(len(ink.segments.values()))
	outputGTfile = open(segName+"_GT.txt",'a')
	for seg in ink.segments.values():
		symb = Inkml()
		symb.UI = ink.UI + "_" + str(k)
		#symb.truth = seg.label
		lab = seg.label
		if(lab == ","):
			lab = "COMMA"
		outputGTfile.write(symb.UI + ","+ lab+"\n")
		for s in seg.strId:
			symb.strokes[s] = ink.strokes[s]
		symb.segments["0"] = seg
		symb.segments["0"].id = "0"
		symb.segments["0"].label = ""
		symb.getInkML(segName + str(k)+ ".inkml")
		k+=1
	outputGTfile.close()
	return k

def generateWrongSeg(ink, segName, nb = -1, nbStrkMax=4, k = 0):
	"""generate nb wrong segmentation from the ink. If nb=-1, it will generate all wrong seg.
	nbStrkMax is the maximum size of the generated hypothesis
	Hypothesis are generated with continuous index in the ink file (no time jump)"""
	nbs =  len(ink.strokes)
	StrokesList = range(nbs)
	AllHypMatrix=[]
	if (nbStrkMax > nbs):
		nbStrkMax =nbs
	for itNbMaxOfStrkPerObj in range(nbStrkMax):
		itNbMaxOfStrkPerObj+=1
		# add all possible segments
		#AllHypMatrix.extend(itertools.combinations(StrokesList,itNbMaxOfStrkPerObj))
		#or add only seg without time jump
		for i in StrokesList:
			if i + itNbMaxOfStrkPerObj < nbs:
				r = range(i,i+itNbMaxOfStrkPerObj)
				#get real id of the strokes (strings)
				seg = []
				for s in r:
					seg.append(ink.strkOrder[s])
				#check if it is not a symbol
				#print str(seg)
				if not ink.isRightSeg(set(seg)):
					#print "JUNK"
					AllHypMatrix.append(seg)
	if nb > -1 and nb < len(AllHypMatrix):
		AllHypMatrix = random.sample(AllHypMatrix,nb)
	symb = Inkml()
	#symb.truth = "junk"
	outputGTfile = open(segName+"_GT.txt",'a')
	for hyp in AllHypMatrix:
		symb.UI = ink.UI + "_" + str(k)
		symb.strokes = {}
		for s in hyp:
			symb.strokes[s] = ink.strokes[s]
		symb.segments["0"] = Segment("0","", hyp)
		symb.getInkML(segName + str(k)+ ".inkml")
		outputGTfile.write(symb.UI + ", junk\n")
		k+=1
	outputGTfile.close()
	return k
	
def main():
	if len(sys.argv) < 3:
		print("Usage: [[python]] segGenerator.py <file.inkml> symbol_file_name [JUNK|BOTH [NB]]")
		print("Usage: [[python]] segGenerator.py <list.txt> symbol_file_name [JUNK|BOTH [NB]]")
		print("")
		print("Extract all symbols from <file.inkml> or from the list of inkml <list.txt> and saved to files named:")
		print("symbol_file_name_0.inkml, symbol_file_name_1.inkml, symbol_file_name_2.inkml ...")
		print("if JUNK is set, wrong segmentations are generated (with time consecutive strokes)")
		print("if BOTH is set, both wrong segmentations and symbols are generated")
		print("	   NB is the number of junk generated per inkml file, randomly chosen (default = all) ")
		sys.exit(0)
	n = -1
	genSymb = True
	genJUNK = False
	#print str(len(sys.argv))+ sys.argv[4]
	if("JUNK" in sys.argv):
		genSymb = False
		genJUNK = True
		print "Extract only junks"
	elif("BOTH" in sys.argv):
		genSymb = True
		genJUNK = True
		print "Extract symbols and junks"
	else:
		print "Extract only symbols"
	if genJUNK:
		try:
			n = int(sys.argv[-1])
			print "extract "+str(n)+" junks per expression"
		except ValueError:
			n = -1
			print "extract all of junk per expression\n"
	fileList = []
	if ".inkml" in sys.argv[1]:
		fileList.append(sys.argv[1])
	else:
		fl = open(sys.argv[1])
		fileList = fl.readlines()
		fl.close()
	nb = 0
	for fname in fileList:
		try:
			f = Inkml(fname.strip())
			if genSymb:
				nb = generateRightSeg(f, sys.argv[2],k=nb)
			if genJUNK:
				nb = generateWrongSeg(f,sys.argv[2],n,k=nb)
		except IOError:
			print "Can not open " + fname.strip()
		except ET.ParseError:
			print "Inkml Parse error " + fname.strip()
	
	print str(nb) + " symbols or junks  extracted" 
 

main()
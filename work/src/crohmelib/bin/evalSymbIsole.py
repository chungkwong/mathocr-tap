################################################################
# evalSymbIsole.py
#
# Program that reads in a ground-truthed file and compare it to
# recognized symbol list. One symbol per line.
#
#	Format of ground-truthed file: UI, class
#	MfrDB3907_85801, a
#	MfrDB3907_85802, l
#
#	Format of output files: UI, class list
#	MfrDB3907_85801, a, b, c, d, e, f, g, h, i, j
#	MfrDB3907_85802, 1, |, l, COMMA, junk, x, X, \times
#
#
# Author: H. Mouchere, March 2014
# Copyright (c) 2014, Harold Mouchere
################################################################
import sys
import collections
import csv
import operator

junkKeywords = set(["JUNK","junk"])

#part of sumDiff.py from LGeval

def addOneError(confM, id1, id2):
	#thanks to "defaultdict" there is nothing to do !
	confM[id1][id2] += 1

def affMat(output, allID, confM):
	output.write(" ")
	for k in sorted(allID):
		output.write(",'"+str(k)+"'")
	output.write("\n")
	for k1 in sorted(allID):
		output.write("'"+str(k1)+"'")
		for k2 in sorted(allID):
			output.write(","+str(confM[k1][k2]))
		output.write("\n")

def affMatHTML(output, allID, confM):
	output.write("<table>\n<tr><th></th>")
	sortedId = sorted(allID)
	for k in sortedId:
		output.write("<th>"+str(k)+"</th>")
	output.write("</tr>\n")
	for k1 in sortedId:
		output.write("<tr><th>"+str(k1)+"</th>")
		i = 0
		for k2 in sortedId:
			val = str(confM[k1][k2])
			if val == "0":
				val = ""
			output.write('<td class="col_'+str(i)+'">'+val+"</td>")
			i = i+1
		output.write("</tr>\n")
	output.write("</table>\n")

#global counter of graph id...
countGraph = 0
def affTopNHTML(output, topNList,nbSamples):
	output.write("<table>\n<tr>")
	for k in range(0,len(topNList)-1):
		output.write("<th>"+str(k+1)+"</th>")
	output.write("<th>never</th></tr><tr>")
	for v in topNList:
		output.write("<td>"+str(v)+"</td>")
	output.write("</tr><tr>")
	cumul = 0
	for v in topNList:
		output.write("<td>"+"{:.2f}".format(100.0*(v+cumul)/nbSamples)+"</td>")
		cumul += v
	output.write("</tr></table>")
	global countGraph
	countGraph+=1
	output.write('<canvas id="topncanvas'+str(countGraph)+'" width=112 height="100" style="border:1px solid black"> </canvas>\n')
	output.write('<script> \nvar c = document.getElementById("topncanvas'+str(countGraph)+'");var ctx = c.getContext("2d");ctx.fillStyle ="#FF0000"; \n')
	cumul = 0
	for k in range(0,len(topNList)):
		tx = 100.0*(topNList[k]+cumul)/nbSamples
		output.write("ctx.fillRect("+str(k*10+2)+","+str(100-tx)+",4,"+str(tx)+")"+"\n")
		cumul += topNList[k]
	output.write('</script>\n')

def affTopNMat(output, tabMatConf, nbSymbPerClass):
	output.write("<table>\n<tr><th>lab</th>")
	for k in range(0,len(tabMatConf)):
		output.write("<th>"+str(k+1)+"</th>")
	output.write("</tr>\n")
	for lab in sorted(tabMatConf[0].keys()):
		nb = max(1,nbSymbPerClass[lab])
		output.write("<tr><th>"+lab+"(#"+str(nb)+")"+"</th>")
		cumul = 0;
		for k in range(0,len(tabMatConf)):
			cumul += tabMatConf[k][lab][lab]
			output.write("<td>"+"{:.2f}".format(100.0*cumul/nb)+"</td>")
		output.write("</tr>\n")
	output.write("</table>")

def sumDiag(tabMatConf):
	s = 0
	for lab,tab in tabMatConf.items():
		s += tab[lab]
	return s

def mergeSymbMat(MatConf, symbSet,newLab):
	newMat = collections.defaultdict(collections.defaultdict(int).copy)
	for lgt,tab in MatConf.items():
		if(lgt in symbSet):
			lgt = newLab
		for r,v in tab.items():
			if(r in symbSet):
				r = newLab
			#print lgt + " " + r + "<br>"
			newMat[lgt][r]+=v
	return newMat
	
def affRejectMat(output, MatConfTop1, nbSymbPerClass):
	def strRate(N,D):
		_D = max(1,D)
		return (str(N) + "/" + str(D) +"<br/>" + "{:.2f}".format(float(N)/_D*100)+"%")
	output.write("<table>\n<tr><td></td><th>Accepted</th><th>Rejected</th></tr>\n")
	nbS = sum(nbSymbPerClass.values()) - nbSymbPerClass["JUNK"] 
	allSymb = set(MatConfTop1.keys())
	allSymb.add("JUNK") # be sure that there is a JUNK class
	allSymb.remove("JUNK") # remove it to obtain only the symbols
	mergedMat = mergeSymbMat(MatConfTop1,allSymb,"SYMBOLS")
	output.write("<tr><th>Symbols</th>")
	output.write("<td>TAR<br/>"+strRate(mergedMat["SYMBOLS"]["SYMBOLS"],nbS)+"</td>")
	output.write("<td>FRR<br/>"+strRate(mergedMat["SYMBOLS"]["JUNK"],nbS)+"</td>")
	output.write("</tr>\n")
	output.write("<tr><th>Junk</th>")
	output.write( "<td>FAR<br/>"+strRate(mergedMat["JUNK"]["SYMBOLS"],nbSymbPerClass["JUNK"])+"</td>")
	output.write( "<td>TRR<br/>"+strRate(mergedMat["JUNK"]["JUNK"],nbSymbPerClass["JUNK"])+"</td>")
	output.write("</tr>\n")
	output.write("</table>")

def affRecoRatesInAccepted(output, MatConfTop1):
	output.write("not implemented...")
	
def writeCSS(output, allID):
	output.write('<head><style type="text/css">\n')
	output.write('table{border-collapse:collapse;}\n')
	output.write('table, td{border: 1px solid lightgray;}\n')
	output.write('th{border: 2px solid black;}\n')
	output.write('h2 {	color: red;}\n')
	output.write('tr:hover{background-color:rgb(100,100,255);}\n ')
	#i = 0
	#for k1 in sorted(allID):
	#	output.write('td.col_'+str(i)+':hover {\nbackground-color:rgb(100,100,255);\n}\n')
	#	i = i+1
	output.write('td:hover{background-color:yellow;} \n')
	output.write('</style></head>\n')



def readGT(fileName):
	try:
		fileReader = csv.reader(open(fileName))
	except:
		sys.stderr.write('  !! IO Error (cannot open): ' + fileName)
		sys.exit(0)
	GT = {};
	nbSymb = collections.defaultdict(int)
	#sys.stdout.write("Loading GT\n")
	#nb = 0
	for row in fileReader:
		# Skip blank lines.
		if len(row) == 0:
			continue
		# skip comments
		if row[0][0] == '#' or row[0][0] == '%':
			continue
		# detect pb of format
		if len(row) != 2:
			sys.stderr.write('  !! File format error in ' + fileName + ' not 2 elements per line: '+ str(len(row)))
			sys.exit(0)
		#print row
		UI = row[0].strip()
		lab = row[1].strip()
		if lab in junkKeywords:
			lab = "JUNK"
		if UI in GT:
			sys.stderr.write(UI + ' already has a label ! (overwritten)')
		GT[UI] = lab
		nbSymb[lab]+=1
		#nb+=1
		#if nb % 1000 == 0:
		#	sys.stderr.write(str(nb)+"\r")
	return (GT,nbSymb)

	
def itResult(fileName):
	try:
		fileReader = csv.reader(open(fileName))
	except:
		sys.stderr.write('  !! IO Error (cannot open): ' + fileName)
		sys.exit(0)
	for row in fileReader:
		# Skip blank lines.
		if len(row) == 0:
			continue
		# skip comments
		if row[0][0] == '#':
			continue
		if row[0].strip() == "scores":
			continue
		# detect pb of format
		if len(row) < 2:
			sys.stderr.write('  !! File format error in ' + fileName + ' less than 2 elements per line: '+ str(len(row))+"\n")
			sys.exit(0)
		#print row
		UI = row.pop(0).strip()
		def applyStrip(s):
			s = s.strip()
			if s in junkKeywords:
				return "JUNK"
			return s
		lab = map(applyStrip, row)
		
		yield (UI,lab)

def main():
	# Read data from CSV file.
	if len(sys.argv) < 3:
		print("usage : [[python]] evalSymbIsole.py ground-truth.txt reco_result.txt [HTML]\n")
		print("	Merge results for each line in a confusion Matrix")
		print("	ouput in stdout with CSV format")
		print("	[HTML] option changes ouput format to HTML")
		sys.exit(0)
	withHTML = False
	if len(sys.argv) > 3:
		withHTML = True
	(gtlist,nbSymb) = readGT(sys.argv[1])
	#confusion matrix = dict->dict->int
	allLabel = set()
	labelM = []
	labelMnoJunk = []
	topN = [0]
	topNnoJunk = [0]
	JunkClassUsedAtLeastOnce = False
	for i in range(0,10):
		labelM.append(collections.defaultdict(collections.defaultdict(int).copy))
		labelMnoJunk.append(collections.defaultdict(collections.defaultdict(int).copy))
		topN.append(0)
		topNnoJunk.append(0)
	for (UI,lab) in itResult(sys.argv[2]):
		ok = False
		if UI in gtlist:
			gtlab = gtlist[UI]
		else:
			sys.stderr.write("Problem in " + sys.argv[2] + ", UI not found in GT :" + UI+" => JUNK\n")
			gtlab = "JUNK"
		noJunk = 0
		for i in range(0,min(len(lab),10)):
			if (not ok):
			#avoid to count several times the same good answer
				addOneError(labelM[i], gtlab, lab[i])
				if (gtlab == lab[i]):
					ok = True
					topN[i] += 1
				#now, not consider the JUNK class
				if lab[i] == "JUNK":
					noJunk = -1
					JunkClassUsedAtLeastOnce = True
				elif gtlab != "JUNK":				
					addOneError(labelMnoJunk[i+noJunk], gtlab, lab[i])
					if (gtlab == lab[i]):
						topNnoJunk[i+noJunk] +=1
		#never recognized
		if(not ok):
			topN[10] += 1
			if gtlab != "JUNK":
				topNnoJunk[10] += 1
	for i in range(0,10):
		for lab,res in labelM[i].items():
			allLabel.add(lab)
			allLabel = allLabel.union(set(res.keys()))
	nbSymbolAndJunk = sum(nbSymb.values())
	nbJUNK = nbSymb["JUNK"]
	nbTrueSymbol = nbSymbolAndJunk - nbJUNK
	if withHTML:
		sys.stdout.write('<html>')
		writeCSS(sys.stdout, allLabel)
		print ("<h1> Results for "+sys.argv[2]+"</h1>")
		print ("<p>Ground-truth file =" + sys.argv[1] + "</p>")
		if nbSymbolAndJunk == 0:
			sys.stderr.write("Error : no sample in this GT list !\n")
			exit(-1)
		print ("<p>nb samples = "+ str(nbSymbolAndJunk) + " <br> with " + str(nbTrueSymbol) + " symbols and " + str(nbJUNK) + " junks</p>")
		if JunkClassUsedAtLeastOnce:
			print("<p>The tested classifier is able to reject (JUNK)</p>")
		else:
			print("<p>The tested classifier is NOT able to reject (JUNK has been never answered)</p>")
			
		print ("<h2>TOP 10</h2>")
		if JunkClassUsedAtLeastOnce:
			print ("<h3> with Junk </h3> Considering all classes as if JUNK is a normal class")
			affTopNHTML(sys.stdout,topN,nbSymbolAndJunk)
			print ("<p>Mean position = ")
			print(str(sum(map(operator.mul,topN, range(1,12)))/float(nbSymbolAndJunk)) + "</p>")
		print ("<h3> without Junk </h3> Removing all JUNK samples and all JUNK answers in the class lists")
		affTopNHTML(sys.stdout,topNnoJunk,nbTrueSymbol)
		print ("<p>Mean position = ")
		print(str(sum(map(operator.mul,topNnoJunk, range(1,12)))/float(nbTrueSymbol)) + "</p>")

		print ("<h2>Symbol label TOP10 table </h2>")
		if JunkClassUsedAtLeastOnce:
			print ("<h3> with Junk </h3>")
			affTopNMat(sys.stdout, labelM, nbSymb)
		print ("<h3> without Junk </h3>")
		affTopNMat(sys.stdout, labelMnoJunk, nbSymb)
		if JunkClassUsedAtLeastOnce:
			print("<h2>Reject Results</h2>")
			affRejectMat(sys.stdout, labelM[0], nbSymb)
		
		for i in range(0,3):
			print ("<h2>Symbol label confusion matrix TOP "+str(i+1)+"</h2>")
			affMatHTML(sys.stdout, allLabel, labelM[i])
		print ("<h2>Symbol label confusion matrix merging symbols</h2>")
		print ("merge x,X,\\times in CROSS<br/>")
		print ("merge o,O,0 in O<br/>")
		print ("merge p,P in P<br/>")
		mergedMat = mergeSymbMat(labelM[0],set(['x','X','\\times']),"CROSS")
		mergedMat = mergeSymbMat(mergedMat,set(['o','O','0']),"O")
		mergedMat = mergeSymbMat(mergedMat,set(['p','P']),"P")
		affMatHTML(sys.stdout, mergedMat.keys(),mergedMat)
		s = sumDiag(mergedMat)
		if JunkClassUsedAtLeastOnce:
			print("<p> Recognition rate with junks = " + str(s)+ "/" + str(nbSymbolAndJunk) + " = " + "{:.2f}".format(float(s)/nbSymbolAndJunk*100)+"%</p>")
		mergedMat = mergeSymbMat(labelMnoJunk[0],set(['x','X','\\times']),"CROSS")
		mergedMat = mergeSymbMat(mergedMat,set(['o','O','0']),"O")
		mergedMat = mergeSymbMat(mergedMat,set(['p','P']),"P")
		s = sumDiag(mergedMat)
		print("<p> Recognition rate without junks = " + str(s)+ "/" + str(nbTrueSymbol) + " = " + "{:.2f}".format(float(s)/nbTrueSymbol*100)+"%</p>")

		sys.stdout.write('</html>')
	else:
		print(",".join(map(str,range(1,11))) + ",more")
		print(",".join(map(str,topN)))
		print("Mean pos,"+str(sum(map(operator.mul,topN, range(1,11)+[0]))/float(nbSymbolAndJunk)))
		print "top 1 matrix"
		affMat(sys.stdout, allLabel ,labelM[0])
main()
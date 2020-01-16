################################################################
# inkml.py - InkML parsing lib
#
# Author: H. Mouchere, Feb. 2014
# Copyright (c) 2014, Harold Mouchere
################################################################

import xml.etree.ElementTree as ET
class Segment(object):
	"""Class to reprsent a Segment compound of strokes (id) with an id and label."""
	__slots__ = ('id', 'label' ,'strId')
	
	def __init__(self, *args):
		if len(args) == 3:
			self.id = args[0]
			self.label = args[1]
			self.strId = args[2]
		else:
			self.id = "none"
			self.label = ""
			self.strId = set([])
	
class Inkml(object):
	"""Class to represent an INKML file with strokes, segmentation and labels"""
	__slots__ = ('fileName', 'strokes', 'strkOrder','segments','truth','UI');
	
	NS = {'ns': 'http://www.w3.org/2003/InkML', 'xml': 'http://www.w3.org/XML/1998/namespace'}
	
	##################################
	# Constructors (in __init__)
	##################################
	def __init__(self,*args):
		"""can be read from an inkml file (first arg)"""
		self.fileName = None
		self.strokes = {}
		self.strkOrder = []
		self.segments = {}
		self.truth = ""
		self.UI = ""
		if len(args) == 1:
			self.fileName = args[0]
			self.loadFromFile()
	
	def fixNS(self,ns,att):
		"""Build the right tag or element name with namespace"""
		return '{'+Inkml.NS[ns]+'}'+att

	def loadFromFile(self):
		"""load the ink from an inkml file (strokes, segments, labels)"""
		tree = ET.parse(self.fileName)
		# # ET.register_namespace();
		root = tree.getroot()
		for info in root.findall('ns:annotation',namespaces=Inkml.NS):
			if 'type' in info.attrib:
				if info.attrib['type'] == 'truth':
					self.truth = info.text.strip()
				if info.attrib['type'] == 'UI':
					self.UI = info.text.strip()
		for strk in root.findall('ns:trace',namespaces=Inkml.NS):
			self.strokes[strk.attrib['id']] = strk.text.strip()
			self.strkOrder.append(strk.attrib['id'])
		segments = root.find('ns:traceGroup',namespaces=Inkml.NS)
		if segments is None or len(segments) == 0:
			print "No segmentation info"
			return
		for seg in (segments.iterfind('ns:traceGroup',namespaces=Inkml.NS)):
			id = seg.attrib[self.fixNS('xml','id')]
			label = seg.find('ns:annotation',namespaces=Inkml.NS).text
			strkList = set([])
			for t in seg.findall('ns:traceView',namespaces=Inkml.NS):
				strkList.add(t.attrib['traceDataRef'])
			self.segments[id] = Segment(id,label, strkList)
			
	def getInkML(self,file):
		"""write the ink to an inkml file (strokes, segments, labels)"""
		outputfile = open(file,'w')
		outputfile.write("<ink xmlns=\"http://www.w3.org/2003/InkML\">\n<traceFormat>\n<channel name=\"X\" type=\"decimal\"/>\n<channel name=\"Y\" type=\"decimal\"/>\n</traceFormat>")
		outputfile.write("<annotation type=\"truth\">"+self.truth+"</annotation>\n")
		outputfile.write("<annotation type=\"UI\">"+self.UI+"</annotation>\n")
		for (id,s) in self.strokes.items():
			outputfile.write("<trace id=\""+id+"\">\n"+s+"\n</trace>\n")
		outputfile.write("<traceGroup>\n")
		for (id,s) in self.segments.items():
			outputfile.write("\t<traceGroup xml:id=\""+id+"\">\n")
			outputfile.write("\t\t<annotation type=\"truth\">"+s.label+"</annotation>\n")
			for t in s.strId:
				outputfile.write("\t\t<traceView traceDataRef=\""+t+"\"/>\n")
			outputfile.write("\t</traceGroup>\n")
		outputfile.write("</traceGroup>\n</ink>")
		outputfile.close()
	
	def isRightSeg(self, seg):
		"""return true is the set seg is an existing segmentation"""
		for s in self.segments.values():
			if s.strId == seg:
				return True
		return False
	def getInkMLwithoutGT(self,withseg,file):
		"""write the ink to an inkml file (strokes, segments, labels)"""
		outputfile = open(file,'w')
		outputfile.write("<ink xmlns=\"http://www.w3.org/2003/InkML\">\n<traceFormat>\n<channel name=\"X\" type=\"decimal\"/>\n<channel name=\"Y\" type=\"decimal\"/>\n</traceFormat>")
		outputfile.write("<annotation type=\"UI\">"+self.UI+"</annotation>\n")
		for id in sorted(self.strokes.keys(), key=lambda x: float(x)):
			outputfile.write("<trace id=\""+id+"\">\n"+self.strokes[id]+"\n</trace>\n")
		if withseg :
			outputfile.write("<traceGroup>\n")
			for id in sorted(self.segments.keys(), key=lambda x: float(x) if x.isdigit() else x):
				outputfile.write("\t<traceGroup xml:id=\""+id+"\">\n")
				outputfile.write("\t\t<annotation type=\"truth\">"+self.segments[id].label+"</annotation>\n")
				for t in sorted(self.segments[id].strId, key=lambda x: float(x) if x.isdigit() else x):
					outputfile.write("\t\t<traceView traceDataRef=\""+t+"\"/>\n")
				outputfile.write("\t</traceGroup>\n")
			outputfile.write("</traceGroup>")
		outputfile.write("</ink>")
		outputfile.close()	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
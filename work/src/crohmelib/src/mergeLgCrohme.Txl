% DIRTY: this is just a modified copy of "insertMathML.Txl" (RZ)

include "Grammars/CROHME_InkML.Grammar"

define program
	[crohme_inkml_file]
end define

define segment_list
		[num_or_id] ':
	|	[num_or_id] ': [segment_list]
	|	[empty]
end define

define num_or_id
		[number]
	|	[id]
end define

% DEBUG: remove time/additional channels.
rule filterNumberCoordinates
	replace $ [crohme_coordinate]
		X[number] Y[number] _[opt number]
	
	by
		X Y
end rule

rule filterFloatCoordinates
	replace $ [crohme_coordinate]
		X[float] Y[float] _[opt float]
	by
		X Y
end rule



function generateTraceView Primitive[num_or_id]
	replace [repeat stroke_ref]
		R[repeat stroke_ref]

	construct StringLit[stringlit]
		_[quote Primitive]

	construct traceView[stroke_ref]
		'<traceView 'traceDataRef '= StringLit '/>

	by
		R[. traceView]
end function

function extractId Symbol[msymbol]
	replace [crohme_symbol]
		_[crohme_symbol]

	deconstruct * [crohme_value] Symbol
		V[crohme_value]

	by
		V
end function

function extractFn Symbol[msymbol]
	replace [crohme_symbol]
		_[crohme_symbol]

	deconstruct * [crohme_function] Symbol
		V[crohme_function]

	by
		V
end function

function extractNumber Symbol[msymbol]
	replace [crohme_symbol]
		_[crohme_symbol]

	deconstruct * [crohme_digit] Symbol
		V[crohme_digit]

	by
		V
end function

function extractOperator Symbol[msymbol]
	replace [crohme_symbol]
		_[crohme_symbol]

	deconstruct * [crohme_op] Symbol
		V[crohme_op]

	by
		V
end function


function generateSegment Symbol[msymbol]
	replace [repeat labeled_segment]
		R[repeat labeled_segment]

	% Recover the primitive set, generate
	% list of strokes.
	deconstruct * [stringlit] Symbol
		segString[stringlit]

	construct SegmentList[segment_list]
		_[parse segString]

	construct Primitives[repeat num_or_id]
		_[^ SegmentList]

	construct traceList[repeat stroke_ref]
		_[generateTraceView each Primitives]

	% Identify the symbol label.
	construct Dud[crohme_symbol]
		'ERROR
	
	construct idValue[crohme_symbol]
		Dud[extractId Symbol]
			[extractFn Symbol]
			[extractNumber Symbol]
			[extractOperator Symbol]
			[extractParen Symbol]
	
	construct Idx[xml_id]
		'xml:id '= segString

	construct NewSegment[labeled_segment]
		'<traceGroup Idx '>
			'<annotation type="truth"> idValue '</annotation>
			traceList
			'<annotationXML href= segString '/>
		'</traceGroup>

	by
		R[. NewSegment]
end function

function extractFrac Structure[mstructure]
	replace [crohme_symbol]
		_[crohme_symbol]

	deconstruct Structure
		_[mlfrac]

	by
		'-
end function

function extractRoot Structure[mstructure]
	replace [crohme_symbol]
		_[crohme_symbol]

	deconstruct Structure
		_[mlroot]

	by
		'\sqrt
end function

function extractParen Symbol[msymbol]
	replace [crohme_symbol]
		_[crohme_symbol]

	deconstruct * [crohme_paren] Symbol
		V[crohme_paren]

	by
		V
end function




function generateStructureSegment Structure[mstructure]
	replace [repeat labeled_segment]
		R[repeat labeled_segment]

	% Recover the primitive set, generate
	% list of strokes.
	deconstruct * [stringlit] Structure
		segString[stringlit]

	construct SegmentList[segment_list]
		_[parse segString]

	construct Primitives[repeat num_or_id]
		_[^ SegmentList]

	construct traceList[repeat stroke_ref]
		_[generateTraceView each Primitives]

	% Identify the symbol label.
	construct Dud[crohme_symbol]
		'ERROR
	
	construct idValue[crohme_symbol]
		Dud[extractFrac Structure]
			[extractRoot Structure]

	where not
		idValue[= Dud]

	construct NewSegment[labeled_segment]
		'<traceGroup xml:id= segString>
			<annotation type="truth"> idValue '</annotation>
			traceList
			<annotationXML href= segString '/>
		'</traceGroup>

	by
		R[. NewSegment]
end function

rule sortSegments
	replace [repeat labeled_segment]
		T1[labeled_segment] T2[labeled_segment] Rest[repeat labeled_segment]

	deconstruct * [stringlit] T1
		L1[stringlit]

	deconstruct * [stringlit] T2
		L2[stringlit]

	where 
		L2[< L1]

	by
		T2 T1 Rest
end rule

%%% DEBUG: crohme2lg.pl script currently fails if
%%% there is a "<traceFormat> ... </traceFormat>" section.
rule removeTraceFormat
	replace [repeat annotation_entry]
		'<traceFormat> 
			<channel name=_[stringlit] type=_[stringlit] /> 
			'<channel name=_[stringlit] type=_[stringlit] />
		 '</traceFormat>  
		 R[repeat annotation_entry]
	by
		R

end rule


function main
	replace [program]
		_[opt xml_header_tag]
		'<ink xmlns="http://www.w3.org/2003/InkML"> 
		A[repeat annotation_entry]
		_[opt crohme_mathEncoding]
		R[repeat stroke]
		_[opt segment_data]
		'</ink>

	construct NormalizedStrokes[repeat stroke]
		R[filterNumberCoordinates]
		 [filterFloatCoordinates]

	import TXLargs[repeat stringlit]
	import TXLinput[stringlit]
	deconstruct TXLargs
		mathMLFile[stringlit] _[repeat stringlit]

	construct IdX[xml_id]
		'xml:id = "*auto*"

	construct Dud[mexpression]
		'<mi IdX>ERROR'</mi>

	construct MathML[mexpression]
		Dud[read mathMLFile]

	construct Symbols[repeat msymbol]
		_[^ MathML]% [print][breakpoint]

	construct Segments[repeat labeled_segment]
		_[generateSegment each Symbols]

	construct Structures[repeat mstructure]
		_[^ MathML] %[print][breakpoint]

	construct StructureSegments[repeat labeled_segment]
		_[generateStructureSegment each Structures]

	by
		'<ink xmlns="http://www.w3.org/2003/InkML"> 
		A[removeTraceFormat]
		<annotationXML type="truth" encoding="Content-MathML">
		'<math xmlns="http://www.w3.org/1998/Math/MathML">
		MathML
		'</math>
		'</annotationXML>

		NormalizedStrokes

		'<traceGroup xml:id="-- Segmentation Data --">
			'<annotation type="truth">Segmentation'</annotation>
			Segments[. StructureSegments][sortSegments]
		'</traceGroup>

		'</ink>
end function

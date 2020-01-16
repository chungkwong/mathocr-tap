%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% mathbrush2CROHMEInput.Txl
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Revision History
% v 1.0.0 Original Version: Richard Zanibbi, Feb 13 2013 22:25:19
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

include "Grammars/MathBrushSCG.Grammar"
include "Grammars/CROHME_InkML.Grammar"

define program
		[SCG_Ink_File]
	|	[crohme_inkml_file]
end define

function addCoordToList Coordinate[coordinate]
	replace [list crohme_coordinate]
		L[list crohme_coordinate]

	deconstruct Coordinate
		X[number] Y[number] _[newline]

	construct NewList[list crohme_coordinate]
		X Y
	by
		L[, NewList]
end function

function convertStrokes MathbrushStrokes[repeat stroke_data] Id[number]
	replace [repeat stroke]
		Strokes[repeat stroke]

	construct NumberStrokes[number]
		_[length MathbrushStrokes]

	where
		NumberStrokes[> 0]

	deconstruct MathbrushStrokes
		Points[number] _[newline]
		C[repeat coordinate] 
		Rest[repeat stroke_data]

	construct IdString[stringlit]
		_[quote Id]

	construct CoordList[list crohme_coordinate]
		_[addCoordToList each C]

	construct NewStroke[stroke]
		'<trace 'id'= IdString '>
			CoordList
		'</trace>
	
	construct NextId[number]
		Id[+ 1]

	by
		Strokes[. NewStroke][convertStrokes Rest NextId]
end function

function main
	replace [program]
		S[SCG_Ink_File]

	deconstruct S
		SCG_INK  _[newline]
		_[stroke_count] _[newline]
		Strokes[repeat stroke_data]

		_[repeat newline]
		'ANNOTATIONS _[newline]
		_[repeat mb_annotation]
		_[opt operator_tree]
	
	import TXLargs[repeat stringlit]
	deconstruct * TXLargs
		FileName[stringlit]

	% Create UI (Unique Identifier) for the expression.
	construct HeaderAnnotations[repeat annotation_entry]
		'<annotation 'type '= "UI" '> FileName '</annotation>

	construct CrohmeStrokes[repeat stroke]
		_[convertStrokes Strokes 0]

	construct CrohmeFile[crohme_inkml_file]
		'<ink xmlns="http://www.w3.org/2003/InkML">
			HeaderAnnotations
			CrohmeStrokes
		</ink>

	by
		CrohmeFile
end function



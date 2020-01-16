%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% mathbrush2lg.Txl
%	- Convert a MathBrush file to a label graph file.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Revision History
% v 1.0.0 Original Version: Richard Zanibbi, Jan 28 2013 20:59:17
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Define symbols separately from file formats.
include "Grammars/MathBrushSCG.Grammar"
include "Grammars/LabelGraph.Grammar"
include "LabelGraphOps.Txl"

define program
 	   [SCG_Ink_File]
	|	[label_graph]
end define


define segment_ids
	[repeat number]
end define

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Symbol (Node) Selection
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function getParentOfType TypeList[repeat mbsymbol_id] Nodes[repeat node_label]
		Edge[edge_label]
	replace [repeat number]
		R[repeat number]

	%construct Below[mbsymbol_id]
	%	'B

	deconstruct Edge
		'E, Parent[number], Child[number], _[mbsymbol_id], _[number]

	% Create a set.
	deconstruct not * [number] R
		Parent

	deconstruct * [node_label] Nodes
		'N, Parent, Symbol[mbsymbol_id], _[number]

	deconstruct * [mbsymbol_id] TypeList
		Symbol

	by
		R[. Parent]
end function

function getChildOfType TypeList[repeat mbsymbol_id] Nodes[repeat node_label]
						Edge[edge_label]
	replace [repeat number]
		R[repeat number]

	%construct Below[mbsymbol_id]
	%	'B

	deconstruct Edge
		'E, Parent[number], Child[number], _[mbsymbol_id], _[number]

	% Create a set.
	deconstruct not * [number] R
		Child

	deconstruct * [node_label] Nodes
		'N, Child, Symbol[mbsymbol_id], _[number]

	deconstruct * [mbsymbol_id] TypeList
		Symbol

	by
		R[. Child]
end function
 
function getDescendents Edges[repeat edge_label] Node[number]
	replace [repeat number]
		R[repeat number]

	deconstruct not * [number] R
		Node

	construct NodeList[repeat number]
		Node

	construct ChildEdges[repeat edge_label]
		Edges[selectParents NodeList]

	construct Children[repeat number]
		_[extractChild each ChildEdges]

	by
		R[addIfNotInList Node]
		 [getDescendents Edges each Children]
end function

function addDominatedSymbols BelowEdges[repeat edge_label] 
		JoinedStrokes[repeat number]
		Symbol[number]
	replace [repeat number]
		R[repeat number]

	deconstruct not * [number] R
		Symbol

	deconstruct not * [number] JoinedStrokes
		Symbol

	construct Below[mbsymbol_id]
		'B

	construct AdjacentSymbols[repeat number]
		_[selectSymbolsSharingEdge Symbol each BelowEdges]
	by
		% Inefficient (repeatedly searching on symbol), but concise.
		R[addIfNotInList Symbol]
		 [addDominatedSymbols BelowEdges JoinedStrokes each AdjacentSymbols]
end function

function addSymbolAtRightOf Symbol[number] Edge[edge_label]
	replace [repeat number]
		SymbolList[repeat number]

	construct Right[mbsymbol_id]
		'R

	deconstruct Edge
		'E, Symbol, OtherSymbol[number], Right, _[number]

	by
		SymbolList[. OtherSymbol]
end function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Process R/B edges in MathBrush (convert for CROHME)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function removeRightEdgesForStructures  BelowEdges[repeat edge_label] 
		DominantSymbol[number]
	% NOTE: We need to remove "R" (right-of) relationships for symbols
	% dominated by other operators in a vertical structure, so that we
	% can produce MathML/TeX (i.e. layout tree) output correctly.
	
	replace [label_graph]
		Nodes[repeat node_label]
		SegmentEdges[repeat edge_label]
		Edges[repeat edge_label]

	construct Right[mbsymbol_id]
		'R

	construct RightEdges[repeat edge_label]
		_[appendRelation Right each Edges]

	construct Init[repeat number]
		DominantSymbol

	% Find all symbols in the vertical structure.
	construct JoinedStrokes[repeat number]
		_[addConnectedStroke DominantSymbol each SegmentEdges]

	construct DomAndDominatedSymbols[repeat number]
		_[addDominatedSymbols BelowEdges JoinedStrokes DominantSymbol]

	construct ListLength[number]
		_[length DomAndDominatedSymbols]

	construct DominatedSymbols[repeat number]
		DomAndDominatedSymbols[select 2 ListLength]

	% Find symbols at right of the dominant symbol. We need
	% to remove 'R' edges from dominated symbols to those symbols.
	construct RightOfDominantSymbols[repeat number]
		_[addSymbolAtRightOf DominantSymbol each RightEdges]

	by	
		Nodes
		SegmentEdges
		Edges[removeEdge Right DominatedSymbols each RightOfDominantSymbols]
end function

function max N2[number]
	replace [number]
		N1[number]

	where 
		N2[> N1]
	by
		N2
end function

function getMax
	replace [repeat number]
		N[number] N2[number] R[repeat number]

	construct Select[number]
		N[max N2]

	by
		Select R
end function

function removeFirst 
	replace [repeat number]
		R[repeat number]

	construct ListLength[number]
		_[length R]

	by
		R[select 2 ListLength]
end function

function removeDescendentEdgesToSymbols Relation[mbsymbol_id] Parent[number] 
	% Designed to remove edges along alternative paths, keeping the ancestor.
	% i.e. remove 'closest' edges of a type relative to a object/primitive set.
	replace [label_graph]
		Nodes[repeat node_label]
		Segments[repeat edge_label]
		AllEdges[repeat edge_label] 

	construct Edges[repeat edge_label]
		_[appendRelation Relation each AllEdges]

	construct ParentList[repeat number]
		Parent

	% Get parent edges, and children.
	construct ParentEdges[repeat edge_label]
		Edges[selectParents ParentList]
	
	construct ParentChildList[repeat number]
		_[extractChild each ParentEdges]

	% **Now identify conflicting descendant edges.
	construct ParentAndDescendents[repeat number]
		_[getDescendents AllEdges Parent]

	% HACK! Obtaining last stroke.
	construct LatestStroke[repeat number]
		ParentList[getMax]

	construct Descendents[repeat number]
		ParentAndDescendents[removeFirst]

	construct DescendentEdgeList[repeat edge_label]
		Edges
		  [selectParents Descendents]
		  [selectChildren ParentChildList]

	by
		Nodes
		Segments
		AllEdges[removeEdgeInList DescendentEdgeList]
end function


function removeInherited Edges[repeat edge_label] AllEdges[repeat edge_label]
		Parent[number]
	% Creates a list of inherited edges to remove.
	replace [repeat edge_label]
		RemovalList[repeat edge_label]

	construct ParentList[repeat number]
		Parent 

	% Get parent edges, and children.
	construct ParentEdges[repeat edge_label]
		Edges[selectParents ParentList]
	
	construct ParentChildList[repeat number]
		_[extractChild each ParentEdges]
	
	construct ChildEdges[repeat edge_label]
		Edges[selectParents ParentChildList]

	construct ChildChildList[repeat number]
		_[extractChild each ChildEdges]

	% Create list of edges to remove from those
	% where the child is a child of a child node.
	construct NewRemovals[repeat edge_label]
		ParentEdges[selectEdgeWithChildInList ChildChildList]

	by
		RemovalList[. NewRemovals]
end function

function removeGrandchildEdges Relation[mbsymbol_id]
	replace [label_graph]
		Nodes[repeat node_label]
		SegmentEdges[repeat edge_label]
		Edges[repeat edge_label]

	construct EdgeList[repeat edge_label]
		_[appendRelation Relation each Edges]

	construct Parents[repeat number]
		_[extractParent each EdgeList]

	construct Children[repeat number]
		_[extractChild each EdgeList]

	construct RemoveList[repeat edge_label]
		_[removeInherited EdgeList Edges each Parents]
	by
		Nodes
		SegmentEdges
		Edges[removeEdgeInList RemoveList]
end function

function createAboveEdges DomSymbol[number_pair] BelowEdges[repeat edge_label]
			ChildrenSet[repeat number] ParentSet[repeat number]
			Processed[repeat number]
			SymbolTargets[repeat mbsymbol_id]
	% Mathbrush does not represent "Above" relationships, only "Below,"
	% from the top to bottom of each vertical structure (e.g. fraction,
	% summation, integral, etc.).

	replace [label_graph]
		Nodes[repeat node_label]
		SegmentEdges[repeat edge_label]
		Edges[repeat edge_label]

	construct NumberChildren[number]
		_[length ChildrenSet]

	construct NumberPars[number]
		_[length ParentSet]

	construct Zero[number]	
		0

	where
		Zero[< NumberChildren]
		 	[< NumberPars]

	construct Below[mbsymbol_id]
		'B

	construct Above[mbsymbol_id]
		'A

	deconstruct DomSymbol
		Id[number] _[number]

	construct NewEdges[repeat edge_label]
		Edges[switchEdgeLabel Below Above Processed Id]

	construct NewGraph[label_graph]
		Nodes
		SegmentEdges
		NewEdges

	construct NewChildren[repeat number]
		ChildrenSet[removeNumber Id]

	construct NewParents[repeat number]
		ParentSet[removeNumber Id]

	construct AllRemainingVerticalOps[repeat number]
		ChildrenSet[addIfNotInList each ParentSet]

	construct Init[number_pair]
		1000000 0

	construct NewProcessed[repeat number]
		Processed[. Id]

	construct NewDomSymbol[number_pair]
		Init[selectDominant BelowEdges NewProcessed each AllRemainingVerticalOps]

	by
		NewGraph[createAboveEdges NewDomSymbol BelowEdges 
			NewChildren NewParents NewProcessed SymbolTargets]
end function


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Top-level functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function appendIfDone Matched[repeat edge_label] Remaining[number]
	replace [repeat edge_label]
		R[repeat edge_label]

	where
		Remaining[= 1]

	by
		R[. Matched]
end function

function appendIfComplete Match[repeat edge_label] Remaining[repeat stringlit]
		Candidate[edge_label]
	replace [repeat edge_label]
		R[repeat edge_label]

	deconstruct Remaining

	by
		R[. Match][. Candidate]
end function

function matchCompound Nodes[repeat node_label]
		Edges[repeat edge_label] Target[repeat stringlit]
		Match[repeat edge_label] NewMatch[edge_label]
	replace [repeat edge_label]
		Rest[repeat edge_label]

	% Obtain edges with desired start and end symbols.
	deconstruct Target
		Next[stringlit] Following[stringlit] Remaining[repeat stringlit]

	construct PrevMatch[repeat edge_label]
		Match[. NewMatch]

	construct NextList[repeat node_label]
		Nodes[selectSymbol Next]

	construct NodeIds[repeat number]
		_[appendNodeNumber each NextList]

	construct FollowingList[repeat node_label]
		Nodes[selectSymbol Following]

	construct FollowingIds[repeat number]
		_[appendNodeNumber each FollowingList]

	construct Right[mbsymbol_id]
		'R

	construct CandidateEdges[repeat edge_label]
		_[appendRelation Right each Edges]
		 [selectParents NodeIds]
		 [selectChildren FollowingIds]

	construct NextTarget[repeat stringlit]
		Following Remaining

	by
		% Base case (full match): append, otherwise continue searching
		% recursively for a match.
		Rest[appendIfComplete PrevMatch Remaining each CandidateEdges]
			[matchCompound Nodes Edges NextTarget PrevMatch 
				each CandidateEdges]
			
end function

function replaceCompound Symbols[repeat stringlit]
	replace [label_graph]
		Nodes[repeat node_label]
		Segments[repeat edge_label]
		Edges[repeat edge_label]

	deconstruct Symbols
		First[stringlit] Rest[repeat stringlit]

	% Obtain edge list with first symbol as parent
	% in 'R' (right-of) relationship.
	construct FirstList[repeat node_label]
		Nodes[selectSymbol First]

	construct NodeIds[repeat number]
		_[appendNodeNumber each FirstList]

	construct Right[mbsymbol_id]
		'R

	construct CandidateEdges[repeat edge_label]
		_[appendRelation Right each Edges]
		 [selectParents NodeIds]

	construct compoundName[stringlit]
		_[+ each Symbols]

	construct ERROR[id]
		'error

	construct idToken[id]
		ERROR[unquote compoundName]

	construct compoundId[mbsymbol_id]
		idToken

	construct Empty[repeat edge_label]

	construct Matches[repeat edge_label]
		_[matchCompound Nodes Edges Rest Empty each CandidateEdges]
	
	construct SegmentList[repeat segment_ids]
		_[createSegments each Matches]

	by
		Nodes[relabelCompoundNode compoundId each Matches]
		Segments[addSegmentFromList each SegmentList] % Merge primitives.
		Edges[removeEdgesForSegment each SegmentList]   
			% Remove at-right rel's for segments.
		    [shareObjectRelationships each SegmentList] 
end function



function replaceCompoundTokens
	replace [label_graph]
		L[label_graph]

	% Compounds for CROHME 2013
	construct cos[repeat stringlit]
		"c" "o" "s"

	construct sin[repeat stringlit]
		"s" "i" "n"

	construct tan[repeat stringlit]
		"t" "a" "n"

	construct lim[repeat stringlit]
		"l" "i" "m"

	construct log[repeat stringlit]
		"l" "o" "g"

	by
		L[replaceCompound cos]
		 [replaceCompound sin]
		 [replaceCompound tan]
		 [replaceCompound lim]
		 [replaceCompound log]
end function

function createLabelGraph Ink[SCG_Ink_File]
    replace [label_graph]
        G[label_graph]

    construct SymbolLabels[repeat symbol_label]
        _[^ Ink]

    construct EdgeLabels[repeat relationship_label]
        _[^ Ink]


	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Symbols
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	construct RawComma[mbsymbol_id]
		',

	construct NormedComma[mbsymbol_id]
		'COMMA

	construct MBLine[mbsymbol_id]
		'horzline
	construct CRLine[mbsymbol_id]
		'-

	construct MBSigma[mbsymbol_id]
		'Sigma
	construct CRSigma[mbsymbol_id]
		'\sum

	construct MBIntegral[mbsymbol_id]
		'Integral
	construct CRIntegral[mbsymbol_id]
		'\int

    construct LabelGraphNodes[repeat node_label]
        _[mapSymbolLabel each SymbolLabels]
		 [replaceSymbol RawComma NormedComma]
		 [replaceSymbol MBLine CRLine]
		 [replaceSymbol MBSigma CRSigma]
		 [replaceSymbol MBIntegral CRIntegral]

    construct SegmentEdges[repeat edge_label]
        _[mapSegments each SymbolLabels]

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Relationships
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	construct MBContains[repeat mbsymbol_id]
		'Cs 'C

	construct CRContains[repeat mbsymbol_id]
		'I 'I

	construct MBSuper[mbsymbol_id]
		'AR
	construct CRSuper[mbsymbol_id]
		'SUP

	construct MBSub[mbsymbol_id]
		'BR
	construct CRSub[mbsymbol_id]
		'SUB

    construct RelationEdges[repeat edge_label]
        _[mapEdgeLabel each EdgeLabels]
		 [replaceSymbol each MBContains CRContains]
		 [replaceSymbol MBSuper CRSuper]
		 [replaceSymbol MBSub CRSub]

	construct LabelGraph[label_graph]
		LabelGraphNodes
		SegmentEdges
		RelationEdges

    by
		LabelGraph
end function

function contains T[number]
	match * [number]
		T
end function

rule replaceRelation Nodes[repeat number] Relations[repeat mbsymbol_id]
		Replacement[mbsymbol_id]
	replace $ [edge_label]
		'E, N1[number], N2[number], R[mbsymbol_id], Conf[number]

	where
		Nodes[contains N1]
		     [contains N2]

	deconstruct * [mbsymbol_id] Relations
		R

	by
		'E, N1, N2, Replacement, Conf
end rule

function replaceDotEdges
	replace [label_graph]
		Nodes[repeat node_label]
		Segments[repeat edge_label]
		Edges[repeat edge_label]

	construct Dots[repeat node_label]
		Nodes[selectSymbol "dot"]

	construct NodeIds[repeat number]
		_[appendNodeNumber each Dots]

	construct Relations[repeat mbsymbol_id]
		'SUB 'SUP

	construct Replacement[mbsymbol_id]
		'R

	by
		Nodes
		Segments
		Edges[replaceRelation NodeIds Relations Replacement]
end function

rule removeContained ContainedList[repeat number] RootOutsideChildList[repeat number]
	replace [repeat edge_label]
		'E, P[number], C[number], _[mbsymbol_id], _[number]
		R[repeat edge_label]

	deconstruct * [number] ContainedList	
		P

	deconstruct * [number] RootOutsideChildList
		C

	by 
		R
end rule

function removeContainedEdges RootNode[number]
	replace [repeat edge_label]
		E[repeat edge_label]

	construct RootList[repeat number]
		RootNode

	construct RootEdges[repeat edge_label]
		E[selectParents RootList]

	construct AllChildren[repeat number]
		_[extractChild each RootEdges]

	construct Contains[mbsymbol_id]
		'I   

	construct ContainsEdges[repeat edge_label]
		_[appendRelation Contains each RootEdges]

	construct ChildNodes[repeat number]
		_[extractChild each ContainsEdges]

	construct OutsideRootNode[repeat number]
		AllChildren[removeNumber each ChildNodes]

	by
		E[removeContained ChildNodes OutsideRootNode]
end function

function removeContainedRelationships
	replace [label_graph]
		Nodes[repeat node_label]
		Segments[repeat edge_label]
		Edges[repeat edge_label]

	construct SymbolTargets[repeat mbsymbol_id]
		'sqrt 'Sqrt 'root 'Root

	construct SqrtNodes[repeat number]
		_[getParentOfType SymbolTargets Nodes each Edges]

	by
		Nodes
		Segments
		Edges[removeContainedEdges each SqrtNodes]
end function


function main
    replace [program]
        MathBrushInk[SCG_Ink_File]

    construct LG[label_graph]
        _[createLabelGraph MathBrushInk]

	deconstruct LG
		Nodes[repeat node_label]
		SegmentsEdges[repeat edge_label]
		Edges[repeat edge_label]


	% Additional work is needed to convert the top-to-bottom
	% ordering of vertical structures in MathBrush to the form
	% used for generating mathML (a format similar to LaTeX, where the dominating
	% operator is taken as the root of the structure, e.g. the horizontal
	% line in a fraction).
	construct Below[mbsymbol_id]
		'B

	construct Right[mbsymbol_id]
		'R

	construct Sub[mbsymbol_id]
		'SUB

	construct Sup[mbsymbol_id]
		'SUP

	construct BelowEdges[repeat edge_label]
		_[appendRelation Below each Edges]

	construct BelowParents[repeat number]
		_[extractParent each BelowEdges]

	construct RightEdges[repeat edge_label]
		_[appendRelation Right each Edges]

	construct RightParents[repeat number]
		_[extractParent each RightEdges]

	construct SubEdges[repeat edge_label]
		_[appendRelation Sub each Edges]

	construct SubParents[repeat number]
		_[extractParent each SubEdges]

	construct SupEdges[repeat edge_label]
		_[appendRelation Sup each Edges]

	construct SupParents[repeat number]
		_[extractParent each SupEdges]

	construct SymbolTargets[repeat mbsymbol_id]
		'sum 'int '- 'Integral 'Sigma '\sum '\int

	construct ChildrenSet[repeat number]
		_[getChildOfType SymbolTargets Nodes each BelowEdges]

	construct ParentSet[repeat number]
		_[getParentOfType SymbolTargets Nodes each BelowEdges]

	construct AllVerticalOps[repeat number]
		ChildrenSet[addIfNotInList each ParentSet]

	construct InitPair[number_pair]
		100000 0

	construct OpBelowEdges[repeat edge_label]
		BelowEdges[selectParents ParentSet]
		  [selectChildren ChildrenSet]

	% NOTE: Currently using this to find 'dominant' symbols - but
	% this is probably not valid in the general case.
	construct TopSymbols[repeat number]
		_[addIfAbove OpBelowEdges ParentSet each ChildrenSet]

	construct EmptyList[repeat number]

	construct DomSymbol[number_pair]
		InitPair[selectDominant BelowEdges EmptyList each AllVerticalOps]
			%[message "Dom"][print]

	construct EmptyNums[repeat number]

    by
		% Remove right edges in dominated symbols, add "Above" edges.
		% Remove alternate paths to symbols, keeping ancestor node edge
		% for each relation type other than Above.
        LG
		  % First, relabel relationships as needed for non-scripted symbol
		  % (e.g. dot), and segment/group tokens comprised of multiple
		  % symbols such as function names.
		  [replaceDotEdges]  % Replace Sub/Sup by R.

		  % Now create Above edges for the MathML translations.
	  	  [createAboveEdges DomSymbol BelowEdges 
				ChildrenSet ParentSet EmptyNums SymbolTargets]

		  % Now that the dominant operator(s) in vertical structures
		  % are defined, remove right edges to adjacent subexpressions
		  % for the non-dominant symbols.]
		  % Then, remove inherited 'right-of' relationships.
		  [removeRightEdgesForStructures BelowEdges each TopSymbols]
		  [removeGrandchildEdges Right]
		  [removeDescendentEdgesToSymbols Right each RightParents]

	  	  % Remove inherited subscript edges (i.e. convert to tree)
		  [removeDescendentEdgesToSymbols Sub each SubParents]
		  %[removeDescendentEdgesToSymbols Sup each SupParents]
		  %[removeGrandchildEdgesToSymbols Sup each SupParents]

		  % Group fraction names, etc.
		  [replaceCompoundTokens]  % Note: this alters segmentation & edges.

		  % Removed contained relationships for symbols inside a square root
		  % (e.g. relationships from contained symbols to an exponent of the root).
		  [removeContainedRelationships]

		  % Sort the edges to make the .lg file readable.
		  [sortEdges]
end function


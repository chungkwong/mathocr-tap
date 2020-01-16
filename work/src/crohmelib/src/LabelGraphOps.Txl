%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% LabelGraphOps.Txl
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Revision History
% v 1.0.0 Original Version: Richard Zanibbi, Feb 17 2013 21:50:33
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

define number_pair
	[number] [number]
end define

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Symbols
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rule selectSymbol Symbol[stringlit]
	replace [repeat node_label]
		'N, Id[number], Label[mbsymbol_id], _[number] R[repeat node_label]

	construct LabelString[stringlit]
		_[quote Label]

	where not
		LabelString[= Symbol]

	by
		R
end rule

function appendNodeNumber Node[node_label]
	replace [repeat number]
		R[repeat number]

	deconstruct Node
		'N, Id[number], _[mbsymbol_id], _[number]

	by
		R[. Id]
end function

function appendNode Symbol[mbsymbol_id] Id[number]
    replace [repeat node_label]
        R[repeat node_label]

    % Use confidence of 1.0.
    construct NewLabel[node_label]
        'N', Id ', Symbol ', 1.0

    by
        R[. NewLabel]
end function

function mapSymbolLabel SymbolLabel[symbol_label]
    replace [repeat node_label]
        R[repeat node_label]

    deconstruct SymbolLabel
        'SYMBOL '< Ids[list number] '> Symbol[mbsymbol_id] _[newline]

    by
        R[appendNode Symbol each Ids]
end function

rule replaceSymbol Target[mbsymbol_id] Replacement[mbsymbol_id]
	% Used for node and edge labels.
	replace $ [mbsymbol_id]
		Target
	by
		Replacement
end rule

rule removeNumber Number[number]
	replace * [repeat number]
		Number R[repeat number]

	by
		R
end rule


function addIfNot Symbol[number] AddSymbol[number]
	replace [repeat number]
		R[repeat number]

	where not
		Symbol[= AddSymbol]

	by
		R[. AddSymbol]
end function

function addIfNotInList AddSymbol[number]
	replace [repeat number]
		R[repeat number]

	deconstruct not * [number] R
		AddSymbol

	by
		R[. AddSymbol]
end function


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Segments (i.e. stroke groupings for symbols)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mapSegments SymbolLabel[symbol_label]
	replace [repeat edge_label]
		R[repeat edge_label]

	deconstruct SymbolLabel
        'SYMBOL '< Ids[list number] '> Symbol[mbsymbol_id] _[newline]

	construct SegRelationship[mbsymbol_id]
		'*

	by
		R[appendEdgeList SegRelationship Ids each Ids]
end function


function addConnectedStroke Symbol[number] Edge[edge_label]
	replace [repeat number]
		R[repeat number]

	construct Join[mbsymbol_id]
		'*

	deconstruct Edge
		'E, Symbol, Other[number], Join, _[number]
	
	by
		R[. Other]
end function

rule relabelCompoundNode Id[mbsymbol_id] Edge[edge_label]
	replace $ [node_label]
		'N, IdNumber[number], _[mbsymbol_id], Conf[number]

	deconstruct Edge
		'E, P[number], C[number], _[mbsymbol_id], _[number]

	where
		IdNumber[= P][= C]

	by
		'N, IdNumber, Id, Conf
end rule

function addSegmentEdge Ids[repeat number] Next[number]
	replace [repeat edge_label]
		R[repeat edge_label]

	construct SegmentLabel[mbsymbol_id]
		'*

	construct NewSegmentEdges[repeat edge_label]
		_[createEdge SegmentLabel Next each Ids]

	by
		R[. NewSegmentEdges]
end function

function removeEdgesForSegment Segment[segment_ids]
	replace [repeat edge_label]
		S[repeat edge_label]

	deconstruct Segment
		Ids[repeat number]

	by
		S[removeEdgesBetween Ids]
end function

function insertIfNew Edge[edge_label]
	replace [repeat edge_label]
		R[repeat edge_label]

	deconstruct not * [edge_label] R
		Edge
	by
		R[. Edge]
end function

function addSegmentFromList Segment[segment_ids]
	replace [repeat edge_label]
		R[repeat edge_label]
	
	deconstruct * [repeat number] Segment
		Ids[repeat number]

	construct NewSegments[repeat edge_label]
		_[addSegmentEdge Ids each Ids]

	by
		R[insertIfNew each NewSegments]
end function

function insertNodeInSegment P[number] C[number]
	replace * [segment_ids]
		R[repeat number]

	where
		R[containsNumber P]
		 [containsNumber C]

	by
		R[addIfNotInList C]
		 [addIfNotInList P]
end function

function containsNumber N[number]
	match * [number]
		N
end function

function removeSegment S[segment_ids]
	replace [repeat segment_ids]
		S R[repeat segment_ids]

	by
		R
end function

rule mergeSegments P[number] C[number]
	replace [repeat segment_ids]
		R[repeat segment_ids]

	deconstruct * [segment_ids] R
		S1[segment_ids]

	deconstruct * [number] S1
		P

	deconstruct * [segment_ids] R
		S2[segment_ids]

	deconstruct * [number] S1
		C

	where not
		S1[= S2]

	deconstruct S1
		N1[repeat number]

	deconstruct S2
		N2[repeat number]

	construct MergedSegment[segment_ids]
		N1[addIfNotInList each N2]

	by
		R[removeSegment S1]
		 [removeSegment S2]
		 [. MergedSegment]
end rule

function newSegment P[number] C[number]
	replace [repeat segment_ids]
		R[repeat segment_ids]

	where not
		R[containsNumber P]
		 [containsNumber C]

	construct NewSegment[segment_ids]
		P C

	by
		R[. NewSegment]
end function
		

function createSegments Edge[edge_label]
	replace [repeat segment_ids]
		R[repeat segment_ids]
	
	deconstruct Edge
		'E, P[number], C[number], _[mbsymbol_id], _[number]

	by
		R[insertNodeInSegment P C]
		 [newSegment P C]
end function

function shareOutRelation Ids[repeat number] Edge[edge_label]
	replace [repeat edge_label]
		R[repeat edge_label]

	by
		R[insertEdgeWithParent Edge each Ids]
end function

function insertEdgeWithChild Edge[edge_label] C[number]
	replace [repeat edge_label]
		R[repeat edge_label]

	deconstruct Edge
		'E, P[number], _[number], Relation[mbsymbol_id], Conf[number]
	
	construct EdgeForInsertion[edge_label]
		'E, P, C, Relation, Conf

	deconstruct not * [edge_label] R
		EdgeForInsertion

	by
		R[. EdgeForInsertion]
end function


function shareInRelation Ids[repeat number] Edge[edge_label]
	replace [repeat edge_label]
		R[repeat edge_label]

	by
		R[insertEdgeWithChild Edge each Ids]
end function

function shareObjectRelationships  Segment[segment_ids]
	replace [repeat edge_label]
		R[repeat edge_label]

	deconstruct Segment
		Ids[repeat number]

	construct OutgoingEdges[repeat edge_label]
		R[selectParents Ids]

	construct IncomingEdges[repeat edge_label]
		R[selectChildren Ids]

	by
		R[shareOutRelation Ids each OutgoingEdges]
		 [shareInRelation Ids each IncomingEdges]
end function


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Edges
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rule sortEdgeList
	replace [repeat edge_label]
		'E, P1[number], C1[number], R1[mbsymbol_id], N1[number]
		'E, P2[number], C2[number], R2[mbsymbol_id], N2[number]
		R[repeat edge_label]


	where
		P2[< P1]

	by
		'E, P2, C2, R2, N2
		'E, P1, C1, R1, N1
		R
end rule

function sortEdges
	replace [label_graph]
		Nodes[repeat node_label]
		Segments[repeat edge_label]
		Edges[repeat edge_label]

	by
		Nodes
		Segments[sortEdgeList]
		Edges[sortEdgeList]
end function

function createEdge Label[mbsymbol_id] P[number] C[number]
	replace [repeat edge_label]
		R[repeat edge_label]

	where not
		P[= C]

	construct NewEdge[edge_label]
		'E, P, C, Label, 1.0

	by
		R[. NewEdge]
end function

function insertEdgeWithParent Edge[edge_label] P[number]
	replace [repeat edge_label]
		R[repeat edge_label]

	deconstruct Edge
		'E, _[number], C[number], Relation[mbsymbol_id], Conf[number]
	
	construct EdgeForInsertion[edge_label]
		'E, P, C, Relation, Conf

	deconstruct not * [edge_label] R
		EdgeForInsertion

	by
		R[. EdgeForInsertion]
end function


rule removeEdgesBetween Ids[repeat number] 
	% ASSUMPTION: the file is well-formed, with no self-edges.
	replace * [repeat edge_label]
		'E, P[number], C[number], _[mbsymbol_id], _[number]
		R[repeat edge_label]

	deconstruct * [number] Ids
		P
	deconstruct * [number] Ids
		C
	
	by
		R
end rule



rule removeEdgeInList Edges[repeat edge_label]
	replace [repeat edge_label]
		E[edge_label] R[repeat edge_label]

	deconstruct * [edge_label] Edges
		E
	by
		R
end rule

rule removeEdge Relation[mbsymbol_id] Parent[repeat number] Child[number] 
	replace [repeat edge_label]
		Edge[edge_label] R[repeat edge_label]

	deconstruct Edge
		'E, P[number], Child, Relation, _[number]

	deconstruct * [number] Parent
		P
	by
		R
end rule

function edgesContain Child[number] Parent[number]
	match [repeat edge_label]
		Edges[repeat edge_label]

	deconstruct * [edge_label] Edges
		'E, Parent, Child, _[mbsymbol_id], _[number]
end function

function addIfAbove BelowEdges[repeat edge_label] ParentSet[repeat number]
		Child[number]
	replace [repeat number]
		R[repeat number]

	where not
		BelowEdges[edgesContain Child each ParentSet]

	by
		R[. Child]
end function

function selectDominant BelowEdges[repeat edge_label] Processed[repeat number] Next[number]
	replace [number_pair]
		Id[number] Count[number]

	deconstruct not * [number] Processed
		Next
		
	construct NextAsList[repeat number]
		Next

	construct Outgoing[repeat edge_label]
		BelowEdges[selectParents NextAsList]

	construct OutCount[number]
		_[length Outgoing]

	construct Incoming[repeat edge_label]
		BelowEdges[selectChildren NextAsList]

	construct InCount[number]
		_[length Incoming]

	construct CountList[repeat number]
		OutCount InCount

	construct MaxList[repeat number]
		CountList[getMax]

	deconstruct MaxList
		Max[number]

	where
		Max[> Count]

	by
		Next Max
end function

function appendEdge Relationship[mbsymbol_id] Id1[number] Id2[number]
    replace [repeat edge_label]
        R[repeat edge_label]

	% Prevent self-edges (convenience for segment processing; not
	% legal for relationships between symbols)
	where not
		Id1[= Id2]
    % Use confidence of 1.0
    construct NewLabel[edge_label]
        'E', Id1', Id2', Relationship, 1.0

    by
        R[. NewLabel]
end function

function appendEdgeList Relationship[mbsymbol_id] L2[list number] N1[number]
    replace [repeat edge_label]
        R[repeat edge_label]

    deconstruct L2
        Id1[number] ', Rest[list number]

    by
        R[appendEdge Relationship N1 Id1][appendEdgeList Relationship Rest N1]
end function

function appendRelation Relation[mbsymbol_id] Edge[edge_label]
	replace [repeat edge_label]
		R[repeat edge_label]

	deconstruct * [mbsymbol_id] Edge
		Relation

	by
		R[. Edge]
end function

function mapEdgeLabel RelLabel[relationship_label] 
    replace [repeat edge_label]
        R[repeat edge_label]

    deconstruct RelLabel
        'LINK '< L1[list number] '> Relationship[mbsymbol_id] '< L2[list number] '> _[newline]

    by
        R[appendEdgeList Relationship L2 each L1]
end function

rule switchEdgeLabel Target[mbsymbol_id] Replacement[mbsymbol_id] 
		Processed[repeat number] Node[number] 
	replace $ [edge_label]
		'E, OtherNode[number], Node, Target, N[number]

	deconstruct not * [number] Processed
		OtherNode

	by
		'E, Node, OtherNode, Replacement, N
end rule


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parent/Child Operations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function extractParent Edge[edge_label]
	replace [repeat number]
		R[repeat number]

	deconstruct Edge
		'E, Parent[number], _[number], _[mbsymbol_id], _[number]

	by
		R[addIfNotInList Parent]
end function

rule selectParents Parents[repeat number]
	replace [repeat edge_label]
		Edge[edge_label] R[repeat edge_label]

	deconstruct Edge
		'E, P[number], _[number], _[mbsymbol_id], _[number]

	deconstruct not * [number] Parents
		P
	by
		R
end rule

rule removeEdgeWithParents Parents[repeat number]
	replace [repeat edge_label]
		Edge[edge_label] R[repeat edge_label]

	deconstruct Edge
		'E, P[number], _[number], _[mbsymbol_id], _[number]

	deconstruct * [number] Parents
		P
	by
		R
end rule


rule selectChildren Children[repeat number]
	replace [repeat edge_label]
		Edge[edge_label] R[repeat edge_label]

	deconstruct Edge
		'E, _[number], C[number], _[mbsymbol_id], _[number]

	deconstruct not * [number] Children
		C
	by
		R
end rule

function extractChild Edge[edge_label]
	replace [repeat number]
		R[repeat number]

	deconstruct Edge
		'E, _[number], Child[number], _[mbsymbol_id], _[number]

	by
		R[addIfNotInList Child]
end function

rule selectEdgeWithChildInList ChildList[repeat number]
	replace [repeat edge_label]
		'E, _[number], CNum[number], _[mbsymbol_id], _[number]
		R[repeat edge_label]

	deconstruct not * [number] ChildList
		CNum

	by
		R
end rule

function selectSymbolsSharingEdge Symbol[number] Edge[edge_label]
	replace [repeat number]
		R[repeat number]
	
	deconstruct Edge
		'E, Parent[number], Child[number], _[mbsymbol_id],  _[number]

	where
		Symbol[= Parent]
		 [= Child]

	by
		R[addIfNot Symbol Parent]
		 [addIfNot Symbol Child]
end function


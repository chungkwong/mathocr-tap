%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% convGrammar.Txl
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Revision History
% v 1.0.0 Original Version: Richard Zanibbi, Feb 13 2013 22:10:04
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

include "Grammars/CROHME_XML_Grammar.Grammar"

function main
	replace [program]
		P[program]

	construct NewProgram[program]
		P[TextRules]
		 [sortRules]
		 [message "Rules sorted."]
		 [FactorRules]

	construct Rules[repeat prod_rule]
		_[^ NewProgram]

	by
		Rules
end function

function bothTerminals R1[repeat symbol]
	match [repeat symbol]
		R2[repeat symbol]

	deconstruct R1
		T1[terminal]

	deconstruct R2
		T2[terminal]
end function

function isNonterminal 
	match [repeat symbol]
		R2[repeat symbol]

	deconstruct * R2
		N[nonterminal]
end function

rule sortRules
	% Bubblesort.
	replace [repeat prod_rule]
		Rule1[prod_rule]
		Rule2[prod_rule]
		Rest[repeat prod_rule]

	deconstruct Rule1
		LHS1[symbol] '-> R1[repeat symbol]

	deconstruct Rule2
		LHS2[symbol] '-> R2[repeat symbol]

	deconstruct not LHS1
		"S"
	
	deconstruct LHS1
		LS1[stringlit]

	deconstruct LHS2
		LS2[stringlit]

	where 
		LS2[< LS1]
	where
		R2[isNonterminal]
		  [bothTerminals R1]

	by
		LHS2 -> R2
		LHS1 -> R1
		Rest
end rule

rule TextRules
	replace $ [prod_rule]
		'< 'rule 'category '= LHS[stringlit] '>
			RHS[repeat symbol]
		'< '/ 'rule '> 

	construct NewRHS[repeat symbol]
		RHS[replaceRHS]

	by
		LHS '-> NewRHS
end rule

rule replaceNonterminal
	replace $ [nonterminal]
		'< 'category 'name '= SYMBOL[stringlit] '/>
	by
		SYMBOL
end rule

rule replaceTerminal
	replace $ [terminal]
		'< 'category 'terminal '= _[stringlit] 'name '= SYMBOL[stringlit] '/>
	by
		SYMBOL
end rule

rule replaceRHS
	replace $ [repeat symbol]
		RHS[repeat symbol]

	by
		RHS[replaceNonterminal]
		   [replaceTerminal]
end rule

rule FactorRules
	% Assumes rules have been sorted before hand.
	replace $ [repeat prod_rule]
		LHS[stringlit] '-> RHS1[repeat symbol]
		R[repeat prod_rule]

	construct Replacement[repeat prod_rule]
		LHS '-> RHS1
		R[replaceLHS LHS]
	by
		Replacement
end rule


rule replaceLHS LHS[stringlit]
	% This assumes rules are sorted prior to applying the rule.
	replace $ [prod_rule]
		LHS '-> RHS[repeat symbol]

	by
		'| RHS
end rule


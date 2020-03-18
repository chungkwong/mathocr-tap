#!/bin/python

def load_dict(dictFile):
    fp=open(dictFile)
    stuff=fp.readlines()
    fp.close()
    lexicon={}
    for l in stuff:
        w=l.strip().split()
        lexicon[w[0]]=int(w[1])

    print('total words/phones',len(lexicon))
    return lexicon

def loadGrammar(grammarFile,worddicts):
    fp=open(grammarFile)
    lines=fp.readlines()
    fp.close()
    rules={}
    for line in lines:
        w=line.rstrip('\n').split("\t")
        if len(w)>=1:
            if len(w[0])>0:
                target=w[0]
                rules[target]=[]
            children=[]
            for child in w[1:]:
                if child in worddicts :
                    children.append(worddicts[child])
                else:
                    children.append(child)
            rules[target].append(children)
    print('rules',rules)
    return rules

def findStart(rules):
    start={target:set() for target in rules}
    changed=True
    while changed:
        changed=False
        for target,childrens in rules.items():
            starts=start[target]
            collected=len(starts)
            for children in childrens:
                nullable=True
                for child in children:
                    nullable=False
                    if type(child)==str:
                        for s in start[child]:
                            if s=='':
                                nullable=True
                            else:
                                starts.add(s)
                    else:
                        starts.add(child)
                    if not nullable:
                        break
                if nullable:
                    starts.add('')
            if len(starts)>collected:
                changed=True
    print('start',start)
    return start

def findFollow(rules,start):
    follow={target:set() for target in rules}
    follow['start'].add(0)
    changed=True
    while changed:
        changed=False
        for target,childrens in rules.items():
            for children in childrens:
                s=follow[target]
                for child in reversed(children):
                    if type(child)==str:
                        f=follow[child]
                        for t in s:
                            if type(t)!=str and (not t in f):
                                f.add(t)
                                changed=True
                        if '' in start[child]:
                            s=s.union(start[child])
                        else:
                            s=set(start[child])
                    else:
                        s=set([child])
    print('follow',follow)
    return follow

def compileGrammar(rules):
    start=findStart(rules)
    follow=findFollow(rules,start)
    grammar={}
    def addEntry(target,token,rule):
        if (target,token) in grammar:
            print('A conflict found:',target,token,rule,grammar[(target,token)])
        else:
            grammar[(target,token)]=rule
    for target,childrens in rules.items():
        for rev in childrens:
            rev.reverse()
            nullable=True
            for child in reversed(rev):
                if type(child)==str:
                    for s in start[child]:
                        if s!='':
                            addEntry(target,s,rev)
                    if not '' in start[child]:
                        nullable=False
                        break
                else:
                    addEntry(target,child,rev)
                    nullable=False
                    break
            if nullable:
                for f in follow[target]:
                    addEntry(target,f,rev)
    print('grammar',grammar)
    return grammar


def parseStart():
    return [0,'start']

FAILED=[0,'failed']

def parseNext(token,state,grammar):
    while True:
        index=len(state)-1
        if index>=0:
            target=state[index]
            if target==token:
                return state[0:index]
            elif (target,token) in grammar:
                state=list(state[0:index])
                state+=grammar[(target,token)]
            else:
                return FAILED
        else:
            return FAILED

def isParseFailed(state):
    return state==FAILED

def isParseFinished(state):
    return len(state)==0

def parse(seq,grammar,worddicts):
    state=parseStart()
    for token in seq+['<eol>']:
        state=parseNext(worddicts[token],state,grammar)
    return state

def verify(caption,grammar,worddicts):
    fp=open(caption)
    stuff=fp.readlines()
    fp.close()
    passed=0
    total=0
    for l in stuff:
        w=l.strip().split()
        total=total+1
        if isParseFinished(parse(w[1:],grammar,worddicts)):
            passed=passed+1
        else:
            print(l.strip())
    print(passed*1.0/total,'% passed')

if __name__ == "__main__":
    worddicts=load_dict('../data/dictionary.txt')
    grammar=compileGrammar(loadGrammar('../data/grammar.txt',worddicts))
    verify('../data/train/caption.txt',grammar,worddicts)
    verify('../data/valid/caption.txt',grammar,worddicts)
    verify('../data/test/caption.txt',grammar,worddicts)


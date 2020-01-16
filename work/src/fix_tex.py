# -*- coding: utf-8 -*-
"""
Fix mismatched braces
@author: chungkwong

"""
import sys

def fix_tex(tex):
    input=tex.strip("\r\n $").split()
    output=[]
    changed=False
    lv=0
    for token in input:
        if token=='{':
            lv=lv+1
        elif token=='}':
            if lv>0:
                lv=lv-1
            else:
                changed=True
                continue
        output.append(token)
    while lv>0:
        output.append('}')
        changed=True
        lv=lv-1
    return '$'+" ".join(output)+'$',changed

if __name__=='__main__':
   
    '''
    Usage: fix_tex.py file

    '''

    if len(sys.argv) < 1:
        print('usage: fix_tex.py file')
        exit()
    with open(sys.argv[1],"r+") as input_file:
        output,changed=fix_tex(input_file.read())
        if changed:
            input_file.seek(0,0)
            input_file.write(output)
            input_file.truncate()
            print("Fixed "+sys.argv[1])

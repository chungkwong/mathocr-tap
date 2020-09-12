import numpy
import os
import sys
import math

def fopen(filename, mode='r'):
    return open(filename, mode)

def normalize(mat):
    xSum=0
    ySum=0
    xxSum=0
    xxCSum=0
    length=0
    last=None
    for curr in mat:
        if not(last is None):
            len=math.hypot(curr[0]-last[0],curr[1]-last[1])
            xSum+=(last[0]+curr[0])*len
            ySum+=(last[1]+curr[1])*len
            xxSum+=(last[0]*last[0]+curr[0]*curr[0])*len
            xxCSum+=(last[0]*curr[0])*len
            length+=len
        if curr[2]==1:
            last=None
        else:
            last=curr
    if not(length>0):
        length=numpy.max(mat[:,1])-numpy.min(mat[:,1])+1e-7
    centerX=xSum*0.5/length
    centerY=ySum*0.5/length
    variance=math.sqrt(((xxSum+xxCSum)/3+centerX*centerX*length-centerX*xSum)/length)
    if not(variance>0):
        variance=length
    matX=mat[:,0:1]
    matY=mat[:,1:2]
    matX=(matX-centerX)/variance
    matY=(matY-centerY)/variance
    matXY=numpy.hstack([matX,matY])
    matXY1=numpy.vstack([matXY[1:],matXY[-1:]])-matXY
    matXY2=numpy.vstack([matXY[2:],matXY[-2:]])-matXY
    matUp=mat[:,-1:]
    matDown=1-matUp
    return numpy.hstack([matXY,matXY1,matXY2,matDown,matUp])

def loadFeature(feature_path,scp_path):
    features={}
    sentNum=0
    scpFile=open(scp_path)
    while 1:
        line=scpFile.readline().strip() # remove the '\r\n'
        if not line:
            break
        else:
            key = line.split('\t')[0]
            feature_file = os.path.join(feature_path, key + '.ascii')
            mat = normalize(numpy.loadtxt(feature_file))
            sentNum = sentNum + 1
            features[key] = mat
            if sentNum // 500 == sentNum * 1.0 / 500:
                print('process sentences ', sentNum)
    scpFile.close()
    print('load ascii file done. sentence number ',sentNum)
    return features

def loadAlign(feature_path,scp_path,align_path):
    alignment={}
    sentNum=0
    scpFile=open(scp_path)
    while 1:
        line=scpFile.readline().strip() # remove the '\n'
        if not line:
            break
        else:
            key = line.split('\t')[0]
            align_file = os.path.join(align_path, key + '.align')
            with open(align_file) as f_align:
                wordNum = 0
                for align_line in f_align:
                    wordNum += 1
            feature_file = os.path.join(feature_path, key + '.ascii')
            fea = numpy.loadtxt(feature_file)
            align = numpy.zeros([fea.shape[0], wordNum], dtype='int8')
            sentNum = sentNum + 1
            penup_index = numpy.where(fea[:,-1] == 1)[0] # 0 denote pen down, 1 denote pen up
            with open(align_file) as f_align:
                wordNum = -1
                for align_line in f_align:
                    wordNum += 1
                    align_tmp = align_line.split()
                    for i in range(1,len(align_tmp)):
                        pos = int(align_tmp[i])
                        if pos == -1:
                            continue
                        elif pos == 0:
                            align[0:(penup_index[pos]+1), wordNum] = 1
                        else:
                            align[(penup_index[pos-1]+1):(penup_index[pos]+1), wordNum] = 1
            alignment[key] = align
            if sentNum // 500 == sentNum * 1.0 / 500:
                print('process sentences ', sentNum)
    scpFile.close()
    print('load align file done. sentence number ',sentNum)
    return alignment

def dataIterator(base_path,dictionary,batch_size,maxlen):
    feature_path=os.path.join(base_path,"on-ascii")
    label_path=os.path.join(base_path,"caption.txt")
    align_path=os.path.join(base_path,"on-align")
    features=loadFeature(feature_path,label_path)
    fp2=open(label_path,'r')
    labels=fp2.readlines()
    fp2.close()
    aligns=loadAlign(feature_path,label_path,align_path)

    targets={}
    # map word to int with dictionary
    for l in labels:
        tmp=l.strip().split()
        uid=tmp[0]
        w_list=[]
        for w in tmp[1:]:
            if w in dictionary:
                w_list.append(dictionary[w])
            else:
                print('a word not in the dictionary !! sentence ',uid,'word ', w)
                sys.exit()
        targets[uid]=w_list



    sentLen={}
    for uid,fea in features.items():
        sentLen[uid]=len(fea)

    sentLen= sorted(sentLen.items(), key=lambda d:d[1]) # sorted by sentence length,  return a list with each triple element


    feature_batch=[]
    label_batch=[]
    alignment_batch=[]
    feature_total=[]
    label_total=[]
    alignment_total=[]

    i=0
    for uid,length in sentLen:
        fea=features[uid]
        ali=aligns[uid]
        lab=targets[uid]
        if len(lab)>maxlen:
            print('sentence', uid, 'length bigger than', maxlen, 'ignore')
        else:
            if i==batch_size: # a batch is full
                feature_total.append(feature_batch)
                label_total.append(label_batch)
                alignment_total.append(alignment_batch)

                i=0
                feature_batch=[]
                label_batch=[]
                alignment_batch=[]
                feature_batch.append(fea)
                label_batch.append(lab)
                alignment_batch.append(ali)
                i=i+1
            else:
                feature_batch.append(fea)
                label_batch.append(lab)
                alignment_batch.append(ali)
                i=i+1

    # last batch
    feature_total.append(feature_batch)
    label_total.append(label_batch)
    alignment_total.append(alignment_batch)

    print('total ',len(feature_total), 'batch data loaded')

    return list(zip(feature_total,label_total, alignment_total))

def dataIterator_valid(base_path,dictionary,batch_size,maxlen):
    
    feature_path=os.path.join(base_path,"on-ascii")
    label_path=os.path.join(base_path,"caption.txt")
    features=loadFeature(feature_path,label_path)
    fp2=open(label_path,'r')
    labels=fp2.readlines()
    fp2.close()

    targets={}
    # map word to int with dictionary
    for l in labels:
        tmp=l.strip().split()
        uid=tmp[0]
        w_list=[]
        for w in tmp[1:]:
            if w in dictionary:
                w_list.append(dictionary[w])
            else:
                print('a word not in the dictionary !! sentence ',uid,'word ', w)
                sys.exit()
        targets[uid]=w_list



    sentLen={}
    for uid,fea in features.items():
        sentLen[uid]=len(fea)

    sentLen= sorted(sentLen.items(), key=lambda d:d[1]) # sorted by sentence length,  return a list with each triple element


    feature_batch=[]
    label_batch=[]
    feature_total=[]
    label_total=[]
    uidList=[]

    i=0
    for uid,length in sentLen:
        fea=features[uid]
        lab=targets[uid]
        if len(lab)>maxlen:
            print('sentence', uid, 'length bigger than', maxlen, 'ignore')
        else:
            uidList.append(uid)
            if i==batch_size: # a batch is full
                feature_total.append(feature_batch)
                label_total.append(label_batch)

                i=0
                feature_batch=[]
                label_batch=[]
                feature_batch.append(fea)
                label_batch.append(lab)
                i=i+1
            else:
                feature_batch.append(fea)
                label_batch.append(lab)
                i=i+1

    # last batch
    feature_total.append(feature_batch)
    label_total.append(label_batch)

    print('total ',len(feature_total), 'batch data loaded')

    return zip(feature_total,label_total),uidList

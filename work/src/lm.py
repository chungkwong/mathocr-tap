#!/usr/bin/python3

import numpy
import keras
import sys
from grammar import load_dict,compileGrammar,loadGrammar,parse,isParseFinished

MAX_LENGTH=100
EMBEDDING_DIM=64
LSTM_UNITS=128

DICTIONARY_PATH='../data/dictionary.txt'
GRAMMAR_PATH='../data/grammar.txt'
PRETRAIN_PATH='../data/train/caption.txt'
TRAIN_PATH='../data/corpus.txt'
VALID_PATH='../data/valid/caption.txt'
TEST_PATH='../data/test/caption.txt'
MODEL_PATH='../lm/lm.h5'

class FormulaSequence(keras.utils.Sequence):
    def __init__(self, formulas, batch_size, voc_size):
        self.formulas = formulas
        self.batch_size = batch_size
        self.voc_size = voc_size
    def __len__(self):
        return int(numpy.ceil(len(self.formulas) / float(self.batch_size)))
    def __getitem__(self, idx):
        batch=self.formulas[idx * self.batch_size:(idx + 1) * self.batch_size]
        batch_steps=numpy.max([len(f) for f in batch])+1
        batch_x=numpy.array([numpy.pad([self.voc_size]+tmp,(0,batch_steps-len(tmp)),'constant',constant_values=0) for tmp in batch])
        batch_y=numpy.array([numpy.pad(tmp+[self.voc_size],(0,batch_steps-len(tmp)),'constant',constant_values=0) for tmp in batch])
        return batch_x, keras.utils.to_categorical(batch_y,self.voc_size+1,'int8')

def load_data(captionFile,dictionary,grammar):
    fp=open(captionFile,'r')
    labels=fp.readlines()
    fp.close()
    formulas=[]
    for l in labels:
        tmp=l.strip().split()[1:]
        if len(tmp)<MAX_LENGTH and all([(w in dictionary) for w in tmp]) and isParseFinished(parse(tmp,grammar,dictionary)):
            formulas.append([dictionary[w] for w in tmp])
        # else:
        #     print('ignored',tmp)
    return FormulaSequence(formulas,24,len(dictionary))
    # return numpy.array(xArray),keras.utils.to_categorical(numpy.array(yArray),len(dictionary)+1,'int8')

def train():
    dictionary=load_dict(DICTIONARY_PATH)
    grammar=compileGrammar(loadGrammar(GRAMMAR_PATH,dictionary))
    trainSet=load_data(TRAIN_PATH,dictionary,grammar)
    validSet=load_data(VALID_PATH,dictionary,grammar)
    voc=len(dictionary)+1
    feature0 = keras.layers.Input(shape=(None,))
    feature1 = keras.layers.Embedding(voc,EMBEDDING_DIM,mask_zero=True,name='embedding')(feature0)
    feature2 = keras.layers.LSTM(LSTM_UNITS,return_sequences=True,name='lstm')(feature1)
    label = keras.layers.TimeDistributed(keras.layers.Dense(voc, activation='softmax'),name='time_distributed')(feature2)
    model = keras.Model(inputs=feature0,outputs=label)
    #model=keras.models.load_model(MODEL_PATH)
    print(model.summary())
    model.compile(optimizer='nadam',
                loss='categorical_crossentropy',
                metrics=['accuracy'])
    model.fit_generator(load_data(PRETRAIN_PATH,dictionary,grammar), epochs=10,validation_data=validSet)
    model.fit_generator(trainSet, epochs=10,validation_data=validSet)
    keras.models.save_model(model,MODEL_PATH)
    #keras.experimental.export_saved_model(model,"lm")

def test():
    dictionary=load_dict(DICTIONARY_PATH)
    grammar=compileGrammar(loadGrammar(GRAMMAR_PATH,dictionary))
    testSet=load_data(TEST_PATH,dictionary,grammar)
    model=keras.models.load_model(MODEL_PATH)
    # feature0 = keras.layers.Input(shape=(None,))
    # feature1 = keras.layers.Embedding(108,EMBEDDING_DIM,mask_zero=True,name='embedding')(feature0)
    # feature2 = keras.layers.LSTM(LSTM_UNITS,return_sequences=True,name='lstm')(feature1)
    # label = keras.layers.TimeDistributed(keras.layers.Dense(108, activation='softmax'),name='time_distributed')(feature2)
    # model = keras.Model(inputs=feature0,outputs=label)
    # model.load_weights(MODEL_PATH)
    # model.compile(optimizer='nadam',
    #             loss='categorical_crossentropy',
    #             metrics=['accuracy'])
    print(model.evaluate_generator(testSet, verbose=2))

def predict(line,model,dictionary,index):
    x=numpy.array([len(dictionary)]+[dictionary[w] for w in line.strip().split()])
    l=len(x)
    x=numpy.reshape(x,(1,l))
    y=model.predict(x)
    z=numpy.argmax(y,2)[0]
    return [(index[z[i]],y[0,i,z[i]]) for i in range(0,l)]

def load_language_model(model_path):
    trained_model=keras.models.load_model(model_path)
    lstm=trained_model.get_layer('lstm')
    voc=trained_model.get_layer('embedding').input_dim-1
    feature0 = keras.layers.Input(shape=(None,))
    oldH = keras.layers.Input(shape=(LSTM_UNITS,))
    oldC = keras.layers.Input(shape=(LSTM_UNITS,))
    feature1 = keras.layers.Embedding(voc+1,EMBEDDING_DIM,mask_zero=True,name='embedding')(feature0)
    feature2,newH,newC = keras.layers.LSTM(LSTM_UNITS,return_sequences=False,return_state=True,name='lstm')(feature1,initial_state=[oldH,oldC])
    label = keras.layers.Dense(voc+1, activation='softmax',name='time_distributed')(feature2)
    model = keras.Model(inputs=[feature0,oldH,oldC],outputs=[label,newH,newC])
    model.get_layer('embedding').set_weights(trained_model.get_layer('embedding').get_weights())
    model.get_layer('lstm').set_weights(trained_model.get_layer('lstm').get_weights())
    model.get_layer('time_distributed').set_weights(trained_model.get_layer('time_distributed').get_weights())
    print(model.summary())
    placeholder=numpy.array([])
    first_output=None
    def f_init(x):
        return placeholder, placeholder
    def f_next(y, ctx, h ,c):
        if h.shape[0]==0:
            return first_output
        else:
            y=numpy.reshape(y,(y.shape[0],1))
            y,h,c=model.predict([y,h,c])
            next_probs=numpy.hstack((y[:,voc:voc+1],y[:,1:voc]))
            return [next_probs, placeholder, h,c]
    init_input=numpy.array([voc],dtype='int32')
    init_h,init_c=numpy.zeros((1,LSTM_UNITS)),numpy.zeros((1,LSTM_UNITS))
    first_output=f_next(init_input,placeholder,init_h,init_c)
    return f_init,f_next,{'dim_enc':[]}


def play():
    dictionary=load_dict(DICTIONARY_PATH)
    index={i:w for (w,i) in dictionary.items()}
    index[len(dictionary)]='<eol>'
    model=keras.models.load_model(MODEL_PATH)
    while True:
        line=sys.stdin.readline()
        print(predict(line,model,dictionary,index))

if __name__ == "__main__":
    train()
    test()
    #play()

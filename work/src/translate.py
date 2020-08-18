'''
Translates a source file using a translation model.
'''

import sys
sys.path.append('/home/aistudio/external-libraries')

import argparse
import theano
import theano.tensor as tensor
from theano.sandbox.rng_mrg import MRG_RandomStreams as RandomStreams

import pickle as pkl
#import ipdb
import numpy
import copy
import pprint
import math
import os
import warnings
import time

from collections import OrderedDict

from data_iterator import dataIterator, dataIterator_valid

from grammar import compileGrammar,loadGrammar,parseStart,parseNext,isParseFailed,isParseFinished
from lm import load_language_model

profile = False

import random
import re

from nmt import (build_sampler, load_params,
                 init_params, init_tparams, load_dict)



def gen_sample(models, x, grammar, trng=None, k=1, maxlen=30, dictlen=107, 
               stochastic=True, argmax=False):

    # k is the beam size we have
    if k > 1:
        assert not stochastic, \
            'Beam search does not support stochastic sampling'

    total_weight=0.0
    sample = []
    sample_score = []
    if stochastic:
        sample_score = 0

    live_k = 1
    dead_k = 0

    hyp_samples = [[]] * live_k
    hyp_scores = numpy.zeros(live_k).astype('float32')
    hyp_stack = [parseStart()]

    # get initial state of decoder rnn and encoder context
    status = []
    for f_init,f_next,options,weight in models:
        total_weight = total_weight + weight
        ret = f_init(x)
        next_state, ctx0 = ret[0], ret[1]
        next_w = -1 * numpy.ones((1,)).astype('int64')  # bos indicator
        SeqL = x.shape[0]
        hidden_sizes=options['dim_enc']
        for i in range(len(hidden_sizes)):
            if options['down_sample'][i]==1:
                SeqL = math.ceil(SeqL / 2.)
        next_alpha_past = 0.0 * numpy.ones((1, int(SeqL))).astype('float32') # start position
        status.append({'ctx0':ctx0, 'next_w':next_w, 'next_state':next_state, 'next_alpha_past':next_alpha_past,'f_next':f_next,'weight':weight})
    

    for ii in range(maxlen):
        next_p = numpy.zeros((live_k,dictlen)).astype('float32')
        for state in status:
            f_next=state['f_next']
            ctx = numpy.tile(state['ctx0'], [live_k, 1])
            ret = f_next(state['next_w'], ctx, state['next_state'], state['next_alpha_past'])
            state['next_w'], state['next_state'], state['next_alpha_past'] = ret[1], ret[2], ret[3]
            next_p += ret[0] * state['weight']
        next_p /= total_weight

        if stochastic:
            if argmax:
                nw = next_p[0].argmax()
            else:
                nw = mode([state['next_w'][0] for state in status])
            sample.append(nw)
            sample_score += next_p[0, nw]
            if nw == 0:
                break
        else:
            cand_scores = hyp_scores[:, None] - numpy.log(next_p)
            cand_flat = cand_scores.flatten()
            ranks_flat = cand_flat.argsort()[:(k-dead_k)]

            voc_size = next_p.shape[1]
            trans_indices = ranks_flat // voc_size
            word_indices = ranks_flat % voc_size
            costs = cand_flat[ranks_flat]

            new_hyp_samples = []
            new_hyp_scores = numpy.zeros(k-dead_k).astype('float32')
            new_hyp_stack = []
            new_hyp_states = []
            new_hyp_alpha_past = []

            for idx, [ti, wi] in enumerate(zip(trans_indices, word_indices)):
                new_hyp_samples.append(hyp_samples[ti]+[wi])
                new_hyp_scores[idx] = copy.copy(costs[idx])
                new_hyp_stack.append(parseNext(wi,hyp_stack[ti],grammar))
                new_hyp_states_comp=[]
                new_hyp_alpha_past_comp=[]
                for state in status:
                    new_hyp_states_comp.append(copy.copy(state['next_state'][ti]))
                    new_hyp_alpha_past_comp.append(copy.copy(state['next_alpha_past'][ti]))
                new_hyp_states.append(new_hyp_states_comp)
                new_hyp_alpha_past.append(new_hyp_alpha_past_comp)

            # check the finished samples
            new_live_k = 0
            hyp_samples = []
            hyp_scores = []
            hyp_stack = []
            hyp_states = []
            hyp_alpha_past = []

            for idx in range(len(new_hyp_samples)):
                if new_hyp_samples[idx][-1] == 0: # <eol>
                    if isParseFinished(new_hyp_stack[idx]):
                        sample.append(new_hyp_samples[idx])
                        sample_score.append(new_hyp_scores[idx])
                        dead_k += 1
                else:
                    if not isParseFailed(new_hyp_stack[idx]):
                        new_live_k += 1
                        hyp_samples.append(new_hyp_samples[idx])
                        hyp_scores.append(new_hyp_scores[idx])
                        hyp_stack.append(new_hyp_stack[idx])
                        hyp_states.append(new_hyp_states[idx])
                        hyp_alpha_past.append(new_hyp_alpha_past[idx])
            hyp_scores = numpy.array(hyp_scores)
            live_k = new_live_k

            if new_live_k < 1:
                break
            if dead_k >= k:
                break

            for idx,state in enumerate(status):
                state['next_w'] = numpy.array([w[-1] for w in hyp_samples])
                state['next_state'] = numpy.array([s[idx] for s in hyp_states])
                state['next_alpha_past'] = numpy.array([s[idx] for s in hyp_alpha_past])

    if not stochastic:
        # dump every remaining one
        if live_k > 0:
            for idx in range(live_k):
                sample.append(hyp_samples[idx])
                sample_score.append(hyp_scores[idx])

    return sample, sample_score


def main(model_files, dictionary_target, grammar_target, data_path, saveto, wer_file, k=5):

    # load source dictionary and invert
    worddicts = load_dict(dictionary_target)
    worddicts_r = [None] * len(worddicts)
    for kk, vv in worddicts.items():
        worddicts_r[vv] = kk
    grammar=compileGrammar(loadGrammar(grammar_target,worddicts))

    trng = RandomStreams(1234)
    
    models=[]
    # load model model_options
    for model_file in model_files:
        print('Loading model: %s' % model_file)
        with open('%s.pkl' % model_file, 'rb') as f:
            options = pkl.load(f)
        print(options)
        params = init_params(options)
        params = load_params(model_file, params)
        tparams = init_tparams(params)
        f_init, f_next = build_sampler(tparams, options, trng)
        models.append((f_init,f_next,options,0.8))

    for lm_file in []:
        print('Loading language model: %s' % lm_file)
        f_init,f_next,options=load_language_model(lm_file)
        models.append((f_init,f_next,options,0.2))

    valid,valid_uid_list = dataIterator_valid(data_path,
                         worddicts, batch_size=1, maxlen=250)

    fpp_sample=[open('%s.%d'%(saveto,beam),'w') for beam in range(k)]
    
    valid_count_idx=0

    print('Decoding...')
    ud_epoch = 0
    ud_epoch_start = time.time()
    
    for x,y in valid:
        for xx in x:
            print('%d : %s' % (valid_count_idx+1, valid_uid_list[valid_count_idx]))
            xx_pad = numpy.zeros((xx.shape[0]+1,xx.shape[1]), dtype='float32')
            xx_pad[:xx.shape[0],:] = xx
            stochastic = False
            sample, score = gen_sample(models,
                                       xx_pad[:, None, :],
                                       grammar,
                                       trng=trng, k=k,
                                       maxlen=250,
                                       dictlen=len(worddicts),
                                       stochastic=stochastic,
                                       argmax=False)
            score = score / numpy.array([len(s) for s in sample])
            sample_rank=numpy.argsort(score)
            for beam in range(k):
                fpp_sample[beam].write(valid_uid_list[valid_count_idx])
                if len(sample)>beam:
                    ss=sample[sample_rank[beam]]
                else:
                    ss=[0]

                for vv in ss:
                    if vv == 0: # <eol>
                        break
                    fpp_sample[beam].write(' '+worddicts_r[vv])
                fpp_sample[beam].write('\n')
            valid_count_idx=valid_count_idx+1

    ud_epoch = (time.time() - ud_epoch_start) 
    print 'test set decode done, cost time ...', ud_epoch
    for beam in range(k):
        fpp_sample[beam].close();
        os.system('python compute-wer.py %s.%d %s %s'%(saveto,beam,os.path.join(data_path,"caption.txt"),wer_file))
        fpp=open(wer_file)
        stuff=fpp.readlines()
        fpp.close()
        m=re.search('WER (.*)\n',stuff[0])
        valid_per=100. * float(m.group(1))
        m=re.search('ExpRate (.*)\n',stuff[1])
        valid_sacc=100. * float(m.group(1))

        print '%d Valid WER: %.2f%%, ExpRate: %.2f%%' % (beam,valid_per,valid_sacc)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-k', type=int, default=5)
    parser.add_argument('dictionary_target', type=str)
    parser.add_argument('grammar_target', type=str)
    parser.add_argument('data_path', type=str)
    parser.add_argument('saveto', type=str)
    parser.add_argument('wer_file', type=str)
    parser.add_argument('model', type=str, nargs='+')

    args = parser.parse_args()

    main(args.model, args.dictionary_target, args.grammar_target, args.data_path,
         args.saveto, args.wer_file, k=args.k)


import sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from model import (FEATURES,HIDDEN,CLASSES,make_data,evaluate_int,event_evaluate,sparse_encode,load_model,wrap32)

def test_all_quantized_samples_dense_equal_sparse():
    x,y=make_data(2000,20261102)
    m=load_model(str(ROOT/'models'))
    h,logits=evaluate_int(x,m)
    for i in range(len(x)):
        a,b=event_evaluate(sparse_encode(x[i]),m)
        assert np.array_equal(a,h[i]),i
        assert np.array_equal(b,logits[i]),i
    assert np.mean(logits.argmax(1)==y)>.98

def test_repeated_event_indexes_and_empty_frames():
    m=load_model(str(ROOT/'models'))
    x=np.zeros((1,FEATURES),dtype=np.int8)
    a,b=evaluate_int(x,m)
    a2,b2=event_evaluate([],m)
    assert np.array_equal(a[0],a2) and np.array_equal(b[0],b2)
    x[0,7]=42
    _,dense=evaluate_int(x,m)
    _,stream=event_evaluate([(7,20),(7,22)],m)
    assert np.array_equal(dense[0],stream)

def test_signed_bitserial_identity():
    for w in (-128,-127,-17,-1,0,1,11,127):
        for x in (-128,-61,-1,0,1,64,127):
            terms=sum(((-1 if bit==7 else 1)*(w<<bit)) for bit in range(8) if ((x&255)>>bit)&1)
            assert terms==w*x

def test_two_complement_wrap():
    assert wrap32(2**31)==-2**31
    assert wrap32(-2**31-1)==2**31-1
    assert wrap32(2**32+123)==123

def test_fixture_mem_matches_oracle():
    m=load_model(str(ROOT/'models'))
    raw=np.loadtxt(ROOT/'models'/'vectors.mem',dtype=str)
    x=np.array([int(q,16) for q in raw],dtype=np.uint8).view(np.int8).reshape(-1,FEATURES)
    _,got=evaluate_int(x,m)
    scores=np.array([int(q,16) for q in np.loadtxt(ROOT/'models'/'scores.mem',dtype=str)],dtype=np.uint32).view(np.int32).reshape(-1,CLASSES)
    assert np.array_equal(got,scores)

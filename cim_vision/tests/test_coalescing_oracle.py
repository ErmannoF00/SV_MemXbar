"""Independent coalescing algebra check including spill and >127 per-tile."""
import sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from model import load_model,event_evaluate,wrap32,FEATURES


def reference_coalescer(raw_events,capacity):
    """Semantic oracle, not a cycle-level model of any RTL signal."""
    table={}; out=[]; spills=0
    for feature in raw_events:
        if feature in table and table[feature]==127:
            out.extend(table.items());table={};spills+=1
        elif feature not in table and len(table)==capacity:
            out.extend(table.items());table={};spills+=1
        table[feature]=table.get(feature,0)+1
    out.extend(table.items())
    if not out:out=[(0,0)]
    return out,spills


def test_coalescer_reconstructs_every_histogram_with_spills():
    rng=np.random.default_rng(903)
    m=load_model(str(ROOT/'models'))
    for capacity in (1,2,4,8,32):
        for _ in range(50):
            n=int(rng.integers(0,350))
            raw=list(map(int,rng.integers(0,FEATURES,size=n)))
            out,spills=reference_coalescer(raw,capacity)
            seen=np.zeros(FEATURES,dtype=np.int64)
            for idx,count in out:seen[idx]+=count
            target=np.bincount(raw,minlength=FEATURES)
            assert np.array_equal(seen,target)
            _,seq=event_evaluate(out,m)
            _,raw_seq=event_evaluate([(x,1) for x in raw],m)
            assert np.array_equal(seq,raw_seq)


def test_127_count_boundary_and_empty_window():
    coalesced,spills=reference_coalescer([4]*258,capacity=1)
    assert spills==2
    assert coalesced == [(4,127),(4,127),(4,4)]
    assert reference_coalescer([],2)==([(0,0)],0)

"""Reproducible SOFTWARE benchmark. Does not claim FPGA/ASIC PPA.

Measures number of numerical events, model storage, exact integer accuracy.
Counts are architectural traffic, NOT measured SRAM energy or latency.
"""
from pathlib import Path
import sys,json,csv
sys.path.insert(0,str(Path(__file__).resolve().parent))
import numpy as np
from model import make_data,evaluate_int,event_evaluate,sparse_encode,load_model,FEATURES,HIDDEN,CLASSES
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'results';OUT.mkdir(exist_ok=True)
m=load_model(str(ROOT/'models'))
x,y=make_data(2000,20261102)
h,p=evaluate_int(x,m)
nonzero=np.count_nonzero(x,axis=1)
raw_events=x.astype(np.int32).sum(axis=1)
# Strict bit-exact dense/sparse equality for all 2000 held-out samples.
for k in range(len(x)):
    a,b=event_evaluate(sparse_encode(x[k]),m)
    if not (np.array_equal(a,h[k]) and np.array_equal(b,p[k])):
        raise AssertionError(f'dense/sparse bit mismatch at {k}')
# Signed 32-bit accumulator update operations: one per output lane per
# accepted input record; W2 is always dense over 32 hidden activations.
dense_l1=int(len(x)*FEATURES*HIDDEN)
sparse_l1=int(nonzero.sum()*HIDDEN)
secondary=int(len(x)*HIDDEN*CLASSES)
metrics={
 'dataset':'Synthetic moving-spot events (independent training/test generators)',
 'test_samples':len(x),
 'correct_test':int(np.sum(p.argmax(1)==y)),
 'int8_test_accuracy':float(np.mean(p.argmax(1)==y)),
 'dense_sparse_exact_score_matches':len(x),
 'features':FEATURES,'hidden':HIDDEN,'classes':CLASSES,
 'mean_nonzero_features':float(nonzero.mean()),
 'mean_raw_events':float(raw_events.mean()),
 'zero_feature_fraction':float(1-nonzero.mean()/FEATURES),
 'mean_dense_feature_records':float(FEATURES),
 'mean_sparse_feature_records':float(nonzero.mean()),
 'dense_l1_weight_lane_reads':dense_l1,
 'sparse_l1_weight_lane_reads':sparse_l1,
 'layer2_weight_lane_reads':secondary,
 'dense_l1_acc_updates':dense_l1,
 'sparse_l1_acc_updates':sparse_l1,
 'dense_total_acc_updates':dense_l1+secondary,
 'sparse_total_acc_updates':sparse_l1+secondary,
 'lane_read_reduction_l1':float(1-sparse_l1/dense_l1),
 'lane_read_reduction_both_layers':float(1-(sparse_l1+secondary)/(dense_l1+secondary)),
 'memory_bytes_weights':int(m.w1.nbytes+m.w2.nbytes),
 'memory_bytes_bias':int(m.b1.nbytes+m.b2.nbytes),
 'mean_dense_stream_bytes':int(FEATURES*2), # uniform 8-bit index + 8-bit value per record
 'mean_sparse_stream_bytes':float(2*nonzero.mean()),
 'caveat':'Traffic counting only; no RTL cycle, FPGA PPA, SRAM characterization, or real DVS validation.'
}
(OUT/'software_metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
with (OUT/'distribution.csv').open('w',newline='') as f:
    w=csv.writer(f);w.writerow(['sample','label','pred','active_features','raw_events'])
    for idx in range(len(x)):
        w.writerow((idx,int(y[idx]),int(p[idx].argmax()),int(nonzero[idx]),int(raw_events[idx])))
print(json.dumps(metrics,indent=2))

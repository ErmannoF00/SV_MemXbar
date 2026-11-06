"""Train a float reference on synthetic directional-motion event histograms,
then quantize and freeze an INT8/INT32 model for deterministic RTL replay.
"""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import json
import numpy as np
import torch
from model import make_data, evaluate_int, QModel, FEATURES, HIDDEN, CLASSES, sparse_encode

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'models'
OUT.mkdir(exist_ok=True)
torch.manual_seed(2026)
torch.set_num_threads(2)
train_x, train_y=make_data(10000,20261101)
test_x, test_y=make_data(2000,20261102)
network=torch.nn.Sequential(torch.nn.Linear(FEATURES,HIDDEN), torch.nn.ReLU(), torch.nn.Linear(HIDDEN,CLASSES))
opt=torch.optim.AdamW(network.parameters(),lr=0.006,weight_decay=0.0001)
X=torch.tensor(train_x,dtype=torch.float32)
Y=torch.tensor(train_y,dtype=torch.long)
for epoch in range(110):
    gen=torch.Generator().manual_seed(1000+epoch)
    perm=torch.randperm(len(X),generator=gen)
    for batch in perm.split(256):
        opt.zero_grad()
        loss=torch.nn.functional.cross_entropy(network(X[batch]),Y[batch])
        loss.backward(); opt.step()
with torch.no_grad():
    float_logits=network(torch.tensor(test_x,dtype=torch.float32)).numpy()
W1=network[0].weight.detach().numpy().T
b1=network[0].bias.detach().numpy()
W2=network[2].weight.detach().numpy().T
b2=network[2].bias.detach().numpy()
# DQ1: W1 Q5, b1 Q5. Rounding ReLU output into Q3 and saturating INT8.
# DQ2: W2 Q5, b2 Q8. Therefore final scores Q8 (not probabilities).
quant=lambda x,scale: np.clip(np.rint(x*scale),-128,127).astype(np.int8)
model=QModel(quant(W1,32),np.rint(b1*32).astype(np.int32),quant(W2,32),np.rint(b2*256).astype(np.int32))
np.savez_compressed(OUT/'quantized.npz',w1=model.w1,b1=model.b1,w2=model.w2,b2=model.b2)
_,scores=evaluate_int(test_x,model)
float_acc=float(np.mean(float_logits.argmax(axis=1)==test_y))
quant_acc=float(np.mean(scores.argmax(axis=1)==test_y))
# Fixed test vectors for RTL: preserve data independent of HDL implementation.
# Include zero vector, positive+negative weight checks, multiple nonzeros.
fixtures=test_x[:24].copy()
fixtures[0]=0
_,fixtures_score=evaluate_int(fixtures,model)
def h8(v): return f'{int(v)&255:02x}'
def h32(v): return f'{int(v)&0xffffffff:08x}'
for stem,a,fn in [
 ('w1',model.w1,h8),('w2',model.w2,h8),('b1',model.b1,h32),('b2',model.b2,h32),
 ('vectors',fixtures,h8),('scores',fixtures_score,h32)]:
    with (OUT/(stem+'.mem')).open('w') as f:
        f.write('\n'.join(fn(v) for v in a.ravel(order='C'))+'\n')
result={'seed_train':20261101,'seed_test':20261102,'n_train':len(train_x),'n_test':len(test_x),
        'float_test_accuracy':float_acc,'quantized_test_accuracy':quant_acc,
        'mean_nonzero':float(np.count_nonzero(test_x,axis=1).mean()),'mean_events':float(test_x.sum(axis=1).mean()),
        'max_nonzero':int(np.count_nonzero(test_x,axis=1).max()),
        'n_rtl_test':len(fixtures),'features':FEATURES,'hidden':HIDDEN,'classes':CLASSES,
        'w1_clip_fraction':float(np.mean(np.abs(W1*32)>127)),
        'w2_clip_fraction':float(np.mean(np.abs(W2*32)>127)),
        'expected_score_first':fixtures_score[0].tolist()}
(OUT/'metrics.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))

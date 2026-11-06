"""One-command human-readable inference trace; runs without PyTorch or RTL tools."""
from pathlib import Path
import sys,argparse
sys.path.insert(0,str(Path(__file__).resolve().parent))
import numpy as np
from model import make_data,load_model,evaluate_int,event_evaluate,sparse_encode,LABELS
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--sample',type=int,default=1,help='Index into 2000 held-out synthetic frames (0..1999)')
a=parser.parse_args()
x,y=make_data(2000,20261102)
if not 0<=a.sample<len(x): parser.error('sample out of range')
model=load_model(str(ROOT/'models'))
v=x[a.sample]
records=sparse_encode(v)
hidden,scores=event_evaluate(records,model)
_,ref=evaluate_int(v[None,:],model)
assert np.array_equal(scores,ref[0])
print('CIM-VISION — deterministic synthetic event-motion inference')
print('Frame:',a.sample,'true:',LABELS[y[a.sample]])
for t in range(2):
    print('\nTime bin',t)
    tile=v[t*64:(t+1)*64].reshape(8,8)
    for row in tile:
        print(' '.join('·' if value==0 else str(int(value)) for value in row))
print('\nSource records:',len(records),'vs 128 dense features')
print('First 12 indexed records:',records[:12])
print('Hidden INT8 first 12:',hidden[:12].tolist())
print('Q8 signed scores:',{label:int(s) for label,s in zip(LABELS,scores)})
print('Predicted:',LABELS[int(np.argmax(scores))], '| reference exact:',bool(np.array_equal(scores,ref[0])))
print('No claims of FPGA timing, SRAM energy or real event-camera accuracy.')

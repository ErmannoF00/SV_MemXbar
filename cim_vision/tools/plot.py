"""Technical application figures generated from independent software test data."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from model import make_data,evaluate_int,load_model,LABELS
ROOT=Path(__file__).resolve().parents[1]
x,y=make_data(2000,20261102)
m=load_model(str(ROOT/'models'))
_,scores=evaluate_int(x,m)
cm=np.zeros((4,4),dtype=np.int64)
for a,b in zip(y,scores.argmax(axis=1)):
    cm[a,b]+=1
fig,axes=plt.subplots(1,2,figsize=(10,3.8),layout='constrained')
axes[0].hist(np.count_nonzero(x,axis=1),bins=np.arange(0,29)-0.5)
axes[0].set(title='Event-histogram nonzero features',xlabel='Active features / 128',ylabel='Test windows')
axes[1].imshow(cm)
axes[1].set(title='INT8 quantized classifier',xticks=range(4),xticklabels=LABELS,
            yticks=range(4),yticklabels=LABELS,xlabel='Predicted',ylabel='True')
for i in range(4):
 for j in range(4):
  axes[1].text(j,i,str(cm[i,j]),ha='center',va='center')
fig.savefig(ROOT/'results'/'motion_benchmark.png',dpi=180)
plt.close(fig)

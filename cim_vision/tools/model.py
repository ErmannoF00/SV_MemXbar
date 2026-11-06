"""Independent integer oracle and reproducible synthetic event-motion corpus.

A frame contains a 2-bin occupancy histogram over an 8x8 tile grid (128
features). Events are (feature_index, multiplicity) and add linearly. All
fixed-point behavior here is specified independently of RTL implementation.
"""
from __future__ import annotations
import numpy as np
from dataclasses import dataclass

GRID = 8
BINS = 2
FEATURES = GRID * GRID * BINS
HIDDEN = 32
CLASSES = 4
LABELS = ('right', 'left', 'down', 'up')


def make_data(n: int, seed: int) -> tuple[np.ndarray, np.ndarray]:
    """Synthetic two-time-bin moving bright blobs plus spatial event noise.

    Events are binned from a mobile 3x3 spot. This is NOT a DVS recording.
    Train/test use independent PRNG seeds and randomly placed trajectories.
    """
    rng = np.random.default_rng(seed)
    X = np.zeros((n, FEATURES), dtype=np.int8)
    labels = rng.integers(0, CLASSES, size=n, dtype=np.int64)
    directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    for r in range(n):
        direction = int(labels[r]); dx, dy = directions[direction]
        x0 = int(rng.integers(2, 6)); y0 = int(rng.integers(2, 6))
        for t in (0, 1):
            cx = x0 + dx*t; cy = y0 + dy*t
            # A compact event cluster in each time bin: geometric structure,
            # not a label embedded into the feature vector.
            for yy in range(cy-1, cy+2):
                for xx in range(cx-1, cx+2):
                    if 0 <= xx < GRID and 0 <= yy < GRID:
                        count = 1 if abs(xx-cx)+abs(yy-cy) >= 2 else 2
                        if rng.random() < 0.12: count = 0
                        idx = t*64 + yy*8 + xx
                        X[r, idx] = count
        # Camera background/shot noise: independent of label.
        for _ in range(int(rng.integers(0, 5))):
            idx = int(rng.integers(0, FEATURES))
            X[r, idx] = min(3, int(X[r, idx])+1)
    return X, labels


@dataclass
class QModel:
    w1: np.ndarray  # (FEATURES, HIDDEN), signed INT8
    b1: np.ndarray  # (HIDDEN,), signed INT32, scale 32
    w2: np.ndarray  # (HIDDEN, CLASSES), signed INT8
    b2: np.ndarray  # (CLASSES,), signed INT32, scale 256


def evaluate_int(x: np.ndarray, m: QModel) -> tuple[np.ndarray,np.ndarray]:
    """Exact integer contract for the RTL, no float inference path.
    h_acc=W1.T*x+b1; h8=clip((max(h_acc,0)+2)//4,0,127);
    scores=W2.T*h8+b2. Accumulators use wrap at signed INT32.
    """
    z = x.astype(np.int64) @ m.w1.astype(np.int64) + m.b1.astype(np.int64)
    h = np.clip((np.maximum(z, 0)+2)//4, 0, 127).astype(np.int64)
    logits = h @ m.w2.astype(np.int64) + m.b2.astype(np.int64)
    if np.any(z > 2**31-1) or np.any(z < -2**31) or np.any(logits > 2**31-1) or np.any(logits < -2**31):
        raise OverflowError('bench vectors exceed signed 32 bit; RTL specifies wrapping')
    return h.astype(np.int8),logits.astype(np.int32)


def wrap32(v: int) -> int:
    return ((int(v)+(1 << 31)) % (1 << 32))-(1 << 31)


def event_evaluate(events: list[tuple[int,int]], m: QModel) -> tuple[np.ndarray,np.ndarray]:
    """Sequential, independent event oracle; allows repeated feature indexes."""
    acc1 = [int(v) for v in m.b1]
    for idx, value in events:
        if not 0 <= idx < FEATURES or not -128 <= value <= 127:
            raise ValueError((idx, value))
        for j in range(HIDDEN):
            acc1[j] = wrap32(acc1[j] + int(m.w1[idx,j])*value)
    hidden = np.array([min(127, max(0,(int(v)+2)//4)) for v in acc1],dtype=np.int8)
    acc2 = [int(v) for v in m.b2]
    for idx,value in enumerate(hidden):
        for j in range(CLASSES):
            acc2[j]=wrap32(acc2[j]+int(m.w2[idx,j])*int(value))
    return hidden,np.asarray(acc2,dtype=np.int32)


def sparse_encode(x: np.ndarray) -> list[tuple[int,int]]:
    return [(int(i),int(v)) for i,v in enumerate(x) if v != 0]


def load_model(folder: str) -> QModel:
    p=np.load(folder+'/quantized.npz')
    return QModel(p['w1'],p['b1'],p['w2'],p['b2'])

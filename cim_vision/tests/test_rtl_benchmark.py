import sys
from pathlib import Path
import pytest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from rtl_benchmark import parse_result

def test_perf_parser():
    row=parse_result('PASS CIM_MLP serial=0 dense=1 samples=24 outputs=96 cycles_with_programming=9000\nPERF serial=0 dense=1 samples=24 inference_cycles=2400',serial=0,dense=1)
    assert row['samples']==24 and row['inference_cycles']==2400 and row['dense']

@pytest.mark.parametrize('raw',[ 'PERF serial=0 dense=1 samples=24 inference_cycles=1',
    'PASS CIM_MLP\nPERF serial=0 dense=0 samples=24 inference_cycles=3',
    'PASS CIM_MLP\nPERF serial=0 dense=1 samples=23 inference_cycles=3'])
def test_reject_unverified_or_wrong_mode(raw):
    with pytest.raises(ValueError):parse_result(raw,serial=0,dense=1)

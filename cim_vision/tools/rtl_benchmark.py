"""Measure full inference cycles excluding model configuration for the locked fixture."""
from __future__ import annotations
import json
import re
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
RTL=sorted((ROOT/'rtl').glob('*.sv'))
PERF=re.compile(r"PERF serial=(\d) dense=(\d) samples=(\d+) inference_cycles=(\d+)")

def parse_result(text: str, *, serial: int, dense: int):
    if 'PASS CIM_MLP' not in text:
        raise ValueError('HDL regression did not report PASS CIM_MLP')
    matches=PERF.findall(text)
    if len(matches)!=1:
        raise ValueError('Expected one performance record')
    bits,mode,samples,cycles=map(int,matches[0])
    if (bits,mode)!=(serial,dense) or samples!=24 or cycles<=0:
        raise ValueError('Unexpected mode, sample count or cycles')
    return {'serial':bool(bits),'dense':bool(mode),'samples':samples,'inference_cycles':cycles}

def benchmark():
    out=ROOT/'build'/'rtl_benchmark'
    out.mkdir(parents=True,exist_ok=True)
    measurements=[]
    for serial in [0,1]:
        exe=out/f'mlp_serial_{serial}'
        subprocess.run(['iverilog','-g2012','-s','tb_cim_mlp',
            f'-Ptb_cim_mlp.BIT_SERIAL={serial}', '-o',str(exe),
            *map(str,RTL),str(ROOT/'tests/tb_cim_mlp.sv')],
            cwd=ROOT,check=True)
        for dense in [0,1]:
            args=['vvp',str(exe)] + (['+DENSE'] if dense else [])
            run=subprocess.run(args,cwd=ROOT,text=True,capture_output=True)
            (out/f'mlp_serial_{serial}_dense_{dense}.log').write_text(run.stdout+run.stderr)
            if run.returncode: raise RuntimeError(f'{args}: {run.stdout[-3000:]} {run.stderr[-3000:]}')
            row=parse_result(run.stdout,serial=serial,dense=dense)
            measurements.append(row)
            print(f"serial={serial} dense={dense}: {row['inference_cycles']} inference cycles for 24 windows")
    results={'scope':'Icarus RTL cycle counts, including testbench input gaps and all inference stages; excludes weight programming',
      'measured':measurements}
    for s in [False,True]:
        d=next(x['inference_cycles'] for x in measurements if x['serial']==s and x['dense'])
        a=next(x['inference_cycles'] for x in measurements if x['serial']==s and not x['dense'])
        results[f'sparse_speedup_serial_{int(s)}']=d/a
    (out/'performance.json').write_text(json.dumps(results,indent=2)+'\n')
    return results

if __name__=='__main__':
    print(json.dumps(benchmark(),indent=2))

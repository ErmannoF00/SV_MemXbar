"""Very limited static checks when HDL tools are unavailable.
NOT a replacement for SystemVerilog parsing, lint, simulation, or synthesis.
"""
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files=list((ROOT/'rtl').glob('*.sv'))+list((ROOT/'tests').glob('*.sv'))
modules={}
for p in files:
    raw=p.read_text()
    src=re.sub(r'//[^\n]*|/\*.*?\*/','',raw,flags=re.S)
    src=re.sub(r'"(?:\\.|[^"\\])*"','""',src)
    begins=len(re.findall(r'\bbegin\b',src))
    ends=len(re.findall(r'\bend\b',src))
    assert begins==ends,(p,begins,ends)
    for m in re.finditer(r'\bmodule\s+(\w+)',src):
        assert m.group(1) not in modules,(p,m.group(1))
        modules[m.group(1)]=p
    assert len(re.findall(r'\bmodule\b',src))==len(re.findall(r'\bendmodule\b',src)),p
required=['cim_bank','cim_layer','relu_q3','cim_vision_mlp','event_coalescer','event_cim_top','bitline_bool_cim']
for m in required:assert m in modules
print('LIMITED STATIC CHECK PASS:',len(files),'HDL files and',len(modules),'unique modules; begin/end/module counts balanced.')
print('This does not verify SystemVerilog semantics or synthesize anything.')

# Embedded SNN

**EEG classification with spiking neural networks and a portable C++ inference runtime.**

Research prototype combining supervised adaptive leaky integrate-and-fire (ALIF) networks, subject-held-out evaluation, early-exit policies, and host-side numerical verification.

> **Status:** Software research prototype. EEG decoding accuracy remains close to chance; MCU firmware and device-level energy measurements are not yet available.

## Pipeline

```text
PhysioNet EEG → 8 channels → 1 s windows → 32 features
                                               ↓
                                  32 → 48 ALIF → 2 classes
                                               ↓
                               Early exit / C++ host inference
```

Two feature representations are evaluated: amplitude statistics and mu/beta spectral log-power. The network uses 20 simulation steps and is trained with surrogate gradients.

## Results

Five subject-held-out folds; 20 subjects, 900 trials, 2,700 windows.

| Model | Accuracy |
|---|---:|
| ALIF, amplitude features | 51.56% |
| ALIF, spectral features | 54.04% |
| Logistic regression, spectral | 54.26% |
| MLP, spectral | 52.30% |

For the spectral ALIF, a validation-calibrated early-exit policy averaged **16.02/20 steps** (19.89% fewer recurrent steps), with **0 observed class disagreements** against full-step inference on these test windows. This does **not** establish energy or latency savings, or a guaranteed zero-error stopping policy.

See [methods](research_addon/docs/METHODS.md) and [results](research_addon/docs/RESULTS.md) for the experimental protocol and limitations.

## Quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r research_addon/requirements-train.txt
cd research_addon
make check
```

The check runs host-side software tests; it does not download EEG data or validate physical MCU execution. Training and evaluation commands are in [research_addon/README.md](research_addon/README.md).

## Repository

| Path | Purpose |
|---|---|
| `snn_pipeline/` | Core supervised SNN and model export |
| `deployment/` | Portable C++ inference reference |
| `research_addon/` | EEG evaluation, early exit, C++ parity checks |
| `tests/` | Core regression tests |
| `docs/` | Core design notes |

## Scope

The current models consume window-derived features, not asynchronous raw EEG events. Spectral feature extraction is host-side. The repository does not claim clinical BCI validation, thought decoding, working STM32 firmware, or measured power efficiency.

**Dataset:** [PhysioNet EEG Motor Movement/Imagery Database](https://physionet.org/content/eegmmidb/1.0.0/). No raw EEG recordings are distributed here.

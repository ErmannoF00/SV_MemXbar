# Memristor Crossbar Model for Neuromorphic Applications

## Overview
This project implements a **memristor crossbar** model designed for neuromorphic computing applications. It leverages:

1. **Memristor Model**: Inspired by the JART memristor model ([JART Memristor Model](https://emrl.de/JART.html)) to simulate memristive behavior accurately.
2. **Adaptive Leaky Integrate-and-Fire (AdLIF) Neuron**: A spiking neural network (SNN) implementation based on the AdLIF neuron model for learning and inference tasks.

The crossbar structure, coupled with AdLIF neurons, facilitates energy-efficient computation for machine learning and neuromorphic tasks.

## Features
- **Memristor Dynamics**:
  - Based on realistic memristor physics, including resistance modulation and ion dynamics.
  - Configurable parameters for exploring different memristor technologies.

- **Crossbar Architecture**:
  - Models large-scale crossbar arrays with memristors at each junction.
  - Facilitates weighted summation and synaptic updates.

- **AdLIF Neuron Model**:
  - Simulates spiking behavior for neuromorphic processing.
  - Incorporates adaptive thresholds for learning mechanisms.

## Objectives
- To create a scalable, modular, and physics-based simulation of memristor crossbars.
- To demonstrate the potential of memristor crossbars for implementing synaptic weight storage in spiking neural networks.
- To integrate memristor-based crossbars with AdLIF neurons for neuromorphic learning and inference.

## Usage
1. **Memristor Simulation**: Use the provided memristor module to simulate individual device characteristics.
2. **Crossbar Design**: Configure the crossbar size and connect memristors to represent synaptic weights.
3. **AdLIF Neuron Simulation**: Simulate spiking behavior and observe how the network adapts to input patterns.
4. **Integration**: Combine the crossbar and AdLIF neuron models to create a neuromorphic system capable of learning tasks.

## Applications
- Neuromorphic computing
- Spiking neural network simulation
- Low-power AI inference
- Real-time pattern recognition

## References
- **JART Memristor Model**: [JART Memristor Model](https://iwe.rwth-aachen.de)
- **AdLIF Neuron**: Adaptive LIF neuron model inspired by spiking neural network research.

## Future Work
- Scaling the crossbar for large datasets.
- Integration with real-world machine learning tasks.
- Optimization of the AdLIF neuron parameters for diverse applications.

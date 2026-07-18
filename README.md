# DE-2LS-COPs-IEEE-CEC-2026-Competition

Official repository for the **DE-2LS** algorithm submitted to the **IEEE CEC 2026 Constrained Single-Objective Numerical Optimization Competition (CSOPs/COPs)**.

## Highlights

- **Competition result:** **4th rank among 8 entries** in the IEEE CEC 2026 constrained optimization competition.
- **Paper:** [DE-2LS: Differential Evolution with Lightweight Late Local Search for Constrained Numerical Optimization](https://arxiv.org/abs/2606.27764)

## Overview

DE-2LS is a constrained optimization variant built on the **RDEx** framework. The method preserves the main RDEx components, including:

- mutation and crossover operators,
- success-history adaptation,
- archive mechanism,
- population-size reduction, and
- feasibility-aware/epsilon-based constraint handling.

To strengthen late-stage exploitation, DE-2LS adds a **lightweight coordinate-pattern local search** around the current best solution. The local search is used conservatively:

- it is activated only in the late stage of the run,
- it uses a small evaluation budget,
- it follows a feasibility-aware acceptance rule, and
- it acts as a polishing component rather than replacing the evolutionary search engine.

## Main Findings

DE-2LS:

- achieved the **best U-score among the tested ablation variants**,
- improved the original **RDEx** by **5.58%** in direct head-to-head comparison, and
- obtained the **highest overall U-score of 80968** and the **best total rank of 48** in the reported four-algorithm comparison.

## Paper Citation

If you use this repository, please cite:

```bibtex
@article{chauhan2026de2lscsops,
  title   = {DE-2LS: Differential Evolution with Lightweight Late Local Search for Constrained Numerical Optimization},
  author  = {Chauhan, Dikshit and Trivedi, Anupam},
  journal = {arXiv preprint arXiv:2606.27764},
  year    = {2026}
}
```

## Repository Structure

A typical repository layout may include:

```text
.
├── src/                # Source code
├── results/            # Competition result files
├── scripts/            # Utilities for evaluation/post-processing
├── paper/              # Manuscript or supplementary files
└── README.md
```

## Notes

This repository is intended to accompany the DE-2LS competition submission and paper. The method focuses on improving **late-stage refinement** while preserving the strong feasibility-oriented search behavior of the RDEx baseline.

## Acknowledgement

The authors sincerely thank Prof. P. N. Suganthan and the organizers of the IEEE CEC numerical optimization competition for providing the official U-score evaluation procedure and related competition resources. These materials were highly valuable for implementing the evaluation framework and ensuring consistency with the intended competition-based assessment protocol used in this work. The authors also thank the authors of RDEx for providing the source code, which facilitated the implementation of the baseline method and the development of the proposed DE-2LS algorithm.

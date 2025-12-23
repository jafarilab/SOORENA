<p align="center">
  <img src="assets/logos/logo.png" alt="Project Logo" width="200"/>
</p>

<h1 align="center">SOORENA</h1>

<p align="center">
  Self-lOOp containing or autoREgulatory Nodes in biological network Analysis
</p>

<p align="center">
  <a href="#introduction">Introduction</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#data--models">Data &amp; Models</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## Introduction

### Self-Loops in Biological Networks

Self-loops represent the simplest form of feedback within a network and can be either positive or negative. Although self-loops are often considered insignificant in static network analyses and consequently ignored in many studies, they play a **critical role** in shaping the dynamics of biological networks. This importance is particularly evident in mathematical models of biological systems—both continuous and discrete ([DOI:10.1529/biophysj.107.125021](https://doi.org/10.1529/biophysj.107.125021)).

[Thomas et al.](https://doi.org/10.1007/BF02460618) demonstrated that:

- **Positive feedback loops** are necessary for **multistationarity**
- **Negative feedback loops** are essential for the **emergence of periodic behavior**

Furthermore, biologists have long recognized that both positive and negative feedback loops are fundamental in regulating the dynamics of a wide range of biological systems (see Figure 1).

When reducing network models for dynamic analysis, most approaches retain **autoregulated nodes**, as their removal would compromise key regulatory properties ([DOI:10.1137/13090537X](https://doi.org/10.1137/13090537X)). Moreover, complex feedback loops involving multiple nodes are often reduced to **self-loops** in simplified versions of the network. These self-loops are crucial for predicting the system's dynamical behavior ([DOI:10.1016/j.jtbi.2011.08.042](https://doi.org/10.1016/j.jtbi.2011.08.042)).

---

### Types of Autoregulation

#### Negative Autoregulation (NAR)

- Accelerates the response time of gene circuits
- Reduces intercellular variation in protein levels caused by fluctuations in production rates
- Occurs when:
  - A transcription factor represses its own gene
  - A protein inhibits its own activity (e.g., via autophosphorylation)

#### Positive Autoregulation

- Increases variability and delays response times
- Under sufficient cooperativity, may lead to **bimodal (all-or-none)** distributions
- Occurs when:
  - A transcription factor enhances its own production
  - A protein activates its own function through autophosphorylation

---

### Project Goal

To the best of our knowledge, no existing database specifically focuses on **self-loops**—neither in the context of signaling pathways nor gene regulatory networks.

This project aims to develop a **text-mining-based approach** to extract, integrate, and catalog information about self-loops in molecular biology using a two-stage deep learning pipeline that:

1. **Stage 1**: Binary classification to identify papers describing autoregulatory mechanisms
2. **Stage 2**: Multi-class classification to categorize the specific mechanism type

The models are trained on data from UniProt and PubMed, and can predict autoregulatory mechanisms across 3.6+ million research papers.

---

### Figure

![Figure 1](assets/figures/figure1.png)
*Adapted from: [SnapShot: Network Motifs](https://doi.org/10.1016/j.cell.2010.09.050), Oren Shoval & Uri Alon, Cell, 2010.*

---

## Quick Start

### Clone Repository

Clone the repository and navigate into it:

```bash
git clone https://github.com/halaarar/SOORENA_2.git
cd SOORENA_2
```

### Data & Models

This repository uses Git LFS for large datasets. Large prediction inputs and model files are hosted externally.

```bash
git lfs install
git lfs pull
```

Download required files from Google Drive and place them in:
- `data/pred/abstracts-authors-date.tsv`
- `models/stage1_best.pt`
- `models/stage2_best.pt`

Google Drive folder:
https://drive.google.com/drive/folders/1cHp6lodUptxHGtIgj3Cnjd7nNBYWHItM?usp=sharing

Verify files downloaded correctly:

```bash
ls -lh data/raw
ls -lh results
```

### Create Environment

**Option 1: Conda (Recommended)**

```bash
conda env create -f environment.yml
conda activate autoregulatory
```

**Option 2: pip + venv**

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

---

## Repository Structure

```
SOORENA_2/
├── README.md                    # This file
├── config.py                    # Central configuration
├── requirements.txt             # Python dependencies
├── environment.yml              # Conda environment
│
├── scripts/                     # All executable scripts
│   ├── python/
│   │   ├── data_processing/     # Data preparation & merging
│   │   ├── training/            # Model training & evaluation
│   │   └── prediction/          # Prediction scripts
│   └── shell/                   # Shell scripts for pipelines
│
├── utils/                       # Python utilities
│   ├── dataset.py              # PyTorch dataset classes
│   └── metrics.py              # Evaluation metrics
│
├── notebooks/                   # Jupyter notebooks (EDA)
├── data/                        # Datasets (raw, processed, pred)
├── models/                      # Trained model checkpoints
├── results/                     # Prediction outputs
├── shiny_app/                   # Interactive Shiny application
├── deployment/                  # Deployment scripts & guides
├── docs/                        # Detailed documentation
├── assets/                      # Logos and figures
└── reports/                     # Generated reports
```

---

## Documentation

Use the docs index to navigate all guides:
- [docs/README.md](docs/README.md)

Direct links:
- [docs/README_PREDICTION.md](docs/README_PREDICTION.md) — Run predictions on new data
- [docs/README_PREDICTION_PIPELINE.md](docs/README_PREDICTION_PIPELINE.md) — End-to-end pipeline
- [docs/README_TRAINING.md](docs/README_TRAINING.md) — Model training (Stage 1 & 2)
- [docs/README_DATA_PREPARATION.md](docs/README_DATA_PREPARATION.md) — Data preprocessing
- [docs/README_ENRICHMENT.md](docs/README_ENRICHMENT.md) — Protein name enrichment
- [docs/README_SHINY_APP.md](docs/README_SHINY_APP.md) — Shiny app usage
- [deployment/README.md](deployment/README.md) — Deployment

---

## Technology Stack

**Languages:** Python 3.11+, R 4.x, Bash

**ML Framework:** PyTorch, Transformers (HuggingFace)

**Model:** PubMedBERT (microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext)

**Web Framework:** R Shiny

**Database:** SQLite

**Deployment:** DigitalOcean, Oracle Cloud, Shiny Server

---

## Dataset Statistics

- **Training set:** 1,332 labeled papers
- **Test set:** 400 papers
- **Unlabeled training negatives:** 2,664 papers
- **Prediction dataset:** 3.6+ million PubMed papers
- **Final database:** 3.6+ million records in Shiny app

### Mechanism Types Distribution

| Mechanism Type | Count |
|----------------|-------|
| Autophosphorylation | 719 |
| Autoregulation | 163 |
| Autocatalytic | 147 |
| Autoinhibition | 122 |
| Autoubiquitination | 121 |
| Autolysis | 41 |
| Autoinducer | 38 |

---

## Performance

### Stage 1 (Binary Classification)
- **Accuracy:** 96%
- **Precision:** 97.8%
- **Recall:** 90%
- **F1-Score:** 93.8%

### Stage 2 (Multi-class Classification)
- **Accuracy:** 97.4%
- **Macro F1-Score:** 97.2%

See [reports/](reports/) for detailed confusion matrices.

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -m 'Add some feature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---


## Contact

For questions or feedback, please open an issue on GitHub.

---

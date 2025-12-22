<p align="center">
  <img src="assets/logos/logo.png" alt="Project Logo" width="200"/>
</p>

<h1 align="center">SOORENA</h1>

<p align="center">
  Self-lOOp containing or autoREgulatory Nodes in biological network Analysis
</p>

<p align="center">
  <a href="#introduction">Introduction</a> •
  <a href="#setup">Setup</a> •
  <a href="#pipeline">Pipeline</a> •
  <a href="#deployment">Deployment</a> •
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

## Setup

### Clone Repository & Install Dependencies

Clone the repository and navigate into it:

```bash
git clone https://github.com/halaarar/SOORENA_2.git
cd SOORENA_2
```

### Download Large Files (Git LFS)

This repository uses Git LFS for large datasets and model files:

```bash
git lfs install
git lfs pull
```

Verify files downloaded correctly:

```bash
ls -lh data/raw
ls -lh models
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

## Pipeline

All commands should be run from the repository root directory.

### 1. Data Preparation

```bash
python scripts/python/data_processing/prepare_data.py
```

This script:
- Loads and merges PubMed and UniProt data
- Cleans and normalizes text
- Creates labeled dataset for training
- Outputs: [data/processed/modeling_dataset.csv](data/processed/modeling_dataset.csv)

### 2. Train Stage 1 (Binary Classification)

```bash
python scripts/python/training/train_stage1.py
```

Trains a binary classifier to identify papers with autoregulatory mechanisms.

- Model: PubMedBERT
- Output: [models/stage1_best.pt](models/stage1_best.pt)

### 3. Train Stage 2 (Multi-class Classification)

```bash
python scripts/python/training/train_stage2.py
```

Trains a multi-class classifier to identify the specific mechanism type:

- autophosphorylation
- autoregulation
- autocatalytic
- autoinhibition
- autoubiquitination
- autolysis
- autoinducer

Output: [models/stage2_best.pt](models/stage2_best.pt)

### 4. Evaluate Models

```bash
python scripts/python/training/evaluate.py
```

Generates confusion matrices and evaluation metrics.

Outputs:
- [reports/stage1_confusion_matrix.png](reports/stage1_confusion_matrix.png)
- [reports/stage2_confusion_matrix.png](reports/stage2_confusion_matrix.png)

### 5. Run Predictions

**Test single paper:**

```bash
python scripts/python/prediction/predict.py
```

**Complete pipeline (create Shiny app data):**

```bash
bash scripts/shell/run_complete_pipeline.sh
```

This runs the full pipeline: extracts training samples, predicts on unused data, and merges everything.

**Outputs:**
- [data/processed/stage1_unlabeled_negatives.csv](data/processed/stage1_unlabeled_negatives.csv) - Papers used as training negatives
- [data/processed/stage1_unlabeled_unused.csv](data/processed/stage1_unlabeled_unused.csv) - Papers NOT used in training
- [results/unused_unlabeled_predictions.csv](results/unused_unlabeled_predictions.csv) - Model predictions on unseen papers
- [shiny_app/data/predictions_for_app.csv](shiny_app/data/predictions_for_app.csv) - Final dataset for Shiny app

### 6. Predict on New Data

To run predictions on new PubMed data:

```bash
bash scripts/shell/run_new_predictions.sh
```

For detailed information, see [docs/README_PREDICTION.md](docs/README_PREDICTION.md)

### 7. Protein Name Enrichment (Optional)

To enrich predictions with protein names from UniProt:

```bash
bash scripts/shell/enrich_existing_data.sh
```

For detailed information, see [docs/README_ENRICHMENT.md](docs/README_ENRICHMENT.md)

---

## Shiny App

### Local Deployment

To launch the interactive interface locally:

```bash
cd shiny_app
Rscript -e "shiny::runApp('app.R')"
```

Open your browser and navigate to the displayed URL (typically `http://127.0.0.1:XXXX`)

For detailed information, see [docs/README_SHINY_APP.md](docs/README_SHINY_APP.md)

---

## Deployment

The SOORENA Shiny application can be deployed to cloud platforms for public access.

### DigitalOcean Deployment

**Technical Advantages:**
- Simple setup with no complex firewall configuration
- Better performance and faster network speeds
- Root access by default

**Resource Requirements:**
- Recommended: 4 GB RAM / 2 vCPUs
- Minimum: 2 GB RAM / 1 vCPU

**Quick Start:**

1. Create a Droplet (Ubuntu 22.04/24.04 LTS)

2. SSH into your droplet:
   ```bash
   ssh root@YOUR_DROPLET_IP
   ```

3. Copy and run setup script:
   ```bash
   # On your local machine
   cd deployment
   scp server_setup_digitalocean.sh root@YOUR_DROPLET_IP:~/

   # On the droplet
   bash server_setup_digitalocean.sh
   ```

4. Deploy the app from your local machine:
   ```bash
   cd deployment
   ./deploy_to_digitalocean.sh
   ```

5. Access your app:
   ```
   http://YOUR_DROPLET_IP:3838/soorena/
   ```

---

### Oracle Cloud Deployment

**Technical Advantages:**
- Free tier with generous resource limits
- Suitable for testing and low-traffic deployments

**Technical Considerations:**
- More complex firewall configuration required
- Lower performance compared to DigitalOcean

**Resource Requirements:**
- Minimum: VM.Standard.E2.1.Micro (1 GB RAM)

**Quick Start:**

1. Create a Compute Instance (Ubuntu 22.04)

2. Configure firewall (VCN Security Lists + instance firewall)

3. SSH into your instance and run setup:
   ```bash
   bash server_setup_1GB.sh
   ```

4. Deploy using:
   ```bash
   cd deployment
   ./deploy_to_oracle.sh
   ```

**Detailed Guide:** [deployment/1GB_RAM_INSTRUCTIONS.md](deployment/1GB_RAM_INSTRUCTIONS.md)

---

### Deployment Scripts

All deployment-related files are in the [deployment/](deployment/) directory:

- [server_setup_digitalocean.sh](deployment/server_setup_digitalocean.sh) - DigitalOcean server configuration
- [server_setup_1GB.sh](deployment/server_setup_1GB.sh) - Oracle Cloud setup (1GB RAM optimized)
- [deploy_to_digitalocean.sh](deployment/deploy_to_digitalocean.sh) - Deploy app to DigitalOcean
- [deploy_to_oracle.sh](deployment/deploy_to_oracle.sh) - Deploy app to Oracle Cloud
- [update_app.sh](deployment/update_app.sh) - Quick app updates (no full redeployment)

For step-by-step instructions, see:
- [deployment/README.md](deployment/README.md) - Deployment overview and technical documentation
- [deployment/USING_EXISTING_DROPLET.md](deployment/USING_EXISTING_DROPLET.md) - Reusing existing infrastructure

---

## Documentation

Comprehensive documentation is available in the [docs/](docs/) directory:

### Core Documentation
- [README_DATA_PREPARATION.md](docs/README_DATA_PREPARATION.md) - Data preprocessing pipeline
- [README_TRAINING.md](docs/README_TRAINING.md) - Model training (Stage 1 & 2)
- [README_PREDICTION.md](docs/README_PREDICTION.md) - Running predictions
- [README_PREDICTION_PIPELINE.md](docs/README_PREDICTION_PIPELINE.md) - Complete prediction workflow
- [README_ENRICHMENT.md](docs/README_ENRICHMENT.md) - Protein name enrichment from UniProt
- [README_SHINY_APP.md](docs/README_SHINY_APP.md) - Interactive web app usage

### Additional Documentation
- [deployment/README.md](deployment/README.md) - Deployment overview
- [data/processed/README.md](data/processed/README.md) - Processed data explanation

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

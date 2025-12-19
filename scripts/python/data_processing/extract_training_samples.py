#!/usr/bin/env python3
"""
Extract the unlabeled papers that were used during Stage 1 training.

This reproduces the exact sampling from train_stage1.py using the same random seed,
allowing us to identify which unlabeled papers were used for training.
"""
import sys
from pathlib import Path

# Add repository root to Python path
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

import pandas as pd
import config


def main():
    """Extract unlabeled papers used in Stage 1 training."""

    print("=" * 80)
    print("EXTRACT TRAINING SAMPLES - Identify Unlabeled Papers Used in Training")
    print("=" * 80)
    print()

    # Step 1: Load splits
    print("Step 1: Loading labeled train/val/test splits...")
    train_df = pd.read_csv(config.TRAIN_FILE)
    val_df = pd.read_csv(config.VAL_FILE)
    test_df = pd.read_csv(config.TEST_FILE)

    print(f"   Train: {len(train_df):,} labeled papers")
    print(f"   Val:   {len(val_df):,} labeled papers")
    print(f"   Test:  {len(test_df):,} labeled papers")
    print()

    # Step 2: Load full dataset
    print("Step 2: Loading full modeling dataset...")
    full_df = pd.read_csv(config.MODELING_DATASET_FILE)
    unlabeled_df = full_df[~full_df['has_mechanism']].copy()

    print(f"   Total papers: {len(full_df):,}")
    print(f"   Unlabeled:    {len(unlabeled_df):,}")
    print()

    # Step 3: Reproduce exact sampling (same logic as train_stage1.py)
    print("Step 3: Reproducing training sample (using random_state={})...".format(config.RANDOM_SEED))

    # Sample unlabeled for train (2:1 ratio)
    unlabeled_train = unlabeled_df.sample(n=len(train_df) * 2, random_state=config.RANDOM_SEED)
    remaining = unlabeled_df.drop(unlabeled_train.index)

    # Sample unlabeled for val (2:1 ratio)
    unlabeled_val = remaining.sample(n=len(val_df) * 2, random_state=config.RANDOM_SEED)
    remaining = remaining.drop(unlabeled_val.index)

    # Sample unlabeled for test (2:1 ratio)
    unlabeled_test = remaining.sample(n=len(test_df) * 2, random_state=config.RANDOM_SEED)

    print(f"   Unlabeled train: {len(unlabeled_train):,} papers")
    print(f"   Unlabeled val:   {len(unlabeled_val):,} papers")
    print(f"   Unlabeled test:  {len(unlabeled_test):,} papers")
    print(f"   Total sampled:   {len(unlabeled_train) + len(unlabeled_val) + len(unlabeled_test):,} papers")
    print()

    # Step 4: Get unused papers
    all_sampled_pmids = set(unlabeled_train['PMID']).union(
        set(unlabeled_val['PMID']),
        set(unlabeled_test['PMID'])
    )

    unused_unlabeled = unlabeled_df[~unlabeled_df['PMID'].isin(all_sampled_pmids)].copy()

    print(f"Step 4: Identifying unused unlabeled papers...")
    print(f"   Unused unlabeled: {len(unused_unlabeled):,} papers")
    print()

    # Step 5: Save results
    print("Step 5: Saving results...")

    # Save sampled unlabeled (used in training)
    sampled_df = pd.concat([unlabeled_train, unlabeled_val, unlabeled_test])
    sampled_df['split'] = (['train'] * len(unlabeled_train) +
                           ['val'] * len(unlabeled_val) +
                           ['test'] * len(unlabeled_test))
    sampled_output = 'data/processed/unlabeled_used_in_training.csv'
    sampled_df.to_csv(sampled_output, index=False)
    print(f"   ✓ Saved: {sampled_output}")
    print(f"     ({len(sampled_df):,} papers used in training as negative samples)")

    # Save unused unlabeled (for prediction)
    unused_output = 'data/processed/unlabeled_unused_for_prediction.csv'
    unused_unlabeled.to_csv(unused_output, index=False)
    print(f"   ✓ Saved: {unused_output}")
    print(f"     ({len(unused_unlabeled):,} papers to predict on)")
    print()

    # Summary
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Labeled papers (has mechanism):           {len(train_df) + len(val_df) + len(test_df):,}")
    print(f"Unlabeled used in training (no mechanism): {len(sampled_df):,}")
    print(f"Unlabeled unused (to predict on):         {len(unused_unlabeled):,}")
    print(f"{'':45} {'―' * 10}")
    print(f"Total:                                     {len(full_df):,}")
    print()
    print("Next steps:")
    print("  1. Run predictions on: data/processed/unlabeled_unused_for_prediction.csv")
    print("  2. For Shiny app, combine:")
    print("     - Labeled papers (train+val+test)")
    print("     - Unlabeled used in training (labeled as 'no mechanism')")
    print("     - Predictions on unused unlabeled")
    print("     - New 3M predictions")
    print("=" * 80)


if __name__ == "__main__":
    main()

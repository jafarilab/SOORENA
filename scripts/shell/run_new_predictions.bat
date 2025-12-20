@echo off
REM ================================================================================
REM SOORENA - New Predictions Pipeline (Windows)
REM ================================================================================
REM This script runs predictions on new PubMed data and merges results with
REM existing predictions for the Shiny app.
REM
REM Usage:
REM   run_new_predictions.bat [--test]
REM
REM Options:
REM   --test    Run in test mode (only process first 100 rows)
REM
REM Requirements:
REM   - Conda environment 'autoregulatory' activated
REM   - Input file: data\pred\abstracts-authors-date.tsv
REM   - Models trained: models\stage1_best.pt, models\stage2_best.pt
REM ================================================================================

setlocal enabledelayedexpansion

REM Parse arguments
set TEST_MODE=
if "%1"=="--test" (
    set TEST_MODE=--test-mode
    echo WARNING: Running in TEST MODE (first 100 rows only^)
)

echo ========================================
echo SOORENA - New Predictions Pipeline
echo ========================================
echo.

REM Step 1: Check environment
echo [Step 1/4] Checking environment...

python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found
    echo Please activate the conda environment:
    echo   conda activate autoregulatory
    exit /b 1
)

echo OK: Python found
python --version

REM Check if input file exists
if not exist "data\pred\abstracts-authors-date.tsv" (
    echo ERROR: Input file not found
    echo Expected: data\pred\abstracts-authors-date.tsv
    exit /b 1
)

echo OK: Input file found

REM Check if models exist
if not exist "models\stage1_best.pt" (
    echo ERROR: Model file not found: models\stage1_best.pt
    exit /b 1
)

if not exist "models\stage2_best.pt" (
    echo ERROR: Model file not found: models\stage2_best.pt
    exit /b 1
)

echo OK: Model files found
echo.

REM Step 2: Run predictions
echo [Step 2/4] Running predictions...
echo This may take several hours for large datasets.
echo Checkpoints are saved every 10,000 predictions.
echo.

python predict_new_data.py --input data\pred\abstracts-authors-date.tsv --output results\new_predictions.csv --checkpoint-interval 10000 %TEST_MODE%

if errorlevel 1 (
    echo ERROR: Prediction failed
    exit /b 1
)

echo.
echo OK: Predictions complete
echo.

REM Step 3: Merge with existing data
echo [Step 3/4] Merging with existing predictions...

python scripts/python/data_processing/merge_final_shiny_data.py

if errorlevel 1 (
    echo ERROR: Merge failed
    exit /b 1
)

echo.
echo OK: Merge complete
echo.

REM Step 4: Summary
echo [Step 4/4] Summary
echo ========================================
echo OK: Pipeline completed successfully
echo ========================================
echo.
echo Output files:
echo   - results\new_predictions.csv (new predictions^)
echo   - shiny_app\data\predictions_for_app.csv (merged data for Shiny app^)
echo.
echo Next steps:
echo   1. Launch the Shiny app to view results:
echo      cd shiny_app ^&^& Rscript -e "shiny::runApp('app.R'^)"
echo.
echo   2. Or commit changes to git and share results
echo.
echo Done
pause

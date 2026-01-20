#!/bin/bash
#SBATCH --job-name=ai_paper_generator
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=paper_gen_%j.out
#SBATCH --error=paper_gen_%j.err

# Navigate to the working directory
cd /data

# Create and activate a Python virtual environment
python -m venv paper_env
source paper_env/bin/activate

# Install required packages
pip install openai arxiv scholarly numpy pandas matplotlib seaborn scikit-learn transformers torch

# Run the academic paper generation
python academic_paper_agent.py \
    --topic "High Performance Computing and AI Integration" \
    --api-key "dummy_api_key_for_demo" \
    --output-dir "./paper_output" \
    --experimental-data "./sample_data.json"

echo "Paper generation completed!"

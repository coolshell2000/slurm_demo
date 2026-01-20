import os
import json
import argparse
from literature_review_agent import LiteratureReviewAgent
from content_generation_agent import ContentGenerationAgent
from analysis_agent import AnalysisAgent

def main():
    parser = argparse.ArgumentParser(description="Academic Paper Generation Agent")
    parser.add_argument("--topic", required=True, help="Research topic")
    parser.add_argument("--api-key", required=True, help="OpenAI API key")
    parser.add_argument("--output-dir", default="./paper_output", help="Output directory")
    parser.add_argument("--experimental-data", help="Path to experimental data JSON")
    
    args = parser.parse_args()
    
    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Initialize agents
    lit_agent = LiteratureReviewAgent(args.api_key, args.topic)
    content_agent = ContentGenerationAgent(args.api_key, args.topic)
    analysis_agent = AnalysisAgent(args.topic)
    
    print("Starting academic paper generation...")
    
    # Step 1: Literature review
    print("1. Conducting literature review...")
    papers = lit_agent.search_relevant_papers(max_results=30)
    literature_analysis = lit_agent.analyze_papers(papers)
    
    # Save literature analysis
    with open(f"{args.output_dir}/literature_review.json", "w") as f:
        json.dump({
            "papers": papers,
            "analysis": literature_analysis
        }, f, indent=2)
    
    # Step 2: Load experimental data if provided
    experimental_data = {}
    if args.experimental_data:
        with open(args.experimental_data, "r") as f:
            experimental_data = json.load(f)
    
    # Step 3: Perform analysis
    print("2. Performing analysis...")
    analysis_results = analysis_agent.analyze_results(experimental_data)
    viz_path = analysis_agent.generate_visualizations(experimental_data, args.output_dir)
    
    # Step 4: Generate paper content
    print("3. Generating paper content...")
    
    # Create paper outline
    outline = {
        "Introduction": {
            "context": f"This paper addresses {args.topic} by proposing a novel approach that builds on recent advances in the field."
        },
        "Related Work": {
            "context": literature_analysis
        },
        "Methodology": {
            "context": "Detailed description of the proposed methodology."
        },
        "Experiments": {
            "context": "Experimental setup and evaluation methodology."
        },
        "Results": {
            "context": f"Results showing {analysis_results}"
        },
        "Discussion": {
            "context": "Discussion of results and implications."
        },
        "Conclusion": {
            "context": "Summary of contributions and future work."
        }
    }
    
    # Generate sections
    sections = content_agent.generate_sections(outline, experimental_data)
    
    # Generate abstract
    abstract = content_agent.generate_abstract(
        f"Novel approach to {args.topic} with results showing {analysis_results}",
        [args.topic, "machine learning", "novel contribution"]
    )
    
    # Compile final paper
    paper_content = {
        "title": f"A Novel Approach to {args.topic}: Advancing the State of the Art",
        "abstract": abstract,
        "sections": sections,
        "references": papers[:10],  # Top 10 references
        "figures": [viz_path],
        "analysis": analysis_results
    }
    
    # Save final paper
    with open(f"{args.output_dir}/final_paper.json", "w") as f:
        json.dump(paper_content, f, indent=2)
    
    # Generate LaTeX template
    generate_latex_template(paper_content, args.output_dir)
    
    print(f"Paper generation completed! Output saved to {args.output_dir}")

def generate_latex_template(paper_content, output_dir):
    """Generate LaTeX template for the paper"""
    latex_content = f"""
\\documentclass[12pt]{{article}}
\\usepackage[utf8]{{inputenc}}
\\usepackage[T1]{{fontenc}}
\\usepackage{{amsmath,amsfonts,amssymb}}
\\usepackage{{graphicx}}
\\usepackage{{url}}
\\usepackage{{hyperref}}

\\title{{{paper_content["title"]}}}
\\author{{AI Research Assistant}}

\\begin{{document}}

\\maketitle

\\begin{{abstract}}
{paper_content["abstract"]}
\\end{{abstract}}

"""
    
    for section_title, content in paper_content["sections"].items():
        latex_content += f"""
\\section{{{section_title.replace("_", " ").title()}}}
{content}

"""
    
    latex_content += """
\\section{References}
% References would go here

\\end{document}
"""
    
    with open(f"{output_dir}/paper.tex", "w") as f:
        f.write(latex_content)

if __name__ == "__main__":
    main()

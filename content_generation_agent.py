import openai
from transformers import pipeline
import json

class ContentGenerationAgent:
    def __init__(self, api_key, research_area):
        self.api_key = api_key
        self.research_area = research_area
        self.client = openai.OpenAI(api_key=api_key)
        
    def generate_abstract(self, research_summary, keywords):
        """Generate abstract based on research summary"""
        prompt = f"""
        Generate a compelling academic abstract for a research paper in {self.research_area}.
        Research Summary: {research_summary}
        Keywords: {", ".join(keywords)}
        
        The abstract should be 150-250 words, clearly stating:
        1. Problem addressed
        2. Methodology used
        3. Key findings
        4. Significance of the work
        """
        
        response = self.client.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500
        )
        
        return response.choices[0].message.content
    
    def generate_sections(self, outline, research_data):
        """Generate content for each section of the paper"""
        sections = {}
        
        for section_title, section_info in outline.items():
            prompt = f"""
            Generate content for the "{section_title}" section of an academic paper in {self.research_area}.
            
            Context: {section_info.get("context", "")}
            Research Data: {json.dumps(research_data, indent=2)[:2000]}
            
            Requirements:
            - Academic tone and style
            - Proper citations where needed
            - Clear and concise language
            - Technical accuracy
            """
            
            response = self.client.chat.completions.create(
                model="gpt-4",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=1500
            )
            
            sections[section_title] = response.choices[0].message.content
            
        return sections

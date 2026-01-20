import openai
import arxiv
import requests
from scholarly import scholarly
import json

class LiteratureReviewAgent:
    def __init__(self, api_key, research_topic):
        self.api_key = api_key
        self.topic = research_topic
        self.client = openai.OpenAI(api_key=api_key)
        
    def search_relevant_papers(self, max_results=20):
        """Search for relevant papers using multiple sources"""
        papers = []
        
        # Search arXiv
        search = arxiv.Search(
            query=self.topic,
            max_results=max_results,
            sort_by=arxiv.SortCriterion.Relevance
        )
        
        for result in search.results():
            papers.append({
                "title": result.title,
                "abstract": result.summary,
                "authors": [author.name for author in result.authors],
                "published": str(result.published),
                "url": result.entry_id
            })
            
        return papers
    
    def analyze_papers(self, papers):
        """Analyze papers to identify key themes and gaps"""
        paper_texts = "\\n\\n".join([
            f"Title: {p["title"]}\\nAbstract: {p["abstract"][:500]}..." 
            for p in papers
        ])
        
        prompt = f"""
        Analyze the following research papers on "{self.topic}" and identify:
        1. Key themes and trends
        2. Research gaps
        3. Methodologies used
        4. Important findings
        5. Future directions
        
        Papers:
        {paper_texts}
        """
        
        response = self.client.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=2000
        )
        
        return response.choices[0].message.content

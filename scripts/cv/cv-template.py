#!/usr/bin/env python3
"""
CV Template Engine - Handles LaTeX template generation and optimization
"""

import re
from typing import Dict, List, Tuple


class CVTemplateEngine:
    """Template engine for CV generation with LaTeX output"""
    
    def __init__(self):
        """Initialize template engine"""
        self.latex_escape_chars = {
            '&': r'\&',
            '%': r'\%',
            '$': r'\$',
            '#': r'\#',
            '_': r'\_',
            '{': r'\{',
            '}': r'\}',
            '~': r'\textasciitilde{}',
            '^': r'\^{}',
            '\\': r'\textbackslash{}'
        }
    
    def escape_latex(self, text: str) -> str:
        """Escape special LaTeX characters"""
        for char, escaped in self.latex_escape_chars.items():
            text = text.replace(char, escaped)
        return text
    
    def generate_header(self, metadata: Dict) -> str:
        """Generate CV header with personal information"""
        return r"""\documentclass{resume} % Use the custom resume.cls style

\usepackage[left=0.75in,top=0.6in,right=0.75in,bottom=0.6in]{geometry} % Document margins
\usepackage{fontawesome5} % For icons
\usepackage{enumitem} % For custom lists
\usepackage{xcolor} % For colors

% Define custom colors
\definecolor{iconblue}{RGB}{0, 102, 204}

\newcommand{\tab}[1]{\hspace{.2667\textwidth}\rlap{#1}}
\newcommand{\itab}[1]{\hspace{0em}\rlap{#1}}
\name{Mohammed Islam} % Your name
\address{{\color{iconblue}\faPhone}\ +44 751 234 9133 {\color{iconblue}\faEnvelope}\ mohammed.islam9494@gmail.com }

\begin{document}
"""
    
    def generate_title(self, requirements: Dict, metadata: Dict) -> str:
        """Generate title section based on job requirements"""
        # Determine title based on job type and requirements
        if 'kubernetes' in str(requirements).lower():
            if 'senior' in str(requirements).lower():
                title = "Senior Platform Engineer | Kubernetes & Cloud Infrastructure Specialist"
            else:
                title = "Platform Engineer | Kubernetes & Cloud Infrastructure"
        elif 'devops' in str(requirements).lower():
            title = "Senior DevOps Engineer | Cloud Infrastructure & Automation"
        else:
            title = "Senior Platform Engineer | Cloud Infrastructure Specialist"
        
        return f"""
%----------------------------------------------------------------------------------------
%	TITLE SECTION
%----------------------------------------------------------------------------------------

\\begin{{center}}
{{\\Large \\textbf{{{title}}}}}
\\end{{center}}
"""
    
    def generate_summary_section(self, summary: str) -> str:
        """Generate professional summary section"""
        return f"""
%----------------------------------------------------------------------------------------
%	PROFILE SECTION
%----------------------------------------------------------------------------------------

\\begin{{rSection}}{{\\faUser\\ Summary}}
\\smallbreak
\\normalfont {summary}
\\end{{rSection}}
"""
    
    def generate_certifications_section(self, certifications: List[str], requirements: Dict) -> str:
        """Generate certifications section prioritized by requirements"""
        # Prioritize certifications based on requirements
        priority_certs = []
        other_certs = []
        
        req_text = str(requirements).lower()
        
        for cert in certifications:
            cert_lower = cert.lower()
            if 'aws' in req_text and 'aws' in cert_lower:
                priority_certs.append(cert)
            elif 'terraform' in req_text and 'terraform' in cert_lower:
                priority_certs.append(cert)
            elif 'azure' in req_text and 'azure' in cert_lower:
                priority_certs.append(cert)
            elif 'google' in req_text and 'gcp' in cert_lower:
                priority_certs.append(cert)
            else:
                other_certs.append(cert)
        
        # Combine with priority first
        all_certs = priority_certs + other_certs
        
        # Limit to top 4-5 certifications
        display_certs = all_certs[:5]
        
        cert_items = "\n".join([f"\\item \\textbf{{{self.escape_latex(cert)}}}" 
                               for cert in display_certs])
        
        return f"""
%----------------------------------------------------------------------------------------
%	CERTIFICATIONS SECTION
%----------------------------------------------------------------------------------------

\\begin{{rSection}}{{\\faCertificate\\ Certifications}}
\\begin{{itemize}}[leftmargin=1em, nosep]
{cert_items}
\\end{{itemize}}
\\end{{rSection}}
"""
    
    def generate_skills_section(self, skills_latex: str) -> str:
        """Generate technical skills section"""
        return f"""
%----------------------------------------------------------------------------------------
%	CORE TECHNICAL SKILLS SECTION
%----------------------------------------------------------------------------------------

\\begin{{rSection}}{{\\faCode\\ Core Technical Skills}}
\\smallbreak

{skills_latex}
\\end{{rSection}}
"""
    
    def generate_experience_section(self, experiences: List[Dict]) -> str:
        """Generate work experience section"""
        exp_latex = """
%----------------------------------------------------------------------------------------
%	WORK EXPERIENCE SECTION
%----------------------------------------------------------------------------------------

\\begin{rSection}{\\faBriefcase\\ Professional Experience}
\\smallbreak
"""
        
        for exp in experiences:
            company = self.escape_latex(exp.get('company', ''))
            position = self.escape_latex(exp.get('position', ''))
            dates = exp.get('dates', '')
            location = exp.get('location', '')
            bullets = exp.get('bullets', [])
            
            exp_latex += f"""\\begin{{rSubsection}}{{{company}}}{{{dates}}}
{{{position}}}{{{location}}}
\\normalfont
"""
            
            for bullet in bullets:
                clean_bullet = self.escape_latex(bullet)
                exp_latex += f"\\item {clean_bullet}\n"
            
            exp_latex += "\\end{rSubsection}\n\n"
        
        exp_latex += "\\end{rSection}\n"
        
        return exp_latex
    
    def generate_education_section(self) -> str:
        """Generate education section"""
        return """
%----------------------------------------------------------------------------------------
%	EDUCATION SECTION
%----------------------------------------------------------------------------------------

\\begin{rSection}{\\faGraduationCap\\ Education}
\\smallbreak
{\\bf University of Warwick} \\hfill { September 2013 - August 2017} 
\\\\ \\normalfont Department of Engineering - MEng Systems Engineering  
\\end{rSection}

%----------------------------------------------------------------------------------------

\\end{document}"""
    
    def optimize_bullet_points(self, bullets: List[str], requirements: Dict, 
                              max_bullets: int = 5) -> List[str]:
        """Optimize and select most relevant bullet points"""
        scored_bullets = []
        req_text = str(requirements).lower()
        tech_list = requirements.get('technologies', [])
        
        for bullet in bullets:
            score = 0
            bullet_lower = bullet.lower()
            
            # Score based on technology matches
            for tech in tech_list:
                if tech in bullet_lower:
                    score += 10
            
            # Score based on keyword matches
            keywords = ['kubernetes', 'terraform', 'aws', 'automation', 'ci/cd', 
                       'cost', 'optimization', 'leadership', 'team', 'production']
            
            for keyword in keywords:
                if keyword in bullet_lower:
                    score += 5
            
            # Score based on quantifiable achievements
            if any(char.isdigit() for char in bullet):
                score += 3
            
            if '%' in bullet or '$' in bullet:
                score += 3
            
            scored_bullets.append((bullet, score))
        
        # Sort by score and select top bullets
        scored_bullets.sort(key=lambda x: x[1], reverse=True)
        
        return [bullet for bullet, score in scored_bullets[:max_bullets]]
    
    def estimate_page_length(self, content: str) -> float:
        """Estimate number of pages for LaTeX content"""
        # Rough estimation based on character and line count
        lines = content.count('\n')
        chars = len(content)
        
        # Approximate: 50 lines per page, adjust for LaTeX overhead
        estimated_pages = (lines / 45) + (chars / 3000)
        
        return min(estimated_pages, 3.0)
    
    def adjust_content_for_length(self, content: str, target_pages: int = 2) -> str:
        """Adjust content to fit target page length"""
        current_estimate = self.estimate_page_length(content)
        
        if current_estimate > target_pages + 0.3:
            # Need to reduce content
            # Remove older experience bullets
            pattern = r'(\\begin\{rSubsection\}.*?September 2017.*?\\end\{rSubsection\})'
            match = re.search(pattern, content, re.DOTALL)
            
            if match:
                # Reduce bullets in older roles
                old_section = match.group(1)
                # Keep only 2 bullets per older role
                modified = re.sub(r'(\\item.*?\n)(\\item.*?\n)(\\item.*?\n)+', 
                                 r'\1\2', old_section)
                content = content.replace(old_section, modified)
        
        return content
    
    def format_employment_entry(self, company: str, position: str, dates: str, 
                               location: str, bullets: List[str]) -> Dict:
        """Format employment entry for template"""
        return {
            'company': company,
            'position': position,
            'dates': dates,
            'location': location,
            'bullets': bullets
        }
    
    def extract_experiences_from_template(self, template_content: str) -> List[Dict]:
        """Extract existing experiences from CV template"""
        experiences = []
        
        # Define company patterns
        companies = [
            ('Phillip Morris International', 'June 2024 - Present', 
             'Senior Platform Engineer - Cloud Infrastructure & Kubernetes', 'London, UK'),
            ('HMRC', 'January 2023 - March 2024',
             'Site Reliability Engineer - Platform Squad', 'London, UK'),
            ('William Hill', 'June 2022 - January 2023',
             'Site Reliability Engineer - Kubernetes Platform', 'Leeds, UK'),
            ('Nationwide Building Society', 'September 2017 - June 2022',
             'Site Reliability Engineer - Enterprise Kubernetes Team', 'London, UK')
        ]
        
        # Extract pattern for each company
        for company, dates, position, location in companies:
            exp = {
                'company': company,
                'dates': dates,
                'position': position,
                'location': location,
                'bullets': []
            }
            experiences.append(exp)
        
        return experiences
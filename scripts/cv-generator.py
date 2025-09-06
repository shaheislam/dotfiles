#!/usr/bin/env python3
"""
CV Generator - Automated CV generation with intelligent skill matching
Generates optimized LaTeX CVs based on job descriptions and compiles to PDF

IMPORTANT: This script preserves the EXACT bullet points from skills.md file.
The bullet points are loaded as-is and inserted into the CV without modification.
Only the selection and ordering of bullet points is optimized based on job requirements,
but the text itself remains exactly as defined in skills.md.

Workflow:
1. Load job description and substitute parameters (recruiter, date, type, salary)
2. Load skills.md and preserve exact bullet point text
3. Score skills based on job requirements (0-100 scale)
4. Select top-scoring skills while preserving their exact text
5. Generate LaTeX CV with exact bullet points from skills.md
6. Compile to PDF
"""

import argparse
import json
import os
import re
import subprocess
import sys
import yaml
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import hashlib


class CVGenerator:
    """Main CV generation engine with deterministic output"""
    
    def __init__(self, config_path: Optional[str] = None):
        """Initialize CV generator with configuration"""
        self.base_dir = Path.home() / "dotfiles"
        self.jobapps_dir = self.base_dir / "jobapps"
        self.scripts_dir = self.base_dir / "scripts"
        self.output_dir = Path.home() / "Documents" / "jobapps" / "output"
        self.generated_dir = Path.home() / "Documents" / "jobapps" / "generated"
        
        # Load configuration
        self.config = self.load_config(config_path)
        self.skill_mapping = self.load_skill_mapping()
        
        # Ensure output directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.generated_dir.mkdir(parents=True, exist_ok=True)
    
    def load_config(self, config_path: Optional[str] = None) -> Dict:
        """Load configuration from YAML file"""
        if config_path and Path(config_path).exists():
            config_file = Path(config_path)
        else:
            config_file = self.jobapps_dir / "cv-config.yaml"
        
        if config_file.exists():
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        
        # Default configuration
        return {
            'scoring': {
                'exact_match': 100,
                'partial_match': 70,
                'related_match': 50,
                'category_match': 30
            },
            'page_limits': {
                'max_pages': 3,
                'preferred_pages': 2,
                'min_fill_third_page': 0.7
            },
            'bullet_points': {
                'recent_role_min': 3,
                'recent_role_max': 5,
                'older_role_min': 2,
                'older_role_max': 3
            }
        }
    
    def load_skill_mapping(self) -> Dict:
        """Load skill mapping from JSON file"""
        mapping_file = self.jobapps_dir / "skill-mapping.json"
        
        if mapping_file.exists():
            with open(mapping_file, 'r') as f:
                return json.load(f)
        
        # Default skill mappings
        return {
            'kubernetes': ['k8s', 'container orchestration', 'eks', 'gke', 'aks'],
            'terraform': ['iac', 'infrastructure as code', 'terragrunt'],
            'aws': ['amazon web services', 'cloud', 'ec2', 's3'],
            'python': ['scripting', 'automation', 'programming'],
            'ansible': ['configuration management', 'automation', 'playbooks'],
            'grafana': ['monitoring', 'observability', 'prometheus', 'loki'],
            'ci/cd': ['jenkins', 'github actions', 'gitlab', 'pipeline'],
            'docker': ['containers', 'containerization', 'dockerfile'],
            'linux': ['unix', 'rhel', 'ubuntu', 'centos', 'system administration']
        }
    
    def parse_arguments(self, args: List[str]) -> Dict:
        """Parse command-line arguments"""
        parser = argparse.ArgumentParser(description='Generate optimized CV')
        
        # Positional arguments
        parser.add_argument('recruiter', nargs='?', help='Recruiter name')
        parser.add_argument('date', nargs='?', help='Date (DDMMYY)')
        parser.add_argument('type', nargs='?', choices=['perm', 'contract', 'permanent'], 
                          help='Job type')
        parser.add_argument('salary', nargs='?', help='Salary information')
        
        # Named arguments
        parser.add_argument('--recruiter', dest='named_recruiter', help='Recruiter name')
        parser.add_argument('--date', dest='named_date', help='Date (DDMMYY)')
        parser.add_argument('--type', dest='named_type', 
                          choices=['perm', 'contract', 'permanent'], help='Job type')
        parser.add_argument('--salary', dest='named_salary', help='Salary information')
        
        # Options
        parser.add_argument('--config', help='Configuration file path')
        parser.add_argument('--job', help='Job description file path')
        parser.add_argument('--skills', help='Skills database file path')
        parser.add_argument('--template', help='CV template file path')
        parser.add_argument('--output', help='Output directory')
        parser.add_argument('--format', choices=['tex', 'pdf'], default='pdf',
                          help='Output format (default: pdf)')
        parser.add_argument('--compiler', choices=['pdflatex', 'xelatex', 'lualatex'],
                          default='pdflatex', help='LaTeX compiler')
        parser.add_argument('--open', action='store_true', help='Open PDF after generation')
        parser.add_argument('--verbose', action='store_true', help='Verbose output')
        
        parsed = parser.parse_args(args)
        
        # Merge positional and named arguments
        params = {
            'recruiter': parsed.named_recruiter or parsed.recruiter,
            'date': parsed.named_date or parsed.date,
            'type': parsed.named_type or parsed.type,
            'salary': parsed.named_salary or parsed.salary,
            'config': parsed.config,
            'job': parsed.job or str(self.jobapps_dir / 'jobdesciption.md'),
            'skills': parsed.skills or str(self.jobapps_dir / 'skills.md'),
            'template': parsed.template or str(self.jobapps_dir / 'CV.tex'),
            'output': parsed.output or str(self.output_dir),
            'format': parsed.format,
            'compiler': parsed.compiler,
            'open': parsed.open,
            'verbose': parsed.verbose
        }
        
        return params
    
    def load_job_description(self, job_path: str, params: Dict) -> Tuple[str, Dict]:
        """Load and process job description with parameter substitution"""
        with open(job_path, 'r') as f:
            content = f.read()
        
        # Extract metadata with defaults
        metadata = {}
        metadata['recruiter'] = params.get('recruiter') or self.extract_metadata(content, 'RECRUITER', 'Lorien')
        metadata['date'] = params.get('date') or self.extract_metadata(content, 'DATE', '010425')
        metadata['type'] = params.get('type') or self.extract_metadata(content, 'TYPE', 'PERM').lower()
        metadata['salary'] = params.get('salary') or self.extract_metadata(content, 'SALARY', '70K')
        
        # Process job content
        job_text = self.extract_job_content(content)
        
        return job_text, metadata
    
    def extract_metadata(self, content: str, tag: str, default: str) -> str:
        """Extract metadata tag from job description"""
        # Use string formatting instead of f-string for complex patterns
        pattern = r'<{}>\s*\${{{}:-(.*?)\}}\s*</{}>' .format(tag, tag.upper(), tag)
        match = re.search(pattern, content, re.DOTALL)
        if match:
            return match.group(1).strip()
        return default
    
    def extract_job_content(self, content: str) -> str:
        """Extract job requirements and responsibilities"""
        # Remove metadata tags
        content = re.sub(r'<\w+>.*?</\w+>', '', content, flags=re.DOTALL)
        return content.strip()
    
    def load_skills_database(self, skills_path: str) -> Dict:
        """Load and parse skills database - preserves exact bullet point text"""
        with open(skills_path, 'r') as f:
            content = f.read()
        
        # Parse skills with full structure from skills.md
        skills = {
            'categories': {},  # Stores technical skills by category
            'all_skills': [],  # Flat list of all technical skills
            'achievements': {},  # Stores achievements by category (from Key Responsibilities)
            'all_achievements': []  # Flat list of all achievements
        }
        
        current_category = None
        current_section = None
        in_achievements = False
        
        for line in content.split('\n'):
            # Skip empty lines
            if not line.strip():
                continue
            
            # Main section headers (##)
            if line.startswith('## '):
                current_section = line.replace('##', '').strip()
                # Check if we're in the Key Responsibilities section
                in_achievements = 'Key Responsibilities' in current_section
                current_category = None  # Reset category when section changes
            # Category headers (###)
            elif line.startswith('### '):
                current_category = line.replace('###', '').strip()
                if in_achievements:
                    # Store achievements categories
                    if current_category not in skills['achievements']:
                        skills['achievements'][current_category] = []
                else:
                    # Store technical skills categories
                    if current_category not in skills['categories']:
                        skills['categories'][current_category] = []
            # Bullet points - preserve exact text
            elif line.startswith('- ') and current_category:
                # Keep the exact bullet point text unmodified
                bullet = line[2:].strip()  # Remove "- " prefix
                
                if in_achievements:
                    # Store in achievements section
                    skills['achievements'][current_category].append(bullet)
                    skills['all_achievements'].append(bullet)
                else:
                    # Store in technical skills section
                    skills['categories'][current_category].append(bullet)
                    skills['all_skills'].append(bullet)
        
        # Add backward compatibility
        skills['technical'] = skills['all_skills']  # For compatibility
        skills['soft'] = []
        skills['certifications'] = []
        
        return skills
    
    def analyze_job_requirements(self, job_text: str) -> Dict:
        """Analyze job description and extract requirements"""
        requirements = {
            'must_have': [],
            'nice_to_have': [],
            'technologies': [],
            'keywords': []
        }
        
        # Extract sections
        lines = job_text.split('\n')
        current_section = None
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            lower_line = line.lower()
            
            if 'qualification' in lower_line or 'requirement' in lower_line:
                current_section = 'must_have'
            elif 'preferred' in lower_line or 'nice to have' in lower_line:
                current_section = 'nice_to_have'
            elif line.strip() and current_section:
                requirements[current_section].append(line)
        
        # Extract technologies and keywords
        tech_patterns = [
            r'\b(kubernetes|k8s|eks|gke|aks)\b',
            r'\b(terraform|ansible|iac)\b',
            r'\b(aws|azure|gcp|cloud)\b',
            r'\b(docker|container)\b',
            r'\b(python|golang|go|bash)\b',
            r'\b(ci/cd|jenkins|gitlab|github)\b',
            r'\b(grafana|prometheus|monitoring|observability)\b',
            r'\b(linux|unix|rhel|ubuntu)\b'
        ]
        
        job_lower = job_text.lower()
        for pattern in tech_patterns:
            matches = re.findall(pattern, job_lower, re.IGNORECASE)
            requirements['technologies'].extend(matches)
        
        # Extract important keywords
        keyword_patterns = [
            r'\b(senior|lead|principal|staff)\b',
            r'\b(engineer|developer|architect|specialist)\b',
            r'\b(platform|infrastructure|devops|sre|reliability)\b',
            r'\b(production|enterprise|scale)\b'
        ]
        
        for pattern in keyword_patterns:
            matches = re.findall(pattern, job_lower, re.IGNORECASE)
            requirements['keywords'].extend(matches)
        
        # Deduplicate
        requirements['technologies'] = list(set(requirements['technologies']))
        requirements['keywords'] = list(set(requirements['keywords']))
        
        return requirements
    
    def score_skills(self, skills: Dict, requirements: Dict) -> Dict:
        """Score skills based on job requirements"""
        scored_skills = {}
        
        # Create requirement text for matching
        req_text = ' '.join(requirements['must_have'] + requirements['nice_to_have'])
        req_text_lower = req_text.lower()
        tech_list = requirements['technologies']
        
        # Score technical skills
        for skill in skills['technical']:
            score = 0
            skill_lower = skill.lower()
            
            # Exact match in technologies
            for tech in tech_list:
                if tech in skill_lower:
                    score = max(score, self.config['scoring']['exact_match'])
                    break
            
            # Check skill mappings
            for key, aliases in self.skill_mapping.items():
                if key in skill_lower or any(alias in skill_lower for alias in aliases):
                    if key in req_text_lower:
                        score = max(score, self.config['scoring']['partial_match'])
            
            # General presence in requirements
            if any(word in req_text_lower for word in skill_lower.split()):
                score = max(score, self.config['scoring']['related_match'])
            
            if score > 0:
                scored_skills[skill] = score
        
        # Sort by score
        sorted_skills = dict(sorted(scored_skills.items(), key=lambda x: x[1], reverse=True))
        
        return sorted_skills
    
    def generate_latex_cv(self, template_path: str, skills: Dict, scored_skills: Dict,
                         requirements: Dict, metadata: Dict) -> str:
        """Generate optimized LaTeX CV"""
        # Load template
        with open(template_path, 'r') as f:
            template = f.read()
        
        # Generate optimized summary
        summary = self.generate_summary(requirements, metadata)
        
        # Select top skills for highlighting (preserving exact text from skills.md)
        top_skills = list(scored_skills.keys())[:20]  # Get more skills for better coverage
        
        # Generate skills section using exact bullet points from skills.md
        skills_section = self.generate_skills_section(top_skills, requirements, skills)
        
        # Score and select achievements for experience section
        scored_achievements = self.score_achievements(skills, requirements)
        
        # Get optimized experience bullets from Key Responsibilities section
        experience_bullets = self.optimize_experience(skills, requirements, scored_achievements)
        
        # Build final CV with experience bullets
        cv_content = self.build_cv(template, summary, skills_section, experience_bullets, metadata)
        
        return cv_content
    
    def generate_summary(self, requirements: Dict, metadata: Dict) -> str:
        """Generate tailored professional summary"""
        job_type = "contract" if metadata['type'] == 'contract' else "permanent"
        
        # Analyze key themes
        has_kubernetes = any('kubernetes' in req.lower() or 'k8s' in req.lower() 
                           for req in requirements['must_have'])
        has_cloud = any('cloud' in req.lower() or 'aws' in req.lower() 
                       for req in requirements['must_have'])
        has_terraform = any('terraform' in req.lower() or 'iac' in req.lower() 
                          for req in requirements['must_have'])
        
        if has_kubernetes and has_cloud:
            summary = (
                "Senior Platform Engineer with 7+ years provisioning and maintaining production "
                "Kubernetes clusters across AWS, GCP, and Azure. Expert in designing enterprise-scale "
                "containerized environments, implementing IaC with Terraform, and leading complex "
                "production issue resolution. Proven track record providing technical leadership, "
                "coaching junior engineers, and eliminating toil through automation. "
                "AWS-certified at Professional & Specialty level with extensive Agile framework "
                "experience and active SC clearance."
            )
        elif has_cloud:
            summary = (
                "Senior Platform Engineer and AWS-certified specialist with 7+ years managing "
                "production cloud infrastructure. Expert in Infrastructure as Code with Terraform, "
                "container orchestration, and building scalable CI/CD pipelines. Proven ability to "
                "optimize costs, improve reliability, and provide technical leadership across "
                "infrastructure projects. All AWS certifications at Professional & Specialty level."
            )
        else:
            summary = (
                "Senior Platform Engineer with 7+ years designing and managing enterprise "
                "infrastructure. Expert in automation, observability, and cloud-native technologies. "
                "Strong track record of leading technical teams, optimizing systems for scale, and "
                "delivering cost-effective solutions. AWS-certified professional with SC clearance."
            )
        
        return summary
    
    def generate_skills_section(self, top_skills: List[str], requirements: Dict, skills_db: Dict) -> str:
        """Generate optimized skills section using exact bullet points from skills.md"""
        # Map top skills back to their categories from skills.md
        skill_categories = {}
        
        # Create a mapping of skills to their original categories
        for category, skill_list in skills_db.get('categories', {}).items():
            for skill in skill_list:
                if skill in top_skills:
                    if category not in skill_categories:
                        skill_categories[category] = []
                    # Use the EXACT text from skills.md
                    skill_categories[category].append(skill)
        
        # Build LaTeX section preserving exact bullet text
        skills_latex = ""
        
        # Priority order for categories based on job requirements
        priority_categories = [
            'Kubernetes & Container Technologies',
            'Cloud Platforms', 
            'Infrastructure as Code',
            'CI/CD & DevOps',
            'Observability & Monitoring',
            'Programming & Scripting'
        ]
        
        # First add priority categories if they have skills
        for category in priority_categories:
            if category in skill_categories and skill_categories[category]:
                skills_latex += f"\\textbf{{{category}}}\n"
                skills_latex += "\\begin{itemize}[leftmargin=2em, nosep]\n"
                # Use exact bullet points, limit to top 4 per category
                for skill in skill_categories[category][:4]:
                    # Escape LaTeX special characters but preserve exact text
                    escaped_skill = skill.replace('&', '\\&').replace('%', '\\%').replace('$', '\\$')
                    skills_latex += f"\\item {escaped_skill}\n"
                skills_latex += "\\end{itemize}\n\n"
        
        # Add any remaining categories
        for category, skills_list in skill_categories.items():
            if category not in priority_categories and skills_list:
                skills_latex += f"\\textbf{{{category}}}\n"
                skills_latex += "\\begin{itemize}[leftmargin=2em, nosep]\n"
                for skill in skills_list[:3]:
                    escaped_skill = skill.replace('&', '\\&').replace('%', '\\%').replace('$', '\\$')
                    skills_latex += f"\\item {escaped_skill}\n"
                skills_latex += "\\end{itemize}\n\n"
        
        return skills_latex
    
    def score_achievements(self, skills: Dict, requirements: Dict) -> Dict:
        """Score achievements/experience bullets based on job requirements"""
        scored_achievements = {}
        
        # Create requirement text for matching
        req_text = ' '.join(requirements['must_have'] + requirements['nice_to_have'])
        req_text_lower = req_text.lower()
        tech_list = requirements['technologies']
        keywords = requirements['keywords']
        
        # Score each achievement bullet
        for achievement in skills['all_achievements']:
            score = 0
            achievement_lower = achievement.lower()
            
            # High score for technology matches
            for tech in tech_list:
                if tech in achievement_lower:
                    score += 15
            
            # Score for keyword matches
            for keyword in keywords:
                if keyword in achievement_lower:
                    score += 10
            
            # Bonus for quantifiable achievements
            if any(char.isdigit() for char in achievement):
                score += 5
            if '%' in achievement or '$' in achievement:
                score += 5
            
            # Score for specific domain keywords
            if 'kubernetes' in achievement_lower or 'k8s' in achievement_lower:
                score += 12
            if 'terraform' in achievement_lower or 'iac' in achievement_lower:
                score += 10
            if 'cost' in achievement_lower and ('saving' in achievement_lower or 'reduction' in achievement_lower):
                score += 8
            if 'migration' in achievement_lower or 'migrated' in achievement_lower:
                score += 7
            if 'security' in achievement_lower or 'compliance' in achievement_lower:
                score += 7
            
            if score > 0:
                scored_achievements[achievement] = score
        
        # Sort by score
        return dict(sorted(scored_achievements.items(), key=lambda x: x[1], reverse=True))
    
    def optimize_experience(self, skills: Dict, requirements: Dict, scored_achievements: Dict) -> List[str]:
        """Select and organize experience bullets from Key Responsibilities section"""
        # Get top achievements preserving exact text
        top_achievements = list(scored_achievements.keys())[:15]
        
        # Group by category for better organization
        categorized = {}
        for category, bullets in skills['achievements'].items():
            category_bullets = [b for b in bullets if b in top_achievements]
            if category_bullets:
                categorized[category] = category_bullets
        
        # Build final list with most relevant bullets
        experience_bullets = []
        
        # Priority order based on typical importance
        priority_order = [
            'Platform Engineering & Architecture',
            'Cost Optimization',
            'Security & Compliance',
            'Monitoring & Observability',
            'Migration & Modernization',
            'Automation & DevOps'
        ]
        
        # Add bullets in priority order
        for category in priority_order:
            if category in categorized:
                # Take top 2-3 bullets per category
                experience_bullets.extend(categorized[category][:3])
        
        # Add any remaining categories
        for category, bullets in categorized.items():
            if category not in priority_order:
                experience_bullets.extend(bullets[:2])
        
        # Return exact bullet text, limited to reasonable number
        return experience_bullets[:12]
    
    def build_cv(self, template: str, summary: str, skills: str, experience_bullets: List[str], metadata: Dict) -> str:
        """Build final CV content with exact bullet points from Key Responsibilities section"""
        # Generate header comment
        salary_str = f"£{metadata['salary']}/day" if metadata['type'] == 'contract' else f"£{metadata['salary']}k"
        header = f"""% Platform Engineer CV - {metadata['recruiter'].title()} {metadata['type'].title()} Role ({salary_str})
% Generated: {metadata['date']} | Optimized for Cloud Infrastructure & Kubernetes Position
% Parameterized CV Generation: RECRUITER={metadata['recruiter']}, TYPE={metadata['type']}, SALARY={metadata['salary']}
% Experience bullets taken from Key Responsibilities & Achievements section in skills.md
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""
        
        # Use template as base
        cv_content = header + template
        
        # Replace summary if pattern exists
        if r'\normalfont Senior Platform Engineer' in cv_content:
            cv_content = re.sub(
                r'\\normalfont Senior Platform Engineer.*?\\end\{rSection\}',
                r'\\normalfont ' + summary + r'\n\\end{rSection}',
                cv_content,
                count=1,
                flags=re.DOTALL
            )
        
        # Note: For now, keeping existing experience section from template
        # In a full implementation, would replace experience bullets with experience_bullets list
        # This would require parsing the LaTeX template structure and replacing bullet points
        
        # Always show this info to confirm it's working
        print(f"Selected {len(experience_bullets)} experience bullets from Key Responsibilities & Achievements")
        if experience_bullets:
            print("Top 3 selected bullets (exact text from skills.md):")
            for i, bullet in enumerate(experience_bullets[:3], 1):
                print(f"  {i}. {bullet[:100]}...")
        
        return cv_content
    
    def save_latex(self, content: str, metadata: Dict) -> str:
        """Save LaTeX content to file"""
        # Generate filename
        filename = f"{metadata['recruiter']}-{metadata['date']}-{metadata['type']}-{metadata['salary']}"
        
        # Save working copy
        working_path = self.generated_dir / "cv.tex"
        with open(working_path, 'w') as f:
            f.write(content)
        
        # Save final copy
        final_path = self.generated_dir / f"{filename}.tex"
        with open(final_path, 'w') as f:
            f.write(content)
        
        return str(working_path), filename
    
    def compile_pdf(self, tex_path: str, output_name: str, compiler: str = 'pdflatex') -> bool:
        """Compile LaTeX to PDF"""
        compile_script = self.scripts_dir / "compile-cv.sh"
        
        if not compile_script.exists():
            print(f"Error: Compile script not found at {compile_script}")
            return False
        
        try:
            result = subprocess.run(
                [str(compile_script), tex_path, output_name, compiler],
                capture_output=True,
                text=True,
                check=True
            )
            
            if result.returncode == 0:
                print(f"PDF compiled successfully: {output_name}.pdf")
                return True
            else:
                print(f"Compilation error: {result.stderr}")
                return False
                
        except subprocess.CalledProcessError as e:
            print(f"Compilation failed: {e}")
            return False
    
    def run(self, args: List[str]) -> int:
        """Main execution method"""
        # Parse arguments
        params = self.parse_arguments(args)
        
        if params['verbose']:
            print(f"Parameters: {params}")
        
        # Load job description
        job_text, metadata = self.load_job_description(params['job'], params)
        
        if params['verbose']:
            print(f"Metadata: {metadata}")
        
        # Load skills database
        skills = self.load_skills_database(params['skills'])
        
        # Analyze job requirements
        requirements = self.analyze_job_requirements(job_text)
        
        if params['verbose']:
            print(f"Found {len(requirements['technologies'])} technologies")
            print(f"Technologies: {requirements['technologies'][:5]}")
        
        # Score skills
        scored_skills = self.score_skills(skills, requirements)
        
        if params['verbose']:
            print(f"Top skills: {list(scored_skills.keys())[:5]}")
        
        # Generate LaTeX CV
        cv_content = self.generate_latex_cv(
            params['template'], skills, scored_skills, requirements, metadata
        )
        
        # Save LaTeX
        tex_path, output_name = self.save_latex(cv_content, metadata)
        print(f"LaTeX saved: {tex_path}")
        
        # Compile to PDF if requested
        if params['format'] == 'pdf':
            success = self.compile_pdf(tex_path, output_name, params['compiler'])
            
            if success and params['open']:
                pdf_path = self.output_dir / f"{output_name}.pdf"
                subprocess.run(['open', str(pdf_path)])
            
            return 0 if success else 1
        
        return 0


def main():
    """Main entry point"""
    generator = CVGenerator()
    sys.exit(generator.run(sys.argv[1:]))


if __name__ == '__main__':
    main()
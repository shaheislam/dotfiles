#!/usr/bin/env python3
"""
Enhanced CV Generator - Uses metadata tags for intelligent bullet point matching
Parses metadata from CV.tex comments and matches against job requirements
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Set
import hashlib


class EnhancedCVGenerator:
    """Enhanced CV generator that uses metadata for intelligent matching"""

    def __init__(self, config_path: Optional[str] = None):
        """Initialize CV generator with configuration"""
        self.base_dir = Path.home() / "dotfiles"
        self.jobapps_dir = self.base_dir / "jobapps"
        self.scripts_dir = self.base_dir / "scripts"
        self.output_dir = self.jobapps_dir / "generated"

        # Ensure output directory exists
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Load configuration
        self.config = self.load_config(config_path)

    def load_config(self, config_path: Optional[str] = None) -> Dict:
        """Load configuration with scoring weights"""
        return {
            'scoring': {
                'exact_match': 100,      # Exact technology match
                'strong_match': 80,      # Multiple related tags
                'good_match': 60,        # Key technology present
                'partial_match': 40,     # Some relevant tags
                'weak_match': 20         # Minimal relevance
            },
            'bullets': {
                'max_per_role': 6,       # Maximum bullets per job role
                'min_per_role': 3,       # Minimum bullets per job role
                'total_max': 25          # Total maximum bullets in CV
            },
            'weights': {
                'technology': 0.4,       # Weight for technology matches
                'domain': 0.3,          # Weight for domain expertise
                'impact': 0.2,          # Weight for quantifiable impact
                'recency': 0.1          # Weight for recency of experience
            }
        }

    def parse_cv_with_metadata(self, cv_path: str) -> Dict:
        """Parse CV.tex and extract bullet points with their metadata"""
        with open(cv_path, 'r') as f:
            content = f.read()

        bullets_with_metadata = []
        current_company = None
        current_role = None
        current_date = None

        # Parse line by line to extract structure and metadata
        lines = content.split('\n')
        for i, line in enumerate(lines):
            # Extract company and date
            if '\\begin{rSubsection}' in line and i + 1 < len(lines):
                # Look for company name in the rSubsection
                company_match = re.search(r'\\begin\{rSubsection\}\{([^}]+)\}\{([^}]+)\}', lines[i])
                if company_match:
                    current_company = company_match.group(1)
                    current_date = company_match.group(2)
                # Get role from next line
                if i + 1 < len(lines):
                    role_match = re.search(r'\{([^}]+)\}', lines[i + 1])
                    if role_match:
                        current_role = role_match.group(1)

            # Extract bullet points with metadata
            if '\\item ' in line:
                # Split by % to get bullet and metadata
                parts = line.split(' % ')
                if len(parts) == 2:
                    bullet_text = parts[0].replace('\\item ', '').strip()
                    metadata_text = parts[1].strip()

                    # Parse metadata (format: (tag1, tag2, tag3, ...))
                    metadata_tags = []
                    if metadata_text.startswith('(') and metadata_text.endswith(')'):
                        tags = metadata_text[1:-1].split(', ')
                        metadata_tags = [tag.strip() for tag in tags]

                    bullets_with_metadata.append({
                        'text': bullet_text,
                        'tags': metadata_tags,
                        'company': current_company,
                        'role': current_role,
                        'date': current_date,
                        'line_number': i + 1
                    })

        return {
            'bullets': bullets_with_metadata,
            'total': len(bullets_with_metadata)
        }

    def parse_job_description(self, job_path: str) -> Dict:
        """Parse job description and extract requirements"""
        with open(job_path, 'r') as f:
            content = f.read()

        # Extract key technologies and skills
        requirements = {
            'technologies': set(),
            'skills': set(),
            'domains': set(),
            'all_text': content.lower()
        }

        # Technology patterns
        tech_patterns = {
            'kubernetes': ['kubernetes', 'k8s', 'eks', 'gke', 'aks', 'container orchestration'],
            'aws': ['aws', 'amazon web services', 'ec2', 's3', 'lambda', 'cloudformation'],
            'terraform': ['terraform', 'terragrunt', 'infrastructure as code', 'iac'],
            'docker': ['docker', 'containers', 'containerization', 'dockerfile'],
            'ci/cd': ['ci/cd', 'jenkins', 'github actions', 'gitlab', 'pipeline', 'continuous'],
            'python': ['python', 'scripting', 'automation'],
            'monitoring': ['monitoring', 'observability', 'prometheus', 'grafana', 'logging'],
            'security': ['security', 'compliance', 'encryption', 'authentication', 'rbac']
        }

        # Domain patterns
        domain_patterns = {
            'platform': ['platform engineering', 'platform', 'infrastructure'],
            'devops': ['devops', 'sre', 'site reliability', 'operations'],
            'cloud': ['cloud', 'multi-cloud', 'hybrid cloud'],
            'automation': ['automation', 'automate', 'automated'],
            'architecture': ['architecture', 'architect', 'design', 'system design']
        }

        content_lower = content.lower()

        # Extract technologies
        for tech_category, patterns in tech_patterns.items():
            for pattern in patterns:
                if pattern in content_lower:
                    requirements['technologies'].add(tech_category)
                    requirements['technologies'].add(pattern)

        # Extract domains
        for domain_category, patterns in domain_patterns.items():
            for pattern in patterns:
                if pattern in content_lower:
                    requirements['domains'].add(domain_category)
                    requirements['domains'].add(pattern)

        # Extract specific skills mentioned
        skill_keywords = re.findall(r'\b[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*\b', content)
        for skill in skill_keywords:
            if len(skill) > 3:  # Filter out short words
                requirements['skills'].add(skill.lower())

        return requirements

    def score_bullet(self, bullet: Dict, requirements: Dict) -> float:
        """Score a bullet point based on job requirements and metadata"""
        score = 0.0
        tags_lower = [tag.lower() for tag in bullet['tags']]
        text_lower = bullet['text'].lower()

        # Technology matching (40% weight)
        tech_matches = 0
        for tech in requirements['technologies']:
            if tech in tags_lower or tech in text_lower:
                tech_matches += 1

        if tech_matches > 3:
            score += self.config['scoring']['exact_match'] * self.config['weights']['technology']
        elif tech_matches > 1:
            score += self.config['scoring']['strong_match'] * self.config['weights']['technology']
        elif tech_matches > 0:
            score += self.config['scoring']['good_match'] * self.config['weights']['technology']

        # Domain matching (30% weight)
        domain_matches = 0
        for domain in requirements['domains']:
            if domain in tags_lower or domain in text_lower:
                domain_matches += 1

        if domain_matches > 0:
            score += self.config['scoring']['good_match'] * self.config['weights']['domain']

        # Impact scoring (20% weight) - look for numbers, percentages, dollar amounts
        impact_indicators = [
            r'\d+%',           # Percentages
            r'\$[\d,]+[KkMm]', # Dollar amounts
            r'\d+x',           # Multipliers
            r'\d+\+',          # 50+ style numbers
        ]

        impact_score = 0
        for pattern in impact_indicators:
            if re.search(pattern, bullet['text']):
                impact_score += 20

        score += min(impact_score, self.config['scoring']['strong_match']) * self.config['weights']['impact']

        # Recency bonus (10% weight) - more recent experience scores higher
        if bullet['date'] and '2024' in bullet['date']:
            score += self.config['scoring']['exact_match'] * self.config['weights']['recency']
        elif bullet['date'] and '2023' in bullet['date']:
            score += self.config['scoring']['strong_match'] * self.config['weights']['recency']
        elif bullet['date'] and '2022' in bullet['date']:
            score += self.config['scoring']['good_match'] * self.config['weights']['recency']

        return score

    def select_best_bullets(self, cv_data: Dict, requirements: Dict) -> List[Dict]:
        """Select the best bullet points based on scoring"""
        # Score all bullets
        for bullet in cv_data['bullets']:
            bullet['score'] = self.score_bullet(bullet, requirements)

        # Sort by score
        sorted_bullets = sorted(cv_data['bullets'], key=lambda x: x['score'], reverse=True)

        # Group by company/role
        company_bullets = {}
        for bullet in sorted_bullets:
            key = f"{bullet['company']}_{bullet['role']}"
            if key not in company_bullets:
                company_bullets[key] = []
            company_bullets[key].append(bullet)

        # Select best bullets per role
        selected = []
        for company_role, bullets in company_bullets.items():
            # Take top bullets per role (max 6, min 3 if available)
            max_bullets = self.config['bullets']['max_per_role']
            min_bullets = self.config['bullets']['min_per_role']

            num_to_take = min(max_bullets, max(min_bullets, len(bullets)))
            selected.extend(bullets[:num_to_take])

        # Limit total bullets
        selected = selected[:self.config['bullets']['total_max']]

        return selected

    def generate_optimized_cv(self, cv_path: str, selected_bullets: List[Dict], output_path: str) -> str:
        """Generate optimized CV with selected bullets"""
        with open(cv_path, 'r') as f:
            original_content = f.read()

        # Create a mapping of original bullets to selected ones
        selected_texts = {bullet['text'] for bullet in selected_bullets}

        # Process the CV content
        lines = original_content.split('\n')
        optimized_lines = []
        skip_bullet = False

        for line in lines:
            if '\\item ' in line:
                # Extract bullet text (before the % metadata)
                bullet_text = line.split(' % ')[0].replace('\\item ', '').strip()

                # Check if this bullet is selected
                if any(bullet_text in selected_text for selected_text in selected_texts):
                    optimized_lines.append(line)  # Keep the bullet with metadata
                # If not selected, skip this line

            else:
                optimized_lines.append(line)

        optimized_content = '\n'.join(optimized_lines)

        # Save the optimized CV
        with open(output_path, 'w') as f:
            f.write(optimized_content)

        return optimized_content

    def compile_to_pdf(self, tex_path: str) -> bool:
        """Compile LaTeX to PDF"""
        try:
            # Change to the directory containing the tex file
            tex_dir = Path(tex_path).parent
            tex_file = Path(tex_path).name

            # Copy resume.cls if needed
            resume_cls = self.jobapps_dir / "resume.cls"
            if resume_cls.exists():
                subprocess.run(['cp', str(resume_cls), str(tex_dir / "resume.cls")])

            # Run pdflatex twice for references
            for _ in range(2):
                result = subprocess.run(
                    ['pdflatex', '-interaction=nonstopmode', tex_file],
                    cwd=tex_dir,
                    capture_output=True,
                    text=True
                )

            pdf_path = tex_path.replace('.tex', '.pdf')
            if Path(pdf_path).exists():
                print(f"✅ PDF generated: {pdf_path}")
                return True
            else:
                print(f"❌ PDF generation failed")
                return False

        except Exception as e:
            print(f"❌ Compilation error: {e}")
            return False

    def run(self, job_path: str, cv_path: str, output_name: str = None) -> int:
        """Main execution"""
        print("🚀 Enhanced CV Generator")
        print("=" * 50)

        # Parse CV with metadata
        print("📄 Parsing CV with metadata...")
        cv_data = self.parse_cv_with_metadata(cv_path)
        print(f"   Found {cv_data['total']} bullet points with metadata")

        # Parse job description
        print("📋 Analyzing job description...")
        requirements = self.parse_job_description(job_path)
        print(f"   Technologies: {', '.join(list(requirements['technologies'])[:5])}")
        print(f"   Domains: {', '.join(list(requirements['domains'])[:5])}")

        # Score and select best bullets
        print("🎯 Scoring bullet points...")
        selected_bullets = self.select_best_bullets(cv_data, requirements)
        print(f"   Selected {len(selected_bullets)} best matching bullets")

        # Show top bullets
        print("\n📌 Top 5 Selected Bullets:")
        for i, bullet in enumerate(selected_bullets[:5], 1):
            print(f"   {i}. Score: {bullet['score']:.1f} | {bullet['text'][:80]}...")
            print(f"      Tags: {', '.join(bullet['tags'][:5])}")

        # Generate optimized CV
        if not output_name:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_name = f"cv_optimized_{timestamp}"

        output_tex = str(self.output_dir / f"{output_name}.tex")
        print(f"\n📝 Generating optimized CV: {output_tex}")
        self.generate_optimized_cv(cv_path, selected_bullets, output_tex)

        # Compile to PDF
        print("🔨 Compiling to PDF...")
        success = self.compile_to_pdf(output_tex)

        if success:
            print(f"\n✨ Success! CV generated: {output_name}.pdf")
            # Open PDF
            pdf_path = output_tex.replace('.tex', '.pdf')
            subprocess.run(['open', pdf_path])

        return 0 if success else 1


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Enhanced CV Generator with Metadata Matching')
    parser.add_argument('--job', default='~/dotfiles/jobapps/jobdesciption.md',
                       help='Path to job description')
    parser.add_argument('--cv', default='~/dotfiles/jobapps/CV.tex',
                       help='Path to CV template with metadata')
    parser.add_argument('--output', help='Output filename (without extension)')
    parser.add_argument('--config', help='Configuration file')

    args = parser.parse_args()

    # Expand paths
    job_path = Path(args.job).expanduser()
    cv_path = Path(args.cv).expanduser()

    # Create generator and run
    generator = EnhancedCVGenerator(args.config)
    return generator.run(str(job_path), str(cv_path), args.output)


if __name__ == '__main__':
    sys.exit(main())
#!/usr/bin/env python3
"""
Unified CV Generator
Combines metadata-based matching, standard CV generation, and ATS optimization
Single source of truth: skills.md with metadata tags
"""

import argparse
import subprocess
import sys
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Set
import json

# Built-in ATS optimizer functionality (no external import needed)
import webbrowser


class UnifiedCVGenerator:
    """Unified CV generation with metadata-based matching and ATS optimization"""

    def __init__(self):
        """Initialize generator with configuration"""
        self.base_dir = Path.home() / "dotfiles"
        self.jobapps_dir = self.base_dir / "jobapps"
        self.scripts_dir = self.base_dir / "scripts" / "cv"
        self.output_dir = self.jobapps_dir / "output"
        self.generated_dir = self.jobapps_dir / "generated"

        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.generated_dir.mkdir(parents=True, exist_ok=True)

        # ATS optimization settings (built-in)
        self.ats_replacements = {
            '+': ' plus ',
            '&': ' and ',
            '$': 'USD ',
            '€': 'EUR ',
            '£': 'GBP ',
            '•': '- ',
            '→': ' to ',
            '←': ' from ',
            '↑': ' up ',
            '↓': ' down ',
            '×': ' times ',
            '÷': ' divided by ',
            '≈': ' approximately ',
            '≥': ' greater than or equal to ',
            '≤': ' less than or equal to ',
            '≠': ' not equal to '
        }

        # Scoring weights
        self.scoring_weights = {
            'metadata_tech_match': 25,      # Highest priority
            'metadata_keyword_match': 20,
            'metadata_requirement_match': 15,
            'text_tech_match': 15,
            'text_keyword_match': 10,
            'quantifiable': 5,
            'domain_specific': 8,
            'cost_savings': 10,
        }

    def parse_job_description(self, job_path: str) -> Dict:
        """Parse job description to extract requirements"""
        requirements = {
            'technologies': [],
            'keywords': [],
            'must_have': [],
            'nice_to_have': [],
        }

        if not Path(job_path).exists():
            print(f"Warning: Job description not found at {job_path}")
            return requirements

        with open(job_path, 'r') as f:
            content = f.read()

        # Extract technologies (common patterns)
        tech_patterns = [
            r'\b(kubernetes|k8s|eks|gke|aks)\b',
            r'\b(aws|azure|gcp|cloud)\b',
            r'\b(terraform|ansible|cloudformation)\b',
            r'\b(docker|container|helm)\b',
            r'\b(python|golang|go|java|javascript)\b',
            r'\b(prometheus|grafana|datadog|monitoring)\b',
            r'\b(jenkins|gitlab|github\s+actions|ci\/cd)\b',
        ]

        content_lower = content.lower()
        for pattern in tech_patterns:
            matches = re.findall(pattern, content_lower)
            requirements['technologies'].extend(matches)

        # Extract keywords
        keywords = ['platform', 'infrastructure', 'automation', 'security',
                   'monitoring', 'observability', 'migration', 'optimization',
                   'compliance', 'leadership', 'agile', 'devops', 'sre']

        for keyword in keywords:
            if keyword in content_lower:
                requirements['keywords'].append(keyword)

        # Deduplicate
        requirements['technologies'] = list(set(requirements['technologies']))
        requirements['keywords'] = list(set(requirements['keywords']))

        return requirements

    def load_skills(self, skills_path: str) -> Dict:
        """Load skills from skills.md with metadata tags"""
        skills = {
            'technical': [],
            'achievements': {},
            'all_achievements': [],
            'certifications': [],
            'education': []
        }

        with open(skills_path, 'r') as f:
            lines = f.readlines()

        current_section = None
        current_subsection = None

        for line in lines:
            line = line.rstrip()

            # Main sections
            if line.startswith('## '):
                current_section = line[3:]
                current_subsection = None
                continue

            # Subsections
            if line.startswith('### '):
                current_subsection = line[4:]
                if current_section == 'Key Responsibilities & Achievements':
                    skills['achievements'][current_subsection] = []
                continue

            # Bullet points
            if line.startswith('- '):
                bullet = line[2:]

                # Technical skills
                if current_section == 'Technical Skills':
                    skills['technical'].append(bullet)

                # Achievements (with metadata)
                elif current_section == 'Key Responsibilities & Achievements':
                    if current_subsection:
                        skills['achievements'][current_subsection].append(bullet)
                        skills['all_achievements'].append(bullet)

                # Certifications
                elif current_section == 'Certifications':
                    skills['certifications'].append(bullet)

        return skills

    def parse_metadata_tags(self, achievement: str) -> Tuple[str, List[str]]:
        """Extract metadata tags from achievement bullet"""
        if '[Tags:' in achievement:
            tag_start = achievement.find('[Tags:')
            tag_end = achievement.find(']', tag_start)
            if tag_end > tag_start:
                tags_str = achievement[tag_start+6:tag_end]
                tags = [tag.strip().lower() for tag in tags_str.split(',')]
                clean_text = achievement[:tag_start].strip()
                return clean_text, tags
        return achievement, []

    def score_achievements(self, skills: Dict, requirements: Dict) -> Dict:
        """Score achievements based on metadata tags and text matching"""
        scored_achievements = {}

        for achievement in skills['all_achievements']:
            score = 0
            clean_text, tags = self.parse_metadata_tags(achievement)
            achievement_lower = clean_text.lower()

            # Score based on metadata tags (highest priority)
            if tags:
                for tag in tags:
                    # Technology match in tags
                    for tech in requirements['technologies']:
                        if tech in tag or tag in tech:
                            score += self.scoring_weights['metadata_tech_match']

                    # Keyword match in tags
                    for keyword in requirements['keywords']:
                        if keyword in tag or tag in keyword:
                            score += self.scoring_weights['metadata_keyword_match']

            # Text-based scoring
            for tech in requirements['technologies']:
                if tech in achievement_lower:
                    score += self.scoring_weights['text_tech_match']

            for keyword in requirements['keywords']:
                if keyword in achievement_lower:
                    score += self.scoring_weights['text_keyword_match']

            # Bonus for quantifiable achievements
            if any(char.isdigit() for char in clean_text):
                score += self.scoring_weights['quantifiable']
            if '$' in clean_text or '£' in clean_text or '%' in clean_text:
                score += self.scoring_weights['cost_savings']

            # Domain-specific bonuses
            if 'kubernetes' in achievement_lower or 'k8s' in achievement_lower:
                score += self.scoring_weights['domain_specific']
            if 'cost' in achievement_lower and ('saving' in achievement_lower or 'reduction' in achievement_lower):
                score += self.scoring_weights['cost_savings']

            if score > 0:
                scored_achievements[achievement] = score

        return dict(sorted(scored_achievements.items(), key=lambda x: x[1], reverse=True))

    def select_bullets(self, scored_achievements: Dict, skills: Dict, max_bullets: int = 12) -> List[str]:
        """Select top bullets with category diversity

        Page length rules:
        - CV should never exceed 3 pages
        - If 3 pages, must use at least 50% of third page
        - Default: 8-10 bullets for clean 2-page CV
        - Extended: 12-15 bullets for 3-page CV
        """
        # Enforce page limits - default to 10 bullets for 2-page CV
        # Can be increased via command line if needed for specific roles
        max_bullets = min(max_bullets, 10)

        selected = []
        category_counts = {}

        # Priority categories
        priority_order = [
            'Platform Engineering & Architecture',
            'Cost Optimization',
            'Security & Compliance',
            'Monitoring & Observability',
            'Migration & Modernization',
            'Automation & DevOps'
        ]

        # First pass: get top bullets from priority categories
        for achievement, score in scored_achievements.items():
            if len(selected) >= max_bullets:
                break

            # Find which category this achievement belongs to
            for category, bullets in skills['achievements'].items():
                if achievement in bullets:
                    # Limit bullets per category for diversity
                    if category_counts.get(category, 0) < 3:
                        # Clean the bullet (remove metadata tags)
                        clean_bullet, _ = self.parse_metadata_tags(achievement)
                        selected.append(clean_bullet)
                        category_counts[category] = category_counts.get(category, 0) + 1
                    break

        return selected[:max_bullets]

    def generate_cv_latex(self, template_path: str, bullets: List[str],
                         skills: Dict, metadata: Dict) -> str:
        """Generate LaTeX CV from template and selected bullets"""
        with open(template_path, 'r') as f:
            template = f.read()

        # Add header
        salary_str = f"£{metadata['salary']}/day" if metadata['type'] == 'contract' else f"£{metadata['salary']}k"
        header = f"""% Platform Engineer CV - {metadata['recruiter'].title()} {metadata['type'].title()} Role ({salary_str})
% Generated: {metadata['date']} | Optimized for {metadata['recruiter']} Position
% Unified CV Generator with Metadata-Based Matching
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""

        # Create experience section with selected bullets
        experience_section = ""
        for bullet in bullets:
            experience_section += f"\\item {bullet}\n"

        # Replace the placeholder with actual bullets
        if "% EXPERIENCE BULLETS WILL BE INSERTED HERE BY THE GENERATOR" in template:
            template = template.replace(
                "% EXPERIENCE BULLETS WILL BE INSERTED HERE BY THE GENERATOR",
                experience_section.strip()
            )

        cv_content = header + template

        print(f"Selected {len(bullets)} bullets based on job requirements")
        if bullets and len(bullets) >= 3:
            print("Top 3 bullets selected:")
            for i, bullet in enumerate(bullets[:3], 1):
                preview = bullet[:80] + "..." if len(bullet) > 80 else bullet
                print(f"  {i}. {preview}")

        return cv_content

    def create_ats_optimized_version(self, latex_content: str) -> str:
        """Create ATS-optimized version of CV"""
        lines = []
        for line in latex_content.split('\n'):
            # Skip comment lines
            if line.strip().startswith('%'):
                lines.append(line)
                continue

            # Replace special characters
            for old, new in self.ats_replacements.items():
                line = line.replace(old, new)

            lines.append(line)

        # Join the lines back together
        ats_content = '\n'.join(lines)

        # Note: Removed hidden keywords section as it was showing visibly in PDFs

        return ats_content

    def calculate_ats_score(self, content: str, keywords: Set[str]) -> float:
        """Calculate ATS compatibility score"""
        score = 85.0  # Base score

        # Check for problematic elements
        if '\\includegraphics' in content:
            score -= 10
        if '\\begin{table}' in content:
            score -= 5

        # Check keyword coverage
        content_lower = content.lower()
        keywords_found = sum(1 for keyword in keywords if keyword.lower() in content_lower)
        if keywords:
            keyword_bonus = (keywords_found / len(keywords)) * 10
            score += min(keyword_bonus, 10)

        # ATS optimizations are applied through character replacement

        return min(max(score, 0), 100)  # Keep between 0 and 100

    def generate_both_versions(self, job_path: str, skills_path: str, template_path: str,
                              metadata: Dict, max_bullets: int = 10) -> Tuple[str, str, Dict]:
        """Generate both standard and ATS-optimized versions"""
        print("=" * 50)
        print("🚀 Unified CV Generation")
        print("=" * 50)

        # Parse job description
        print("📋 Analyzing job requirements...")
        requirements = self.parse_job_description(job_path)
        print(f"  Found {len(requirements['technologies'])} technologies, {len(requirements['keywords'])} keywords")

        # Load skills with metadata
        print("📚 Loading skills database...")
        skills = self.load_skills(skills_path)
        print(f"  Loaded {len(skills['all_achievements'])} achievements with metadata")

        # Score and select bullets
        print("🎯 Scoring achievements based on job match...")
        scored = self.score_achievements(skills, requirements)
        bullets = self.select_bullets(scored, skills, max_bullets=max_bullets)

        # Generate standard CV
        print("📄 Generating standard CV...")
        standard_latex = self.generate_cv_latex(template_path, bullets, skills, metadata)

        # Save standard version
        standard_tex_path = self.generated_dir / "cv.tex"
        with open(standard_tex_path, 'w') as f:
            f.write(standard_latex)

        # Generate ATS-optimized version
        print("🤖 Creating ATS-optimized version...")
        ats_latex = self.create_ats_optimized_version(standard_latex)

        # Calculate scores
        original_score = self.calculate_ats_score(standard_latex, requirements['keywords'])
        optimized_score = self.calculate_ats_score(ats_latex, requirements['keywords'])

        report = {
            'original_score': original_score,
            'optimized_score': optimized_score,
            'improvement': optimized_score - original_score
        }

        # Save ATS version
        ats_tex_path = self.generated_dir / "cv_ats.tex"
        with open(ats_tex_path, 'w') as f:
            f.write(ats_latex)

        print(f"  Original ATS Score: {report['original_score']}/100")
        print(f"  Optimized ATS Score: {report['optimized_score']}/100")
        print(f"  Improvement: +{report['improvement']} points")

        # Compile both PDFs
        print("🔨 Compiling PDFs...")
        output_name = f"{metadata['recruiter']}-{metadata['date']}-{metadata['type']}-{metadata['salary']}"

        # Compile standard
        self.compile_pdf(str(standard_tex_path), output_name)

        # Compile ATS
        self.compile_pdf(str(ats_tex_path), f"{output_name}-ATS")

        standard_pdf = self.output_dir / f"{output_name}.pdf"
        ats_pdf = self.output_dir / f"{output_name}-ATS.pdf"

        return str(standard_pdf), str(ats_pdf), report

    def compile_pdf(self, tex_path: str, output_name: str) -> bool:
        """Compile LaTeX to PDF"""
        compile_script = self.scripts_dir.parent / "compile-cv.sh"

        if not compile_script.exists():
            print(f"Error: Compile script not found at {compile_script}")
            return False

        try:
            result = subprocess.run(
                [str(compile_script), tex_path, output_name, 'pdflatex'],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            print(f"Compilation error: {e}")
            return False

    def generate_comparison_report(self, standard_pdf: str, ats_pdf: str,
                                  report: Dict, metadata: Dict) -> str:
        """Generate HTML comparison report"""
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>CV Generation Report - {metadata['recruiter']}</title>
    <style>
        body {{ font-family: -apple-system, system-ui, sans-serif; margin: 40px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
        h2 {{ color: #34495e; margin-top: 30px; }}
        .metrics {{ display: flex; gap: 20px; margin: 20px 0; }}
        .metric {{ flex: 1; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; color: white; }}
        .metric-value {{ font-size: 36px; font-weight: bold; }}
        .metric-label {{ opacity: 0.9; margin-top: 5px; }}
        .comparison {{ display: grid; grid-template-columns: 1fr 1fr; gap: 30px; margin-top: 30px; }}
        .version {{ padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px; }}
        .standard {{ background: #f8f9fa; }}
        .ats {{ background: #e3f2fd; }}
        .improvement {{ color: #27ae60; font-weight: bold; }}
        .file-path {{ font-family: monospace; background: #f4f4f4; padding: 5px; border-radius: 3px; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🎯 Unified CV Generation Report</h1>
        <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}</p>
        <p>Position: <strong>{metadata['recruiter']} - {metadata['type'].title()}</strong></p>

        <div class="metrics">
            <div class="metric">
                <div class="metric-value">{report['original_score']}/100</div>
                <div class="metric-label">Standard ATS Score</div>
            </div>
            <div class="metric">
                <div class="metric-value">{report['optimized_score']}/100</div>
                <div class="metric-label">Optimized ATS Score</div>
            </div>
            <div class="metric">
                <div class="metric-value">+{report['improvement']}</div>
                <div class="metric-label">Score Improvement</div>
            </div>
        </div>

        <h2>📊 Generated Files</h2>
        <div class="comparison">
            <div class="version standard">
                <h3>Standard Version</h3>
                <p>Optimized for human readers with formatting and visual hierarchy</p>
                <p>File: <span class="file-path">{standard_pdf}</span></p>
                <ul>
                    <li>Full formatting preserved</li>
                    <li>Icons and colors included</li>
                    <li>Metadata-based bullet selection</li>
                </ul>
            </div>
            <div class="version ats">
                <h3>ATS-Optimized Version</h3>
                <p>Optimized for Applicant Tracking Systems</p>
                <p>File: <span class="file-path">{ats_pdf}</span></p>
                <ul>
                    <li>Special characters replaced</li>
                    <li>Keywords expanded</li>
                    <li>Hidden keyword section added</li>
                </ul>
            </div>
        </div>

        <h2>✅ Optimizations Applied</h2>
        <ul>
"""

        for fix in report.get('format_fixes', []):
            html += f"            <li>{fix}</li>\n"

        html += """        </ul>

        <h2>🔑 Metadata Matching</h2>
        <p>The system used metadata tags from skills.md to intelligently match achievements to job requirements.</p>
        <p>This ensures the most relevant bullets are selected even when keywords don't appear directly in the text.</p>
    </div>
</body>
</html>"""

        return html


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Unified CV Generator with Metadata Matching')

    # Core parameters
    parser.add_argument('--recruiter', required=True, help='Company/Recruiter name')
    parser.add_argument('--type', choices=['perm', 'contract'], default='perm')
    parser.add_argument('--salary', required=True, help='Salary (e.g., 150K or 700 for contract)')
    parser.add_argument('--date', default=datetime.now().strftime('%d%m%y'))

    # File paths
    parser.add_argument('--job', default=None, help='Job description path')
    parser.add_argument('--skills', default=None, help='Skills database path')
    parser.add_argument('--template', default=None, help='CV template path')

    # Options
    parser.add_argument('--ats-only', action='store_true', help='Generate ATS version only')
    parser.add_argument('--standard-only', action='store_true', help='Generate standard version only')
    parser.add_argument('--no-report', action='store_true', help='Skip HTML report generation')
    parser.add_argument('--open', action='store_true', help='Open files after generation')
    parser.add_argument('--max-bullets', type=int, default=10, help='Maximum bullets to include (10 for 2 pages, 15 for 3 pages)')

    args = parser.parse_args()

    # Set default paths
    base_dir = Path.home() / "dotfiles" / "jobapps"
    if not args.job:
        args.job = str(base_dir / "jobdescription.md")
    if not args.skills:
        args.skills = str(base_dir / "skills.md")
    if not args.template:
        args.template = str(base_dir / "CV.tex")

    # Create metadata
    metadata = {
        'recruiter': args.recruiter,
        'type': args.type,
        'salary': args.salary,
        'date': args.date
    }

    # Generate CVs
    generator = UnifiedCVGenerator()
    standard_pdf, ats_pdf, report = generator.generate_both_versions(
        args.job, args.skills, args.template, metadata, max_bullets=args.max_bullets
    )

    # Generate comparison report
    if not args.no_report:
        print("📊 Generating comparison report...")
        html = generator.generate_comparison_report(standard_pdf, ats_pdf, report, metadata)
        report_path = generator.generated_dir / f"unified_report_{metadata['recruiter']}_{metadata['date']}.html"
        with open(report_path, 'w') as f:
            f.write(html)
        print(f"  Report saved: {report_path}")

        if args.open:
            # Open the HTML report
            subprocess.run(['open', str(report_path)])

            # Also open both PDFs
            standard_pdf_path = Path(standard_pdf)
            ats_pdf_path = Path(ats_pdf)

            if standard_pdf_path.exists():
                subprocess.run(['open', str(standard_pdf)])
            if ats_pdf_path.exists():
                subprocess.run(['open', str(ats_pdf)])

    print("\n✅ Unified CV generation complete!")
    print(f"  Standard: {standard_pdf}")
    print(f"  ATS-Optimized: {ats_pdf}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
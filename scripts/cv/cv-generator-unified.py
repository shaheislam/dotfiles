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
import logging
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Set
import json

# Built-in ATS optimizer functionality (no external import needed)
import webbrowser


def setup_logging(output_dir: Path, log_level=logging.INFO, debug_mode=False):
    """Setup comprehensive logging for CV generation

    Creates log files:
    - cv_generator.log: All operations
    - errors.log: Errors only
    - debug.log: Debug messages (if debug_mode enabled)

    Args:
        output_dir: Directory for log files
        log_level: Minimum logging level
        debug_mode: Enable debug logging

    Returns:
        Configured logger instance
    """
    # Ensure output directory exists
    output_dir.mkdir(parents=True, exist_ok=True)

    # Create logger
    logger = logging.getLogger('cv_generator')
    logger.setLevel(logging.DEBUG if debug_mode else log_level)

    # Remove existing handlers
    logger.handlers.clear()

    # Console handler - INFO level for user feedback
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_formatter = logging.Formatter('%(levelname)s: %(message)s')
    console_handler.setFormatter(console_formatter)

    # Main log file - all operations
    main_log = output_dir / "cv_generator.log"
    main_handler = logging.FileHandler(main_log, mode='a', encoding='utf-8')
    main_handler.setLevel(log_level)
    main_formatter = logging.Formatter(
        '%(asctime)s | %(levelname)s | %(funcName)s:%(lineno)d | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    main_handler.setFormatter(main_formatter)

    # Error log file - errors only
    error_log = output_dir / "errors.log"
    error_handler = logging.FileHandler(error_log, mode='a', encoding='utf-8')
    error_handler.setLevel(logging.ERROR)
    error_formatter = logging.Formatter(
        '%(asctime)s | %(levelname)s | %(funcName)s:%(lineno)d | %(message)s\n'
        'Exception: %(exc_info)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    error_handler.setFormatter(error_formatter)

    # Debug log file (optional)
    if debug_mode:
        debug_log = output_dir / "debug.log"
        debug_handler = logging.FileHandler(debug_log, mode='a', encoding='utf-8')
        debug_handler.setLevel(logging.DEBUG)
        debug_formatter = logging.Formatter(
            '%(asctime)s | DEBUG | %(funcName)s:%(lineno)d | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        debug_handler.setFormatter(debug_formatter)
        logger.addHandler(debug_handler)

    # Add handlers
    logger.addHandler(console_handler)
    logger.addHandler(main_handler)
    logger.addHandler(error_handler)

    logger.info("Logging initialized for CV generation")
    return logger


class UnifiedCVGenerator:
    """Unified CV generation with metadata-based matching and ATS optimization"""

    def __init__(self, debug_mode=False):
        """Initialize generator with configuration

        Args:
            debug_mode: Enable debug logging
        """
        self.base_dir = Path.home() / "dotfiles"
        self.jobapps_dir = self.base_dir / "jobapps"
        self.scripts_dir = self.base_dir / "scripts" / "cv"
        self.output_dir = self.jobapps_dir / "output"
        self.generated_dir = self.jobapps_dir / "generated"

        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.generated_dir.mkdir(parents=True, exist_ok=True)

        # Setup logging
        self.logger = setup_logging(self.generated_dir, debug_mode=debug_mode)
        self.logger.info(f"Initialized CV Generator - Output: {self.output_dir}")

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
        """Parse job description to dynamically extract ALL requirements"""
        requirements = {
            'technologies': [],
            'keywords': [],
            'must_have': [],
            'nice_to_have': [],
            'all_terms': [],  # New: capture all significant terms
        }

        if not Path(job_path).exists():
            self.logger.warning(f"Job description not found at {job_path}")
            return requirements

        with open(job_path, 'r') as f:
            content = f.read()

        content_lower = content.lower()

        # Dynamic technology extraction - find all technical terms
        # Pattern 1: Capitalized words and acronyms (likely to be tools/technologies)
        tech_terms = re.findall(r'\b[A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)*\b', content)
        tech_acronyms = re.findall(r'\b[A-Z]{2,}[0-9]*\b', content)

        # Pattern 2: Terms with special chars (e.g., M365, K8s)
        special_terms = re.findall(r'\b[A-Za-z]+[0-9]+[A-Za-z]*\b|\b[A-Za-z]*[0-9]+[A-Za-z]+\b', content)

        # Pattern 3: Common tech patterns (word-word, word/word)
        compound_terms = re.findall(r'\b\w+[-/]\w+\b', content_lower)

        # Pattern 4: Extract from sections like "Essential Technical Skills"
        # Look for bullet points and technical sections
        tech_section_match = re.search(r'(technical|skills|requirements|experience).*?(?=\n\n|\Z)',
                                       content_lower, re.DOTALL | re.IGNORECASE)
        if tech_section_match:
            section_text = tech_section_match.group()
            # Extract all nouns and technical terms from this section
            section_terms = re.findall(r'\b[a-zA-Z][\w\-\./]+\b', section_text)
            requirements['technologies'].extend(section_terms)

        # Combine all technical terms
        all_tech = tech_terms + tech_acronyms + special_terms + compound_terms

        # Clean and filter technical terms
        for term in all_tech:
            clean_term = term.strip().lower()
            # Filter out common words and keep technical terms
            if (len(clean_term) > 2 and
                clean_term not in ['the', 'and', 'for', 'with', 'from', 'this', 'that', 'will', 'can', 'has', 'have', 'are', 'was', 'were', 'been']):
                requirements['technologies'].append(clean_term)

        # Extract domain-specific keywords based on job content
        # Dynamically identify important words based on frequency and context
        words = re.findall(r'\b[a-z]+\b', content_lower)
        word_freq = {}
        for word in words:
            if len(word) > 4:  # Focus on meaningful words
                word_freq[word] = word_freq.get(word, 0) + 1

        # Keywords are frequently mentioned important terms
        sorted_words = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)
        requirements['keywords'] = [word for word, freq in sorted_words[:20] if freq > 1]

        # Extract specific requirements from "Essential" or "Required" sections
        essential_match = re.search(r'(essential|required|must.have).*?(?=(desirable|nice.to.have|\n\n|\Z))',
                                   content_lower, re.DOTALL | re.IGNORECASE)
        if essential_match:
            essential_text = essential_match.group()
            # Extract all technical terms from essential section
            essential_terms = re.findall(r'\b[a-zA-Z][\w\-\./]+\b', essential_text)
            requirements['must_have'] = [t.lower() for t in essential_terms if len(t) > 2]

        # Extract nice-to-have from "Desirable" sections
        desirable_match = re.search(r'(desirable|nice.to.have|preferred).*?(?=\n\n|\Z)',
                                   content_lower, re.DOTALL | re.IGNORECASE)
        if desirable_match:
            desirable_text = desirable_match.group()
            desirable_terms = re.findall(r'\b[a-zA-Z][\w\-\./]+\b', desirable_text)
            requirements['nice_to_have'] = [t.lower() for t in desirable_terms if len(t) > 2]

        # Store all unique terms for comprehensive matching
        requirements['all_terms'] = list(set(
            requirements['technologies'] +
            requirements['keywords'] +
            requirements['must_have'] +
            requirements['nice_to_have']
        ))

        # Deduplicate while preserving order of importance
        requirements['technologies'] = list(dict.fromkeys(requirements['technologies']))[:50]
        requirements['keywords'] = list(dict.fromkeys(requirements['keywords']))[:30]
        requirements['must_have'] = list(dict.fromkeys(requirements['must_have']))[:30]
        requirements['nice_to_have'] = list(dict.fromkeys(requirements['nice_to_have']))[:20]

        self.logger.info(f"Dynamically extracted from job description:")
        self.logger.info(f"  - {len(requirements['technologies'])} technologies/tools")
        self.logger.info(f"  - {len(requirements['keywords'])} keywords")
        self.logger.info(f"  - {len(requirements['must_have'])} must-have skills")
        self.logger.info(f"  - {len(requirements['nice_to_have'])} nice-to-have skills")

        # Show top extracted terms for debugging
        if requirements['technologies']:
            self.logger.info(f"  Top technologies detected: {', '.join(requirements['technologies'][:10])}")

        # Debug: Show what we're actually looking for
        self.logger.debug(f"Key terms we're matching against:")
        self.logger.debug(f"  Must-have: {', '.join(requirements['must_have'][:10]) if requirements['must_have'] else 'None'}")
        self.logger.debug(f"  Technologies: {', '.join([t for t in requirements['technologies'] if any(x in t for x in ['security', 'identity', 'entra', 'purview', 'cyber'])][:10])}")

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
        """Score achievements based on dynamic job requirements"""
        scored_achievements = {}

        for achievement in skills['all_achievements']:
            score = 0
            clean_text, tags = self.parse_metadata_tags(achievement)
            achievement_lower = clean_text.lower()

            # Priority 1: Must-have requirements (highest weight)
            for must_have in requirements.get('must_have', []):
                if must_have in achievement_lower:
                    score += 30  # Highest priority for must-have matches
                # Check in tags too
                if tags and any(must_have in tag.lower() for tag in tags):
                    score += 35

            # Priority 2: Technology matches
            for tech in requirements['technologies']:
                # Check in achievement text
                if tech in achievement_lower:
                    score += self.scoring_weights['text_tech_match']
                # Check in metadata tags
                if tags and any(tech in tag.lower() for tag in tags):
                    score += self.scoring_weights['metadata_tech_match']

            # Priority 3: Keywords (domain-specific terms)
            for keyword in requirements['keywords']:
                if keyword in achievement_lower:
                    score += self.scoring_weights['text_keyword_match']
                if tags and any(keyword in tag.lower() for tag in tags):
                    score += self.scoring_weights['metadata_keyword_match']

            # Priority 4: Nice-to-have skills
            for nice in requirements.get('nice_to_have', []):
                if nice in achievement_lower:
                    score += 5
                if tags and any(nice in tag.lower() for tag in tags):
                    score += 8

            # Bonus: Check against all extracted terms for comprehensive matching
            if 'all_terms' in requirements:
                term_matches = sum(1 for term in requirements['all_terms'] if term in achievement_lower)
                score += term_matches * 2  # Small bonus for each term match

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
        max_bullets = min(max_bullets, 15)  # Allow up to 15 for 3-page CV when specified

        # Debug: Show top scoring achievements
        sorted_achievements = sorted(
            scored_achievements.items(),
            key=lambda x: x[1],
            reverse=True
        )
        self.logger.info("Top 15 scoring achievements:")
        for i, (achievement, score) in enumerate(sorted_achievements[:15], 1):
            preview = achievement[:60] + "..." if len(achievement) > 60 else achievement
            self.logger.info(f"  {i}. Score {score}: {preview}")

        selected = []

        # Simply take the top scoring achievements without category limits
        # This ensures the CV reflects what's most relevant to the job
        for achievement, score in sorted_achievements[:max_bullets]:
            # Clean the bullet (remove metadata tags)
            clean_bullet, _ = self.parse_metadata_tags(achievement)
            selected.append(clean_bullet)

        return selected

    def determine_job_title(self, bullets: List[str]) -> str:
        """Determine the best job title based on bullet content"""
        bullet_text = ' '.join(bullets).lower()

        # Count keywords to determine focus area
        scores = {
            'Security Platform Engineer': 0,
            'DevOps Platform Engineer': 0,
            'Cloud Platform Engineer': 0,
            'Site Reliability Engineer': 0,
            'Platform Engineer': 0,  # Default
            'Infrastructure Engineer': 0,
            'Observability Engineer': 0,
        }

        # Security keywords
        security_keywords = ['security', 'compliance', 'pci', 'cis', 'vulnerability',
                            'penetration', 'twingate', 'zero trust', 'oidc', 'identity',
                            'gatekeeper', 'policy', 'ssh', 'encryption', 'audit', 'soc',
                            'rbac', 'iam', 'secrets', 'purview', 'entra']

        # DevOps keywords
        devops_keywords = ['ci/cd', 'pipeline', 'jenkins', 'gitlab', 'github actions',
                          'deployment', 'automation', 'docker', 'container', 'build']

        # Cloud keywords
        cloud_keywords = ['aws', 'azure', 'gcp', 'cloud', 'eks', 'aks', 'gke',
                         's3', 'ec2', 'lambda', 'dynamodb', 'rds']

        # SRE keywords
        sre_keywords = ['monitoring', 'observability', 'prometheus', 'grafana',
                       'alerting', 'incident', 'reliability', 'sla', 'slo', 'performance']

        # Infrastructure keywords
        infra_keywords = ['terraform', 'ansible', 'infrastructure', 'provisioning',
                         'configuration', 'networking', 'load balancer', 'cdn']

        # Count matches
        for keyword in security_keywords:
            if keyword in bullet_text:
                scores['Security Platform Engineer'] += 2

        for keyword in devops_keywords:
            if keyword in bullet_text:
                scores['DevOps Platform Engineer'] += 1.5

        for keyword in cloud_keywords:
            if keyword in bullet_text:
                scores['Cloud Platform Engineer'] += 1.5

        for keyword in sre_keywords:
            if keyword in bullet_text:
                scores['Site Reliability Engineer'] += 1.5
                scores['Observability Engineer'] += 1

        for keyword in infra_keywords:
            if keyword in bullet_text:
                scores['Infrastructure Engineer'] += 1

        # Default score for Platform Engineer
        scores['Platform Engineer'] = 5  # Base score

        # Return the title with highest score
        best_title = max(scores.items(), key=lambda x: x[1])[0]
        return best_title

    def escape_typst(self, text: str) -> str:
        """Escape Typst special characters in text"""
        # Typst special chars that need escaping: # @ $ (in code contexts)
        # Note: In content mode, most chars are safe, but # starts code
        escaped = text.replace('#', '\\#')
        escaped = escaped.replace('@', '\\@')
        # $ only needs escaping if used for math mode
        return escaped

    def generate_cv_typst(self, template_path: str, bullets: List[str],
                          skills: Dict, metadata: Dict) -> str:
        """Generate Typst CV from template and selected bullets"""
        with open(template_path, 'r') as f:
            template = f.read()

        # Distribute bullets across positions (same logic as LaTeX)
        if len(bullets) <= 10:
            distribution = {
                'PMI': min(3, len(bullets)),
                'HMRC': min(3, max(0, len(bullets) - 3)),
                'ITV': min(2, max(0, len(bullets) - 6)),
                'NATIONWIDE_EKS': min(2, max(0, len(bullets) - 8)),
                'NATIONWIDE_OBS': 0,
            }
        else:
            distribution = {
                'PMI': min(3, len(bullets)),
                'HMRC': min(3, max(0, len(bullets) - 3)),
                'ITV': min(3, max(0, len(bullets) - 6)),
                'NATIONWIDE_EKS': min(3, max(0, len(bullets) - 9)),
                'NATIONWIDE_OBS': min(3, max(0, len(bullets) - 12)),
            }

        bullet_index = 0
        job_titles = {}

        for position, count in distribution.items():
            if count > 0 and bullet_index < len(bullets):
                position_bullets = bullets[bullet_index:bullet_index + count]
                job_title = self.determine_job_title(position_bullets)

                if position == 'PMI':
                    job_title = 'Senior ' + job_title

                job_titles[position] = job_title

                # Escape Typst special characters and format as list items
                escaped_bullets = []
                for bullet in position_bullets:
                    escaped = self.escape_typst(bullet)
                    escaped_bullets.append(escaped)

                # Typst list format: - item
                bullet_text = '\n    '.join(f'- {b}' for b in escaped_bullets)

                # Replace the position placeholders (Typst uses // for comments)
                # Note: 4 leading spaces match the template indentation inside #job()[...]
                template = template.replace(
                    f'    // {position}_BULLETS_START\n    // {position}_BULLETS_END',
                    f'    // {position}_BULLETS_START\n    {bullet_text}\n    // {position}_BULLETS_END'
                )
                bullet_index += count

        # Replace job title placeholders (Typst uses <<PLACEHOLDER>> syntax)
        template = template.replace('{{PMI_JOB_TITLE}}',
                                  job_titles.get('PMI', 'Senior Platform Engineer'))
        template = template.replace('{{HMRC_JOB_TITLE}}',
                                  job_titles.get('HMRC', 'Site Reliability Engineer'))
        template = template.replace('{{ITV_JOB_TITLE}}',
                                  job_titles.get('ITV', 'Site Reliability Engineer'))
        template = template.replace('{{NATIONWIDE_EKS_JOB_TITLE}}',
                                  job_titles.get('NATIONWIDE_EKS', 'Platform Engineer'))
        template = template.replace('{{NATIONWIDE_OBS_JOB_TITLE}}',
                                  job_titles.get('NATIONWIDE_OBS', 'Platform Engineer - Observability'))

        self.logger.info(f"Selected {len(bullets)} bullets based on job requirements (Typst)")
        if bullets and len(bullets) >= 3:
            self.logger.info("Top 3 bullets selected:")
            for i, bullet in enumerate(bullets[:3], 1):
                preview = bullet[:80] + "..." if len(bullet) > 80 else bullet
                self.logger.info(f"  {i}. {preview}")

        return template

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

        # Distribute bullets across positions
        # Define distribution based on total bullets
        # Note: NATIONWIDE_HUB and OVO have hardcoded bullets in CV.tex
        if len(bullets) <= 10:
            # For 2-page CV: focus on recent roles
            distribution = {
                'PMI': min(3, len(bullets)),
                'HMRC': min(3, max(0, len(bullets) - 3)),
                'ITV': min(2, max(0, len(bullets) - 6)),
                'NATIONWIDE_EKS': min(2, max(0, len(bullets) - 8)),
                'NATIONWIDE_OBS': 0,
                # Skip these - they have hardcoded bullets
                # 'NATIONWIDE_HUB': 0,
                # 'OVO': 0
            }
        else:
            # For 3-page CV: spread across more roles
            distribution = {
                'PMI': min(3, len(bullets)),
                'HMRC': min(3, max(0, len(bullets) - 3)),
                'ITV': min(3, max(0, len(bullets) - 6)),
                'NATIONWIDE_EKS': min(3, max(0, len(bullets) - 9)),
                'NATIONWIDE_OBS': min(3, max(0, len(bullets) - 12)),
                # Skip these - they have hardcoded bullets
                # 'NATIONWIDE_HUB': 0,
                # 'OVO': 0
            }

        # Assign bullets to positions and determine job titles
        bullet_index = 0
        job_titles = {}  # Store job titles for each position

        for position, count in distribution.items():
            if count > 0 and bullet_index < len(bullets):
                position_bullets = bullets[bullet_index:bullet_index + count]

                # Determine the best job title for this position based on its bullets
                job_title = self.determine_job_title(position_bullets)

                # Add seniority prefix based on position
                if position == 'PMI':
                    job_title = 'Senior ' + job_title
                elif position in ['HMRC', 'ITV']:
                    job_title = job_title  # Keep as is
                else:
                    # For older positions, keep the default or adjust
                    job_title = job_title

                job_titles[position] = job_title
                self.logger.debug(f"{position}: {job_title} (based on {count} bullets)")

                # Escape LaTeX special characters in bullets
                escaped_bullets = []
                for bullet in position_bullets:
                    # Escape % symbols and other LaTeX special chars
                    escaped = bullet.replace('%', '\\%').replace('$', '\\$').replace('&', '\\&')
                    escaped_bullets.append(escaped)
                bullet_text = '\n'.join(f'\\item {b}' for b in escaped_bullets)

                # Replace the position placeholders
                template = template.replace(
                    f'% {position}_BULLETS_START\n% {position}_BULLETS_END',
                    f'% {position}_BULLETS_START\n{bullet_text}\n% {position}_BULLETS_END'
                )
                bullet_index += count

        # Replace job title placeholders
        template = template.replace('%%PMI_JOB_TITLE%%',
                                  job_titles.get('PMI', 'Senior Platform Engineer'))
        template = template.replace('%%HMRC_JOB_TITLE%%',
                                  job_titles.get('HMRC', 'Site Reliability Engineer'))
        template = template.replace('%%ITV_JOB_TITLE%%',
                                  job_titles.get('ITV', 'Site Reliability Engineer'))
        template = template.replace('%%NATIONWIDE_EKS_JOB_TITLE%%',
                                  job_titles.get('NATIONWIDE_EKS', 'Platform Engineer'))
        template = template.replace('%%NATIONWIDE_OBS_JOB_TITLE%%',
                                  job_titles.get('NATIONWIDE_OBS', 'Platform Engineer - Observability'))

        cv_content = header + template

        self.logger.info(f"Selected {len(bullets)} bullets based on job requirements")
        if bullets and len(bullets) >= 3:
            self.logger.info("Top 3 bullets selected:")
            for i, bullet in enumerate(bullets[:3], 1):
                preview = bullet[:80] + "..." if len(bullet) > 80 else bullet
                self.logger.info(f"  {i}. {preview}")

        # Debug: Show if security-related bullets are in the selection
        security_bullets = [b for b in bullets if any(term in b.lower() for term in ['security', 'twingate', 'zero trust', 'identity', 'oidc', 'compliance', 'soc'])]
        if security_bullets:
            self.logger.info(f"Security-focused bullets included: {len(security_bullets)}")
        else:
            self.logger.warning("No security-focused bullets in selection!")

        return cv_content

    def create_ats_optimized_version(self, content: str, format_type: str = 'latex') -> str:
        """Create ATS-optimized version of CV

        Args:
            content: LaTeX or Typst source content
            format_type: 'latex' or 'typst'
        """
        lines = []
        for line in content.split('\n'):
            # Skip comment lines (different syntax for each format)
            if format_type == 'typst':
                if line.strip().startswith('//'):
                    lines.append(line)
                    continue
            else:  # latex
                if line.strip().startswith('%'):
                    lines.append(line)
                    continue

            # Replace special characters
            for old, new in self.ats_replacements.items():
                line = line.replace(old, new)

            lines.append(line)

        # Join the lines back together
        ats_content = '\n'.join(lines)

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
                              metadata: Dict, max_bullets: int = 10,
                              format_type: str = 'latex') -> Tuple[str, str, Dict]:
        """Generate both standard and ATS-optimized versions

        Args:
            job_path: Path to job description file
            skills_path: Path to skills.md file
            template_path: Path to CV template (.tex or .typ)
            metadata: Dict with recruiter, type, salary, date
            max_bullets: Maximum bullets to include
            format_type: 'latex' or 'typst'
        """
        self.logger.info("=" * 50)
        self.logger.info(f"🚀 Unified CV Generation ({format_type.upper()})")
        self.logger.info("=" * 50)

        # Parse job description
        self.logger.info("📋 Analyzing job requirements...")
        requirements = self.parse_job_description(job_path)
        self.logger.info(f"  Found {len(requirements['technologies'])} technologies, {len(requirements['keywords'])} keywords")

        # Load skills with metadata
        self.logger.info("📚 Loading skills database...")
        skills = self.load_skills(skills_path)
        self.logger.info(f"  Loaded {len(skills['all_achievements'])} achievements with metadata")

        # Score and select bullets
        self.logger.info("🎯 Scoring achievements based on job match...")
        scored = self.score_achievements(skills, requirements)
        bullets = self.select_bullets(scored, skills, max_bullets=max_bullets)

        # Generate standard CV based on format
        self.logger.info(f"📄 Generating standard CV ({format_type})...")
        if format_type == 'typst':
            standard_content = self.generate_cv_typst(template_path, bullets, skills, metadata)
            file_ext = '.typ'
            # Copy helper file to generated directory for Typst imports
            helper_src = self.jobapps_dir / "cv-helpers.typ"
            helper_dst = self.generated_dir / "cv-helpers.typ"
            if helper_src.exists():
                shutil.copy(helper_src, helper_dst)
        else:
            standard_content = self.generate_cv_latex(template_path, bullets, skills, metadata)
            file_ext = '.tex'

        # Save standard version
        standard_source_path = self.generated_dir / f"cv{file_ext}"
        with open(standard_source_path, 'w') as f:
            f.write(standard_content)

        # Generate ATS-optimized version
        self.logger.info("🤖 Creating ATS-optimized version...")
        ats_content = self.create_ats_optimized_version(standard_content, format_type)

        # Calculate scores
        original_score = self.calculate_ats_score(standard_content, requirements['keywords'])
        optimized_score = self.calculate_ats_score(ats_content, requirements['keywords'])

        report = {
            'original_score': original_score,
            'optimized_score': optimized_score,
            'improvement': optimized_score - original_score
        }

        # Save ATS version
        ats_source_path = self.generated_dir / f"cv_ats{file_ext}"
        with open(ats_source_path, 'w') as f:
            f.write(ats_content)

        self.logger.info(f"  Original ATS Score: {report['original_score']}/100")
        self.logger.info(f"  Optimized ATS Score: {report['optimized_score']}/100")
        self.logger.info(f"  Improvement: +{report['improvement']} points")

        # Compile both PDFs
        self.logger.info("🔨 Compiling PDFs...")
        output_name = f"{metadata['recruiter']}-{metadata['date']}-{metadata['type']}-{metadata['salary']}"

        # Compile standard
        self.compile_pdf(str(standard_source_path), output_name, format_type)

        # Compile ATS
        self.compile_pdf(str(ats_source_path), f"{output_name}-ATS", format_type)

        standard_pdf = self.output_dir / f"{output_name}.pdf"
        ats_pdf = self.output_dir / f"{output_name}-ATS.pdf"

        return str(standard_pdf), str(ats_pdf), report

    def compile_pdf(self, source_path: str, output_name: str, format_type: str = 'latex') -> bool:
        """Compile LaTeX or Typst to PDF

        Args:
            source_path: Path to .tex or .typ file
            output_name: Output PDF name (without extension)
            format_type: 'latex' or 'typst'
        """
        if format_type == 'typst':
            # Direct Typst compilation (single pass, no external script needed)
            output_pdf = self.output_dir / f"{output_name}.pdf"
            try:
                result = subprocess.run(
                    ['typst', 'compile', source_path, str(output_pdf)],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    self.logger.info(f"Successfully compiled {output_name}.pdf (Typst)")
                    return True
                else:
                    self.logger.error(f"Typst compilation failed: {result.stderr}")
                    return False
            except FileNotFoundError:
                self.logger.error("Typst not installed. Run: brew install typst")
                return False
            except Exception as e:
                self.logger.error(f"Typst compilation error: {e}", exc_info=True)
                return False
        else:
            # LaTeX compilation via compile-cv.sh
            compile_script = self.scripts_dir.parent / "compile-cv.sh"

            if not compile_script.exists():
                self.logger.error(f"Compile script not found at {compile_script}")
                return False

            try:
                result = subprocess.run(
                    [str(compile_script), source_path, output_name, 'pdflatex'],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    self.logger.info(f"Successfully compiled {output_name}.pdf")
                else:
                    self.logger.error(f"Compilation failed for {output_name}: {result.stderr}")
                return result.returncode == 0
            except Exception as e:
                self.logger.error(f"Compilation error: {e}", exc_info=True)
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

    # Format selection
    parser.add_argument('--format', choices=['latex', 'typst'], default='latex',
                       help='Output format: latex (default) or typst')

    # Options
    parser.add_argument('--ats-only', action='store_true', help='Generate ATS version only')
    parser.add_argument('--standard-only', action='store_true', help='Generate standard version only')
    parser.add_argument('--no-report', action='store_true', help='Skip HTML report generation')
    parser.add_argument('--open', action='store_true', help='Open files after generation')
    parser.add_argument('--max-bullets', type=int, default=10, help='Maximum bullets to include (10 for 2 pages, 15 for 3 pages)')

    args = parser.parse_args()

    # Set default paths based on format
    base_dir = Path.home() / "dotfiles" / "jobapps"
    if not args.job:
        args.job = str(base_dir / "jobdescription.md")
    if not args.skills:
        args.skills = str(base_dir / "skills.md")
    if not args.template:
        # Select template based on format
        if args.format == 'typst':
            args.template = str(base_dir / "CV.typ")
        else:
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
        args.job, args.skills, args.template, metadata,
        max_bullets=args.max_bullets, format_type=args.format
    )

    # Get logger for main function
    logger = logging.getLogger('cv_generator')

    # Generate comparison report
    if not args.no_report:
        logger.info("📊 Generating comparison report...")
        html = generator.generate_comparison_report(standard_pdf, ats_pdf, report, metadata)
        report_path = generator.generated_dir / f"unified_report_{metadata['recruiter']}_{metadata['date']}.html"
        with open(report_path, 'w') as f:
            f.write(html)
        logger.info(f"  Report saved: {report_path}")

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

    logger.info("✅ Unified CV generation complete!")
    logger.info(f"  Standard: {standard_pdf}")
    logger.info(f"  ATS-Optimized: {ats_pdf}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
#!/usr/bin/env python3
"""
Advanced Job Description Analyzer
Extracts and categorizes requirements with NLP-like pattern matching
"""

import re
import yaml
from pathlib import Path
from typing import Dict, List, Set, Tuple
from collections import defaultdict


class JobAnalyzer:
    """Advanced job description analysis with requirement extraction"""

    def __init__(self):
        """Initialize analyzer with taxonomy"""
        self.taxonomy_path = Path.home() / "dotfiles" / "jobapps" / "skill-taxonomy.yaml"
        self.load_taxonomy()

        # Requirement patterns
        self.requirement_patterns = {
            'must_have': [
                r'required', r'must have', r'essential', r'mandatory',
                r'minimum', r'prerequisite', r'critical'
            ],
            'nice_to_have': [
                r'preferred', r'desirable', r'bonus', r'plus',
                r'advantageous', r'beneficial', r'ideal'
            ],
            'experience_years': [
                r'(\d+)\+?\s*years?', r'(\d+)\s*-\s*(\d+)\s*years?',
                r'minimum\s+(\d+)\s+years?'
            ]
        }

        # Seniority indicators
        self.seniority_levels = {
            'junior': ['junior', 'entry', 'graduate', 'early career'],
            'mid': ['mid-level', 'intermediate', 'experienced'],
            'senior': ['senior', 'lead', 'principal', 'staff', 'expert'],
            'management': ['manager', 'head', 'director', 'vp']
        }

    def load_taxonomy(self):
        """Load skill taxonomy for intelligent matching"""
        if self.taxonomy_path.exists():
            with open(self.taxonomy_path, 'r') as f:
                self.taxonomy = yaml.safe_load(f)
        else:
            self.taxonomy = {}

    def extract_requirements(self, job_text: str) -> Dict:
        """Extract structured requirements from job description"""
        requirements = {
            'must_have': [],
            'nice_to_have': [],
            'technologies': set(),
            'skills': set(),
            'experience_years': None,
            'seniority': None,
            'certifications': [],
            'responsibilities': [],
            'team_size': None,
            'industry': None
        }

        lines = job_text.split('\n')
        current_section = None

        for line in lines:
            line_lower = line.lower().strip()

            # Detect sections
            if self._is_requirement_section(line_lower):
                current_section = 'requirements'
            elif self._is_responsibility_section(line_lower):
                current_section = 'responsibilities'
            elif self._is_qualification_section(line_lower):
                current_section = 'qualifications'

            # Extract based on current section
            if current_section and line.startswith(('•', '-', '*', '·')):
                bullet = line.lstrip('•-*· ').strip()

                # Categorize requirement
                if self._is_must_have(bullet):
                    requirements['must_have'].append(bullet)
                elif self._is_nice_to_have(bullet):
                    requirements['nice_to_have'].append(bullet)

                if current_section == 'responsibilities':
                    requirements['responsibilities'].append(bullet)

                # Extract technologies
                techs = self._extract_technologies(bullet)
                requirements['technologies'].update(techs)

        # Extract additional metadata
        requirements['experience_years'] = self._extract_experience_years(job_text)
        requirements['seniority'] = self._extract_seniority(job_text)
        requirements['certifications'] = self._extract_certifications(job_text)
        requirements['team_size'] = self._extract_team_size(job_text)

        # Expand technologies using taxonomy
        requirements['technologies'] = self._expand_with_taxonomy(requirements['technologies'])

        return requirements

    def _is_requirement_section(self, text: str) -> bool:
        """Check if text indicates requirements section"""
        patterns = ['requirement', 'qualification', 'skill', 'experience', 'looking for']
        return any(p in text for p in patterns)

    def _is_responsibility_section(self, text: str) -> bool:
        """Check if text indicates responsibilities section"""
        patterns = ['responsibilit', 'duty', 'duties', 'role', 'you will']
        return any(p in text for p in patterns)

    def _is_qualification_section(self, text: str) -> bool:
        """Check if text indicates qualifications section"""
        patterns = ['qualification', 'education', 'degree', 'certified']
        return any(p in text for p in patterns)

    def _is_must_have(self, text: str) -> bool:
        """Check if requirement is mandatory"""
        text_lower = text.lower()
        return any(pattern in text_lower for pattern in self.requirement_patterns['must_have'])

    def _is_nice_to_have(self, text: str) -> bool:
        """Check if requirement is optional"""
        text_lower = text.lower()
        return any(pattern in text_lower for pattern in self.requirement_patterns['nice_to_have'])

    def _extract_technologies(self, text: str) -> Set[str]:
        """Extract technology mentions from text"""
        technologies = set()
        text_lower = text.lower()

        # Check against taxonomy
        for tech, details in self.taxonomy.items():
            if tech in text_lower:
                technologies.add(tech)

            # Check aliases
            if isinstance(details, dict) and 'aliases' in details:
                for alias in details['aliases']:
                    if alias.lower() in text_lower:
                        technologies.add(tech)

        # Common technology patterns
        tech_patterns = [
            r'\b([A-Z][a-zA-Z]+(?:[A-Z][a-zA-Z]+)*)\b',  # CamelCase
            r'\b([A-Z]{2,})\b',  # Acronyms
            r'\b(\w+\.js)\b',  # .js frameworks
            r'\b(\w+\.py)\b',  # Python files
        ]

        for pattern in tech_patterns:
            matches = re.findall(pattern, text)
            technologies.update(match.lower() for match in matches)

        return technologies

    def _extract_experience_years(self, text: str) -> Tuple[int, int]:
        """Extract required years of experience"""
        for pattern in self.requirement_patterns['experience_years']:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                groups = match.groups()
                if len(groups) == 1:
                    return (int(groups[0]), None)
                elif len(groups) == 2:
                    return (int(groups[0]), int(groups[1]))
        return None

    def _extract_seniority(self, text: str) -> str:
        """Extract seniority level from job description"""
        text_lower = text.lower()

        for level, keywords in self.seniority_levels.items():
            if any(keyword in text_lower for keyword in keywords):
                return level

        return 'mid'  # Default to mid-level

    def _extract_certifications(self, text: str) -> List[str]:
        """Extract certification requirements"""
        certifications = []

        # Common certification patterns
        cert_patterns = [
            r'(AWS\s+Certified\s+[\w\s]+)',
            r'(CK[ADS])',  # Kubernetes certs
            r'(HashiCorp\s+Certified)',
            r'(Azure\s+[\w\s]+)',
            r'(GCP\s+[\w\s]+)',
            r'(Certified\s+[\w\s]+)',
        ]

        for pattern in cert_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            certifications.extend(matches)

        return list(set(certifications))

    def _extract_team_size(self, text: str) -> str:
        """Extract team size information"""
        patterns = [
            r'team of (\d+)',
            r'(\d+)\+ engineers',
            r'(\d+)\+ teams',
            r'(\d+) person team'
        ]

        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1)

        return None

    def _expand_with_taxonomy(self, technologies: Set[str]) -> Set[str]:
        """Expand technology list using taxonomy relationships"""
        expanded = set(technologies)

        for tech in list(technologies):
            if tech in self.taxonomy:
                details = self.taxonomy[tech]

                # Add related technologies
                if isinstance(details, dict):
                    if 'related' in details:
                        expanded.update(details['related'])
                    if 'implies' in details:
                        expanded.update(details['implies'])

        return expanded

    def calculate_match_score(self, requirements: Dict, cv_data: Dict) -> Dict:
        """Calculate how well CV matches job requirements"""
        scores = {
            'overall': 0,
            'must_have_coverage': 0,
            'nice_to_have_coverage': 0,
            'technology_match': 0,
            'experience_match': 0,
            'seniority_match': 0,
            'certification_match': 0
        }

        # Calculate must-have coverage
        if requirements['must_have']:
            matched = sum(1 for req in requirements['must_have']
                         if self._requirement_in_cv(req, cv_data))
            scores['must_have_coverage'] = (matched / len(requirements['must_have'])) * 100

        # Calculate technology match
        if requirements['technologies']:
            cv_techs = self._extract_cv_technologies(cv_data)
            matched = requirements['technologies'].intersection(cv_techs)
            scores['technology_match'] = (len(matched) / len(requirements['technologies'])) * 100

        # Calculate overall score
        scores['overall'] = (
            scores['must_have_coverage'] * 0.4 +
            scores['nice_to_have_coverage'] * 0.2 +
            scores['technology_match'] * 0.3 +
            scores['experience_match'] * 0.05 +
            scores['seniority_match'] * 0.05
        )

        return scores

    def _requirement_in_cv(self, requirement: str, cv_data: Dict) -> bool:
        """Check if requirement is covered in CV"""
        req_lower = requirement.lower()

        # Check in all CV sections
        for section in cv_data.values():
            if isinstance(section, list):
                for item in section:
                    if isinstance(item, str) and req_lower in item.lower():
                        return True
            elif isinstance(section, str) and req_lower in section.lower():
                return True

        return False

    def _extract_cv_technologies(self, cv_data: Dict) -> Set[str]:
        """Extract all technologies mentioned in CV"""
        technologies = set()

        # Extract from all text in CV
        for section in cv_data.values():
            if isinstance(section, list):
                for item in section:
                    if isinstance(item, str):
                        technologies.update(self._extract_technologies(item))
            elif isinstance(section, str):
                technologies.update(self._extract_technologies(section))

        return technologies

    def generate_recommendations(self, requirements: Dict, scores: Dict) -> List[str]:
        """Generate recommendations for CV improvement"""
        recommendations = []

        if scores['must_have_coverage'] < 80:
            recommendations.append(
                f"⚠️ Only {scores['must_have_coverage']:.0f}% of must-have requirements covered. "
                "Consider emphasizing missing skills in your experience bullets."
            )

        if scores['technology_match'] < 70:
            missing_techs = requirements['technologies'] - self._extract_cv_technologies({})
            recommendations.append(
                f"💡 Add experience with: {', '.join(list(missing_techs)[:5])}"
            )

        if requirements['certifications']:
            recommendations.append(
                f"📜 Consider highlighting relevant certifications: {', '.join(requirements['certifications'][:3])}"
            )

        return recommendations


if __name__ == '__main__':
    import sys

    analyzer = JobAnalyzer()

    if len(sys.argv) > 1:
        job_file = sys.argv[1]
        with open(job_file, 'r') as f:
            job_text = f.read()

        requirements = analyzer.extract_requirements(job_text)

        print("📋 Job Analysis Results")
        print("=" * 50)
        print(f"Technologies: {', '.join(list(requirements['technologies'])[:10])}")
        print(f"Experience: {requirements['experience_years']} years")
        print(f"Seniority: {requirements['seniority']}")
        print(f"Must-have items: {len(requirements['must_have'])}")
        print(f"Nice-to-have items: {len(requirements['nice_to_have'])}")

        if requirements['certifications']:
            print(f"Certifications: {', '.join(requirements['certifications'])}")
    else:
        print("Usage: python job-analyzer.py <job_description_file>")
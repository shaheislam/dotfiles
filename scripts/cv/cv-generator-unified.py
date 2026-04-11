#!/usr/bin/env python3
"""
Unified CV Generator
Combines metadata-based matching, standard CV generation, and ATS optimization
Single source of truth: skills.md with metadata tags + role_bullets.py for role-specific bullets
"""

import argparse
import subprocess
import sys
import re
import logging
import shutil
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Set
import json

# Import role bullets data
sys.path.insert(0, str(Path(__file__).parent))
from role_bullets import ROLE_BULLETS, ROLE_METADATA, get_all_role_bullets

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
    logger = logging.getLogger("cv_generator")
    logger.setLevel(logging.DEBUG if debug_mode else log_level)

    # Remove existing handlers
    logger.handlers.clear()

    # Console handler - INFO level for user feedback
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_formatter = logging.Formatter("%(levelname)s: %(message)s")
    console_handler.setFormatter(console_formatter)

    # Main log file - all operations
    main_log = output_dir / "cv_generator.log"
    main_handler = logging.FileHandler(main_log, mode="a", encoding="utf-8")
    main_handler.setLevel(log_level)
    main_formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(funcName)s:%(lineno)d | %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
    )
    main_handler.setFormatter(main_formatter)

    # Error log file - errors only
    error_log = output_dir / "errors.log"
    error_handler = logging.FileHandler(error_log, mode="a", encoding="utf-8")
    error_handler.setLevel(logging.ERROR)
    error_formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(funcName)s:%(lineno)d | %(message)s\nException: %(exc_info)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    error_handler.setFormatter(error_formatter)

    # Debug log file (optional)
    if debug_mode:
        debug_log = output_dir / "debug.log"
        debug_handler = logging.FileHandler(debug_log, mode="a", encoding="utf-8")
        debug_handler.setLevel(logging.DEBUG)
        debug_formatter = logging.Formatter(
            "%(asctime)s | DEBUG | %(funcName)s:%(lineno)d | %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
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
        self.base_dir = Path(os.environ.get("DOTFILES_ROOT", Path(__file__).resolve().parents[2])).expanduser()
        self.jobapps_dir = Path(os.environ.get("JOBAPPS_DIR", self.base_dir / "jobapps")).expanduser()
        self.scripts_dir = self.base_dir / "scripts" / "cv"
        self.documents_jobapps_dir = Path(
            os.environ.get("CV_DOCUMENTS_JOBAPPS_DIR", Path.home() / "Documents" / "jobapps")
        ).expanduser()
        self.output_dir = Path(os.environ.get("CV_OUTPUT_DIR", self.documents_jobapps_dir / "output")).expanduser()
        self.generated_dir = Path(
            os.environ.get("CV_GENERATED_DIR", self.documents_jobapps_dir / "generated")
        ).expanduser()

        # Ensure directories exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.generated_dir.mkdir(parents=True, exist_ok=True)

        # Setup logging
        self.logger = setup_logging(self.generated_dir, debug_mode=debug_mode)
        self.logger.info(f"Initialized CV Generator - Output: {self.output_dir}")

        # ATS optimization settings (built-in)
        self.ats_replacements = {
            "+": " plus ",
            "&": " and ",
            "$": "USD ",
            "€": "EUR ",
            "£": "GBP ",
            "•": "- ",
            "→": " to ",
            "←": " from ",
            "↑": " up ",
            "↓": " down ",
            "×": " times ",
            "÷": " divided by ",
            "≈": " approximately ",
            "≥": " greater than or equal to ",
            "≤": " less than or equal to ",
            "≠": " not equal to ",
        }

        # Scoring weights
        self.scoring_weights = {
            "metadata_tech_match": 25,  # Highest priority
            "metadata_keyword_match": 20,
            "metadata_requirement_match": 15,
            "text_tech_match": 15,
            "text_keyword_match": 10,
            "quantifiable": 5,
            "domain_specific": 8,
            "cost_savings": 10,
        }

        # Page estimation settings
        # Rough heuristics: ~30-32 bullets = 3 pages
        self.max_total_bullets = 32
        self.min_bullets_per_role = 3

        # Role order for CV (most recent first)
        self.role_order = ["DFE", "HMRC", "ITV", "NATIONWIDE_EKS", "NATIONWIDE_OBS", "NATIONWIDE_HUB", "OVO"]

        # Score threshold for DFE consideration
        self.dfe_score_threshold = 20

    def parse_job_description(self, job_path: str) -> Dict:
        """Parse job description to dynamically extract ALL requirements"""
        requirements = {
            "technologies": [],
            "keywords": [],
            "must_have": [],
            "nice_to_have": [],
            "all_terms": [],  # New: capture all significant terms
        }

        if not Path(job_path).exists():
            self.logger.warning(f"Job description not found at {job_path}")
            return requirements

        with open(job_path, "r") as f:
            content = f.read()

        content_lower = content.lower()

        # Dynamic technology extraction - find all technical terms
        # Pattern 1: Capitalized words and acronyms (likely to be tools/technologies)
        tech_terms = re.findall(r"\b[A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)*\b", content)
        tech_acronyms = re.findall(r"\b[A-Z]{2,}[0-9]*\b", content)

        # Pattern 2: Terms with special chars (e.g., M365, K8s)
        special_terms = re.findall(r"\b[A-Za-z]+[0-9]+[A-Za-z]*\b|\b[A-Za-z]*[0-9]+[A-Za-z]+\b", content)

        # Pattern 3: Common tech patterns (word-word, word/word)
        compound_terms = re.findall(r"\b\w+[-/]\w+\b", content_lower)

        # Pattern 4: Extract from sections like "Essential Technical Skills"
        # Look for bullet points and technical sections
        tech_section_match = re.search(
            r"(technical|skills|requirements|experience).*?(?=\n\n|\Z)", content_lower, re.DOTALL | re.IGNORECASE
        )
        if tech_section_match:
            section_text = tech_section_match.group()
            # Extract all nouns and technical terms from this section
            section_terms = re.findall(r"\b[a-zA-Z][\w\-\./]+\b", section_text)
            requirements["technologies"].extend(section_terms)

        # Combine all technical terms
        all_tech = tech_terms + tech_acronyms + special_terms + compound_terms

        # Clean and filter technical terms
        for term in all_tech:
            clean_term = term.strip().lower()
            # Filter out common words and keep technical terms
            if len(clean_term) > 2 and clean_term not in [
                "the",
                "and",
                "for",
                "with",
                "from",
                "this",
                "that",
                "will",
                "can",
                "has",
                "have",
                "are",
                "was",
                "were",
                "been",
            ]:
                requirements["technologies"].append(clean_term)

        # Extract domain-specific keywords based on job content
        # Dynamically identify important words based on frequency and context
        words = re.findall(r"\b[a-z]+\b", content_lower)
        word_freq = {}
        for word in words:
            if len(word) > 4:  # Focus on meaningful words
                word_freq[word] = word_freq.get(word, 0) + 1

        # Keywords are frequently mentioned important terms
        sorted_words = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)
        requirements["keywords"] = [word for word, freq in sorted_words[:20] if freq > 1]

        # Extract specific requirements from "Essential" or "Required" sections
        essential_match = re.search(
            r"(essential|required|must.have).*?(?=(desirable|nice.to.have|\n\n|\Z))",
            content_lower,
            re.DOTALL | re.IGNORECASE,
        )
        if essential_match:
            essential_text = essential_match.group()
            # Extract all technical terms from essential section
            essential_terms = re.findall(r"\b[a-zA-Z][\w\-\./]+\b", essential_text)
            requirements["must_have"] = [t.lower() for t in essential_terms if len(t) > 2]

        # Extract nice-to-have from "Desirable" sections
        desirable_match = re.search(
            r"(desirable|nice.to.have|preferred).*?(?=\n\n|\Z)", content_lower, re.DOTALL | re.IGNORECASE
        )
        if desirable_match:
            desirable_text = desirable_match.group()
            desirable_terms = re.findall(r"\b[a-zA-Z][\w\-\./]+\b", desirable_text)
            requirements["nice_to_have"] = [t.lower() for t in desirable_terms if len(t) > 2]

        # Store all unique terms for comprehensive matching
        requirements["all_terms"] = list(
            set(
                requirements["technologies"]
                + requirements["keywords"]
                + requirements["must_have"]
                + requirements["nice_to_have"]
            )
        )

        # Deduplicate while preserving order of importance
        requirements["technologies"] = list(dict.fromkeys(requirements["technologies"]))[:50]
        requirements["keywords"] = list(dict.fromkeys(requirements["keywords"]))[:30]
        requirements["must_have"] = list(dict.fromkeys(requirements["must_have"]))[:30]
        requirements["nice_to_have"] = list(dict.fromkeys(requirements["nice_to_have"]))[:20]

        self.logger.info(f"Dynamically extracted from job description:")
        self.logger.info(f"  - {len(requirements['technologies'])} technologies/tools")
        self.logger.info(f"  - {len(requirements['keywords'])} keywords")
        self.logger.info(f"  - {len(requirements['must_have'])} must-have skills")
        self.logger.info(f"  - {len(requirements['nice_to_have'])} nice-to-have skills")

        # Show top extracted terms for debugging
        if requirements["technologies"]:
            self.logger.info(f"  Top technologies detected: {', '.join(requirements['technologies'][:10])}")

        # Debug: Show what we're actually looking for
        self.logger.debug(f"Key terms we're matching against:")
        self.logger.debug(
            f"  Must-have: {', '.join(requirements['must_have'][:10]) if requirements['must_have'] else 'None'}"
        )
        self.logger.debug(
            f"  Technologies: {', '.join([t for t in requirements['technologies'] if any(x in t for x in ['security', 'identity', 'entra', 'purview', 'cyber'])][:10])}"
        )

        return requirements

    def load_skills(self, skills_path: str) -> Dict:
        """Load skills from skills.md with metadata tags"""
        skills = {"technical": [], "achievements": {}, "all_achievements": [], "certifications": [], "education": []}

        with open(skills_path, "r") as f:
            lines = f.readlines()

        current_section = None
        current_subsection = None

        for line in lines:
            line = line.rstrip()

            # Main sections
            if line.startswith("## "):
                current_section = line[3:]
                current_subsection = None
                continue

            # Subsections
            if line.startswith("### "):
                current_subsection = line[4:]
                if current_section == "Key Responsibilities & Achievements":
                    skills["achievements"][current_subsection] = []
                continue

            # Bullet points
            if line.startswith("- "):
                bullet = line[2:]

                # Technical skills
                if current_section == "Technical Skills":
                    skills["technical"].append(bullet)

                # Achievements (with metadata)
                elif current_section == "Key Responsibilities & Achievements":
                    if current_subsection:
                        skills["achievements"][current_subsection].append(bullet)
                        skills["all_achievements"].append(bullet)

                # Certifications
                elif current_section == "Certifications":
                    skills["certifications"].append(bullet)

        return skills

    def parse_metadata_tags(self, achievement: str) -> Tuple[str, List[str], bool]:
        """Extract metadata tags and ALWAYS_DFE flag from achievement bullet.

        Returns: (clean_text, tags, always_dfe)
        """
        always_dfe = "[ALWAYS_DFE]" in achievement
        # Remove ALWAYS_DFE marker from text
        text = achievement.replace("[ALWAYS_DFE]", "").strip()

        if "[Tags:" in text:
            tag_start = text.find("[Tags:")
            tag_end = text.find("]", tag_start)
            if tag_end > tag_start:
                tags_str = text[tag_start + 6 : tag_end]
                tags = [tag.strip().lower() for tag in tags_str.split(",")]
                clean_text = text[:tag_start].strip()
                return clean_text, tags, always_dfe
        return text, [], always_dfe

    def score_achievements(self, skills: Dict, requirements: Dict) -> Tuple[Dict, List[str]]:
        """Score achievements based on dynamic job requirements.

        Returns: (scored_achievements dict, list of always_dfe bullet texts)
        """
        scored_achievements = {}
        always_dfe_bullets = []

        for achievement in skills["all_achievements"]:
            score = 0
            clean_text, tags, always_dfe = self.parse_metadata_tags(achievement)
            achievement_lower = clean_text.lower()

            # Track ALWAYS_DFE bullets
            if always_dfe:
                always_dfe_bullets.append(clean_text)
                self.logger.info(f"Found ALWAYS_DFE bullet: {clean_text[:60]}...")

            # Priority 1: Must-have requirements (highest weight)
            for must_have in requirements.get("must_have", []):
                if must_have in achievement_lower:
                    score += 30  # Highest priority for must-have matches
                # Check in tags too
                if tags and any(must_have in tag.lower() for tag in tags):
                    score += 35

            # Priority 2: Technology matches
            for tech in requirements["technologies"]:
                # Check in achievement text
                if tech in achievement_lower:
                    score += self.scoring_weights["text_tech_match"]
                # Check in metadata tags
                if tags and any(tech in tag.lower() for tag in tags):
                    score += self.scoring_weights["metadata_tech_match"]

            # Priority 3: Keywords (domain-specific terms)
            for keyword in requirements["keywords"]:
                if keyword in achievement_lower:
                    score += self.scoring_weights["text_keyword_match"]
                if tags and any(keyword in tag.lower() for tag in tags):
                    score += self.scoring_weights["metadata_keyword_match"]

            # Priority 4: Nice-to-have skills
            for nice in requirements.get("nice_to_have", []):
                if nice in achievement_lower:
                    score += 5
                if tags and any(nice in tag.lower() for tag in tags):
                    score += 8

            # Bonus: Check against all extracted terms for comprehensive matching
            if "all_terms" in requirements:
                term_matches = sum(1 for term in requirements["all_terms"] if term in achievement_lower)
                score += term_matches * 2  # Small bonus for each term match

            # Bonus for quantifiable achievements
            if any(char.isdigit() for char in clean_text):
                score += self.scoring_weights["quantifiable"]
            if "$" in clean_text or "£" in clean_text or "%" in clean_text:
                score += self.scoring_weights["cost_savings"]

            # Domain-specific bonuses
            if "kubernetes" in achievement_lower or "k8s" in achievement_lower:
                score += self.scoring_weights["domain_specific"]
            if "cost" in achievement_lower and ("saving" in achievement_lower or "reduction" in achievement_lower):
                score += self.scoring_weights["cost_savings"]

            # Always include ALWAYS_DFE bullets, even with 0 score
            if score > 0 or always_dfe:
                scored_achievements[achievement] = score

        sorted_achievements = dict(sorted(scored_achievements.items(), key=lambda x: x[1], reverse=True))
        return sorted_achievements, always_dfe_bullets

    def score_role_bullets(self, requirements: Dict) -> List[Dict]:
        """Score all role bullets from role_bullets.py against job requirements.

        Returns list of dicts with: text, tags, role, score, static
        """
        scored_bullets = []

        for bullet_info in get_all_role_bullets():
            score = 0
            text = bullet_info["text"]
            tags = bullet_info["tags"]
            text_lower = text.lower()

            # Priority 1: Must-have requirements
            for must_have in requirements.get("must_have", []):
                if must_have in text_lower:
                    score += 30
                if any(must_have in tag.lower() for tag in tags):
                    score += 35

            # Priority 2: Technology matches
            for tech in requirements.get("technologies", []):
                if tech in text_lower:
                    score += self.scoring_weights["text_tech_match"]
                if any(tech in tag.lower() for tag in tags):
                    score += self.scoring_weights["metadata_tech_match"]

            # Priority 3: Keywords
            for keyword in requirements.get("keywords", []):
                if keyword in text_lower:
                    score += self.scoring_weights["text_keyword_match"]
                if any(keyword in tag.lower() for tag in tags):
                    score += self.scoring_weights["metadata_keyword_match"]

            # Priority 4: Nice-to-have
            for nice in requirements.get("nice_to_have", []):
                if nice in text_lower:
                    score += 5
                if any(nice in tag.lower() for tag in tags):
                    score += 8

            # All terms matching
            if "all_terms" in requirements:
                term_matches = sum(1 for term in requirements["all_terms"] if term in text_lower)
                score += term_matches * 2

            # Quantifiable bonus
            if any(char.isdigit() for char in text):
                score += self.scoring_weights["quantifiable"]
            if "$" in text or "£" in text or "%" in text:
                score += self.scoring_weights["cost_savings"]

            scored_bullets.append(
                {
                    "text": text,
                    "tags": tags,
                    "role": bullet_info["role"],
                    "score": score,
                    "static": bullet_info["static"],
                }
            )

        return scored_bullets

    def distribute_bullets_dynamically(
        self, skills_bullets: List[Dict], role_bullets: List[Dict], requirements: Dict
    ) -> Dict[str, List[str]]:
        """Distribute bullets across roles based on job requirements.

        Algorithm:
        1. Reserve minimum bullets for each role from their own pool
        2. Allocate remaining skills.md bullets to DFE
        3. If DFE needs more bullets, borrow high-scoring ones from other roles
        4. If total exceeds max_total_bullets, remove lowest-scoring bullets

        Returns: Dict mapping role -> list of bullet texts
        """
        # Initialize role allocations
        role_allocations = {role: [] for role in self.role_order}
        used_bullets = set()

        # Phase 1: Reserve minimum bullets for each role (not DFE) from their own pool
        self.logger.info("Phase 1: Reserving minimum bullets per role...")

        # Sort role bullets by score within each role
        role_bullets_by_role = {}
        for bullet in role_bullets:
            role = bullet["role"]
            if role not in role_bullets_by_role:
                role_bullets_by_role[role] = []
            role_bullets_by_role[role].append(bullet)

        # Sort each role's bullets by score
        for role in role_bullets_by_role:
            role_bullets_by_role[role].sort(key=lambda x: x["score"], reverse=True)

        # Allocate minimum to each role
        for role in self.role_order:
            if role == "DFE":
                continue  # DFE comes later

            role_own_bullets = role_bullets_by_role.get(role, [])
            metadata = ROLE_METADATA.get(role, {})

            # Static roles get ALL their bullets
            if metadata.get("static", False):
                for bullet in role_own_bullets:
                    role_allocations[role].append(bullet)
                    used_bullets.add(bullet["text"])
                self.logger.info(f"  {role}: {len(role_allocations[role])} bullets (static)")
            else:
                # Non-static roles get their minimum
                min_required = metadata.get("min_bullets", self.min_bullets_per_role)
                for bullet in role_own_bullets[:min_required]:
                    role_allocations[role].append(bullet)
                    used_bullets.add(bullet["text"])
                self.logger.info(f"  {role}: {len(role_allocations[role])} bullets (min reserved)")

        # Phase 2a: First add ALWAYS_DFE bullets (guaranteed inclusion)
        self.logger.info("Phase 2a: Adding ALWAYS_DFE bullets to DFE...")
        always_dfe_count = 0
        for bullet in skills_bullets:
            if bullet.get("always_dfe", False) and bullet["text"] not in used_bullets:
                role_allocations["DFE"].append(
                    {
                        **bullet,
                        "role": "DFE",
                        "static": True,  # Mark as static so it won't be trimmed
                        "source": "skills.md (ALWAYS_DFE)",
                    }
                )
                used_bullets.add(bullet["text"])
                always_dfe_count += 1
                self.logger.info(f"  Added ALWAYS_DFE: {bullet['text'][:60]}...")

        self.logger.info(f"  DFE: {always_dfe_count} ALWAYS_DFE bullets added")

        # Phase 2b: Allocate remaining skills.md bullets to DFE by score
        self.logger.info("Phase 2b: Allocating remaining skills.md bullets to DFE...")

        # Sort skills bullets by score
        sorted_skills = sorted(skills_bullets, key=lambda x: x["score"], reverse=True)

        # Add high-scoring skills.md bullets to DFE
        for bullet in sorted_skills:
            if bullet["score"] >= self.dfe_score_threshold and bullet["text"] not in used_bullets:
                role_allocations["DFE"].append(
                    {
                        **bullet,
                        "role": "DFE",
                        "static": False,
                        "source": "skills.md",
                    }
                )
                used_bullets.add(bullet["text"])

        self.logger.info(f"  DFE: {len(role_allocations['DFE'])} total bullets from skills.md")

        # Phase 3: If DFE needs more bullets, consider borrowing from other roles
        # (Only if skills.md didn't provide enough high-scoring matches)
        min_dfe_bullets = 5
        if len(role_allocations["DFE"]) < min_dfe_bullets:
            # Lower threshold for borrowing if we're desperate
            borrow_threshold = (
                self.dfe_score_threshold // 2 if len(role_allocations["DFE"]) == 0 else self.dfe_score_threshold
            )
            self.logger.info(f"Phase 3: DFE has only {len(role_allocations['DFE'])} bullets, looking for more...")

            # Get remaining high-scoring bullets from other roles
            remaining_role_bullets = []
            for role, bullets in role_bullets_by_role.items():
                metadata = ROLE_METADATA.get(role, {})
                if metadata.get("static", False):
                    continue  # Never borrow from static roles

                min_required = metadata.get("min_bullets", self.min_bullets_per_role)
                # Only consider bullets above the minimum
                for bullet in bullets[min_required:]:
                    if bullet["text"] not in used_bullets and not bullet["static"]:
                        remaining_role_bullets.append(bullet)

            # Sort by score and borrow highest scoring
            remaining_role_bullets.sort(key=lambda x: x["score"], reverse=True)

            for bullet in remaining_role_bullets:
                if len(role_allocations["DFE"]) >= min_dfe_bullets:
                    break
                if bullet["score"] >= borrow_threshold:
                    role_allocations["DFE"].append(
                        {
                            **bullet,
                            "borrowed_from": bullet["role"],
                        }
                    )
                    used_bullets.add(bullet["text"])
                    self.logger.info(f"  Borrowed from {bullet['role']}: {bullet['text'][:50]}...")

        # Phase 4: Fill remaining slots in each role (above minimum)
        self.logger.info("Phase 4: Filling remaining slots in each role...")
        for role in self.role_order:
            if role == "DFE":
                continue

            metadata = ROLE_METADATA.get(role, {})
            if metadata.get("static", False):
                continue  # Static roles already have all bullets

            role_own_bullets = role_bullets_by_role.get(role, [])
            current_count = len(role_allocations[role])
            min_required = metadata.get("min_bullets", self.min_bullets_per_role)

            # Add more bullets if available and under total limit
            for bullet in role_own_bullets[current_count:]:
                if bullet["text"] not in used_bullets:
                    role_allocations[role].append(bullet)
                    used_bullets.add(bullet["text"])

        # Log allocations before trimming
        for role in self.role_order:
            self.logger.info(f"Before trimming - {role}: {len(role_allocations[role])} bullets")

        # Phase 5: Check page limit and trim if needed
        total_bullets = sum(len(bullets) for bullets in role_allocations.values())
        self.logger.info(f"Total bullets before trimming: {total_bullets}")

        if total_bullets > self.max_total_bullets:
            self.logger.info(f"Over limit ({total_bullets} > {self.max_total_bullets}), trimming...")

            # Collect all removable bullets with their role and score
            removable = []
            for role in self.role_order:
                metadata = ROLE_METADATA.get(role, {})
                if metadata.get("static", False):
                    continue  # Never remove from static roles

                min_required = metadata.get("min_bullets", self.min_bullets_per_role)
                bullets = role_allocations[role]

                # Only bullets above minimum are removable
                for i, bullet in enumerate(bullets):
                    if i >= min_required:
                        removable.append(
                            {
                                "role": role,
                                "index": i,
                                "score": bullet["score"],
                                "text": bullet["text"],
                            }
                        )

            # Sort by score (lowest first) and remove
            removable.sort(key=lambda x: x["score"])

            while total_bullets > self.max_total_bullets and removable:
                # Find the lowest scoring removable bullet
                to_remove = removable.pop(0)
                role = to_remove["role"]

                # Find and remove it
                for i, bullet in enumerate(role_allocations[role]):
                    if bullet["text"] == to_remove["text"]:
                        role_allocations[role].pop(i)
                        self.logger.debug(f"Removed from {role}: {to_remove['text'][:50]}...")
                        total_bullets -= 1
                        break

        # Edge case: If DFE still has no bullets, take top skills regardless of score
        if len(role_allocations["DFE"]) == 0:
            self.logger.warning("DFE has no bullets! Taking top skills regardless of score...")
            fallback_skills = sorted(skills_bullets, key=lambda x: x["score"], reverse=True)
            for bullet in fallback_skills[:min_dfe_bullets]:
                if bullet["text"] not in used_bullets:
                    role_allocations["DFE"].append(
                        {
                            **bullet,
                            "role": "DFE",
                            "static": False,
                            "source": "skills.md (fallback)",
                        }
                    )
                    used_bullets.add(bullet["text"])

        # Log final allocations
        self.logger.info("Final bullet distribution:")
        for role in self.role_order:
            self.logger.info(f"  {role}: {len(role_allocations[role])} bullets")

        # Validate minimums weren't violated
        for role in self.role_order:
            metadata = ROLE_METADATA.get(role, {})
            if not metadata.get("static", False):
                min_required = metadata.get("min_bullets", self.min_bullets_per_role)
                if len(role_allocations[role]) < min_required and role != "DFE":
                    self.logger.warning(
                        f"  WARNING: {role} has {len(role_allocations[role])} bullets, below minimum {min_required}"
                    )

        # Convert to Dict[str, List[str]] (just the text)
        result = {}
        for role, bullets in role_allocations.items():
            result[role] = [b["text"] for b in bullets]

        return result

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
        sorted_achievements = sorted(scored_achievements.items(), key=lambda x: x[1], reverse=True)
        self.logger.info("Top 15 scoring achievements:")
        for i, (achievement, score) in enumerate(sorted_achievements[:15], 1):
            preview = achievement[:60] + "..." if len(achievement) > 60 else achievement
            self.logger.info(f"  {i}. Score {score}: {preview}")

        selected = []

        # Simply take the top scoring achievements without category limits
        # This ensures the CV reflects what's most relevant to the job
        for achievement, score in sorted_achievements[:max_bullets]:
            # Clean the bullet (remove metadata tags)
            clean_bullet, _, _ = self.parse_metadata_tags(achievement)
            selected.append(clean_bullet)

        return selected

    def determine_job_title(self, bullets: List[str]) -> str:
        """Determine the best job title based on bullet content"""
        bullet_text = " ".join(bullets).lower()

        # Count keywords to determine focus area
        scores: Dict[str, float] = {
            "Security Platform Engineer": 0,
            "DevOps Platform Engineer": 0,
            "Cloud Platform Engineer": 0,
            "Site Reliability Engineer": 0,
            "Platform Engineer": 0,  # Default
            "Infrastructure Engineer": 0,
            "Observability Engineer": 0,
        }

        # Security keywords
        security_keywords = [
            "security",
            "compliance",
            "pci",
            "cis",
            "vulnerability",
            "penetration",
            "twingate",
            "zero trust",
            "oidc",
            "identity",
            "gatekeeper",
            "policy",
            "ssh",
            "encryption",
            "audit",
            "soc",
            "rbac",
            "iam",
            "secrets",
            "purview",
            "entra",
        ]

        # DevOps keywords
        devops_keywords = [
            "ci/cd",
            "pipeline",
            "jenkins",
            "gitlab",
            "github actions",
            "deployment",
            "automation",
            "docker",
            "container",
            "build",
        ]

        # Cloud keywords
        cloud_keywords = ["aws", "azure", "gcp", "cloud", "eks", "aks", "gke", "s3", "ec2", "lambda", "dynamodb", "rds"]

        # SRE keywords
        sre_keywords = [
            "monitoring",
            "observability",
            "prometheus",
            "grafana",
            "alerting",
            "incident",
            "reliability",
            "sla",
            "slo",
            "performance",
        ]

        # Infrastructure keywords
        infra_keywords = [
            "terraform",
            "ansible",
            "infrastructure",
            "provisioning",
            "configuration",
            "networking",
            "load balancer",
            "cdn",
        ]

        # Count matches
        for keyword in security_keywords:
            if keyword in bullet_text:
                scores["Security Platform Engineer"] += 2

        for keyword in devops_keywords:
            if keyword in bullet_text:
                scores["DevOps Platform Engineer"] += 1.5

        for keyword in cloud_keywords:
            if keyword in bullet_text:
                scores["Cloud Platform Engineer"] += 1.5

        for keyword in sre_keywords:
            if keyword in bullet_text:
                scores["Site Reliability Engineer"] += 1.5
                scores["Observability Engineer"] += 1

        for keyword in infra_keywords:
            if keyword in bullet_text:
                scores["Infrastructure Engineer"] += 1

        # Default score for Platform Engineer
        scores["Platform Engineer"] = 5  # Base score

        # Return the title with highest score
        best_title = max(scores.items(), key=lambda x: x[1])[0]
        return best_title

    def generate_cv_latex(
        self, template_path: str, role_distribution: Dict[str, List[str]], skills: Dict, metadata: Dict
    ) -> str:
        """Generate LaTeX CV from template with dynamic bullet distribution.

        Args:
            template_path: Path to CV.tex template
            role_distribution: Dict mapping role -> list of bullet texts
            skills: Skills data from skills.md
            metadata: Generation metadata (recruiter, date, etc.)
        """
        with open(template_path, "r") as f:
            template = f.read()

        # Add header
        salary_str = f"£{metadata['salary']}/day" if metadata["type"] == "contract" else f"£{metadata['salary']}k"
        header = f"""% Platform Engineer CV - {metadata["recruiter"].title()} {metadata["type"].title()} Role ({salary_str})
% Generated: {metadata["date"]} | Optimized for {metadata["recruiter"]} Position
% Unified CV Generator with Dynamic Bullet Distribution
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""

        # Inject bullets into each role section and determine job titles
        job_titles = {}

        for role in self.role_order:
            bullets = role_distribution.get(role, [])

            if bullets:
                # Determine the best job title for this role based on its bullets
                job_title = self.determine_job_title(bullets)

                # Add seniority prefix based on role
                if role in ["DFE", "HMRC"]:
                    job_title = "Senior " + job_title
                elif role.startswith("NATIONWIDE_"):
                    # Use default job titles from metadata for Nationwide sub-roles
                    role_meta = ROLE_METADATA.get(role, {})
                    job_title = role_meta.get("default_job_title", job_title)
                elif role == "OVO":
                    job_title = ROLE_METADATA.get(role, {}).get("default_job_title", "Research Analyst")

                job_titles[role] = job_title
                self.logger.debug(f"{role}: {job_title} (with {len(bullets)} bullets)")

                # Escape LaTeX special characters in bullets
                escaped_bullets = []
                for bullet in bullets:
                    # Order matters: escape backslash first, then other special chars
                    escaped = bullet
                    escaped = escaped.replace("&", "\\&")
                    escaped = escaped.replace("%", "\\%")
                    escaped = escaped.replace("$", "\\$")
                    escaped = escaped.replace("#", "\\#")
                    escaped = escaped.replace("_", "\\_")
                    escaped = escaped.replace("{", "\\{")
                    escaped = escaped.replace("}", "\\}")
                    escaped = escaped.replace("~", "\\textasciitilde{}")
                    escaped = escaped.replace("^", "\\textasciicircum{}")
                    escaped_bullets.append(escaped)
                bullet_text = "\n".join(f"\\item {b}" for b in escaped_bullets)

                # Replace the bullet placeholders
                template = template.replace(
                    f"% {role}_BULLETS_START\n% {role}_BULLETS_END",
                    f"% {role}_BULLETS_START\n{bullet_text}\n% {role}_BULLETS_END",
                )
            else:
                # Use default job title if no bullets
                role_meta = ROLE_METADATA.get(role, {})
                job_titles[role] = role_meta.get("default_job_title", "Platform Engineer")

        # Replace all job title placeholders
        for role in self.role_order:
            placeholder = f"%%{role}_JOB_TITLE%%"
            default_title = ROLE_METADATA.get(role, {}).get("default_job_title", "Platform Engineer")
            template = template.replace(placeholder, job_titles.get(role, default_title))

        cv_content = header + template

        # Log summary
        total_bullets = sum(len(b) for b in role_distribution.values())
        self.logger.info(f"Generated CV with {total_bullets} total bullets")

        # Show DFE bullets for debugging
        dfe_bullets = role_distribution.get("DFE", [])
        if dfe_bullets:
            self.logger.info(f"DFE has {len(dfe_bullets)} bullets:")
            for i, bullet in enumerate(dfe_bullets[:3], 1):
                preview = bullet[:80] + "..." if len(bullet) > 80 else bullet
                self.logger.info(f"  {i}. {preview}")

        return cv_content

    def create_ats_optimized_version(self, content: str) -> str:
        """Create ATS-optimized version of CV

        Args:
            content: LaTeX source content
        """
        lines = []
        for line in content.split("\n"):
            # Skip LaTeX comment lines
            if line.strip().startswith("%"):
                lines.append(line)
                continue

            # Replace special characters
            for old, new in self.ats_replacements.items():
                line = line.replace(old, new)

            lines.append(line)

        # Join the lines back together
        ats_content = "\n".join(lines)

        return ats_content

    def calculate_ats_score(self, content: str, keywords: Set[str]) -> float:
        """Calculate ATS compatibility score"""
        score = 85.0  # Base score

        # Check for problematic elements
        if "\\includegraphics" in content:
            score -= 10
        if "\\begin{table}" in content:
            score -= 5

        # Check keyword coverage
        content_lower = content.lower()
        keywords_found = sum(1 for keyword in keywords if keyword.lower() in content_lower)
        if keywords:
            keyword_bonus = (keywords_found / len(keywords)) * 10
            score += min(keyword_bonus, 10)

        # ATS optimizations are applied through character replacement

        return min(max(score, 0), 100)  # Keep between 0 and 100

    def generate_both_versions(
        self,
        job_path: str,
        skills_path: str,
        template_path: str,
        metadata: Dict,
        max_bullets: int = 13,
        output_format: str = "pdf",
    ) -> Tuple[str, str, Dict]:
        """Generate both standard and ATS-optimized versions

        Args:
            job_path: Path to job description file
            skills_path: Path to skills.md file
            template_path: Path to CV template (.tex)
            metadata: Dict with recruiter, type, salary, date
            max_bullets: Maximum bullets to include (now used as max per role for DFE)
        """
        self.logger.info("=" * 50)
        self.logger.info("🚀 Unified CV Generation with Dynamic Distribution")
        self.logger.info("=" * 50)

        # Parse job description
        self.logger.info("📋 Analyzing job requirements...")
        requirements = self.parse_job_description(job_path)
        self.logger.info(
            f"  Found {len(requirements['technologies'])} technologies, {len(requirements['keywords'])} keywords"
        )

        # Load skills with metadata (for DFE)
        self.logger.info("📚 Loading skills database (skills.md)...")
        skills = self.load_skills(skills_path)
        self.logger.info(f"  Loaded {len(skills['all_achievements'])} achievements from skills.md")

        # Score skills.md bullets (for DFE)
        self.logger.info("🎯 Scoring skills.md achievements...")
        scored_skills, always_dfe_bullets = self.score_achievements(skills, requirements)

        # Convert to list of dicts for distribution
        skills_bullets = []
        for achievement, score in scored_skills.items():
            clean_text, tags, is_always_dfe = self.parse_metadata_tags(achievement)
            skills_bullets.append(
                {
                    "text": clean_text,
                    "tags": tags,
                    "score": score,
                    "always_dfe": is_always_dfe,
                }
            )

        # Score role bullets (from role_bullets.py)
        self.logger.info("🎯 Scoring role bullets (role_bullets.py)...")
        role_bullets = self.score_role_bullets(requirements)
        self.logger.info(f"  Scored {len(role_bullets)} role bullets")

        # Distribute bullets dynamically
        self.logger.info("📊 Distributing bullets across roles...")
        role_distribution = self.distribute_bullets_dynamically(skills_bullets, role_bullets, requirements)

        # Generate standard CV
        self.logger.info("📄 Generating standard CV (latex)...")
        standard_content = self.generate_cv_latex(template_path, role_distribution, skills, metadata)

        # Save standard version
        standard_source_path = self.generated_dir / "cv.tex"
        with open(standard_source_path, "w") as f:
            f.write(standard_content)

        # Generate ATS-optimized version
        self.logger.info("🤖 Creating ATS-optimized version...")
        ats_content = self.create_ats_optimized_version(standard_content)

        # Calculate scores
        original_score = self.calculate_ats_score(standard_content, requirements["keywords"])
        optimized_score = self.calculate_ats_score(ats_content, requirements["keywords"])

        report = {
            "original_score": original_score,
            "optimized_score": optimized_score,
            "improvement": optimized_score - original_score,
        }

        # Save ATS version
        ats_source_path = self.generated_dir / "cv_ats.tex"
        with open(ats_source_path, "w") as f:
            f.write(ats_content)

        self.logger.info(f"  Original ATS Score: {report['original_score']}/100")
        self.logger.info(f"  Optimized ATS Score: {report['optimized_score']}/100")
        self.logger.info(f"  Improvement: +{report['improvement']} points")

        output_name = f"{metadata['recruiter']}-{metadata['date']}-{metadata['type']}-{metadata['salary']}"

        if output_format == "tex":
            self.logger.info("📝 Skipping PDF compilation; returning generated .tex sources")
            standard_tex = self.generated_dir / f"{output_name}.tex"
            ats_tex = self.generated_dir / f"{output_name}-ATS.tex"
            shutil.move(str(standard_source_path), str(standard_tex))
            shutil.move(str(ats_source_path), str(ats_tex))
            return str(standard_tex), str(ats_tex), report

        # Compile both PDFs
        self.logger.info("🔨 Compiling PDFs...")

        # Compile standard
        standard_ok = self.compile_pdf(str(standard_source_path), output_name)

        # Compile ATS
        ats_ok = self.compile_pdf(str(ats_source_path), f"{output_name}-ATS")

        if not standard_ok or not ats_ok:
            failed_outputs = []
            if not standard_ok:
                failed_outputs.append(output_name)
            if not ats_ok:
                failed_outputs.append(f"{output_name}-ATS")
            raise RuntimeError(f"PDF compilation failed for: {', '.join(failed_outputs)}")

        standard_pdf = self.output_dir / f"{output_name}.pdf"
        ats_pdf = self.output_dir / f"{output_name}-ATS.pdf"

        return str(standard_pdf), str(ats_pdf), report

    def compile_pdf(self, source_path: str, output_name: str) -> bool:
        """Compile LaTeX to PDF

        Args:
            source_path: Path to .tex file
            output_name: Output PDF name (without extension)
        """
        # LaTeX compilation via compile-cv.sh
        compile_script = self.scripts_dir / "compile-cv.sh"

        if not compile_script.exists():
            self.logger.error(f"Compile script not found at {compile_script}")
            return False

        try:
            result = subprocess.run(
                [str(compile_script), source_path, output_name, "pdflatex"], capture_output=True, text=True
            )
            if result.returncode == 0:
                self.logger.info(f"Successfully compiled {output_name}.pdf")
            else:
                compile_output = result.stderr.strip() or result.stdout.strip()
                self.logger.error(f"Compilation failed for {output_name}: {compile_output}")
            return result.returncode == 0
        except Exception as e:
            self.logger.error(f"Compilation error: {e}", exc_info=True)
            return False

    def generate_comparison_report(self, standard_pdf: str, ats_pdf: str, report: Dict, metadata: Dict) -> str:
        """Generate HTML comparison report"""
        html = f"""<!DOCTYPE html>
<html>
<head>
    <title>CV Generation Report - {metadata["recruiter"]}</title>
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
        <p>Generated: {datetime.now().strftime("%Y-%m-%d %H:%M")}</p>
        <p>Position: <strong>{metadata["recruiter"]} - {metadata["type"].title()}</strong></p>

        <div class="metrics">
            <div class="metric">
                <div class="metric-value">{report["original_score"]}/100</div>
                <div class="metric-label">Standard ATS Score</div>
            </div>
            <div class="metric">
                <div class="metric-value">{report["optimized_score"]}/100</div>
                <div class="metric-label">Optimized ATS Score</div>
            </div>
            <div class="metric">
                <div class="metric-value">+{report["improvement"]}</div>
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

        for fix in report.get("format_fixes", []):
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
    parser = argparse.ArgumentParser(description="Unified CV Generator with Metadata Matching")

    # Core parameters
    parser.add_argument("--recruiter", required=True, help="Company/Recruiter name")
    parser.add_argument("--type", choices=["perm", "contract"], default="perm")
    parser.add_argument("--salary", required=True, help="Salary (e.g., 150K or 700 for contract)")
    parser.add_argument("--date", default=datetime.now().strftime("%d%m%y"))

    # File paths
    parser.add_argument("--job", default=None, help="Job description path")
    parser.add_argument("--skills", default=None, help="Skills database path")
    parser.add_argument("--template", default=None, help="CV template path")

    # Options
    parser.add_argument("--ats-only", action="store_true", help="Generate ATS version only")
    parser.add_argument("--standard-only", action="store_true", help="Generate standard version only")
    parser.add_argument("--no-report", action="store_true", help="Skip HTML report generation")
    parser.add_argument("--open", action="store_true", help="Open files after generation")
    parser.add_argument(
        "--max-bullets", type=int, default=13, help="Maximum bullets to include (13 default, up to 15 for 3 pages)"
    )
    parser.add_argument("--format", choices=["pdf", "tex"], default="pdf", help="Output format")

    args = parser.parse_args()

    # Set default paths
    dotfiles_root = Path(os.environ.get("DOTFILES_ROOT", Path(__file__).resolve().parents[2])).expanduser()
    base_dir = Path(os.environ.get("JOBAPPS_DIR", dotfiles_root / "jobapps")).expanduser()
    if not args.job:
        args.job = str(base_dir / "jobdescription.md")
    if not args.skills:
        args.skills = str(base_dir / "skills.md")
    if not args.template:
        args.template = str(base_dir / "CV.tex")

    # Create metadata
    metadata = {"recruiter": args.recruiter, "type": args.type, "salary": args.salary, "date": args.date}

    # Generate CVs
    generator = UnifiedCVGenerator()
    standard_pdf, ats_pdf, report = generator.generate_both_versions(
        args.job, args.skills, args.template, metadata, max_bullets=args.max_bullets, output_format=args.format
    )

    # Get logger for main function
    logger = logging.getLogger("cv_generator")

    # Generate comparison report
    if not args.no_report:
        logger.info("📊 Generating comparison report...")
        html = generator.generate_comparison_report(standard_pdf, ats_pdf, report, metadata)
        report_path = generator.generated_dir / f"unified_report_{metadata['recruiter']}_{metadata['date']}.html"
        with open(report_path, "w") as f:
            f.write(html)
        logger.info(f"  Report saved: {report_path}")

        if args.open:
            # Open the HTML report
            subprocess.run(["open", str(report_path)])

            # Also open both PDFs
            standard_pdf_path = Path(standard_pdf)
            ats_pdf_path = Path(ats_pdf)

            if standard_pdf_path.exists():
                subprocess.run(["open", str(standard_pdf)])
            if ats_pdf_path.exists():
                subprocess.run(["open", str(ats_pdf)])

    logger.info("✅ Unified CV generation complete!")
    logger.info(f"  Standard: {standard_pdf}")
    logger.info(f"  ATS-Optimized: {ats_pdf}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

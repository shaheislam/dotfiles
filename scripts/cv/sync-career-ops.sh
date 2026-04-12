#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
JOBAPPS_DIR="${JOBAPPS_DIR:-$DOTFILES_ROOT/jobapps}"
CAREER_OPS_DIR="${CAREER_OPS_DIR:-$HOME/career-ops}"

RUN_DOCTOR=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--doctor)
		RUN_DOCTOR=1
		shift
		;;
	--help | -h)
		cat <<'EOF'
Usage: sync-career-ops.sh [--doctor]

Generates the minimum shared Career-Ops context from the canonical jobapps data
and writes it into ~/career-ops (or $CAREER_OPS_DIR).
EOF
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		exit 1
		;;
	esac
done

if [[ ! -d "$CAREER_OPS_DIR" ]]; then
	echo "Career-Ops repo not found at $CAREER_OPS_DIR" >&2
	exit 1
fi

mkdir -p "$CAREER_OPS_DIR/config"

export DOTFILES_ROOT JOBAPPS_DIR CAREER_OPS_DIR

python3 <<'PY'
from pathlib import Path
import os
import re

dotfiles_root = Path(os.environ["DOTFILES_ROOT"])
jobapps_dir = Path(os.environ["JOBAPPS_DIR"])
career_ops_dir = Path(os.environ["CAREER_OPS_DIR"])

cv_tex = (jobapps_dir / "CV.tex").read_text()
skills_md = (jobapps_dir / "skills.md").read_text()

def latex_to_text(text: str) -> str:
    text = text.replace(r"\&", "&")
    text = text.replace(r"\newline", "\n")
    text = re.sub(r"\\textbf\{([^}]*)\}", r"\1", text)
    text = re.sub(r"\\normalfont", "", text)
    text = re.sub(r"\\smallbreak", "", text)
    text = re.sub(r"\\vspace\{[^}]*\}", "", text)
    text = re.sub(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?(\{[^}]*\})?", "", text)
    text = re.sub(r"[{}]", "", text)
    text = re.sub(r"\n\s+", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

name_match = re.search(r"\\name\{([^}]*)\}", cv_tex)
address_match = re.search(r"\\address\{([^}]*)\}", cv_tex)
profile_match = re.search(r"\\begin\{rSection\}\{Profile\}(.*?)\\end\{rSection\}", cv_tex, re.S)
skills_match = re.search(r"\\begin\{rSection\}\{Skills\}(.*?)\\end\{rSection\}", cv_tex, re.S)

name = name_match.group(1).replace(" - SC Cleared", "").strip() if name_match else "Shahe Islam"
address_raw = address_match.group(1) if address_match else "+44 751 234 9133 \\\\ shahedulislam94@gmail.com"
address_parts = [part.strip() for part in re.split(r"\\\\", address_raw) if part.strip()]
phone = address_parts[0] if address_parts else "+44 751 234 9133"
email = address_parts[1] if len(address_parts) > 1 else "shahedulislam94@gmail.com"
profile = latex_to_text(profile_match.group(1)) if profile_match else "Senior platform engineer specializing in Kubernetes and multi-cloud delivery."

experience_entries = re.findall(r"\\begin\{rSubsection\}\{([^}]*)\}\{([^}]*)\}\{([^}]*)\}\{([^}]*)\}", cv_tex)
experience_lines = []
for company, dates_a, title, dates_b in experience_entries:
    if not company and not title:
        continue
    company = company or "Nationwide Building Society"
    title = title.replace("%%", "").replace("_", " ").title() if "%%" in title else title
    dates = dates_a or dates_b
    experience_lines.append(f"### {company}\n**{title or 'Platform Engineer'}**\n{dates}\n- See LaTeX source in jobapps/CV.tex for role-specific bullets rendered by /cv-generate.")

skill_lines = []
for line in skills_md.splitlines():
    if line.startswith("- "):
      skill_lines.append(line)
    if len(skill_lines) >= 18:
      break

cv_md = f"# CV -- {name}\n\n**Location:** London, UK\n**Email:** {email}\n**Phone:** {phone}\n**LinkedIn:** linkedin.com/in/shahe-islam\n**GitHub:** github.com/shaheislam\n\n## Professional Summary\n\n{profile}\n\n## Work Experience\n\n" + "\n\n".join(experience_lines) + "\n\n## Skills\n\n" + "\n".join(skill_lines)

profile_yml = f'''candidate:
  full_name: "{name}"
  email: "{email}"
  phone: "{phone}"
  location: "London, UK"
  linkedin: "linkedin.com/in/shahe-islam"
  portfolio_url: "https://github.com/shaheislam/dotfiles"
  github: "github.com/shaheislam"

target_roles:
  primary:
    - "Senior Platform Engineer"
    - "Cloud Platform Engineer"
    - "Site Reliability Engineer"
  archetypes:
    - name: "Platform Engineer"
      level: "Senior/Lead"
      fit: "primary"
    - name: "Cloud Platform Engineer"
      level: "Senior"
      fit: "primary"
    - name: "Infrastructure Engineer"
      level: "Senior"
      fit: "secondary"
    - name: "Site Reliability Engineer"
      level: "Senior"
      fit: "secondary"

narrative:
  headline: "Senior platform engineer focused on Kubernetes, observability, and cloud migration"
  exit_story: "Nine plus years shipping AWS and Azure platform engineering systems, with deep delivery experience across Kubernetes, observability, migration, and cost optimization."
  superpowers:
    - "Enterprise Kubernetes platforms on AWS and Azure"
    - "Observability stack design and operations"
    - "Migration and modernization programs"
    - "Platform automation and developer tooling"
  proof_points:
    - name: "Cluster API platform architecture"
      url: "https://github.com/shaheislam/dotfiles"
      hero_metric: "Supported 50+ development teams with standardized platform workflows"
    - name: "Cost optimization migrations"
      url: "https://github.com/shaheislam/dotfiles"
      hero_metric: "$150K annual savings and 60% compute reduction"

compensation:
  target_range: "GBP 650-800/day contract or GBP 110K-140K permanent"
  currency: "GBP"
  minimum: "GBP 550/day or GBP 95K permanent"
  location_flexibility: "Remote preferred, hybrid London acceptable"

location:
  country: "United Kingdom"
  city: "London"
  timezone: "GMT/BST"
  visa_status: "No sponsorship required"
  onsite_availability: "Hybrid or remote; travel for key workshops acceptable"
'''

portals_yml = '''title_filter:
  positive:
    - "Platform Engineer"
    - "Cloud Platform"
    - "SRE"
    - "Site Reliability"
    - "DevOps"
    - "Kubernetes"
    - "Infrastructure"
    - "Observability"
    - "Azure"
    - "AWS"
    - "Contract"
    - "Remote"
  negative:
    - "Junior"
    - "Intern"
    - "iOS"
    - "Android"
    - "PHP"
    - "Ruby"
  seniority_boost:
    - "Senior"
    - "Lead"
    - "Principal"

search_queries:
  - name: "Greenhouse — Platform Engineering"
    query: 'site:boards.greenhouse.io OR site:job-boards.greenhouse.io "Platform Engineer" OR "SRE" kubernetes remote contract'
    enabled: true
  - name: "Ashby — Cloud Platform"
    query: 'site:jobs.ashbyhq.com "Cloud Platform Engineer" OR "DevOps Engineer" kubernetes remote contract'
    enabled: true
  - name: "Lever — Azure & AWS Platform"
    query: 'site:jobs.lever.co "Azure" OR "AWS" "Platform Engineer" OR "Infrastructure Engineer" remote contract'
    enabled: true

tracked_companies:
  - name: "Microsoft"
    careers_url: "https://jobs.careers.microsoft.com/"
    enabled: true
  - name: "Grafana Labs"
    careers_url: "https://grafana.com/about/careers/open-positions/"
    enabled: true
  - name: "HashiCorp"
    careers_url: "https://www.hashicorp.com/careers"
    enabled: true
'''

(career_ops_dir / "cv.md").write_text(cv_md)
(career_ops_dir / "config" / "profile.yml").write_text(profile_yml)
(career_ops_dir / "portals.yml").write_text(portals_yml)
PY

echo "Synced shared Career-Ops files into $CAREER_OPS_DIR"

if [[ "$RUN_DOCTOR" -eq 1 ]]; then
	(cd "$CAREER_OPS_DIR" && bun run doctor)
fi

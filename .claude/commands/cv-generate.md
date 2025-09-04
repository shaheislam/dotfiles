# /cv-generate - AI-Powered CV Generator

Generate an optimized CV in LaTeX format by analyzing job descriptions and matching relevant skills.

## Command Structure
```bash
/cv-generate [options]
```

## Description
This command intelligently analyzes a job description, cross-references it with your skills database, and generates a tailored CV in LaTeX format that highlights the most relevant experience and qualifications.

## Required Files
Default location: `/jobapps/` directory (working files)

- `/jobapps/jobdescription.md` - The target job description
- `/jobapps/skills.md` - Your comprehensive skills database
- `/jobapps/cv.md` - Your master CV template (or .tex template)
- `/jobapps/resume.cls` - LaTeX class file (required for PDF compilation)
- Working Output: `/jobapps/generated/cv.tex` - Generated LaTeX file (temporary)
- **Final Output: `~/Documents/jobapps/output/<RECRUITER>-<DATE>-<TYPE>-<SALARY>.pdf`** - Compiled PDF (when --format pdf)
- **Final Output: `~/Documents/jobapps/generated/<RECRUITER>-<DATE>-<TYPE>-<SALARY>.tex`** - Final LaTeX file

## Workflow

### 1. Analysis Phase
- Parse job description for key requirements, technologies, and qualifications
- Extract metadata tags: RECRUITER, DATE, TYPE, SALARY for filename generation
- Extract skill categories: technical, soft skills, domain expertise
- Identify priority keywords and phrases

### 2. Skill Matching
- Cross-reference job requirements with skills database
- Score relevance of each skill (0-100)
- Identify skill gaps and transferable skills
- Prioritize skills based on frequency and importance in job description

### 3. CV Generation
- **CRITICAL: Maintain fixed employment structure** - preserve all company names, position titles, and employment dates exactly as in template
- **PAGE LENGTH REQUIREMENTS**: 
  - Maximum 3 pages allowed
  - Prefer 2 pages when possible
  - If using 3 pages, the third page MUST be at least 70% filled
  - Never leave a mostly empty final page
- **Content Optimization Strategy**:
  - Prioritize most impactful achievements and skills
  - Use concise bullet points (1-2 lines each)
  - Adjust content based on available space
  - If content fits well in 2 pages, keep it at 2
  - Only expand to 3 pages if you have substantial content
- Select most relevant bullet points for each role based on job requirements
- **Skill Distribution Strategy**:
  - Most recent roles: Populate with highly relevant, cutting-edge skills matching job description
  - Middle roles: Include supporting skills and relevant achievements
  - Older roles: Place less relevant but still valuable experiences
- Generate professional summary tailored to position (3-4 lines)
- Format in clean, ATS-friendly LaTeX with optimized spacing

### 4. Optimization
- Ensure keyword density without stuffing
- Balance technical and soft skills across chronological roles
- Highlight quantifiable achievements in context of each position
- Maintain professional formatting and employment continuity

## Usage Examples

### Basic Usage
```bash
/cv-generate
```
Reads from default files in `/jobapps/` directory

### With Custom Paths
```bash
/cv-generate --job @jobs/senior-dev.md --skills @personal/skills.md --template @templates/cv.md
```

### With Focus Areas
```bash
/cv-generate --focus "cloud,kubernetes,python" --style technical
```

### With Company Research
```bash
/cv-generate --company "TechCorp" --research
```

## Options

### Input Options
- `--job <path>` - Path to job description (default: /jobapps/jobdescription.md)
- `--skills <path>` - Path to skills database (default: /jobapps/skills.md)
- `--template <path>` - Path to CV template (default: /jobapps/cv.md or cv.tex)
- `--cls <path>` - Path to resume.cls file (default: /jobapps/resume.cls)
- `--output <path>` - Output path for generated file (default: /jobapps/generated/cv.tex)

### Optimization Options
- `--focus <keywords>` - Comma-separated priority keywords
- `--style <type>` - CV style: technical, executive, creative, academic
- `--length <pages>` - Target CV length (2-3 pages, default: 2, 3rd page must be 70% filled)
- `--ats` - Optimize for Applicant Tracking Systems

### Enhancement Options
- `--company <name>` - Research company for better targeting
- `--research` - Include company culture and values analysis
- `--gap-analysis` - Include skill gap analysis
- `--cover-letter` - Also generate matching cover letter

### Output Options
- `--format <type>` - Output format: tex (default), pdf (compile to PDF)
- `--compiler <type>` - LaTeX compiler: pdflatex (default), xelatex, lualatex
- `--pdf-name <name>` - Custom PDF filename (default: auto-generated from metadata tags)
- `--pdf-dir <path>` - PDF output directory (default: ~/Documents/jobapps/output/)
- `--keep-temp` - Keep intermediate LaTeX files after PDF compilation
- `--open` - Open PDF after compilation
- `--preview` - Generate preview before finalizing
- `--variants <n>` - Generate n variations
- `--explain` - Include explanation of choices made

## File Formats

### jobdescription.md
```markdown
# Position: [Job Title]
## Company: [Company Name]
## Requirements
- Requirement 1
- Requirement 2
## Responsibilities
- Task 1
- Task 2
## Nice to Have
- Bonus skill 1

<RECRUITER>
    recruiter_name
</RECRUITER>
<DATE>
    DDMMYY
</DATE>
<TYPE>
    CONTRACT|PERMANENT
</TYPE>
<SALARY>
    salary_info
</SALARY>
```

### skills.md
```markdown
# Technical Skills
## Programming Languages
- Python (Expert, 5 years)
- JavaScript (Advanced, 3 years)
## Frameworks
- React (Advanced)
- Django (Expert)
# Soft Skills
- Team Leadership
- Project Management
```

### cv.md (Template)
```markdown
# [Your Name]
## Contact Information
Email: | Phone: | LinkedIn: | GitHub:

## Professional Summary
[Summary placeholder]

## Experience
### [Company] - [Role]
[Date Range]
- Achievement 1
- Achievement 2

## Skills
[Skills section]

## Education
[Education details]
```

### cv.tex (Generated Output)
```latex
\documentclass{resume}  % Uses custom resume.cls
\usepackage{[packages]}

\name{[Your Name]}
\address{[Location]}
\email{[email]}
\phone{[phone]}
\linkedin{[linkedin]}
\github{[github]}

\begin{document}
\makecvheader

\section{Professional Summary}
[Tailored summary based on job requirements]

\section{Relevant Experience}
\begin{itemize}
  \item [Prioritized and tailored experiences]
  \item [Quantified achievements]
\end{itemize}

\section{Key Skills}
[Matched and prioritized skills from job description]

\section{Education}
[Education details]

\end{document}
```

## Execution Flow

1. **Read Input Files**
   - Load job description, skills database, and CV template
   - Validate file formats and content

2. **Analyze Job Requirements**
   - Extract technical requirements
   - Identify soft skill requirements
   - Parse experience level needed
   - Note industry-specific terms

3. **Match and Score Skills**
   - Compare job requirements with skills database
   - Calculate relevance scores
   - Identify transferable skills
   - Flag missing but learnable skills

4. **Generate Optimized CV**
   - Create tailored professional summary (3-4 lines)
   - **IMPORTANT: Preserve employment chronology** - Keep all companies, positions, and dates unchanged
   - **PAGE LENGTH MANAGEMENT**:
     - Target 2 pages when possible
     - Allow up to 3 pages if content warrants it
     - If using 3rd page, ensure it's at least 70% filled
     - Adjust bullet points per role based on total length:
       * 2-page CV: 3-5 bullets per recent role, 2-3 for older
       * 3-page CV: 4-6 bullets per recent role, 3-4 for older
   - **Intelligently distribute achievements**:
     - Recent positions: Insert most relevant job-matching bullet points
     - Earlier positions: Include foundational and supporting experiences
   - Highlight matching achievements while maintaining role authenticity
   - Format skills section strategically
   - Ensure ATS compatibility

5. **Output LaTeX**
   - Generate clean LaTeX code to `/jobapps/generated/cv.tex`
   - Include formatting for readability
   - Add comments for customization
   - Ensure `\documentclass{resume}` for custom class

6. **PDF Compilation (if --format pdf)**
   - Copy `resume.cls` to compilation directory
   - Run LaTeX compiler (pdflatex/xelatex/lualatex)
   - Execute two passes for proper references
   - Clean up auxiliary files
   - Move PDF to `/jobapps/output/` with timestamp
   - Archive previous versions if needed
   - Open PDF if `--open` flag is used

## Advanced Features

### AI-Powered Enhancements
- **Keyword Optimization**: Automatically identify and incorporate industry keywords
- **Achievement Quantification**: Convert descriptions to quantifiable achievements
- **Skill Gap Analysis**: Identify skills to develop or emphasize transferable ones
- **Tone Matching**: Adjust writing style to match company culture
- **Chronological Intelligence**: Strategically place relevant skills in recent roles while maintaining employment history integrity

### Multi-Version Generation
- Generate multiple CV versions for A/B testing
- Create variations emphasizing different skill sets
- Produce industry-specific versions

### Integration Options
- Export to PDF directly
- Integration with job boards
- LinkedIn profile sync
- Portfolio website generation

## Tips for Best Results

1. **Comprehensive Skills Database**: Keep skills.md updated with all skills, tools, and technologies
2. **Detailed Job Description**: Include full job posting for better analysis
3. **Rich CV Template**: Include diverse experiences for algorithm to choose from
4. **Keyword Research**: Add industry-specific terms to skills database
5. **Quantify Achievements**: Include metrics in CV template for stronger impact
6. **Employment Structure**: Template must include all employment positions with dates - the generator will only modify bullet points, not the structure
7. **Page Length Management**: CV will be 2 pages by default, expanding to 3 only if content justifies it (3rd page must be 70% filled)

## Example Implementation

```bash
# Basic CV generation (generates .tex file)
/cv-generate

# Generate and compile to PDF
/cv-generate --format pdf

# Generate PDF and open it
/cv-generate --format pdf --open

# Auto-generated filename from metadata tags
/cv-generate --format pdf --open
# Creates: stottandmay-010425-CONTRACT-60OIR35.pdf

# Custom PDF name override (optional)
/cv-generate --format pdf --pdf-name "JohnDoe_SeniorDev_2024" --open

# Use XeLaTeX for better font support
/cv-generate --format pdf --compiler xelatex

# Use files from a different project directory
/cv-generate --job @/projects/applications/role1/jobdescription.md --format pdf

# For senior position with technical focus
/cv-generate --style technical --length 2 --focus "architecture,leadership,scalability" --format pdf

# For startup with research and PDF output
/cv-generate --company "StartupXYZ" --research --style creative --format pdf --open

# Generate multiple versions
/cv-generate --variants 3 --explain

# Full optimization pipeline with PDF
/cv-generate --ats --research --gap-analysis --cover-letter --format pdf --open

# Batch generation for multiple positions
/cv-generate --job @/jobapps/google/job.md --pdf-name "CV_Google" --format pdf
/cv-generate --job @/jobapps/meta/job.md --pdf-name "CV_Meta" --format pdf
/cv-generate --job @/jobapps/amazon/job.md --pdf-name "CV_Amazon" --format pdf
```

## Error Handling

The command will validate:

- File existence and readability
- Proper markdown formatting
- Minimum content requirements
- LaTeX syntax validity

## Performance Considerations

- Processing time: 10-30 seconds depending on options
- Memory usage: Minimal, processes files incrementally
- Output size: Typically 2-5KB LaTeX file

## Related Commands

- `/resume-analyze` - Analyze existing resume effectiveness
- `/skill-extract` - Extract skills from job descriptions
- `/interview-prep` - Prepare for interviews based on CV
- `/portfolio-sync` - Sync CV with online portfolio

---

**Auto-activates**: analyzer, scribe personas
**MCP Integration**: Sequential (analysis), Context7 (best practices)
**Tools**: Read, Write, Grep, Task, Bash (for PDF compilation)
**Category**: Documentation, Career
**Compilation Script**: Uses `/Users/shahe/dotfiles/scripts/compile-cv.sh` for PDF generation

## Workflow Integration

When `--format pdf` is specified, the command will:

1. Extract metadata from job description (RECRUITER, DATE, TYPE, SALARY)
2. Generate the optimized `.tex` file in `/jobapps/generated/` (working directory)
3. Execute `/Users/shahe/dotfiles/scripts/compile-cv.sh` with auto-generated filename
4. Copy the final PDF to `~/Documents/jobapps/output/<RECRUITER>-<DATE>-<TYPE>-<SALARY>.pdf`
5. Copy the final `.tex` file to `~/Documents/jobapps/generated/<RECRUITER>-<DATE>-<TYPE>-<SALARY>.tex`
6. Optionally open the PDF if `--open` flag is provided

The compilation script handles:

- Automatic LaTeX installation if needed
- Resume.cls file management
- Multiple compilation passes for references
- Cleanup of auxiliary files
- PDF archiving and versioning

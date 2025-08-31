# /cv-generate - AI-Powered CV Generator

Generate an optimized CV in LaTeX format by analyzing job descriptions and matching relevant skills.

## Command Structure
```bash
/cv-generate [options]
```

## Description
This command intelligently analyzes a job description, cross-references it with your skills database, and generates a tailored CV in LaTeX format that highlights the most relevant experience and qualifications.

## Required Files
- `jobdescription.md` - The target job description
- `skills.md` - Your comprehensive skills database
- `cv.md` - Your master CV template
- Output: `latex.md` - Generated LaTeX CV optimized for the position

## Workflow

### 1. Analysis Phase
- Parse job description for key requirements, technologies, and qualifications
- Extract skill categories: technical, soft skills, domain expertise
- Identify priority keywords and phrases

### 2. Skill Matching
- Cross-reference job requirements with skills database
- Score relevance of each skill (0-100)
- Identify skill gaps and transferable skills
- Prioritize skills based on frequency and importance in job description

### 3. CV Generation
- Select most relevant experiences from master CV
- Reorder sections based on job priorities
- Emphasize matching skills and keywords
- Generate professional summary tailored to position
- Format in clean, ATS-friendly LaTeX

### 4. Optimization
- Ensure keyword density without stuffing
- Balance technical and soft skills
- Highlight quantifiable achievements
- Maintain professional formatting

## Usage Examples

### Basic Usage
```bash
/cv-generate
```
Reads from default files in current directory

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
- `--job <path>` - Path to job description (default: ./jobdescription.md)
- `--skills <path>` - Path to skills database (default: ./skills.md)
- `--template <path>` - Path to CV template (default: ./cv.md)
- `--output <path>` - Output path for LaTeX CV (default: ./latex.md)

### Optimization Options
- `--focus <keywords>` - Comma-separated priority keywords
- `--style <type>` - CV style: technical, executive, creative, academic
- `--length <pages>` - Target CV length (1-3 pages)
- `--ats` - Optimize for Applicant Tracking Systems

### Enhancement Options
- `--company <name>` - Research company for better targeting
- `--research` - Include company culture and values analysis
- `--gap-analysis` - Include skill gap analysis
- `--cover-letter` - Also generate matching cover letter

### Output Options
- `--format <type>` - Output format: latex, markdown, pdf
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

### latex.md (Generated Output)
```latex
\documentclass{article}
\usepackage{[packages]}
\begin{document}
\section{Professional Summary}
[Tailored summary based on job requirements]
\section{Relevant Experience}
[Prioritized and tailored experiences]
\section{Key Skills}
[Matched and prioritized skills]
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
   - Create tailored professional summary
   - Reorder experiences by relevance
   - Highlight matching achievements
   - Format skills section strategically
   - Ensure ATS compatibility

5. **Output LaTeX**
   - Generate clean LaTeX code
   - Include formatting for readability
   - Add comments for customization
   - Provide compilation instructions

## Advanced Features

### AI-Powered Enhancements
- **Keyword Optimization**: Automatically identify and incorporate industry keywords
- **Achievement Quantification**: Convert descriptions to quantifiable achievements
- **Skill Gap Analysis**: Identify skills to develop or emphasize transferable ones
- **Tone Matching**: Adjust writing style to match company culture

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

## Example Implementation

```bash
# Basic CV generation
/cv-generate

# For senior position with technical focus
/cv-generate --style technical --length 2 --focus "architecture,leadership,scalability"

# For startup with research
/cv-generate --company "StartupXYZ" --research --style creative

# Generate multiple versions
/cv-generate --variants 3 --explain

# Full optimization pipeline
/cv-generate --ats --research --gap-analysis --cover-letter --format pdf
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
**Tools**: Read, Write, Grep, Task
**Category**: Documentation, Career
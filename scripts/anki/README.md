# Examice Anki Flashcard Generator

Automated scraper for converting **any** Examice exam questions into Anki flashcards using Playwright.

## Overview

This tool connects to an existing authenticated Chrome browser session and scrapes exam questions from Examice.com, converting them into ready-to-import Anki flashcards.

**Works with ANY Examice exam:**
- ☁️ Cloud certifications (AWS, Azure, GCP)
- 🐧 Linux Foundation exams (KCNA, CKA, CKAD, etc.)
- 🔐 Security certifications (CompTIA, etc.)
- 📊 IT certifications (Microsoft, Cisco, etc.)
- 🎯 Any other exam on Examice.com

**Features:**
- ✅ **Flexible**: Works with any Examice exam URL
- 🔐 **Authenticated**: Maintains your login session
- 🚀 **Automatic**: Scrapes all pages with question count detection
- 📊 **Complete**: Extracts question, all options (4 or 5), answer, and explanation
- 🏷️ **Smart tagging**: Auto-generates tags based on exam (provider + exam code)
- 📁 **Organized**: Dynamic filenames based on exam (e.g., `microsoft-az-104_complete.txt`)
- 🎯 **Adaptive**: Handles different question formats (4-option and 5-option questions)

## Prerequisites

1. **Python 3.13+** with pip
2. **Google Chrome** browser
3. **Active Examice account** with access to exam questions

## Setup

### 1. Install Dependencies

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install required packages
pip install -r requirements.txt

# Install Playwright browsers
playwright install chromium
```

### 2. Authenticate to Examice

1. Open Chrome and log into https://examice.com
2. Navigate to any exam you want to scrape
3. Verify you can see the questions (requires active subscription)

## Usage

### Quick Start (Auto-detect from Browser)

```bash
# 1. Start Chrome with your exam URL
./start_chrome_debug.sh https://examice.com/exams/microsoft/az-104/

# 2. Ensure you're logged in (Chrome will open to exam page)

# 3. Run the scraper (auto-detects exam from browser)
python scrape_with_playwright.py
```

### Specify Exam URL Explicitly

```bash
# Start Chrome (optionally with URL)
./start_chrome_debug.sh

# Run scraper with specific exam URL
python scrape_with_playwright.py https://examice.com/exams/linux-foundation/kcna/
```

## Examples

### KCNA (Kubernetes and Cloud Native Associate)
```bash
./start_chrome_debug.sh https://examice.com/exams/linux-foundation/kcna/
python scrape_with_playwright.py
```
Output: `output/linux-foundation-kcna_complete.txt`

### Microsoft AZ-104
```bash
./start_chrome_debug.sh https://examice.com/exams/microsoft/az-104/
python scrape_with_playwright.py
```
Output: `output/microsoft-az-104_complete.txt`

### AWS SAA-C03
```bash
./start_chrome_debug.sh https://examice.com/exams/aws/saa-c03/
python scrape_with_playwright.py
```
Output: `output/aws-saa-c03_complete.txt`

## How It Works

### Step-by-Step Process

#### 1. Start Chrome with Remote Debugging

```bash
./start_chrome_debug.sh [exam-url]
```

This script:
- Kills any existing debug Chrome sessions
- Starts Chrome with remote debugging on port 9222
- Opens the specified exam URL (or KCNA by default)

**Manual alternative:**
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug \
  "https://examice.com/exams/your-exam-here/"
```

#### 2. Run the Scraper

```bash
python scrape_with_playwright.py [exam-url]
```

The scraper will:
1. Connect to Chrome via CDP (Chrome DevTools Protocol)
2. Auto-detect or use provided exam URL
3. Extract total question count from first page
4. Calculate total pages needed (~5 questions per page)
5. Navigate through all pages automatically
6. Extract questions, options, answers, and explanations
7. Generate exam-specific output files

#### 3. Import to Anki

1. Open Anki
2. File → Import
3. Select: `output/[exam-name]_complete.txt`
4. Set field separator to **Tab**
5. Click Import

## Output Files

### `output/[exam-name]_complete.json`
Structured data with all questions:
```json
{
  "number": 1,
  "total": 138,
  "question": "What native runtime is Open Container Initiative (OCI) compliant?",
  "options": ["runC", "runV", "kata-containers", "gvisor"],
  "answer": "A",
  "explanation": "runC is the native runtime that is..."
}
```

### `output/[exam-name]_complete.txt`
Anki-ready flashcards (tab-separated):
- **Front**: Question number, text, and all options (4 or 5 depending on exam)
- **Back**: Correct answer with explanation
- **Tags**: Auto-generated from URL (e.g., `examice microsoft az-104`)

**Note**: Different exams have different question formats:
- **KCNA**: 4 options per question (A-D)
- **LFCS**: 5 options per question (A-E)
- The scraper automatically adapts to both formats

### Filename Examples
| Exam URL | Output Filename |
|----------|----------------|
| `.../exams/linux-foundation/kcna/` | `linux-foundation-kcna_complete.txt` |
| `.../exams/microsoft/az-104/` | `microsoft-az-104_complete.txt` |
| `.../exams/aws/saa-c03/` | `aws-saa-c03_complete.txt` |
| `.../exams/comptia/security-plus/` | `comptia-security-plus_complete.txt` |

## Architecture

### Exam Detection
```python
# Automatically parses exam info from URL pattern:
# https://examice.com/exams/{provider}/{exam-code}/

# Examples:
# Provider: linux-foundation, Exam: kcna
# Provider: microsoft, Exam: az-104
# Provider: aws, Exam: saa-c03
```

### Question Count Detection
```javascript
// Extracts total from page: "Question 1 of 138"
const numMatch = sectionText.match(/Question (\d+) of (\d+)/);
const questionNum = parseInt(numMatch[1]);
const totalQuestions = parseInt(numMatch[2]);
```

### DOM Structure
```
article (question container)
  └─ DIV (parent)
      └─ SECTION (grandparent - contains "Question X of Y" and answer)
  FIELDSET (next sibling - contains options)
      └─ [role="checkbox"] × 4 (option elements)
```

**Page Structure:**
- **Page 1**: 6 articles (1 header + 5 questions) - skips first
- **Pages 2+**: 5 articles (5 questions) - processes all

## Troubleshooting

### "No browser contexts found"
- Ensure Chrome is running with remote debugging
- Check port 9222 is available: `lsof -i :9222`
- Restart Chrome: `./start_chrome_debug.sh`

### "No questions found" or "Could not detect total questions"
- Verify you're logged into Examice
- Ensure you have active subscription access to the exam
- Check that questions are visible in browser
- Navigate manually to first page of questions

### Wrong question count
- The scraper auto-detects from "Question X of Y" text
- Verify this text appears on the exam pages
- Check output for actual count vs expected

### Import Issues in Anki
- Ensure field separator is **Tab** (not comma)
- Verify file encoding is UTF-8
- Check HTML tags are preserved in import settings
- Confirm you're importing the correct exam file

## Command Reference

### Chrome Debugging
```bash
# Default (KCNA)
./start_chrome_debug.sh

# Specific exam
./start_chrome_debug.sh https://examice.com/exams/microsoft/az-104/
```

### Scraper Options
```bash
# Auto-detect from browser
python scrape_with_playwright.py

# Specify exam URL
python scrape_with_playwright.py https://examice.com/exams/aws/saa-c03/
```

### Multiple Exams
```bash
# Scrape multiple exams sequentially
./start_chrome_debug.sh https://examice.com/exams/linux-foundation/kcna/
python scrape_with_playwright.py
# Anki import, then:
./start_chrome_debug.sh https://examice.com/exams/microsoft/az-104/
python scrape_with_playwright.py
```

## Files

| File | Description |
|------|-------------|
| `scrape_with_playwright.py` | Main scraper (works with any exam) |
| `start_chrome_debug.sh` | Chrome debugging helper (accepts URL) |
| `requirements.txt` | Python dependencies (playwright) |
| `.gitignore` | Excludes venv and output files |
| `output/` | Generated exam files (gitignored) |

## Technical Details

### Dependencies
- **playwright**: Browser automation library (CDP connection)
- **Python 3.13+**: Async/await support

### Performance
- Time: ~2-5 minutes per exam (network-dependent)
- Includes 1-second delays between pages for stability
- Auto-calculates total pages based on question count

### Data Quality
- ✅ All questions extracted sequentially
- ✅ Question numbers verified (1 to N)
- ✅ Each question has 4 or 5 options (exam-dependent)
- ✅ Answers and explanations included
- ✅ No duplicates or gaps
- ✅ Automatically adapts to different question formats

### URL Pattern Recognition
```regex
/exams/([^/]+)/([^/?]+)
       ↑         ↑
    provider  exam-code
```

## Notes

- ⚠️ Requires active Examice subscription with exam access
- 🔐 Uses your personal authenticated session
- 📚 For personal study use only
- 🚫 Output files are gitignored to respect copyright
- 📖 Respects Examice terms of service

## License

For personal educational use only. Respect Examice terms of service and copyright.

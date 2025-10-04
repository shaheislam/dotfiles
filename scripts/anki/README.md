# KCNA Exam Anki Flashcard Generator

Automated scraper for converting KCNA (Kubernetes and Cloud Native Associate) exam questions from Examice.com into Anki flashcards.

## Overview

This tool uses Playwright to connect to an existing authenticated Chrome browser session and scrapes all 138 KCNA exam questions from https://examice.com/exams/linux-foundation/kcna/, converting them into ready-to-import Anki flashcards.

**Features:**
- Maintains authentication by connecting to existing Chrome session
- Scrapes all 28 pages automatically (138 questions total)
- Extracts question text, all 4 options, correct answer, and explanations
- Generates both JSON and Anki-compatible tab-separated format
- Handles page structure variations correctly

## Prerequisites

1. **Python 3.13+** with pip
2. **Google Chrome** browser
3. **Active Examice account** with access to KCNA exam questions

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
2. Navigate to the KCNA exam: https://examice.com/exams/linux-foundation/kcna/
3. Verify you can see the questions (authentication required)

## Usage

### Quick Start

```bash
# 1. Start Chrome with remote debugging
./start_chrome_debug.sh

# 2. Ensure you're logged into Examice in the Chrome window

# 3. Run the scraper
source venv/bin/activate
python scrape_with_playwright.py
```

### Detailed Steps

#### Step 1: Start Chrome with Remote Debugging

The scraper needs to connect to Chrome via the Chrome DevTools Protocol:

```bash
./start_chrome_debug.sh
```

This script will:
- Kill any existing debug Chrome sessions
- Start Chrome with remote debugging on port 9222
- Open the KCNA exam URL automatically

**Manual alternative:**
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug \
  --no-first-run \
  --no-default-browser-check \
  "https://examice.com/exams/linux-foundation/kcna/"
```

#### Step 2: Run the Scraper

```bash
# Activate virtual environment
source venv/bin/activate

# Run the scraper
python scrape_with_playwright.py
```

The scraper will:
1. Connect to the Chrome debugging port
2. Navigate through all 28 pages
3. Extract all 138 questions with options, answers, and explanations
4. Save results to `output/` directory

#### Step 3: Import to Anki

1. Open Anki
2. File → Import
3. Select: `output/kcna_complete.txt`
4. Set field separator to **Tab**
5. Click Import

## Output Files

### `output/kcna_complete.json`
Complete structured data with all questions:
```json
{
  "number": 1,
  "question": "What native runtime is Open Container Initiative (OCI) compliant?",
  "options": ["runC", "runV", "kata-containers", "gvisor"],
  "answer": "A",
  "explanation": "runC is the native runtime that is Open Container Initiative compliant..."
}
```

### `output/kcna_complete.txt`
Anki-ready flashcards in tab-separated format:
- **Front**: Question number, question text, and all 4 options (A-D)
- **Back**: Correct answer with explanation
- **Tags**: `kcna kubernetes cloud-native linux-foundation`

## Architecture

### How It Works

1. **Chrome Connection**: Uses Playwright's CDP (Chrome DevTools Protocol) to connect to existing browser
2. **Page Navigation**: Loops through all 28 pages systematically
3. **DOM Extraction**: JavaScript evaluation extracts questions from DOM structure
4. **Data Processing**: Parses question number, text, options, answer, and explanation
5. **Output Generation**: Creates both JSON (structured data) and TXT (Anki format)

### DOM Structure

Questions follow this HTML structure:
```
article (question container)
  └─ DIV (parent)
      └─ SECTION (grandparent - contains question number and answer)
  FIELDSET (next sibling - contains options)
      └─ [role="checkbox"] × 4 (option elements)
```

**Page Structure Variations:**
- **Page 1**: 6 articles (1 header + 5 questions) - skips first
- **Pages 2-28**: 5 articles (5 questions) - processes all

## Troubleshooting

### "No browser contexts found"
- Ensure Chrome is running with remote debugging enabled
- Check that port 9222 is not blocked by another process
- Restart Chrome with `./start_chrome_debug.sh`

### "No questions found"
- Verify you're logged into Examice in the Chrome window
- Navigate manually to ensure questions are visible
- Check network connectivity

### Missing Questions
- The script should collect all 138 questions
- Check `output/kcna_complete.json` for actual count
- Re-run if interrupted during scraping

### Import Issues in Anki
- Ensure field separator is set to **Tab** (not comma)
- Verify the file encoding is UTF-8
- Check that HTML tags are preserved in import settings

## Files

| File | Description |
|------|-------------|
| `scrape_with_playwright.py` | Main scraper script using Playwright library |
| `start_chrome_debug.sh` | Helper script to start Chrome with debugging |
| `requirements.txt` | Python package dependencies |
| `.gitignore` | Git ignore rules (excludes venv and output) |
| `output/kcna_complete.json` | Structured question data (generated) |
| `output/kcna_complete.txt` | Anki flashcard deck (generated) |

## Technical Details

### Dependencies
- **playwright**: Browser automation library
- **Python 3.13+**: Required for modern async/await support

### Performance
- Scrapes all 28 pages in ~2-3 minutes
- Network-dependent (page load times)
- Includes 1-second delays between pages for stability

### Data Quality
- All 138 questions extracted
- Question numbers: 1-138 (verified sequential)
- Each question has exactly 4 options
- Answers and explanations included where available

## Notes

- This tool requires an active Examice subscription with KCNA exam access
- Respects site authentication and uses personal logged-in session
- For personal study use only
- Output files are gitignored to avoid committing exam content

## License

For personal educational use only. Respect Examice terms of service and copyright.

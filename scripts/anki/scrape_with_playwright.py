#!/usr/bin/env python3
"""
Examice Question Scraper using Playwright Library
Connects to existing Chrome browser to maintain authentication
Works with any Examice exam (KCNA, AZ-104, etc.)
"""

import asyncio
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse
from playwright.async_api import async_playwright

async def extract_questions_from_page(page, page_num):
    """Extract all questions from a single page using DOM queries"""
    questions = []

    # Wait for questions to load with better timing
    # Page 1 has 6 articles (1 header + 5 questions), pages 2+ have 5 articles
    expected_articles = 6 if page_num == 1 else 5

    try:
        # Wait for first article to appear
        await page.wait_for_selector('article', timeout=10000)

        # Smart wait: Wait for expected number of articles instead of fixed sleep
        # This is much faster and more reliable than sleep-based waiting
        try:
            await page.wait_for_function(
                f"document.querySelectorAll('article').length >= {expected_articles}",
                timeout=5000
            )
        except Exception:
            # If we timeout, continue anyway - we'll work with what we have
            article_count = await page.evaluate("document.querySelectorAll('article').length")
            if article_count < expected_articles:
                # One more short wait for stragglers
                await asyncio.sleep(1)

    except Exception as e:
        print(f"⚠️ Wait error: {e}")

    # Execute JavaScript to extract questions directly from DOM
    # Structure: article → DIV (parent) → SECTION (grandparent)
    # Next sibling of DIV is FIELDSET with checkboxes
    questions_data = await page.evaluate("""
        (pageNum) => {
            const questions = [];
            const debug = [];

            // Only page 1 has a header article; pages 2+ don't
            const allArticles = Array.from(document.querySelectorAll('article'));
            debug.push(`Total articles found: ${allArticles.length}`);

            const questionArticles = pageNum === 1 ? allArticles.slice(1) : allArticles;
            debug.push(`Question articles to process: ${questionArticles.length}`);

            questionArticles.forEach((article, idx) => {
                try {
                    // Get question text
                    const questionPara = article.querySelector('p');
                    if (!questionPara) {
                        debug.push(`Article ${idx}: No question paragraph found`);
                        return;
                    }
                    const questionText = questionPara.textContent.trim();

                    // Get parent DIV and grandparent SECTION
                    const parent = article.parentElement;
                    if (!parent) {
                        debug.push(`Article ${idx}: No parent found`);
                        return;
                    }
                    const section = parent.parentElement;
                    if (!section) {
                        debug.push(`Article ${idx}: No section found`);
                        return;
                    }

                    // Get question number and total from section text
                    const sectionText = section.textContent;
                    const numMatch = sectionText.match(/Question (\\d+) of (\\d+)/);
                    if (!numMatch) {
                        debug.push(`Article ${idx}: No question number found in section text`);
                        return;
                    }
                    const questionNum = parseInt(numMatch[1]);
                    const totalQuestions = parseInt(numMatch[2]);

                    // Get FIELDSET sibling with options
                    const fieldset = parent.nextElementSibling;
                    if (!fieldset) {
                        debug.push(`Article ${idx}: No fieldset found (parent.nextElementSibling is null)`);
                        return;
                    }

                    // Extract options from checkboxes in fieldset
                    const checkboxes = fieldset.querySelectorAll('[role="checkbox"]');
                    const options = [];

                    if (checkboxes.length === 0) {
                        debug.push(`Article ${idx}: Fieldset exists but no checkboxes found`);
                        // Try alternative selector - maybe some questions use different structure
                        const altCheckboxes = fieldset.querySelectorAll('input[type="checkbox"]');
                        debug.push(`Article ${idx}: Alternative selector found ${altCheckboxes.length} checkboxes`);
                    }

                    checkboxes.forEach(cb => {
                        const para = cb.querySelector('p');
                        if (para) {
                            options.push(para.textContent.trim());
                        } else {
                            // Try getting text directly from checkbox element
                            const text = cb.textContent.trim();
                            if (text && text.length > 0) {
                                options.push(text);
                            }
                        }
                    });

                    // Handle different question types
                    let answer = '';
                    let isTextQuestion = false;

                    // Accept questions with 4 or 5 options (multiple choice)
                    if (options.length >= 4 && options.length <= 5) {
                        // Extract answer (A-E for 5 options, A-D for 4 options)
                        const answerMatch = sectionText.match(/Correct Answer:\\s*([A-E])/);
                        if (!answerMatch) {
                            debug.push(`Article ${idx}: Multiple choice but no answer found`);
                            return;
                        }
                        answer = answerMatch[1];
                    } else if (options.length === 0) {
                        // Text-based question (fill-in-blank, code, etc.)
                        // Try to extract the answer from the section text
                        const textAnswerMatch = sectionText.match(/Correct Answer:\\s*([^\\n]+)/);
                        if (textAnswerMatch) {
                            answer = textAnswerMatch[1].trim();
                            isTextQuestion = true;
                            debug.push(`Article ${idx}: ✓ Extracted text-based question ${questionNum} (answer: ${answer.substring(0, 30)}...)`);
                        } else {
                            debug.push(`Article ${idx}: Text question but no answer found`);
                            return;
                        }
                    } else {
                        debug.push(`Article ${idx}: Found ${options.length} options (expected 4-5 or 0) - fieldset.tagName=${fieldset.tagName}`);
                        return;
                    }

                    // Extract explanation from section paragraphs
                    const allParas = Array.from(section.querySelectorAll('p'));
                    let explanation = '';

                    for (const para of allParas) {
                        const text = para.textContent.trim();

                        // Skip question and options
                        if (text === questionText || options.includes(text)) continue;

                        // Skip short text and navigation
                        if (text.length < 20 ||
                            text.includes('Prev page') ||
                            text.includes('Next page') ||
                            text.includes('Examice') ||
                            text.includes('Follow us') ||
                            text.includes('Copyright')) continue;

                        explanation = text;
                        break;
                    }

                    questions.push({
                        number: questionNum,
                        total: totalQuestions,
                        question: questionText,
                        options: options,
                        answer: answer,
                        explanation: explanation,
                        isTextQuestion: isTextQuestion
                    });

                    if (!isTextQuestion) {
                        debug.push(`Article ${idx}: ✓ Extracted question ${questionNum}`);
                    }

                } catch (err) {
                    debug.push(`Article ${idx}: Error - ${err.message}`);
                }
            });

            return { questions, debug };
        }
    """, page_num)

    # Show debug info if we found fewer questions than expected
    if len(questions_data['questions']) < (5 if page_num > 1 else 5):
        print(f"\n  Debug: {' | '.join(questions_data['debug'])}")

    return questions_data['questions']

async def scrape_single_page(context, page_num, total_pages, base_url, semaphore, progress_lock):
    """Scrape a single page with semaphore control for concurrent execution"""
    async with semaphore:
        url = f"{base_url}?page={page_num}"
        page = None

        try:
            # Thread-safe progress printing
            async with progress_lock:
                print(f"📄 Page {page_num}/{total_pages}...", end=" ", flush=True)

            # Create a new page for this task to avoid conflicts
            page = await context.new_page()

            # Use domcontentloaded instead of networkidle for faster loads (2-3x speedup)
            await page.goto(url, wait_until='domcontentloaded', timeout=15000)
            questions = await extract_questions_from_page(page, page_num)

            async with progress_lock:
                if questions:
                    print(f"✓ Found {len(questions)} questions")
                else:
                    print(f"⚠️  No questions found")

            return (page_num, questions if questions else [])

        except Exception as e:
            async with progress_lock:
                print(f"❌ Error: {e}")
            return (page_num, e)

        finally:
            # Always close the page when done
            if page:
                await page.close()

async def scrape_pages_parallel(context, total_pages, base_url, max_concurrent=5):
    """Orchestrate parallel page scraping with semaphore-based concurrency control"""
    semaphore = asyncio.Semaphore(max_concurrent)
    progress_lock = asyncio.Lock()

    # Create tasks for all pages (starting from page 2)
    tasks = [
        scrape_single_page(context, page_num, total_pages, base_url, semaphore, progress_lock)
        for page_num in range(2, total_pages + 1)
    ]

    # Execute all tasks concurrently
    results = await asyncio.gather(*tasks, return_exceptions=False)

    # Sort results by page number and filter out errors
    all_questions = []
    failed_pages = []

    for page_num, result in sorted(results, key=lambda x: x[0]):
        if isinstance(result, Exception):
            failed_pages.append(page_num)
        else:
            all_questions.extend(result)

    if failed_pages:
        print(f"\n⚠️  Warning: {len(failed_pages)} page(s) failed: {failed_pages}")

    return all_questions

def parse_exam_info(url):
    """Extract exam information from URL"""
    # Parse URL: https://examice.com/exams/provider/exam-name/
    match = re.search(r'/exams/([^/]+)/([^/?]+)', url)
    if match:
        provider = match.group(1)
        exam_code = match.group(2)
        return {
            'provider': provider,
            'exam_code': exam_code,
            'name': f"{provider}-{exam_code}".replace('/', '-')
        }
    return {'provider': 'unknown', 'exam_code': 'exam', 'name': 'exam'}

async def scrape_all_pages(browser_url="http://localhost:9222", exam_url=None):
    """Connect to existing browser and scrape all pages"""

    print("=" * 70)
    print("Examice Question Scraper - Playwright Direct")
    print("=" * 70)
    print()
    print(f"Connecting to Chrome at {browser_url}...")

    async with async_playwright() as p:
        try:
            # Connect to existing browser
            browser = await p.chromium.connect_over_cdp(browser_url)

            # Get the default context and page
            contexts = browser.contexts
            if not contexts:
                print("❌ No browser contexts found")
                print("   Please open Chrome first and navigate to the exam site")
                return

            context = contexts[0]
            pages = context.pages

            if not pages:
                print("❌ No pages found in browser")
                return

            page = pages[0]

            # Get exam URL from browser if not provided
            current_url = page.url
            if not exam_url:
                exam_url = current_url

            # Parse exam info from URL
            exam_info = parse_exam_info(exam_url)

            # Extract base URL (without query parameters)
            base_url = exam_url.split('?')[0]

            print(f"✓ Connected to browser")
            print(f"  Current URL: {current_url}")
            print(f"  Exam: {exam_info['provider'].upper()} - {exam_info['exam_code'].upper()}")
            print()

            all_questions = []
            total_questions = None
            total_pages = None

            # First, get total questions from page 1
            # Use domcontentloaded for faster initial load
            await page.goto(base_url, wait_until='domcontentloaded', timeout=15000)

            # Get total from first page
            first_page_questions = await extract_questions_from_page(page, 1)
            if first_page_questions:
                total_questions = first_page_questions[0]['total']
                # Estimate total pages (assuming ~5 questions per page)
                total_pages = (total_questions + 4) // 5
                print(f"📊 Detected {total_questions} total questions across ~{total_pages} pages")
                print()
                all_questions.extend(first_page_questions)
                print(f"📄 Page 1/{total_pages}... ✓ Found {len(first_page_questions)} questions")

            if not total_pages:
                print("❌ Could not detect total questions. Please ensure you're on a valid exam page.")
                return

            # Scrape remaining pages in parallel
            print(f"🚀 Starting parallel scraping (max 5 concurrent pages)...")
            print()
            parallel_questions = await scrape_pages_parallel(context, total_pages, base_url, max_concurrent=5)
            all_questions.extend(parallel_questions)

            # Save all questions
            output_dir = Path(__file__).parent / "output"
            output_dir.mkdir(exist_ok=True)

            # Dynamic filenames based on exam
            exam_name = exam_info['name']
            json_file = output_dir / f"{exam_name}_complete.json"
            anki_file = output_dir / f"{exam_name}_complete.txt"

            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(all_questions, f, indent=2, ensure_ascii=False)

            # Count question types
            multiple_choice = sum(1 for q in all_questions if not q.get('isTextQuestion', False))
            text_based = sum(1 for q in all_questions if q.get('isTextQuestion', False))

            print()
            print("=" * 70)
            print(f"✅ Scraping complete!")
            print(f"✅ Total questions collected: {len(all_questions)}/{total_questions}")
            print(f"   - Multiple choice: {multiple_choice}")
            print(f"   - Text-based: {text_based}")
            print(f"✅ Saved to: {json_file}")
            print()

            # Generate Anki deck
            print("📝 Generating Anki deck...")

            # Generate tags based on exam info
            tags = f"examice {exam_info['provider']} {exam_info['exam_code']}".lower()

            with open(anki_file, 'w', encoding='utf-8', newline='') as f:
                import csv
                writer = csv.writer(f, delimiter='\t')

                for q in sorted(all_questions, key=lambda x: x['number']):
                    # Front of card
                    front = f"<b>Question {q['number']}:</b><br><br>{q['question']}<br><br>"

                    # Handle different question types
                    if q.get('isTextQuestion', False):
                        # Text-based question (no options)
                        front += "<i>(Text-based question - see answer for details)</i>"
                    else:
                        # Multiple choice - show all options (4 or 5)
                        for i, opt in enumerate(q['options']):
                            front += f"{chr(65+i)}. {opt}<br>"

                    # Back of card
                    back = f"<b>Answer: {q['answer']}</b><br><br>"
                    if q['explanation']:
                        back += f"<i>{q['explanation']}</i>"

                    writer.writerow([front, back, tags])

            print(f"✅ Anki deck saved to: {anki_file}")
            print(f"✅ Tags: {tags}")

            # Also save to ~/Documents for easy access
            import shutil
            documents_dir = Path.home() / "Documents"
            documents_file = documents_dir / f"{exam_name}_complete.txt"
            shutil.copy2(anki_file, documents_file)
            print(f"✅ Copy saved to: {documents_file}")

            print()
            print("=" * 70)
            print("🎉 All done! Import the Anki deck:")
            print(f"   1. Open Anki")
            print(f"   2. File → Import")
            print(f"   3. Select: {anki_file}")
            print(f"      OR: {documents_file}")
            print(f"   4. Field separator: Tab")
            print("=" * 70)

            await browser.close()

        except Exception as e:
            print(f"❌ Error: {e}")
            print()
            print("Make sure Chrome is running with remote debugging enabled:")
            print("  /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome \\")
            print("    --remote-debugging-port=9222 \\")
            print("    --user-data-dir=/tmp/chrome-debug")

if __name__ == "__main__":
    print("""
╔════════════════════════════════════════════════════════════════════╗
║              Examice Exam Question Scraper                         ║
║                Using Playwright Library                            ║
╚════════════════════════════════════════════════════════════════════╝

PREREQUISITES:
--------------
1. Start Chrome with remote debugging enabled:

   ./start_chrome_debug.sh <exam-url>

   Example:
   ./start_chrome_debug.sh https://examice.com/exams/linux-foundation/kcna/
   ./start_chrome_debug.sh https://examice.com/exams/microsoft/az-104/

2. Make sure you're logged in and can see the questions

3. Run this script with optional exam URL:

   python scrape_with_playwright.py [exam-url]

   If no URL provided, will use the current browser page.

Press Ctrl+C to cancel...
""")

    # Get exam URL from command line or use None to detect from browser
    exam_url = sys.argv[1] if len(sys.argv) > 1 else None

    if exam_url:
        print(f"📍 Using provided exam URL: {exam_url}\n")

    try:
        asyncio.run(scrape_all_pages(exam_url=exam_url))
    except KeyboardInterrupt:
        print("\n\n⚠️  Cancelled by user")
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")

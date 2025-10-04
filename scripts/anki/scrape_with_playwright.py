#!/usr/bin/env python3
"""
KCNA Question Scraper using Playwright Library
Connects to existing Chrome browser to maintain authentication
"""

import asyncio
import json
import re
from pathlib import Path
from playwright.async_api import async_playwright

async def extract_questions_from_page(page, page_num):
    """Extract all questions from a single page using DOM queries"""
    questions = []

    # Wait for questions to load
    await page.wait_for_selector('article', timeout=30000)

    # Execute JavaScript to extract questions directly from DOM
    # Structure: article → DIV (parent) → SECTION (grandparent)
    # Next sibling of DIV is FIELDSET with checkboxes
    questions_data = await page.evaluate("""
        (pageNum) => {
            const questions = [];

            // Only page 1 has a header article; pages 2-28 don't
            const allArticles = Array.from(document.querySelectorAll('article'));
            const questionArticles = pageNum === 1 ? allArticles.slice(1) : allArticles;

            questionArticles.forEach(article => {
                try {
                    // Get question text
                    const questionPara = article.querySelector('p');
                    if (!questionPara) return;
                    const questionText = questionPara.textContent.trim();

                    // Get parent DIV and grandparent SECTION
                    const parent = article.parentElement;
                    if (!parent) return;
                    const section = parent.parentElement;
                    if (!section) return;

                    // Get question number from section text
                    const sectionText = section.textContent;
                    const numMatch = sectionText.match(/Question (\\d+) of 138/);
                    if (!numMatch) return;
                    const questionNum = parseInt(numMatch[1]);

                    // Get FIELDSET sibling with options
                    const fieldset = parent.nextElementSibling;
                    if (!fieldset) return;

                    // Extract options from checkboxes in fieldset
                    const checkboxes = fieldset.querySelectorAll('[role="checkbox"]');
                    const options = [];

                    checkboxes.forEach(cb => {
                        const para = cb.querySelector('p');
                        if (para) {
                            options.push(para.textContent.trim());
                        }
                    });

                    if (options.length !== 4) return;

                    // Extract answer
                    const answerMatch = sectionText.match(/Correct Answer:\\s*([A-D])/);
                    if (!answerMatch) return;
                    const answer = answerMatch[1];

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
                        question: questionText,
                        options: options,
                        answer: answer,
                        explanation: explanation
                    });

                } catch (err) {
                    console.error('Error extracting question:', err);
                }
            });

            return questions;
        }
    """, page_num)

    return questions_data

async def scrape_all_pages(browser_url="http://localhost:9222"):
    """Connect to existing browser and scrape all pages"""

    print("=" * 70)
    print("KCNA Question Scraper - Playwright Direct")
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

            print(f"✓ Connected to browser")
            print(f"  Current URL: {page.url}")
            print()

            all_questions = []
            base_url = "https://examice.com/exams/linux-foundation/kcna/"

            # Scrape all 28 pages
            for page_num in range(1, 29):
                url = f"{base_url}?page={page_num}" if page_num > 1 else base_url

                print(f"📄 Scraping page {page_num}/28...")

                try:
                    await page.goto(url, wait_until='load', timeout=15000)
                    await asyncio.sleep(1)  # Give page time to fully render

                    questions = await extract_questions_from_page(page, page_num)

                    if questions:
                        all_questions.extend(questions)
                        print(f"   ✓ Found {len(questions)} questions")
                    else:
                        print(f"   ⚠️  No questions found on page {page_num}")

                except Exception as e:
                    print(f"   ❌ Error on page {page_num}: {e}")
                    continue

            # Save all questions
            output_dir = Path(__file__).parent / "output"
            output_dir.mkdir(exist_ok=True)

            # Save as JSON
            json_file = output_dir / "kcna_complete.json"
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(all_questions, f, indent=2, ensure_ascii=False)

            print()
            print("=" * 70)
            print(f"✅ Scraping complete!")
            print(f"✅ Total questions collected: {len(all_questions)}")
            print(f"✅ Saved to: {json_file}")
            print()

            # Generate Anki deck
            print("📝 Generating Anki deck...")
            anki_file = output_dir / "kcna_complete.txt"

            with open(anki_file, 'w', encoding='utf-8', newline='') as f:
                import csv
                writer = csv.writer(f, delimiter='\t')

                for q in sorted(all_questions, key=lambda x: x['number']):
                    # Front of card
                    front = f"<b>Question {q['number']}:</b><br><br>{q['question']}<br><br>"
                    for i, opt in enumerate(q['options']):
                        front += f"{chr(65+i)}. {opt}<br>"

                    # Back of card
                    back = f"<b>Answer: {q['answer']}</b><br><br>"
                    if q['explanation']:
                        back += f"<i>{q['explanation']}</i>"

                    # Tags
                    tags = "kcna kubernetes cloud-native linux-foundation"

                    writer.writerow([front, back, tags])

            print(f"✅ Anki deck saved to: {anki_file}")
            print()
            print("=" * 70)
            print("🎉 All done! Import the Anki deck:")
            print(f"   1. Open Anki")
            print(f"   2. File → Import")
            print(f"   3. Select: {anki_file}")
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
║                  KCNA Exam Question Scraper                        ║
║                     Using Playwright Library                       ║
╚════════════════════════════════════════════════════════════════════╝

PREREQUISITES:
--------------
1. Start Chrome with remote debugging enabled:

   /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome \\
     --remote-debugging-port=9222 \\
     --user-data-dir=/tmp/chrome-debug

2. Navigate to: https://examice.com/exams/linux-foundation/kcna/
   (Make sure you're logged in)

3. Run this script

The script will automatically navigate all 28 pages and collect all 138
questions, then generate a ready-to-import Anki deck.

Press Ctrl+C to cancel...
""")

    try:
        asyncio.run(scrape_all_pages())
    except KeyboardInterrupt:
        print("\n\n⚠️  Cancelled by user")
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")

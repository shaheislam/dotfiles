#!/bin/bash
# Start Chrome with remote debugging enabled for Playwright
# Usage: ./start_chrome_debug.sh [exam-url]
# Example: ./start_chrome_debug.sh https://examice.com/exams/microsoft/az-104/

# Default to KCNA exam if no URL provided
EXAM_URL="${1:-https://examice.com/exams/linux-foundation/kcna/}"

echo "═══════════════════════════════════════════════════════════════"
echo "  Starting Chrome with Remote Debugging"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Exam URL: $EXAM_URL"
echo "Remote debugging port: 9222"
echo ""
echo "Usage:"
echo "  ./start_chrome_debug.sh [exam-url]"
echo ""
echo "Examples:"
echo "  ./start_chrome_debug.sh https://examice.com/exams/linux-foundation/kcna/"
echo "  ./start_chrome_debug.sh https://examice.com/exams/microsoft/az-104/"
echo "  ./start_chrome_debug.sh https://examice.com/exams/aws/saa-c03/"
echo ""
echo "Next steps:"
echo "  1. This script will open Chrome to the exam URL"
echo "  2. Make sure you're logged in to Examice"
echo "  3. Run the scraper:"
echo "     python scrape_with_playwright.py"
echo "     OR"
echo "     python scrape_with_playwright.py $EXAM_URL"
echo ""
echo "Press Ctrl+C to stop Chrome when done"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Kill any existing Chrome debug instances
pkill -f "chrome-debug" 2>/dev/null
sleep 1

# Start Chrome with remote debugging
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug \
  --no-first-run \
  --no-default-browser-check \
  "$EXAM_URL" &

CHROME_PID=$!

echo "✓ Chrome started (PID: $CHROME_PID)"
echo "✓ Opening: $EXAM_URL"
echo ""
echo "Waiting for Chrome process..."
echo ""

# Wait for Chrome process
wait $CHROME_PID

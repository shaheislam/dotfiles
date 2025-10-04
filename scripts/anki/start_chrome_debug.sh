#!/bin/bash
# Start Chrome with remote debugging enabled for Playwright

echo "═══════════════════════════════════════════════════════════════"
echo "  Starting Chrome with Remote Debugging"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Chrome will start with remote debugging on port 9222"
echo "Your Playwright script can connect to it."
echo ""
echo "To use:"
echo "  1. This script will open Chrome"
echo "  2. Navigate to: https://examice.com/exams/linux-foundation/kcna/"
echo "  3. Make sure you're logged in"
echo "  4. Run: venv/bin/python scrape_with_playwright.py"
echo ""
echo "Press Ctrl+C to stop Chrome when done"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Kill any existing Chrome debug instances
pkill -f "chrome-debug" 2>/dev/null

# Start Chrome with remote debugging
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug \
  --no-first-run \
  --no-default-browser-check \
  "https://examice.com/exams/linux-foundation/kcna/" &

CHROME_PID=$!

echo "✓ Chrome started (PID: $CHROME_PID)"
echo "✓ Remote debugging port: 9222"
echo ""
echo "Next steps:"
echo "  1. Log in to Examice if needed"
echo "  2. Open a new terminal"
echo "  3. Run: cd ~/dotfiles/scripts/anki && venv/bin/python scrape_with_playwright.py"
echo ""
echo "Press Ctrl+C to stop Chrome..."

# Wait for Chrome process
wait $CHROME_PID

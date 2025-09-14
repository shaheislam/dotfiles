#!/bin/bash

# CV Compilation Script
# Compiles LaTeX CV to PDF with proper error handling

set -e  # Exit on error

# Arguments
TEX_PATH="${1}"
OUTPUT_NAME="${2}"
COMPILER="${3:-pdflatex}"

# Check if tex file exists
if [ ! -f "$TEX_PATH" ]; then
    echo "Error: LaTeX file not found: $TEX_PATH"
    exit 1
fi

# Get directories
TEX_DIR=$(dirname "$TEX_PATH")
TEX_FILE=$(basename "$TEX_PATH")
OUTPUT_DIR="$HOME/dotfiles/jobapps/output"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Copy resume.cls to working directory if it exists
RESUME_CLS="$HOME/dotfiles/jobapps/resume.cls"
if [ -f "$RESUME_CLS" ]; then
    cp "$RESUME_CLS" "$TEX_DIR/"
fi

# Change to tex directory for compilation
cd "$TEX_DIR"

echo "Compiling $TEX_FILE with $COMPILER..."

# Run compiler twice for references
for i in 1 2; do
    echo "Pass $i..."
    $COMPILER -interaction=nonstopmode -output-directory="$TEX_DIR" "$TEX_FILE" > /dev/null 2>&1 || {
        echo "Compilation failed on pass $i"
        echo "Trying to continue..."
    }
done

# Check if PDF was created
PDF_FILE="${TEX_FILE%.tex}.pdf"
if [ -f "$PDF_FILE" ]; then
    # Copy to output directory with proper name
    if [ -n "$OUTPUT_NAME" ]; then
        cp "$PDF_FILE" "$OUTPUT_DIR/${OUTPUT_NAME}.pdf"
        echo "✅ PDF created: $OUTPUT_DIR/${OUTPUT_NAME}.pdf"
    else
        cp "$PDF_FILE" "$OUTPUT_DIR/"
        echo "✅ PDF created: $OUTPUT_DIR/$PDF_FILE"
    fi

    # Clean up auxiliary files
    rm -f *.aux *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz

    exit 0
else
    echo "❌ PDF generation failed"
    exit 1
fi
#!/bin/bash

# CV Compilation Script
# Compiles LaTeX or Typst CV to PDF with proper error handling
# Supports both .tex (LaTeX) and .typ (Typst) files

set -e  # Exit on error

# Arguments
SOURCE_PATH="${1}"
OUTPUT_NAME="${2}"
COMPILER="${3:-auto}"  # auto, pdflatex, xelatex, lualatex, or typst

# Check if source file exists
if [ ! -f "$SOURCE_PATH" ]; then
    echo "Error: Source file not found: $SOURCE_PATH"
    exit 1
fi

# Get directories and file info
SOURCE_DIR=$(dirname "$SOURCE_PATH")
SOURCE_FILE=$(basename "$SOURCE_PATH")
SOURCE_EXT="${SOURCE_FILE##*.}"
OUTPUT_DIR="$HOME/dotfiles/jobapps/output"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Auto-detect format based on file extension
if [ "$COMPILER" = "auto" ]; then
    if [ "$SOURCE_EXT" = "typ" ]; then
        COMPILER="typst"
    else
        COMPILER="pdflatex"
    fi
fi

# Handle Typst compilation
if [ "$COMPILER" = "typst" ]; then
    echo "Compiling $SOURCE_FILE with Typst..."

    # Check if typst is installed
    if ! command -v typst &> /dev/null; then
        echo "Error: Typst not installed. Run: brew install typst"
        exit 1
    fi

    # Determine output path
    if [ -n "$OUTPUT_NAME" ]; then
        OUTPUT_PDF="$OUTPUT_DIR/${OUTPUT_NAME}.pdf"
    else
        OUTPUT_PDF="$OUTPUT_DIR/${SOURCE_FILE%.typ}.pdf"
    fi

    # Single-pass compilation (Typst doesn't need multiple passes)
    if typst compile "$SOURCE_PATH" "$OUTPUT_PDF"; then
        echo "✅ PDF created: $OUTPUT_PDF"
        exit 0
    else
        echo "❌ Typst compilation failed"
        exit 1
    fi
fi

# Handle LaTeX compilation
echo "Compiling $SOURCE_FILE with $COMPILER..."

# Copy resume.cls to working directory if it exists
RESUME_CLS="$HOME/dotfiles/jobapps/resume.cls"
if [ -f "$RESUME_CLS" ]; then
    cp "$RESUME_CLS" "$SOURCE_DIR/"
fi

# Change to source directory for compilation
cd "$SOURCE_DIR"

# Run compiler twice for references
for i in 1 2; do
    echo "Pass $i..."
    $COMPILER -interaction=nonstopmode -output-directory="$SOURCE_DIR" "$SOURCE_FILE" > /dev/null 2>&1 || {
        echo "Compilation failed on pass $i"
        echo "Trying to continue..."
    }
done

# Check if PDF was created
PDF_FILE="${SOURCE_FILE%.tex}.pdf"
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

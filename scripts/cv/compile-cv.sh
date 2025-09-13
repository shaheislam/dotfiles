#!/bin/bash

# compile-cv.sh - Compile LaTeX CV to PDF with custom class file support
# Usage: ./compile-cv.sh <tex-file> [output-name] [compiler]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# Default paths
JOBAPPS_DIR="$HOME/Documents/jobapps"
TEMPLATES_DIR="$HOME/dotfiles/jobapps/templates"  # Keep templates in dotfiles
GENERATED_DIR="$HOME/Documents/jobapps/generated"
# Final output goes to Documents
OUTPUT_DIR="$HOME/Documents/jobapps/output"
ARCHIVE_DIR="$HOME/Documents/jobapps/archive"

# Check if tex file is provided
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <tex-file> [output-name] [compiler]"
    print_info "Example: $0 /jobapps/generated/cv.tex MyCV_2024 pdflatex"
    exit 1
fi

TEX_FILE="$1"
TEX_DIR=$(dirname "$TEX_FILE")
TEX_BASENAME=$(basename "$TEX_FILE" .tex)

# Output name (default: CV_timestamp)
if [ -n "$2" ]; then
    OUTPUT_NAME="$2"
else
    OUTPUT_NAME="CV_$(date +%Y%m%d_%H%M%S)"
fi

# Compiler (default: pdflatex, alternatives: xelatex, lualatex)
COMPILER="${3:-pdflatex}"

# Add TeX binaries to PATH (for macOS with MacTeX)
export PATH="/Library/TeX/texbin:$PATH"

# Check if compiler exists
if ! command -v "$COMPILER" &> /dev/null; then
    print_error "$COMPILER is not installed"
    print_info "Installing MacTeX... This may take a while..."
    brew install --cask mactex-no-gui
    eval "$(/usr/libexec/path_helper)"
    export PATH="/Library/TeX/texbin:$PATH"
    
    # Check again
    if ! command -v "$COMPILER" &> /dev/null; then
        print_error "Failed to install LaTeX. Please install MacTeX manually."
        exit 1
    fi
fi

# Check if tex file exists
if [ ! -f "$TEX_FILE" ]; then
    print_error "TeX file not found: $TEX_FILE"
    exit 1
fi

print_info "Compiling $TEX_FILE with $COMPILER..."

# Look for resume.cls in multiple locations
CLS_LOCATIONS=(
    "$TEX_DIR/resume.cls"
    "$JOBAPPS_DIR/resume.cls"
    "$TEMPLATES_DIR/resume.cls"
    "./resume.cls"
)

CLS_FOUND=""
for location in "${CLS_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        CLS_FOUND="$location"
        print_info "Found resume.cls at: $location"
        break
    fi
done

# If resume.cls is found and not in the same directory as tex file, copy it
if [ -n "$CLS_FOUND" ] && [ "$CLS_FOUND" != "$TEX_DIR/resume.cls" ]; then
    print_info "Copying resume.cls to compilation directory..."
    cp "$CLS_FOUND" "$TEX_DIR/resume.cls"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Change to tex directory for compilation
cd "$TEX_DIR"

# Compile the document (run twice for references)
print_info "First compilation pass..."
$COMPILER -interaction=nonstopmode -output-directory="$TEX_DIR" "$TEX_FILE" > /dev/null 2>&1
# Check if PDF exists after first pass (even if compiler returns error)
PDF_FILE="$TEX_DIR/$TEX_BASENAME.pdf"
if [ -f "$PDF_FILE" ]; then
    print_success "First pass completed (PDF generated)"
else
    print_error "Compilation failed. Running with verbose output:"
    $COMPILER -interaction=nonstopmode -output-directory="$TEX_DIR" "$TEX_FILE"
    # Check again if PDF was created despite errors
    if [ ! -f "$PDF_FILE" ]; then
        exit 1
    fi
    print_info "PDF generated despite LaTeX warnings"
fi

print_info "Second compilation pass (for references)..."
$COMPILER -interaction=nonstopmode -output-directory="$TEX_DIR" "$TEX_FILE" > /dev/null 2>&1

# Check if PDF was created
PDF_FILE="$TEX_DIR/$TEX_BASENAME.pdf"
if [ ! -f "$PDF_FILE" ]; then
    print_error "PDF generation failed"
    exit 1
fi

# Move PDF to output directory with custom name
FINAL_PDF="$OUTPUT_DIR/${OUTPUT_NAME}.pdf"
mv "$PDF_FILE" "$FINAL_PDF"
print_success "PDF created: $FINAL_PDF"

# Archive if file already exists
if [ -f "$ARCHIVE_DIR/${OUTPUT_NAME}.pdf" ]; then
    ARCHIVE_NAME="${OUTPUT_NAME}_$(date +%Y%m%d_%H%M%S).pdf"
    mv "$ARCHIVE_DIR/${OUTPUT_NAME}.pdf" "$ARCHIVE_DIR/$ARCHIVE_NAME"
    print_info "Previous version archived as: $ARCHIVE_NAME"
fi

# Clean up auxiliary files
print_info "Cleaning up auxiliary files..."
rm -f "$TEX_DIR"/*.{aux,log,out,toc,bbl,blg,fls,fdb_latexmk,synctex.gz}

# Summary
echo ""
print_success "=== Compilation Complete ==="
echo "Output: $FINAL_PDF"
echo "Size: $(du -h "$FINAL_PDF" | cut -f1)"

# Option to open the PDF
if [ "$4" == "--open" ]; then
    print_info "Opening PDF..."
    open "$FINAL_PDF"
fi

exit 0
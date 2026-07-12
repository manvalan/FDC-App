# Build PDF — FdC Railway Manager documentation
MAIN = main
BUILD_DIR = build
LATEX = pdflatex

.PHONY: all clean open

all: $(BUILD_DIR)/$(MAIN).pdf

$(BUILD_DIR)/$(MAIN).pdf: $(MAIN).tex preamble.tex modules/*.tex
	mkdir -p $(BUILD_DIR)
	$(LATEX) -output-directory=$(BUILD_DIR) $(MAIN).tex
	$(LATEX) -output-directory=$(BUILD_DIR) $(MAIN).tex

clean:
	rm -rf $(BUILD_DIR) *.aux *.log *.out *.toc *.lof *.lot

open: all
	open $(BUILD_DIR)/$(MAIN).pdf

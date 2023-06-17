PACKAGE_NAME=config
SOURCE_DIR="."

BUILD_FLAGS=
TEST_FLAGS=-q

SOURCES=main.rkt

DOC_ROOT=scribblings/config.scrbl
DOC_FILES=scribblings/config.scrbl

# Where raco is installed
RACO="$(shell which raco)"
RACKET="$(shell which racket)"

# Optional ARG when provided
ARG=$(filter-out $@,$(MAKECMDGOALS))

# Build it all
all: build test

build: $(SOURCES)
	@ echo "Building ..." &&\
	  $(RACO) make $(BUILD_FLAGS) $(SOURCES)

# Test it all
test:
	@ echo "Running tests ..." &&\
	$(RACO) test $(TEST_FLAGS) $(SOURCES)

clean:
	find . -name 'compiled' | xargs -I% rm -rf %

doc: $(DOC_FILES)
	mkdir -p html
	raco scribble --quiet +m --htmls --dest html $(DOC_ROOT)

doc-pdf: $(DOC_FILES)
	raco scribble --quiet +m --pdf $(DOC_ROOT)

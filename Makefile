
# Makefile for building PyLucene
#
# Supported operating systems: Mac OS X, Linux and Windows.
# See INSTALL file for requirements.
# See jcc/INSTALL for information about --shared.
# 
# Steps to build
#   1. Edit the sections below as documented
#   2. make
#   3. make install
#
# The install target installs the lucene python extension in python's
# site-packages directory.
#

VERSION=4.0-0
LUCENE_SVN_VER=HEAD
LUCENE_VER=4.0
LUCENE_SVN=http://svn.apache.org/repos/asf/lucene/dev/trunk/lucene
MODULES_SVN=http://svn.apache.org/repos/asf/lucene/dev/trunk/modules
PYLUCENE:=$(shell pwd)
LUCENE=lucene-java-$(LUCENE_VER)
MODULES=lucene-modules-$(LUCENE_VER)

# 
# You need to uncomment and edit the variables below in the section
# corresponding to your operating system.
#
# Windows drive-absolute paths need to be expressed cygwin style.
#
# PREFIX: where programs are normally installed on your system (Unix).
# PREFIX_PYTHON: where your version of python is installed.
# JCC: how jcc is invoked, depending on the python version:
#  - python 3.2:
#      $(PYTHON) -m jcc
#  - python 3.1:
#      $(PYTHON) -m jcc.__main__
# NUM_FILES is the number of wrapper files to generate. By default, jcc
# generates all C++ classes into one single file. This may exceed a compiler
# limit.
#

# Mac OS X 10.6 (MacPorts 1.8.0 64-bit Python 2.7, Java 1.6)
#PREFIX_PYTHON=/Users/vajda/apache/python3/_install
#ANT=ant
#PYTHON=$(PREFIX_PYTHON)/bin/python
#JCC=$(PYTHON) -m jcc.__main__ --arch x86_64
#NUM_FILES=3

#
# No edits required below
#

ifeq ($(DEBUG),1)
  DEBUG_OPT=--debug
endif

DEFINES=-DPYLUCENE_VER="\"$(VERSION)\"" -DLUCENE_VER="\"$(LUCENE_VER)\""

LUCENE_JAR=$(LUCENE)/build/lucene-core-$(LUCENE_VER).jar
ANALYZERS_JAR=$(MODULES)/analysis/build/common/lucene-analyzers-common-$(LUCENE_VER).jar
HIGHLIGHTER_JAR=$(LUCENE)/build/contrib/highlighter/lucene-highlighter-$(LUCENE_VER).jar
MEMORY_JAR=$(LUCENE)/build/contrib/memory/lucene-memory-$(LUCENE_VER).jar
QUERIES_JAR=$(LUCENE)/build/contrib/queries/lucene-queries-$(LUCENE_VER).jar
EXTENSIONS_JAR=build/jar/extensions.jar

ICUPKG:=$(shell which icupkg)

.PHONY: generate compile install default all clean realclean \
	sources test jars distrib

default: all

$(LUCENE):
	svn export -r $(LUCENE_SVN_VER) $(LUCENE_SVN) $(LUCENE)
	svn export -r $(LUCENE_SVN_VER) $(MODULES_SVN) $(MODULES)

sources: $(LUCENE)

to-orig: sources
	mkdir -p $(LUCENE)-orig
	tar -C $(LUCENE) -cf - . | tar -C $(LUCENE)-orig -xvf -

from-orig: $(LUCENE)-orig
	mkdir -p $(LUCENE)
	tar -C $(LUCENE)-orig -cf - . | tar -C $(LUCENE) -xvf -

lucene:
	rm -f $(LUCENE_JAR)
	$(MAKE) $(LUCENE_JAR)

$(LUCENE_JAR): $(LUCENE)
	cd $(LUCENE); $(ANT) -Dversion=$(LUCENE_VER)

$(ANALYZERS_JAR): $(LUCENE_JAR)
	cd $(MODULES); $(ANT) -Dversion=$(LUCENE_VER) compile

$(MEMORY_JAR): $(LUCENE_JAR)
	cd $(LUCENE)/contrib/memory; $(ANT) -Dversion=$(LUCENE_VER)

$(HIGHLIGHTER_JAR): $(LUCENE_JAR)
	cd $(LUCENE)/contrib/highlighter; $(ANT) -Dversion=$(LUCENE_VER)

$(QUERIES_JAR): $(LUCENE_JAR)
	cd $(LUCENE)/contrib/queries; $(ANT) -Dversion=$(LUCENE_VER)

$(EXTENSIONS_JAR): $(LUCENE_JAR)
	$(ANT) -f extensions.xml -Dlucene.dir=$(LUCENE)

JARS=$(LUCENE_JAR) $(ANALYZERS_JAR) \
     $(MEMORY_JAR) $(HIGHLIGHTER_JAR) $(QUERIES_JAR) \
     $(EXTENSIONS_JAR)

JCCFLAGS?=

jars: $(JARS)


ifneq ($(ICUPKG),)

ICURES= $(MODULES)/analysis/icu/src/resources
RESOURCES=--resources $(ICURES)
ENDIANNESS:=$(shell $(PYTHON) -c "import struct; print(struct.pack('h', 1) == '\000\001' and 'b' or 'l')")

resources: $(ICURES)/org/apache/lucene/analysis/icu/utr30.dat

$(ICURES)/org/apache/lucene/analysis/icu/utr30.dat: $(ICURES)/org/apache/lucene/analysis/icu/utr30.nrm
	rm -f $@
	cd $(dir $<); $(ICUPKG) --type $(ENDIANNESS) --add $(notdir $<) new $(notdir $@)

else

RESOURCES=

resources:
	@echo ICU not installed

endif

GENERATE=$(JCC) $(foreach jar,$(JARS),--jar $(jar)) \
           $(JCCFLAGS) \
           --package java.lang java.lang.System \
                               java.lang.Runtime \
           --package java.util \
                     java.util.Arrays \
                     java.text.SimpleDateFormat \
                     java.text.DecimalFormat \
                     java.text.Collator \
           --package java.io java.io.StringReader \
                             java.io.InputStreamReader \
                             java.io.FileInputStream \
           --exclude org.apache.lucene.queryParser.Token \
           --exclude org.apache.lucene.queryParser.TokenMgrError \
           --exclude org.apache.lucene.queryParser.QueryParserTokenManager \
           --exclude org.apache.lucene.queryParser.ParseException \
           --exclude org.apache.lucene.search.regex.JakartaRegexpCapabilities \
           --exclude org.apache.regexp.RegexpTunnel \
           --python lucene \
           --mapping org.apache.lucene.document.Document 'get:(Ljava/lang/String;)Ljava/lang/String;' \
           --mapping java.util.Properties 'getProperty:(Ljava/lang/String;)Ljava/lang/String;' \
           --sequence java.util.AbstractList 'size:()I' 'get:(I)Ljava/lang/Object;' \
           --rename org.apache.lucene.search.highlight.SpanScorer=HighlighterSpanScorer \
           --version $(LUCENE_VER) \
           --module python/collections.py \
           --module python/ICUNormalizer2Filter.py \
           --module python/ICUFoldingFilter.py \
           --module python/ICUTransformFilter.py \
           $(RESOURCES) \
           --files $(NUM_FILES)

generate: jars
	$(GENERATE)

compile: jars
	$(GENERATE) --build $(DEBUG_OPT)

install: jars
	$(GENERATE) --install $(DEBUG_OPT) $(INSTALL_OPT)

bdist: jars
	$(GENERATE) --bdist

wininst: jars
	$(GENERATE) --wininst

all: sources jars resources compile
	@echo build of $(PYLUCENE_LIB) complete

clean:
	if test -f $(LUCENE)/build.xml; then cd $(LUCENE); $(ANT) clean; fi
	rm -rf build

realclean:
	rm -rf $(LUCENE) build samples/LuceneInAction/index

OS=$(shell uname)
BUILD_TEST:=$(PYLUCENE)/build/test

ifeq ($(findstring CYGWIN,$(OS)),CYGWIN)
  BUILD_TEST:=`cygpath -aw $(BUILD_TEST)`
else
  ifeq ($(findstring MINGW,$(OS)),MINGW)
    BUILD_TEST:=`$(PYTHON) -c "import os, sys; print os.path.normpath(sys.argv[1]).replace(chr(92), chr(92)*2)" $(BUILD_TEST)`
  endif
endif

install-test:
	mkdir -p $(BUILD_TEST)
	PYTHONPATH=$(BUILD_TEST) $(GENERATE) --install $(DEBUG_OPT) --install-dir $(BUILD_TEST)

samples/LuceneInAction/index:
	cd samples/LuceneInAction; PYTHONPATH=$(BUILD_TEST) $(PYTHON) index.py

test: install-test samples/LuceneInAction/index
	find test -name 'test_*.py' | PYTHONPATH=$(BUILD_TEST) xargs -t -n 1 $(PYTHON)
	ls samples/LuceneInAction/*Test.py | PYTHONPATH=$(BUILD_TEST) xargs -t -n 1 $(PYTHON)
	PYTHONPATH=$(BUILD_TEST) $(PYTHON) samples/LuceneInAction/AnalyzerDemo.py
	PYTHONPATH=$(BUILD_TEST) $(PYTHON) samples/LuceneInAction/AnalyzerUtils.py
	PYTHONPATH=$(BUILD_TEST) $(PYTHON) samples/LuceneInAction/BooksLikeThis.py
	PYTHONPATH=$(BUILD_TEST) $(PYTHON) samples/LuceneInAction/Explainer.py samples/LuceneInAction/index programming
	PYTHONPATH=$(BUILD_TEST) $(PYTHON) samples/LuceneInAction/HighlightIt.py
	PYTHONPATH=$(BUILD_TEST) $(PYTHON) samples/LuceneInAction/SortingExample.py


ARCHIVE=pylucene-$(VERSION)-src.tar.gz
SITE=../site/build/site/en

distrib:
	mkdir -p distrib
	svn export . distrib/pylucene-$(VERSION)
	tar -cf - --exclude build $(LUCENE) | tar -C distrib/pylucene-$(VERSION) -xvf -
	mkdir distrib/pylucene-$(VERSION)/doc
	tar -C $(SITE) -cf - . | tar -C distrib/pylucene-$(VERSION)/doc -xvf -
	cd distrib; tar -cvzf $(ARCHIVE) pylucene-$(VERSION)
	cd distrib; gpg2 --armor --output $(ARCHIVE).asc --detach-sig $(ARCHIVE)
	cd distrib; openssl md5 < $(ARCHIVE) > $(ARCHIVE).md5

stage:
	cd distrib; scp -p $(ARCHIVE) $(ARCHIVE).asc $(ARCHIVE).md5 \
                           people.apache.org:public_html/staging_area

release:
	cd distrib; scp -p $(ARCHIVE) $(ARCHIVE).asc $(ARCHIVE).md5 \
                           people.apache.org:/www/www.apache.org/dist/lucene/pylucene

print-%:
	@echo $* = $($*)

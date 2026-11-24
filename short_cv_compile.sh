#!/bin/bash

# Compile CV pdf
OUTPUT_DIR="./output/latex"
OUTPUT_NAME="short_cv_bgetraer"
INPUT_FILE="src/short_cv_template.tex"
mkdir -p $OUTPUT_DIR
echo -n "Compiling cv in lualatex..."
lualatex --output-directory=$OUTPUT_DIR --jobname=$OUTPUT_NAME $INPUT_FILE > output/short_cv_compile.log
lualatex --output-directory=$OUTPUT_DIR --jobname=$OUTPUT_NAME $INPUT_FILE > output/short_cv_compile.log
echo " Done"

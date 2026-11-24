#!/bin/bash

# Compile CV pdf
OUTPUT_DIR="./output/latex"
OUTPUT_NAME="cv_bgetraer"
INPUT_FILE="src/cv_template.tex"
mkdir -p $OUTPUT_DIR
echo -n "Compiling cv in lualatex..."
lualatex --output-directory=$OUTPUT_DIR --jobname=$OUTPUT_NAME $INPUT_FILE > output/cv_compile.log
lualatex --output-directory=$OUTPUT_DIR --jobname=$OUTPUT_NAME $INPUT_FILE > output/cv_compile.log
echo " Done"


# Compile CV HTML
OUTPUT_DIR="./output/html"
OUTPUT_NAME="cv.html"
PARSER_FILE="src/cv_html.lua"
DATA_FILE="data/cv_data.json"
echo -n "Parsing cv to html..."
luatex $PARSER_FILE $DATA_FILE > "${OUTPUT_DIR}/${OUTPUT_NAME}"
echo " Done"

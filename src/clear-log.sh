#!/bin/bash

FILES=$(ls *.log)
rm -f $FILES
touch $FILES

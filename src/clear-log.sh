#!/bin/bash

FILES=$(ls *.log)
for f in ${FILES[@]}
do
	echo "" > $f
done

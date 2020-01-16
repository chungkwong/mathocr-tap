#!/bin/bash

source prepare.sh
python -u ./train_nmt.py $LOG_DIRECTORY ../model/ 2>&1 | tee $LOG_DIRECTORY/log.txt


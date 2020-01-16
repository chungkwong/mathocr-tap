#!/bin/bash

source prepare.sh
python -u ./train_nmt_weightnoise.py $LOG_DIRECTORY ../model/ 2>&1 | tee $LOG_DIRECTORY/log.txt


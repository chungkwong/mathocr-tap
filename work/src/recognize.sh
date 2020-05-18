#!/bin/bash

if [ $# = 0 ]; then
	echo './recognize.sh image...'
else
	TMP_DIRECTORY=`mktemp`
	rm $TMP_DIRECTORY
	mkdir -p $TMP_DIRECTORY/on-ascii
	if  command -v nvcc >/dev/null 2>&1;then
		echo "Cuda detected";
		export THEANO_FLAGS=device=cuda,floatX=float32;
	elif command -v clinfo >/dev/null 2>&1;then
		echo "OpenCL detected";
		export THEANO_FLAGS=device=cuda,floatX=float32;
	else
		echo "Using CPU";
		export THEANO_FLAGS=device=cpu,floatX=float32;
	fi
	for IMAGE in $@ ; do
		BASENAME=`basename ${IMAGE}`
		echo "${BASENAME%.*}	1 + 1 = 2">>$TMP_DIRECTORY/caption.txt
	done
	java -jar mathocr-myscript-1.1.jar -o $TMP_DIRECTORY/on-ascii -ascii $@
	#python gen_ascii_pkl.py $TMP_DIRECTORY
	python3 -u ./translate.py -k 10 \
		../data/dictionary.txt \
		../data/grammar.txt \
		$TMP_DIRECTORY/ \
		$TMP_DIRECTORY/test_decode_result.txt \
		$TMP_DIRECTORY/test.wer \
		../model/*.npz
	cat $TMP_DIRECTORY/test_decode_result.txt
	rm -rf $TMP_DIRECTORY
fi


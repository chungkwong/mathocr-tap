#!/bin/bash

if ! [ -d ../data/test ] ; then
	if test `whoami` = 'aistudio' ; then
		mkdir /home/aistudio/external-libraries
		conda install theano pygpu python=2.7 pandoc --prefix /home/aistudio/external-libraries
		ln -s /home/aistudio/external-libraries/bin/x86_64-conda_cos6-linux-gnu-g++ /home/aistudio/external-libraries/bin/g++
		ln -s /usr/lib/x86_64-linux-gnu/libcudnn.so /home/aistudio/external-libraries/x86_64-conda_cos6-linux-gnu/sysroot/lib/libcudnn.so;
		mkdir ../data ../model ../log ../lm
		du -hs /home/aistudio/external-libraries
	fi
	echo 'Preparing data ...'
	tar -xJf ../../data/offline.tar.xz -C ../data ;
	./gen.sh ;
	tar -xJf ../../data/test_symlg.tar.xz -C ../data ;
fi

LOG_DIRECTORY=`pwd`/../log/`date +%Y%m%d-%H%M%S`
mkdir -p $LOG_DIRECTORY
mkdir -p ../model
if test `whoami` = 'aistudio';then
	source activate /home/aistudio/external-libraries;
	export THEANO_FLAGS=device=cuda,floatX=float32;
	export CPLUS_INCLUDE_PATH=/home/aistudio/external-libraries/x86_64-conda_cos6-linux-gnu/include/c++/7.3.0:/home/aistudio/external-libraries/x86_64-conda_cos6-linux-gnu/sysroot/usr/include/:/usr/include:/usr/local/cuda/include;
	export C_INCLUDE_PATH=/home/aistudio/external-libraries/x86_64-conda_cos6-linux-gnu/sysroot/usr/include/:/usr/include:/usr/local/cuda/include;
	python3 -m pip install bs4 lxml numpy
elif command -v nvcc >/dev/null 2>&1;then
	echo "Cuda detected";
	export THEANO_FLAGS=device=cuda,floatX=float32;
elif command -v clinfo >/dev/null 2>&1;then
	echo "OpenCL detected";
	export THEANO_FLAGS=device=opencl0:0,floatX=float32;
else
	echo "Using CPU";
	export THEANO_FLAGS=device=cpu,floatX=float32;
fi



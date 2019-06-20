#==========================================================================
# Makefile
#==========================================================================
# @brief: A makefile the compiles and runs the digitrec program
#
# @desc: 1. Enter "make" to compile & execute the digitrec program
#        2. Enter "make clean" to clean up the directory (before submission)

SRC = $(wildcard *.cpp)
OBJ = $(wildcard *.o)

# Extract Vivado HLS include path
VHLS_PATH := $(dir $(shell which vivado_hls))..
VHLS_INC ?= ${VHLS_PATH}/include

# Specify compilation flags
#-DK_CONST=3
CFLAGS = -std=c++11 -g -I${VHLS_INC}

# Compile & run implementation
os_pfb: $(SRC)
	g++ ${CFLAGS} $(SRC) -o $@.bin

run: os_pfb.bin
	./$<

# Clean up the directory before submission
clean:
	@echo "Clean up output files"
	rm -rf *.bin vivado_hls.log *~

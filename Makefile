# makefile for standard compilation
.PHONY : parser all clean

parser:
	$(MAKE) -C sim parser

all:
	$(MAKE) -C sim all

clean:
	echo "why?"

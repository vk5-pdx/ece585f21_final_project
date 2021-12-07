# makefile for standard compilation
.PHONY : queue parser all clean

queue:
	$(MAKE) -C sim queue

parser:
	$(MAKE) -C sim parser

all:
	$(MAKE) -C sim all

gui:
	$(MAKE) -C sim gui

clean:
	echo "why?"

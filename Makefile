# makefile for standard compilation
.PHONY : queue parser all clean

queue:
	$(MAKE) -C sim queue

parser:
	$(MAKE) -C sim parser

debug:
	$(MAKE) -C sim debug

all:
	$(MAKE) -C sim all

gui:
	$(MAKE) -C sim gui

clean:
	echo "why?"

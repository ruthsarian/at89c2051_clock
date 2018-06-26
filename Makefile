SDCC ?= sdcc
STCCODESIZE ?= 2048
SDCCOPTS ?= -mmcs51 --code-size $(STCCODESIZE)
FLASHFILE ?= main.hex

all: main

build/%.rel: src/%.c src/%.h
	mkdir -p $(dir $@)
	$(SDCC) $(SDCCOPTS) -o $@ -c $<

main: $(OBJ)
	$(SDCC) -o build/ src/$@.c $(SDCCOPTS) $^
	cp build/$@.ihx clock.hex

clean:
	rm -f *.ihx *.hex *.bin
	rm -rf build/*

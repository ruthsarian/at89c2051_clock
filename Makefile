SDCC = sdcc
STCCODESIZE = 2048
SDCCOPTS = -mmcs51 --opt-code-size --code-size $(STCCODESIZE)
TARGET = main
BUILDDIR = build

ifdef OS
   RM = del /Q
   CP = copy
   FixPath = $(subst /,\,$1)
else
   ifeq ($(shell uname), Linux)
      RM = rm -f
      CP = cp
      FixPath = $1
   endif
endif

all: $(BUILDDIR) $(TARGET)

$(BUILDDIR):
        @mkdir $@

$(TARGET): src/$(TARGET).c
        $(SDCC) -o build/ src/$@.c $(SDCCOPTS)
        @$(CP) $(call FixPath,build/$@.ihx) clock.hex

clean:
        @$(RM) $(call FixPath,build/*)
        @rmdir $(BUILDDIR)

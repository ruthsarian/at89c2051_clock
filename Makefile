SDCC = sdcc
STCCODESIZE = 2048
SDCCOPTS = -mmcs51 --opt-code-size --code-size $(STCCODESIZE)
TARGET = main
BUILDDIR = build

ifdef OS
	RM = del /Q
	CP = copy
	DIRSEP = \$
	RMDIR = rmdir
else
	ifeq ($(shell uname), Linux)
		RM = rm -f
		CP = cp
		DIRSEP = /
		RMDIR = rmdir
	endif
endif

all: $(BUILDDIR) $(TARGET)

$(BUILDDIR):
	@mkdir $@

$(TARGET): src/$(TARGET).c
	$(SDCC) -o build/ src/$@.c $(SDCCOPTS)
	@$(CP) $(BUILDDIR)$(DIRSEP)$@.ihx clock.hex

clean:
	@$(RM) "$(BUILDDIR)$(DIRSEP)*"
	@$(RMDIR) "$(BUILDDIR)"

CC=diet gcc
CFLAGS=-mpreferred-stack-boundary=2 -malign-jumps=0 -malign-loops=0 -malign-functions=0 -Os -march=i386 -mcpu=i386
LDFLAGS=-s
CFLAGS+=-fomit-frame-pointer -Wl,--gc-sections

OBJS=bitcheck

all:	$(OBJS)

%:	%.c
	$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $<
	strip -R .comment -R .note $@
	objdump -h $@ | grep -q '\.data[ ]*00000000' && strip -R .data $@ || true
	sstrip $@

%-debug:	%.c
	$(CC) $(LDFLAGS) $(CFLAGS) -DDEBUG -o $@ $<
	strip -R .comment -R .note $@
	objdump -h $@ | grep -q '\.data[ ]*00000000' && strip -R .data $@ || true

clean:
	@rm -f *.[ao] *~ core
	@rm -f $(OBJS)

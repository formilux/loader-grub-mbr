#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/stat.h>

/*
 * usage:
 * $0 <device> <offset>  -t <mask> | -l <mask> <value> | -e <mask> <value> |
 *                       -g <mask> <value>
 *                       (&mask!=0, &mask<value, &mask==value, &mask>value)
 *
 * $0 <device> <offset>  -s <mask> <value> | -x <mask> | -a <mask> | -o <mask>
 *                   (set <value> to <mask> bits, xor mask, and mask, or mask)
 *
 *
 */

char usage_msg[] =
"Bitcheck: test/set bits on a file/device          [2003/09/30 - Willy Tarreau]\n"
"Usage: bitcheck <device> <offset> { -r | -t <mask> | -[leg] <mask> <value> | \n"
"       -s <mask> <value> | -[aox] <mask> }\n"
"offset/mask/value may be set in hexadecimal with a '0x' prefix.\n"
"\n";

enum {
    OP_R=0,	// -
    OP_T,	// mask
    OP_L,	// mask val
    OP_E,	// mask val
    OP_G,	// mask val
    OP_S,	// mask val
    OP_A,	// mask
    OP_O,	// mask
    OP_X,	// mask
};

const char ops[][2] = { "-r", "-t", "-l", "-e", "-g", "-s", "-a", "-o", "-x", "\0" };
static char out[5] = "0x00\n";

usage() {
    write(2, usage_msg, sizeof(usage_msg));
    exit(1);
}

error(char *msg) {
    write(2, "Error: ", 7);
    write(2, msg, strlen(msg));
    write(2, " failed\n", 8);
    exit(2);
}

static inline char i2h(int i) {
    i &= 0xF;
    return (i < 10) ? '0' + i : 'A' - 10 + i;
}

main(int argc, char **argv) {
    int fd;
    loff_t offset;
    unsigned char bits, mask, value;
    char *endp;
    int op;

    if (argc < 4)
	usage();

    offset = strtoul(argv[2], &endp, 0);
    if (*endp)
	usage();

    for (op = 0; *ops[op]; op++)
	if (!strncmp(ops[op], argv[3], 2))
	    break;

    if (!*ops[op])
	usage();

    if (op >= OP_T) {
	if (argc < 5)
	    usage();
	else {
	    mask = strtoul(argv[4], &endp, 0);
	    if (*endp)
		usage();
	}
    }

    if (op >= OP_L && op <= OP_S) {
	if (argc < 6)
	    usage();
	else {
	    value = strtoul(argv[5], &endp, 0);
	    if (*endp)
		usage();
	}
    }

    if ((fd = open(argv[1], O_RDWR)) < 0) {
	error("open");
    }

    if (lseek(fd, offset, SEEK_SET) == (off_t)-1) {
	error("seek");
    }

    if (read(fd, &bits, 1) < 1) {
	error("read");
    }

    if (op < OP_S)
	close(fd);

    switch(op) {
    case OP_R:
	out[2] = i2h(bits >> 4);
	out[3] = i2h(bits);
	write(1, out, sizeof(out));
	return 0;
    case OP_T:
	return ! ((bits & mask) != 0);
    case OP_L:
	return ! ((bits & mask) < value);
    case OP_E:
	return ! ((bits & mask) == value);
    case OP_G:
	return ! ((bits & mask) > value);
    case OP_S:
	bits = (bits & ~mask) | (value & mask);
	break;
    case OP_A:
	bits &= mask;
	break;
    case OP_O:
	bits |= mask;
	break;
    case OP_X:
	bits ^= mask;
	break;
    }
    
    if (lseek(fd, offset, SEEK_SET) == (off_t)-1) {
	error("seek");
    }

    if (write(fd, &bits, 1) < 1) {
	error("write");
    }

    close(fd);
    return 0;
}

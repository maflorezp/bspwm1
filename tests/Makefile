CFLAGS  += -std=c99 -D_POSIX_C_SOURCE=200809L -pedantic -Wall -Wextra

all: test_window test_window_wl
all: send_moveresize

test_window: test_window.c
	$(CC) $(CFLAGS) -o $@ $< -lxcb -lxcb-icccm

test_window_wl: test_window_wl.c xdg-shell-protocol.c xdg-shell-client-protocol.h
	$(CC) $(CFLAGS) -o $@ test_window_wl.c xdg-shell-protocol.c -lwayland-client

send_moveresize: send_moveresize.c
	$(CC) $(CFLAGS) -o $@ $< -lxcb

clean:
	$(RM) test_window test_window_wl test_color test_magnet send_moveresize test_edge_zone *.o

.PHONY: all clean

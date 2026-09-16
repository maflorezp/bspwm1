CFLAGS  += -std=c99 -D_POSIX_C_SOURCE=200809L -pedantic -Wall -Wextra

all: test_window test_window_wl

all: test_magnet

test_window: test_window.c
	$(CC) $(CFLAGS) -o $@ $< -lxcb -lxcb-icccm

test_window_wl: test_window_wl.c xdg-shell-protocol.c xdg-shell-client-protocol.h
	$(CC) $(CFLAGS) -o $@ test_window_wl.c xdg-shell-protocol.c -lwayland-client

test_magnet: test_magnet.c ../src/magnet.c ../src/magnet.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_magnet.c ../src/magnet.c

clean:
	$(RM) test_window test_window_wl test_color test_magnet send_moveresize test_edge_zone *.o

.PHONY: all clean

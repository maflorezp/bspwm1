CFLAGS  += -std=c99 -D_POSIX_C_SOURCE=200809L -pedantic -Wall -Wextra

all: test_window test_window_wl
all: test_color
all: test_magnet
all: test_edge_zone
all: send_moveresize
all: test_rule_match

test_window: test_window.c
	$(CC) $(CFLAGS) -o $@ $< -lxcb -lxcb-icccm

test_window_wl: test_window_wl.c xdg-shell-protocol.c xdg-shell-client-protocol.h
	$(CC) $(CFLAGS) -o $@ test_window_wl.c xdg-shell-protocol.c -lwayland-client

test_color: test_color.c ../src/color.c ../src/color.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_color.c ../src/color.c

test_magnet: test_magnet.c ../src/magnet.c ../src/magnet.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_magnet.c ../src/magnet.c

test_edge_zone: test_edge_zone.c ../src/edge_zone.c ../src/edge_zone.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_edge_zone.c ../src/edge_zone.c

send_moveresize: send_moveresize.c
	$(CC) $(CFLAGS) -o $@ $< -lxcb

test_rule_match: test_rule_match.c ../src/rule_match.c ../src/rule_match.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_rule_match.c ../src/rule_match.c

clean:
	$(RM) test_window test_window_wl test_color test_magnet send_moveresize test_edge_zone test_rule_match *.o

.PHONY: all clean

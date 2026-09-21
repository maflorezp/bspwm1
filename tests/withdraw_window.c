/* Withdraws a window on behalf of its client: unmaps it and sends the
 * synthetic UnmapNotify that ICCCM asks a client to send when it takes a
 * window back to the Withdrawn state. That is what a tray application does
 * when it hides to the system tray, and what a toolkit does when it closes a
 * dialog it means to reuse: the window survives, unmapped, and the window
 * manager is expected to stop managing it.
 *
 * Usage: withdraw_window <window-id>
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xcb/xcb.h>

int main(int argc, char **argv)
{
	if (argc < 2) {
		fprintf(stderr, "Usage: %s <window-id>\n", argv[0]);
		return EXIT_FAILURE;
	}

	xcb_window_t win = (xcb_window_t) strtoul(argv[1], NULL, 0);
	if (win == XCB_NONE) {
		fprintf(stderr, "Not a window id: %s\n", argv[1]);
		return EXIT_FAILURE;
	}

	xcb_connection_t *dpy = xcb_connect(NULL, NULL);
	if (xcb_connection_has_error(dpy)) {
		fprintf(stderr, "Can't connect to X.\n");
		return EXIT_FAILURE;
	}

	xcb_screen_t *screen = xcb_setup_roots_iterator(xcb_get_setup(dpy)).data;
	if (screen == NULL) {
		fprintf(stderr, "Can't get current screen.\n");
		xcb_disconnect(dpy);
		return EXIT_FAILURE;
	}

	xcb_void_cookie_t ck = xcb_unmap_window_checked(dpy, win);
	xcb_generic_error_t *err = xcb_request_check(dpy, ck);
	if (err != NULL) {
		fprintf(stderr, "Can't unmap 0x%08X: error code %u.\n", win, err->error_code);
		free(err);
		xcb_disconnect(dpy);
		return EXIT_FAILURE;
	}

	/* ICCCM 4.1.4: the client also sends a synthetic UnmapNotify to the
	 * root, so a window manager that never saw the real one still learns
	 * about the withdrawal. */
	xcb_unmap_notify_event_t e;
	memset(&e, 0, sizeof(e));
	e.response_type = XCB_UNMAP_NOTIFY;
	e.event = screen->root;
	e.window = win;
	e.from_configure = 0;
	ck = xcb_send_event_checked(dpy, false, screen->root,
	                            XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY,
	                            (char *) &e);
	err = xcb_request_check(dpy, ck);
	if (err != NULL) {
		fprintf(stderr, "Can't send the synthetic UnmapNotify: error code %u.\n", err->error_code);
		free(err);
		xcb_disconnect(dpy);
		return EXIT_FAILURE;
	}

	xcb_disconnect(dpy);
	return EXIT_SUCCESS;
}

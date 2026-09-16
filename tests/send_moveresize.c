/* Send a _NET_WM_MOVERESIZE client message for a window, as a client that
 * draws its own title bar does to ask the window manager for a drag.
 * Usage: send_moveresize WINDOW X Y DIRECTION BUTTON */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xcb/xcb.h>

int main(int argc, char **argv)
{
	if (argc != 6) {
		fprintf(stderr, "usage: %s WINDOW X Y DIRECTION BUTTON\n", argv[0]);
		return 2;
	}
	xcb_connection_t *dpy = xcb_connect(NULL, NULL);
	if (xcb_connection_has_error(dpy))
		return 1;
	xcb_screen_t *screen = xcb_setup_roots_iterator(xcb_get_setup(dpy)).data;
	const char *name = "_NET_WM_MOVERESIZE";
	xcb_intern_atom_reply_t *atom = xcb_intern_atom_reply(dpy,
		xcb_intern_atom(dpy, 0, strlen(name), name), NULL);
	if (atom == NULL)
		return 1;

	xcb_client_message_event_t ev;
	memset(&ev, 0, sizeof(ev));
	ev.response_type = XCB_CLIENT_MESSAGE;
	ev.format = 32;
	ev.window = strtoul(argv[1], NULL, 0);
	ev.type = atom->atom;
	ev.data.data32[0] = strtoul(argv[2], NULL, 0);
	ev.data.data32[1] = strtoul(argv[3], NULL, 0);
	ev.data.data32[2] = strtoul(argv[4], NULL, 0);
	ev.data.data32[3] = strtoul(argv[5], NULL, 0);
	ev.data.data32[4] = 1; /* source: a normal application */
	free(atom);

	xcb_send_event(dpy, 0, screen->root,
		XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY,
		(const char *) &ev);
	/* Wait for a reply, so the server has handled the event before the
	 * connection goes away. */
	free(xcb_get_input_focus_reply(dpy, xcb_get_input_focus(dpy), NULL));
	xcb_disconnect(dpy);
	return 0;
}

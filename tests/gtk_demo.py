#!/usr/bin/env python3
"""
PyGObject GTK3 Demo — Simple Note Taker
Showcases: Window, Box layout, Toolbar, TextView, Dialogs, Signals
"""

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib
import datetime


class NoteApp(Gtk.Window):
    """
    Main application window.
    Inherits from Gtk.Window — the top-level container for our UI.
    """

    def __init__(self):
        super().__init__(title="📝 PyGObject Note Taker")
        self.set_default_size(600, 450)
        self.set_border_width(0)

        # Track whether the note has unsaved changes
        self.is_modified = False

        # ── Connect the window's "delete-event" signal ──────────────────────
        # Signals are GTK's event system. Here we intercept the close button.
        self.connect("delete-event", self.on_quit)

        # ── Build the UI ─────────────────────────────────────────────────────
        self._build_ui()

        # Show every widget inside the window
        self.show_all()

    # ── UI Construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        """Assemble all widgets inside a vertical Box container."""

        # Gtk.Box arranges children either horizontally or vertically.
        # VERTICAL means widgets stack top-to-bottom.
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(vbox)

        # ── Header bar ───────────────────────────────────────────────────────
        header = Gtk.HeaderBar()
        header.set_show_close_button(True)
        header.props.title = "Note Taker"
        header.props.subtitle = "PyGObject Demo"
        self.set_titlebar(header)

        # Buttons in the header bar
        new_btn = Gtk.Button(label="New")
        new_btn.connect("clicked", self.on_new)
        header.pack_start(new_btn)

        save_btn = Gtk.Button(label="Save")
        save_btn.get_style_context().add_class("suggested-action")  # makes it blue
        save_btn.connect("clicked", self.on_save)
        header.pack_end(save_btn)

        about_btn = Gtk.Button(label="About")
        about_btn.connect("clicked", self.on_about)
        header.pack_end(about_btn)

        # ── Toolbar with formatting helpers ──────────────────────────────────
        toolbar = Gtk.Toolbar()
        toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR)
        vbox.pack_start(toolbar, False, False, 0)

        # Timestamp button
        ts_btn = Gtk.ToolButton()
        ts_btn.set_label("Insert Timestamp")
        ts_btn.set_icon_name("appointment-new")
        ts_btn.connect("clicked", self.on_insert_timestamp)
        toolbar.insert(ts_btn, 0)

        toolbar.insert(Gtk.SeparatorToolItem(), 1)

        # Clear button
        clear_btn = Gtk.ToolButton()
        clear_btn.set_label("Clear")
        clear_btn.set_icon_name("edit-clear")
        clear_btn.connect("clicked", self.on_clear)
        toolbar.insert(clear_btn, 2)

        # ── Scrollable text area ──────────────────────────────────────────────
        # Gtk.ScrolledWindow adds scroll bars to any widget that needs them.
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        vbox.pack_start(scroll, True, True, 0)   # expand & fill remaining space

        # Gtk.TextView is a multi-line text editor widget.
        self.textview = Gtk.TextView()
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.textview.set_left_margin(12)
        self.textview.set_right_margin(12)
        self.textview.set_top_margin(8)
        self.textview.set_bottom_margin(8)

        # Every TextView has a TextBuffer that holds the actual text.
        self.buffer = self.textview.get_buffer()
        self.buffer.set_text("Welcome to the PyGObject Note Taker!\n\nStart typing your note here...\n")

        # Connect the "changed" signal on the buffer to track modifications
        self.buffer.connect("changed", self.on_text_changed)

        scroll.add(self.textview)

        # ── Status bar ───────────────────────────────────────────────────────
        self.statusbar = Gtk.Statusbar()
        self.status_ctx = self.statusbar.get_context_id("main")
        vbox.pack_start(self.statusbar, False, False, 0)
        self._set_status("Ready  ·  PyGObject + GTK 3")

    # ── Signal Handlers ───────────────────────────────────────────────────────
    # These are plain Python methods; GTK calls them when events occur.

    def on_text_changed(self, buffer):
        """Called every time the text buffer content changes."""
        self.is_modified = True
        count = buffer.get_char_count()
        self._set_status(f"Modified  ·  {count} characters")

    def on_new(self, widget):
        """Clear the editor after confirming with the user (if modified)."""
        if self.is_modified:
            if not self._confirm_discard():
                return
        self.buffer.set_text("")
        self.is_modified = False
        self._set_status("New note  ·  0 characters")

    def on_save(self, widget):
        """Open a file chooser and save the note to disk."""
        dialog = Gtk.FileChooserDialog(
            title="Save Note",
            parent=self,
            action=Gtk.FileChooserAction.SAVE,
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_SAVE,   Gtk.ResponseType.OK,
        )
        dialog.set_do_overwrite_confirmation(True)
        dialog.set_current_name("note.txt")

        # GTK dialogs return a response code when dismissed
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            path = dialog.get_filename()
            start, end = self.buffer.get_bounds()
            text = self.buffer.get_text(start, end, True)
            with open(path, "w") as f:
                f.write(text)
            self.is_modified = False
            self._set_status(f"Saved → {path}")
        dialog.destroy()

    def on_insert_timestamp(self, widget):
        """Insert the current date/time at the cursor position."""
        ts = datetime.datetime.now().strftime("\n── %A, %d %B %Y  %H:%M:%S ──\n")
        self.buffer.insert_at_cursor(ts)

    def on_clear(self, widget):
        """Clear all text after confirming."""
        if self._confirm_discard():
            self.buffer.set_text("")

    def on_about(self, widget):
        """Show a standard About dialog."""
        dialog = Gtk.AboutDialog(transient_for=self, modal=True)
        dialog.set_program_name("PyGObject Note Taker")
        dialog.set_version("1.0")
        dialog.set_comments(
            "A simple demo app showing PyGObject + GTK 3 concepts:\n"
            "• Windows & HeaderBar\n"
            "• Box layout containers\n"
            "• Toolbar & ToolButton\n"
            "• TextView & TextBuffer\n"
            "• Signals & event handlers\n"
            "• Dialogs (File, About, Message)"
        )
        dialog.set_license_type(Gtk.License.MIT_X11)
        dialog.run()
        dialog.destroy()

    def on_quit(self, widget, event):
        """Intercept the window-close button. Ask to discard if modified."""
        if self.is_modified:
            if not self._confirm_discard():
                return True   # returning True prevents the window from closing
        Gtk.main_quit()

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _confirm_discard(self) -> bool:
        """Show a yes/no message dialog. Returns True if user says Discard."""
        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.NONE,
            text="Discard unsaved changes?",
        )
        dialog.format_secondary_text("Your note has unsaved changes. Discard them?")
        dialog.add_buttons(
            "Cancel",  Gtk.ResponseType.CANCEL,
            "Discard", Gtk.ResponseType.OK,
        )
        response = dialog.run()
        dialog.destroy()
        return response == Gtk.ResponseType.OK

    def _set_status(self, message: str):
        self.statusbar.pop(self.status_ctx)
        self.statusbar.push(self.status_ctx, f"  {message}")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    app = NoteApp()
    Gtk.main()          # starts the GTK event loop
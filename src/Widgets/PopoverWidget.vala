/*
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 */

public class Password.Widgets.PopoverWidget : Gtk.Stack {

    const string SEARCH_VIEW = "search";
    const string UNLOCK_VIEW = "unlock";
    const string DETAILS_VIEW = "details";

    const uint CLIPBOARD_EXPIRY_MS = 1000 * 5;

    string? current_clipboard_val = null;
    uint clipboard_expiry_timeout;

    string? selected_path = null;

    int _selected_search_result = -1;
    int selected_search_result {
        get {
            return _selected_search_result;
        }
        set {
            if (_selected_search_result >= 0) {
                get_nth_search_item (_selected_search_result).set_state_flags (Gtk.StateFlags.NORMAL, true);
            }
            _selected_search_result = value;
            if (_selected_search_result >= 0) {
                get_nth_search_item (_selected_search_result).set_state_flags (Gtk.StateFlags.SELECTED, true);
            }
        }
    }

    Gtk.CssProvider css_provider;

    Gtk.Entry password_entry;
    Gtk.Label unlock_error_label;

    Gtk.Entry search_entry;
    Gtk.Grid search_list;

    Gtk.Grid values_list;
    Gtk.Label title_label;

    Password.Services.Watcher watcher;

    construct {
        watcher = new Password.Services.Watcher (Environment.get_home_dir () + "/.password-store");

        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("de/tombeckmann/password-indicator/indicator.css");

        add_named (build_search_grid (), SEARCH_VIEW);
        add_named (build_unlock_grid (), UNLOCK_VIEW);
        add_named (build_details_grid (), DETAILS_VIEW);

        visible_child_name = SEARCH_VIEW;
        transition_type = Gtk.StackTransitionType.SLIDE_LEFT;
        vhomogeneous = false;
    }

    public override bool key_press_event (Gdk.EventKey event) {
        if (event.keyval == Gdk.Key.Left && (event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
            reset_view ();
            focused ();
        }
        return true;
    }

    /**
     * Gets the nth visible item from the search list
     */
    Wingpanel.Widgets.Button? get_nth_search_item (uint n) {
        var children = search_list.get_children ();

        for (int i = (int) children.length () - 1; i >= 0; i--) {
            if (!children.nth_data (i).visible) {
                continue;
            }
            if (n-- == 0) {
                return (Wingpanel.Widgets.Button) children.nth_data (i);
            }
        }
        return null;
    }

    uint get_n_search_items () {
        var children = search_list.get_children ();
        uint n = 0;

        for (int i = (int) children.length () - 1; i >= 0; i--) {
            if (children.nth_data (i).visible) {
                n++;
            }
        }
        return n;
    }

    Gtk.Grid build_grid () {
        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;

        var style_context = grid.get_style_context ();
        style_context.add_class ("password-view");
        style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        return grid;
    }

    Gtk.Widget build_details_grid () {
        var grid = build_grid ();

        title_label = new Gtk.Label ("");
        title_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        title_label.get_style_context ().add_class ("h3");
        title_label.margin_top = title_label.margin_bottom = 12;
        title_label.hexpand = true;
        title_label.halign = Gtk.Align.START;

        values_list = new Gtk.Grid ();
        values_list.row_spacing = 2;
        values_list.column_spacing = 12;
        values_list.hexpand = true;

        var scroll = new Wingpanel.Widgets.AutomaticScrollBox (null, null);
        scroll.hexpand = true;
        scroll.max_height = 300;
        scroll.margin_bottom = 6;
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add (values_list);

        var back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic", Gtk.IconSize.MENU);
        back_button.margin = 12;
        back_button.clicked.connect (() => {
            visible_child_name = SEARCH_VIEW;
        });

        grid.attach (back_button, 0, 0, 1, 1);
        grid.attach (title_label, 1, 0, 1, 1);
        grid.attach (scroll, 0, 1, 2, 1);

        return grid;
    }

    void populate_details_grid (string path, string file_data) {
        values_list.forall ((element) => values_list.remove (element));

        title_label.label = path;

        var button_padding = Gtk.Border ();

        var i = 0;
        foreach (var row in file_data.split ("\n")) {
            Gtk.Widget key, val;

            string copy_value;

            if (i == 0) {
                key = new Gtk.Label ("Password:");
                val = new InitiallyHiddenLabel (row);
                copy_value = row;
                button_padding = ((Gtk.Button) val).get_child ().get_style_context ().get_padding (Gtk.StateFlags.NORMAL);
            } else {
                var parts = row.split(":", 2);
                if (parts.length < 2) {
                    i++;
                    continue;
                }
                copy_value = parts[1].strip ();
                key = new Gtk.Label (parts[0].strip () + ":");
                val = new Gtk.Label (copy_value);
                print("%i %i %i %i\n", button_padding.top, button_padding.left, button_padding.right, button_padding.bottom);
                ((Gtk.Label) val).xalign = button_padding.left;
                val.margin_top = button_padding.top;
                val.margin_left = button_padding.left;
                val.margin_right = button_padding.right;
                val.margin_bottom = button_padding.bottom;
            }

            key.margin_left = 12;
            key.halign = Gtk.Align.START;

            var style_context = key.get_style_context ();
            style_context.add_class ("password-view-key-label");
            style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            val.halign = Gtk.Align.START;

            var copy = new Gtk.Button.from_icon_name ("edit-copy-symbolic", Gtk.IconSize.MENU);
            copy.margin_right = 6;
            copy.relief = Gtk.ReliefStyle.NONE;

            copy.clicked.connect (() => {
                copy_with_expiry (copy_value);
            });

            values_list.attach (key, 0, i, 1, 1);
            values_list.attach (val, 1, i, 1, 1);
            values_list.attach (copy, 2, i, 1, 1);

            i++;
        }

        values_list.show_all ();
    }

    void copy_with_expiry (string val) {
        if (clipboard_expiry_timeout != 0) {
            Source.remove (clipboard_expiry_timeout);
        }

        clipboard_expiry_timeout = Timeout.add (CLIPBOARD_EXPIRY_MS, () => {
            current_clipboard_val = null;
            clipboard_expiry_timeout = 0;
            return false;
        });

        current_clipboard_val = val;

        var clipboard = Gtk.Clipboard.get_default (Gdk.Display.get_default ());
        var targets = new Gtk.TargetList (null);
        targets.add_text_targets (0);
        var list = Gtk.target_table_new_from_list(targets);
        clipboard.set_with_owner (list,
                                  (clipboard, data, info, ptr) => {
                                      var self = (PopoverWidget) ptr;
                                      if (self.current_clipboard_val != null) {
                                          data.set_text (self.current_clipboard_val, -1);
                                      }
                                  },
                                  (clipboard, ptr) => {},
                                  this);
    }

    Gtk.Widget build_unlock_grid () {
        var grid = build_grid ();

        var locked_icon = new Gtk.Image.from_icon_name ("dialog-password", Gtk.IconSize.DIALOG);
        locked_icon.halign = Gtk.Align.CENTER;
        locked_icon.valign = Gtk.Align.CENTER;
        locked_icon.hexpand = true;

        unlock_error_label = new Gtk.Label ("");
        unlock_error_label.margin_top = unlock_error_label.margin_bottom = 6;
        unlock_error_label.visible = false;
        unlock_error_label.no_show_all = true;

        password_entry = new Gtk.Entry ();
        password_entry.placeholder_text = _("Master Password ...");
        password_entry.caps_lock_warning = true;
        password_entry.visibility = false;
        password_entry.hexpand = true;
        password_entry.halign = Gtk.Align.CENTER;
        password_entry.activate.connect (() => {
            var passphrase = password_entry.text;
            password_entry.sensitive = false;
            password_entry.text = "";
            watcher.decrypt_file.begin(selected_path, passphrase, (obj, res) => {
                password_entry.sensitive = true;
                try {
                    unlock_error_label.visible = false;
                    populate_details_grid (selected_path, watcher.decrypt_file.end (res));
                    visible_child_name = DETAILS_VIEW;
                } catch (DecryptError e) {
                    password_entry.grab_focus_without_selecting ();
                    unlock_error_label.label = e.message;
                    unlock_error_label.visible = true;
                }
            });
        });

        // add (new Wingpanel.Widgets.Separator ());

        grid.add (locked_icon);
        grid.add (password_entry);
        grid.add (unlock_error_label);

        return grid;
    }

    Wingpanel.Widgets.Button add_button_for_entry (string file) {
        var b = new Wingpanel.Widgets.Button (file);
        b.clicked.connect ((button) => {
            selected_path = ((Wingpanel.Widgets.Button) button).get_caption ();
            visible_child_name = UNLOCK_VIEW;
        });
        search_list.add (b);
        return b;
    }

    Gtk.Widget build_search_grid () {
        var grid = build_grid ();

        search_list = new Gtk.Grid ();
        search_list.orientation = Gtk.Orientation.VERTICAL;

        watcher.fetch_file_list.begin ((obj, res) => {
            foreach (var file in watcher.fetch_file_list.end (res)) {
                add_button_for_entry (file);
            }
            search_list.show_all ();
        });
        watcher.added.connect ((file) => {
            add_button_for_entry (file);
        });
        watcher.removed.connect ((file) => {
            foreach (var child in search_list.get_children ()) {
                if (((Wingpanel.Widgets.Button) child).label == file) {
                    search_list.remove (child);
                    break;
                }
            }
            reset_view ();
        });

        var scroll = new Wingpanel.Widgets.AutomaticScrollBox (null, null);
        scroll.expand = true;
        scroll.max_height = 300;
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.add (search_list);

        search_entry = new Gtk.SearchEntry ();
        search_entry.margin = 6;

        search_entry.activate.connect (() => {
            selected_path = get_nth_search_item (int.max (selected_search_result, 0)).get_caption ();
            visible_child_name = UNLOCK_VIEW;
        });

        search_entry.key_press_event.connect ((e) => {
            if (e.keyval == Gdk.Key.Up) {
                selected_search_result = int.max (selected_search_result - 1, -1);
                return true;
            } else if (e.keyval == Gdk.Key.Down) {
                selected_search_result = int.min (selected_search_result + 1, (int) get_n_search_items () - 1);
                return true;
            }

            return false;
        });

        search_entry.changed.connect (() => {
            var query = search_entry.text.down ();

            selected_search_result = -1;

            if (query.length < 1) {
                show_all_entries ();
                return;
            }

            foreach (var button in search_list.get_children ()) {
                var label = ((Wingpanel.Widgets.Button) button).get_caption ().down ();
                button.visible = query in label;
            }
        });

        grid.add (search_entry);
        grid.add (scroll);

        return grid;
    }

    void reset_view () {
        password_entry.sensitive = true;
        visible_child_name = SEARCH_VIEW;
        search_entry.text = "";
        password_entry.text = "";
        unlock_error_label.visible = false;
        selected_search_result = -1;
        show_all_entries ();
    }

    void show_all_entries () {
        foreach (var button in search_list.get_children ()) {
            button.visible = true;
        }
    }

    public void unfocused () {
        if (visible_child_name == UNLOCK_VIEW) {
            reset_view ();
        }
    }

    public void focused () {
        switch (visible_child_name) {
            case SEARCH_VIEW:
                search_entry.grab_focus_without_selecting ();
                break;
            case UNLOCK_VIEW:
                password_entry.grab_focus_without_selecting ();
                break;
        }
    }
}

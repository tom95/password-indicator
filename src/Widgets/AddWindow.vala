
public class Password.Widgets.AddWindow : Gtk.Window {

    Gtk.Grid grid;

    Gtk.Grid rows;
    int n_rows = 0;

    construct {
        var header = new Gtk.HeaderBar ();
        header.show_close_button = true;
        var header_context = header.get_style_context ();
        header_context.add_class ("titlebar");
        header_context.add_class ("default-decoration");
        header_context.add_class (Gtk.STYLE_CLASS_FLAT);
        set_titlebar (header);

        title = "Add an Entry";

        grid = new Gtk.Grid ();
        grid.margin = 24;
        grid.row_spacing = 12;

        rows = new Gtk.Grid ();
        rows.row_spacing = 4;
        rows.column_spacing = 6;

        var title = new Gtk.Entry ();
        title.hexpand = true;
        title.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
        title.placeholder_text = "Entry Title";
        title.text = "Entry Title";

        var add_button = new Gtk.Button.with_label ("Add Field");
        add_button.halign = Gtk.Align.START;
        add_button.clicked.connect (() => add_row ());

        add_row (true);

        var confirm = new Gtk.Button.with_label ("Create Entry");
        confirm.halign = Gtk.Align.END;

        grid.attach (title, 0, 0, 2, 1);
        grid.attach (rows, 0, 1, 2, 1);
        grid.attach (add_button, 0, 2, 1, 1);
        grid.attach (confirm, 1, 2, 1, 1);

        confirm.set_can_default (true);
        set_default (confirm);

        add (grid);
    }

    void connect_entry_signals (Gtk.Entry entry) {
        entry.activate.connect (() => add_row ());
        entry.move_focus.connect (direction => {
            if (direction == Gtk.DirectionType.TAB_FORWARD)
                add_row ();
        });
    }

    void add_row (bool is_password = false) {
        var label = new Gtk.Entry ();
        label.placeholder_text = "Label";
        label.sensitive = !is_password;
        if (is_password)
            label.text = "Password";

        var val = new Gtk.Entry ();
        val.hexpand = true;
        val.placeholder_text = "Value";
        val.visibility = !is_password;
        connect_entry_signals (val);

        var colon = new Gtk.Label (":");

        var remove = new Gtk.Button.from_icon_name ("list-remove-symbolic", Gtk.IconSize.MENU);
        remove.halign = remove.valign = Gtk.Align.CENTER;
        remove.tooltip_text = _("Remove field");
        remove.sensitive = !is_password;

        var my_row = n_rows;
        remove.clicked.connect (() => {
            rows.remove_row (my_row);
            n_rows--;
        });

        rows.attach (label, 0, n_rows, 1, 1);
        rows.attach (colon, 1, n_rows, 1, 1);
        rows.attach (val, 2, n_rows, 1, 1);
        rows.attach (remove, 3, n_rows, 1, 1);

        rows.show_all ();
        label.grab_focus ();

        n_rows++;
    }
}



public class Password.Widgets.AddWindow : Gtk.Window {

    Gtk.Grid grid;

    Gtk.Grid rows;
    int n_rows = 0;

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        grid = new Gtk.Grid ();
        rows = new Gtk.Grid ();

        var title = new Gtk.Entry ();
        title.placeholder_text = "Entry Title";

        var add_button = new Gtk.Button.from_icon_name ("plus-symbolic");
        add_button.clicked.connect (() => add_row ());

        add_row ();

        grid.attach (title, 0, 0, 1, 1);
        grid.attach (rows, 0, 0, 1, 1);
    }

    void add_row () {
        var label = new Gtk.Entry ();
        label.hexpand = true;
        label.placeholder_text = "Label";

        var val = new Gtk.Entry ();
        val.hexpand = true;
        val.placeholder_text = "Value";

        var colon = new Gtk.Label (":");

        var remove = new Gtk.Button.from_icon_name ("minus-symbolic");

        var my_row = n_rows;
        remove.clicked.connect (() => {
            grid.remove_row (my_row);
            n_rows--;
        });

        grid.attach (label, 0, n_rows, 1, 1);
        grid.attach (colon, 1, n_rows, 1, 1);
        grid.attach (val, 2, n_rows, 1, 1);
        grid.attach (remove, 3, n_rows, 1, 1);

        n_rows++;
    }
}


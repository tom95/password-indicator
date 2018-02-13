
public class Password.Widgets.InitiallyHiddenLabel : Gtk.Button {

    const string HIDDEN_LABEL = "●●●●●●"; // 0x25CF BLACK CIRCLE

    public string real_label { get; set; }

    bool revealed = false;

    public InitiallyHiddenLabel (string real_label) {
        Object (real_label: real_label);
    }

    construct {
        update ();

        relief = Gtk.ReliefStyle.NONE;

        clicked.connect (() => {
            revealed = !revealed;
            update ();
        });
    }

    void update () {
        label = revealed ? real_label : HIDDEN_LABEL;
    }
}

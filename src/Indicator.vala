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

public class Password.Indicator : Wingpanel.Indicator {
    private Wingpanel.Widgets.OverlayIcon? indicator_icon = null;
    private Password.Widgets.PopoverWidget? popover_widget = null;

    const string CODE_NAME = "de.tombeckmann.password";
    const string SHORTCUT = "<Super>D";

    public Indicator (Wingpanel.IndicatorManager.ServerType server_type) {
        Object (code_name: CODE_NAME,
                display_name: _("Password"),
                description: _("The Password indicator"));

        Keybinder.bind(SHORTCUT, () => {
            try {
                Process.spawn_sync (null,
                                    {"wingpanel", "--toggle-indicator", CODE_NAME},
                                    null,
                                    SpawnFlags.SEARCH_PATH,
                                    null);
            } catch (Error e) {
                critical (e.message);
            }
        }, null);
    }

    public override Gtk.Widget get_display_widget () {
        if (indicator_icon == null) {
            indicator_icon = new Wingpanel.Widgets.OverlayIcon ("dialog-password-symbolic");
        }

        return indicator_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (popover_widget == null) {
            popover_widget = new Password.Widgets.PopoverWidget ();
            popover_widget.request_close.connect (() => close ());
        }

        visible = true;

        return popover_widget;
    }

    public override void opened () {
        if (popover_widget != null) {
            popover_widget.focused ();
        }
    }

    public override void closed () {
        if (popover_widget != null) {
            popover_widget.unfocused ();
        }
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Password Indicator");

    Keybinder.init();

    var indicator = new Password.Indicator (server_type);
    return indicator;
}

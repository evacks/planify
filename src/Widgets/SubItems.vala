/*
* Copyright © 2023 Alain M. (https://github.com/alainm23/planify)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
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
*
* Authored by: Alain M. <alainmh23@gmail.com>
*/

public class Widgets.SubItems : Gtk.Grid {
    public Objects.Item item_parent { get; construct; }
    
    private Gtk.ListBox listbox;
    private Gtk.ListBox checked_listbox;
    private Gtk.Revealer checked_revealer;
    private Gtk.Revealer main_revealer;

    public Gee.HashMap <string, Layouts.ItemRow> items;
    public Gee.HashMap <string, Layouts.ItemRow> items_checked;

    public bool has_children {
        get {
            return items.size > 0 || (items_checked.size > 0 && item_parent.project.show_completed);
        }
    }

    public bool is_creating {
        get {
            return item_parent.id == "";
        }
    }

    public bool reveal_child {
        get {
            return main_revealer.reveal_child;
        }

        set {
            main_revealer.reveal_child = value;
        }
    }

    public SubItems (Objects.Item item_parent) {
        Object (
            item_parent: item_parent
        );
    }

    construct {
        items = new Gee.HashMap <string, Layouts.ItemRow> ();
        items_checked = new Gee.HashMap <string, Layouts.ItemRow> ();

        listbox = new Gtk.ListBox () {
            valign = Gtk.Align.START,
            activate_on_single_click = true,
            selection_mode = Gtk.SelectionMode.SINGLE,
            hexpand = true
        };
        listbox.add_css_class ("listbox-background");

        var listbox_grid = new Gtk.Grid ();
        listbox_grid.attach (listbox, 0, 0);
        
        checked_listbox = new Gtk.ListBox () {
            valign = Gtk.Align.START,
            activate_on_single_click = true,
            selection_mode = Gtk.SelectionMode.SINGLE,
            hexpand = true,
        };
        checked_listbox.add_css_class ("listbox-background");

        var checked_listbox_grid = new Gtk.Grid ();

        checked_listbox_grid.attach (checked_listbox, 0, 0);

        checked_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
            reveal_child = item_parent.project.show_completed
        };

        checked_revealer.child = checked_listbox_grid;

        var main_grid = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            hexpand = true,
            margin_start = 24,
            margin_top = 3
        };

        main_grid.append (listbox_grid);
        main_grid.append (checked_revealer);

        main_revealer = new Gtk.Revealer ();
        main_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        main_revealer.child = main_grid;
        
        attach (main_revealer, 0, 0);

        if (!is_creating) {
            add_items ();
        }

        item_parent.item_added.connect (add_item);

        //  listbox.add.connect (() => {
        //      main_revealer.reveal_child = has_children;
        //  });

        //  listbox.remove.connect (() => {
        //      main_revealer.reveal_child = has_children;
        //  });

        Services.Database.get_default ().item_updated.connect ((item, update_id) => {
            if (items.has_key (item.id_string)) {
                if (items [item.id_string].update_id != update_id) {
                    items [item.id_string].update_request ();
                }
            }

            if (items_checked.has_key (item.id_string)) {
                items_checked [item.id_string].update_request ();
            }
        });

        Services.Database.get_default ().item_deleted.connect ((item) => {
            if (items.has_key (item.id_string)) {
                items [item.id_string].hide_destroy ();
                items.unset (item.id_string);
            }

            if (items_checked.has_key (item.id_string)) {
                items_checked [item.id_string].hide_destroy ();
                items_checked.unset (item.id_string);
            }
        });

        Services.EventBus.get_default ().item_moved.connect ((item, old_project_id, old_section_id, old_parent_id, insert) => {
            if (old_parent_id == item_parent.id) {
                if (items.has_key (item.id_string)) {
                    items [item.id_string].hide_destroy ();
                    items.unset (item.id_string);
                }

                if (items_checked.has_key (item.id_string)) {
                    items_checked [item.id_string].hide_destroy ();
                    items_checked.unset (item.id_string);
                }
            }

            if (item.parent_id == item_parent.id) {
                add_item (item);
            }
        });

        Services.EventBus.get_default ().checked_toggled.connect ((item, old_checked) => {
            if (item.parent.id == item_parent.id) {
                if (!old_checked) {
                    if (items.has_key (item.id_string)) {
                        items [item.id_string].hide_destroy ();
                        items.unset (item.id_string);
                    }

                    if (!items_checked.has_key (item.id_string)) {
                        items_checked [item.id_string] = new Layouts.ItemRow (item);
                        checked_listbox.insert (items_checked [item.id_string], 0);
                    }
                } else {
                    if (items_checked.has_key (item.id_string)) {
                        items_checked [item.id_string].hide_destroy ();
                        items_checked.unset (item.id_string);
                    }

                    if (!items.has_key (item.id_string)) {
                        items [item.id_string] = new Layouts.ItemRow (item);
                        listbox.append (items [item.id_string]);
                    }
                }
            }
        });

        item_parent.project.show_completed_changed.connect (() => {
            if (item_parent.project.show_completed) {
                add_completed_items ();
                checked_revealer.reveal_child = item_parent.project.show_completed;
            } else {
                //  items_checked.clear ();
                //  foreach (unowned Gtk.Widget child in checked_listbox.get_children ()) {
                //      child.destroy ();
                //  }

                //  checked_revealer.reveal_child = item_parent.project.show_completed;
            }
        });
    }

    public void add_items () {
        items.clear ();

        //  foreach (unowned Gtk.Widget child in listbox.get_children ()) {
        //      child.destroy ();
        //  }

        foreach (Objects.Item item in item_parent.items) {
            add_item (item);
        }

        if (item_parent.project.show_completed) {
            add_completed_items ();
        }

        Timeout.add (main_revealer.transition_duration, () => {
            main_revealer.reveal_child = has_children;
            return GLib.Source.REMOVE;
        });
    }

    public void add_completed_items () {
        items_checked.clear ();

        //  foreach (unowned Gtk.Widget child in checked_listbox.get_children ()) {
        //      child.destroy ();
        //  }

        foreach (Objects.Item item in item_parent.items) {
            add_complete_item (item);
        }
    }

    public void add_complete_item (Objects.Item item) {
        if (item_parent.project.show_completed && item.checked) {
            if (!items_checked.has_key (item.id_string)) {
                items_checked [item.id_string] = new Layouts.ItemRow (item);
                checked_listbox.append (items_checked [item.id_string]);
            }
        }
    }

    public void add_item (Objects.Item item) {
        if (!item.checked && !items.has_key (item.id_string)) {
            items [item.id_string] = new Layouts.ItemRow (item);
            listbox.append (items [item.id_string]);
        }
    }

    public void prepare_new_item (string content = "") {
        Services.EventBus.get_default ().item_selected (null);
        main_revealer.reveal_child = true;

        Layouts.ItemRow row = new Layouts.ItemRow.for_parent (item_parent);
        row.update_content (content);
        row.update_priority (Util.get_default ().get_default_priority ());

        row.item_added.connect (() => {
            items [row.item.id_string] = row;
            row.update_inserted_item ();
            item_parent.add_item_if_not_exists (row.item);
        });

        listbox.append (row);
    }
}
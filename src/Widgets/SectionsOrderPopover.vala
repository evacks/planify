public class Widgets.SectionsOrderPopover : Gtk.Popover {
    public Objects.Project project { get; construct; }

    private Gtk.ListBox listbox;

    public SectionsOrderPopover (Objects.Project project) {
        Object (
            project: project,
            has_arrow: false,
            // autohide: false,
            position: Gtk.PositionType.BOTTOM,
            width_request: 250
        );
    }

    construct {
        listbox = new Gtk.ListBox ();
        var add_section_item = new Widgets.ContextMenu.MenuItem (_("Add Section"), "planner-section");

        var main_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            hexpand = true,
            vexpand = true
        };

        main_content.append (listbox);
        main_content.append (new Widgets.ContextMenu.MenuSeparator ());
        main_content.append (add_section_item);

        child = main_content;

        foreach (Objects.Section section in project.sections) {
            listbox.append (new Widgets.SectionsOrderItem (section));
        }

        Timeout.add (225, () => {
            set_sort_func ();
            return GLib.Source.REMOVE;
        });
    }

    private void set_sort_func () {
        listbox.set_sort_func ((row1, row2) => {
            Objects.Section item1 = ((Widgets.SectionsOrderItem) row1).section;
            Objects.Section item2 = ((Widgets.SectionsOrderItem) row2).section;
    
            return item1.section_order - item2.section_order;
        });
    
        listbox.set_sort_func (null);
    }
}

public class Widgets.SectionsOrderItem : Gtk.ListBoxRow {
    public Objects.Section section { get; construct; }

    private Gtk.Grid handle_grid;

    public SectionsOrderItem (Objects.Section section) {
        Object (
            section: section
        );
    }

    construct {
        add_css_class ("selectable-item");
        add_css_class ("transition");

        var order_icon = new Widgets.DynamicIcon ();
        order_icon.size = 16;
        order_icon.update_icon_name ("menu");
        order_icon.add_css_class ("dim-label");

        var widget_color = new Gtk.Grid () {
            height_request = 12,
            width_request = 12,
            valign = Gtk.Align.CENTER,
            halign = Gtk.Align.CENTER
        };

        widget_color.add_css_class ("label-color");
        Util.get_default ().set_widget_color ("#7ecc49", widget_color);

        var name_label = new Gtk.Label (section.name);
        name_label.valign = Gtk.Align.CENTER;
        name_label.ellipsize = Pango.EllipsizeMode.END;

        var visible_switch = new Gtk.Switch () {
			valign = CENTER,
            hexpand = true,
            halign = END,
            margin_start = 6
		};
        visible_switch.add_css_class ("switch-min");

        var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_top = 6,
            margin_start = 10,
            margin_end = 6,
            margin_bottom = 6
        };

        content_box.append (order_icon);
        content_box.append (name_label);
        content_box.append (visible_switch);

        handle_grid = new Gtk.Grid ();
        handle_grid.attach (content_box, 0, 0);

        child = handle_grid;
        build_drag_and_drop ();
    }

    private void build_drag_and_drop () {
        var drag_source = new Gtk.DragSource ();
        drag_source.set_actions (Gdk.DragAction.MOVE);
        
        drag_source.prepare.connect ((source, x, y) => {
            return new Gdk.ContentProvider.for_value (this);
        });

        drag_source.drag_begin.connect ((source, drag) => {
            var paintable = new Gtk.WidgetPaintable (handle_grid);
            source.set_icon (paintable, 0, 0);
            drag_begin ();
        });
        
        drag_source.drag_end.connect ((source, drag, delete_data) => {
            drag_end ();
        });

        drag_source.drag_cancel.connect ((source, drag, reason) => {
            drag_end ();
            return false;
        });

        add_controller (drag_source);

        var drop_target = new Gtk.DropTarget (typeof (Widgets.SectionsOrderItem), Gdk.DragAction.MOVE);
        drop_target.preload = true;

        drop_target.drop.connect ((value, x, y) => {
            var picked_widget = (Widgets.SectionsOrderItem) value;
            var target_widget = this;

            Gtk.Allocation alloc;
            target_widget.get_allocation (out alloc);

            picked_widget.drag_end ();
            target_widget.drag_end ();

            if (picked_widget == target_widget || target_widget == null) {
                return false;
            }

            var source_list = (Gtk.ListBox) picked_widget.parent;
            var target_list = (Gtk.ListBox) target_widget.parent;
            var position = 0;

            source_list.remove (picked_widget);
            
            if (target_widget.get_index () == 0) {
                if (y > (alloc.height / 2)) {
                    position = target_widget.get_index () + 1;
                }
            } else {
                position = target_widget.get_index () + 1;
            }

            target_list.insert (picked_widget, position);

            return true;
        });

        add_controller (drop_target);
    }

    public void drag_begin () {
        handle_grid.add_css_class ("card");
        opacity = 0.3;        
    }

    public void drag_end () {
        handle_grid.remove_css_class ("card");
        opacity = 1;
    }
}

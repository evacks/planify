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

public class Widgets.Calendar.CalendarView : Gtk.Box {
    private Gee.ArrayList <Widgets.Calendar.CalendarDay> days_arraylist;
    private Gtk.Grid days_grid;

    public signal void day_selected (int day);

    public CalendarView () {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            margin_start: 6,
            margin_end: 6
        );
    }

    construct {
        days_arraylist = new Gee.ArrayList<Widgets.Calendar.CalendarDay> ();

        days_grid = new Gtk.Grid () {
            column_homogeneous = true,
            row_homogeneous = true
        };

        var col = 0;
        var row = 0;

        for (int i = 0; i < 42; i++) {
            var day = new Widgets.Calendar.CalendarDay ();
            day.day_selected.connect (day_selected_style);
            days_grid.attach (day, col, row, 1, 1);
            col = col + 1;

            if (col != 0 && col % 7 == 0) {
                row = row + 1;
                col = 0;
            }

            day.visible = false;
            days_arraylist.add (day);
        }

        append (days_grid);
    }

    public void fill_grid_days (int start_day,
                                int max_day,
                                int current_day,
                                bool is_current_month,
                                bool block_past_days = false,
                                GLib.DateTime month = new GLib.DateTime.now_local ()) {
        var day_number = 1;

        int _current_day = current_day;
        if (is_current_month) {
            var current_date = new GLib.DateTime.now_local ();
            _current_day = current_date.get_day_of_month ();
        }

        for (int i = 0; i < 42; i++) {
            var item = days_arraylist [i];
            item.sensitive = true;
            item.visible = true;

            item.remove_css_class ("calendar-today");

            if (i < start_day || i >= max_day + start_day) {
                item.visible = false;
            } else {
                if (day_number < _current_day) {
                    if (block_past_days && is_current_month) {
                        item.sensitive = false;
                    }
                }

                if (_current_day != -1 && (i + 1) == _current_day + start_day) {
                    if (is_current_month) {
                        item.add_css_class ("calendar-today");
                    }
                }

                item.day = day_number;
                day_number = day_number + 1;
            }

            if (block_past_days) {
                if (is_current_month == false) {
                    if (month.compare (new GLib.DateTime.now_local ()) == -1) {
                        item.sensitive = false;
                    }
                }
            }
        }

        clear_style ();
    }

    private void clear_style () {
        for (int i = 0; i < 42; i++) {
            var item = days_arraylist [i];
            item.remove_css_class ("calendar-day-selected");
        }
    }
    private void day_selected_style (int day) {
        day_selected (day);

        for (int i = 0; i < 42; i++) {
            var day_item = days_arraylist [i];
            day_item.remove_css_class ("calendar-day-selected");
        }
    }
}
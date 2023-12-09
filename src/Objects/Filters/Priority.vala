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

public class Objects.Priority : Objects.BaseObject {
    public int priority { get; construct; }

    private static Priority? _instance;
    public static Priority get_default (int priority) {
        if (_instance == null) {
            _instance = new Priority (priority);
        }

        return _instance;
    }

    string _view_id;
    public string view_id {
        get {
            _view_id = "priority-%d".printf (priority);
            return _view_id;
        }
    }

    public Priority (int priority) {
        Object (
            priority: priority
        );
    }

    int? _count = null;
    public int count {
        get {
            if (_count == null) {
                _count = Services.Database.get_default ().get_items_by_priority (priority, false).size;
            }

            return _count;
        }

        set {
            _count = value;
        }
    }

    public signal void count_updated ();

    construct {
        name = Util.get_default ().get_priority_title (priority);
        keywords = "%s;%s".printf (_("priority"), "p" + priority.to_string ());

        Services.Database.get_default ().item_added.connect (() => {
            _count = Services.Database.get_default ().get_items_by_priority (priority, false).size;
            count_updated ();
        });

        Services.Database.get_default ().item_deleted.connect (() => {
            _count = Services.Database.get_default ().get_items_by_priority (priority, false).size;
            count_updated ();
        });

        Services.Database.get_default ().item_updated.connect (() => {
            _count = Services.Database.get_default ().get_items_by_priority (priority, false).size;
            count_updated ();
        });
    }
}
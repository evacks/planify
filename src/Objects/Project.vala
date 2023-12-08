public class Objects.Project : Objects.BaseObject {
    public string parent_id { get; set; default = ""; }
    public string due_date { get; set; default = ""; }
    public string color { get; set; default = ""; }
    public string emoji { get; set; default = ""; }
    public string description { get; set; default = ""; }
    public ProjectIconStyle icon_style { get; set; default = ProjectIconStyle.PROGRESS; }
    public BackendType backend_type { get; set; default = BackendType.NONE; }
    public bool inbox_project { get; set; default = false; }
    public bool team_inbox { get; set; default = false; }
    public bool is_deleted { get; set; default = false; }
    public bool is_archived { get; set; default = false; }
    public bool is_favorite { get; set; default = false; }
    public bool shared { get; set; default = false; }
    public bool collapsed { get; set; default = false; }
    
    ProjectViewStyle _view_style = ProjectViewStyle.LIST;
    public ProjectViewStyle view_style {
        get {
            return _view_style;
        }

        set {
            _view_style = value;
            view_style_changed ();
        }
    }

    bool _show_completed = false;
    public bool show_completed {
        get {
            return _show_completed;
        }

        set {
            _show_completed = value;
            show_completed_changed ();
        }
    }

    int _sort_order = 0;
    public int sort_order {
        get {
            return _sort_order;
        }

        set {
            _sort_order = value;
            sort_order_changed ();
        }
    }
    
    public int child_order { get; set; default = 0; }
    
    string _view_id;
    public string view_id {
        get {
            _view_id ="project-%s".printf (id_string);
            return _view_id;
        }
    }

    string _parent_id_string;
    public string parent_id_string {
        get {
            _parent_id_string = parent_id.to_string ();
            return _parent_id_string;
        }
    }

    string _short_name;
    public string short_name {
        get {
            _short_name = Util.get_default ().get_short_name (name);
            return _short_name;
        }
    }

    public bool is_inbox_project {
        get {
            return id == Services.Settings.get_default ().settings.get_string ("inbox-project-id");
        }
    }

    Gee.ArrayList<Objects.Section> _sections;
    public Gee.ArrayList<Objects.Section> sections {
        get {
            _sections = Services.Database.get_default ().get_sections_by_project (this);
            return _sections;
        }
    }

    Gee.ArrayList<Objects.Item> _items;
    public Gee.ArrayList<Objects.Item> items {
        get {
            _items = Services.Database.get_default ().get_item_by_baseobject (this);
            _items.sort ((a, b) => {
                if (a.child_order > b.child_order) {
                    return 1;
                } if (a.child_order == b.child_order) {
                    return 0;
                }
                
                return -1;
            });
            
            return _items;
        }
    }

    Gee.ArrayList<Objects.Item> _items_checked;
    public Gee.ArrayList<Objects.Item> items_checked {
        get {
            _items = Services.Database.get_default ().get_items_checked_by_project (this);
            return _items;
        }
    }

    Gee.ArrayList<Objects.Project> _subprojects;
    public Gee.ArrayList<Objects.Project> subprojects {
        get {
            _subprojects = Services.Database.get_default ().get_subprojects (this);
            return _subprojects;
        }
    }

    Objects.Project? _parent;
    public Objects.Project parent {
        get {
            _parent = Services.Database.get_default ().get_project (parent_id);
            return _parent;
        }
    }

    public signal void section_added (Objects.Section section);
    public signal void subproject_added (Objects.Project project);
    public signal void item_added (Objects.Item item);
    public signal void show_completed_changed ();
    public signal void sort_order_changed ();
    public signal void section_sort_order_changed ();
    public signal void view_style_changed ();

    int? _project_count = null;
    public int project_count {
        get {
            if (_project_count == null) {
                _project_count = update_project_count ();
            }

            return _project_count;
        }

        set {
            _project_count = value;
        }
    }

    double? _percentage = null;
    public double percentage {
        get {
            if (_percentage == null) {
                _percentage = update_percentage ();
            }
            
            return _percentage;
        }
    }

    public signal void project_count_updated ();

    Gee.HashMap <string, Objects.Label> _label_filter = new Gee.HashMap <string, Objects.Label> ();
    public Gee.HashMap <string, Objects.Label> label_filter {
        get {
            return _label_filter;
        }

        set {
            _label_filter = value;
            label_filter_change ();
        }
    }

    public signal void label_filter_change ();

    construct {
        deleted.connect (() => {
            Idle.add (() => {
                Services.Database.get_default ().project_deleted (this);
                return false;
            });
        });

        Services.EventBus.get_default ().checked_toggled.connect ((item) => {
            if (item.project_id == id) {
                _project_count = update_project_count ();
                _percentage = update_percentage ();
                project_count_updated ();
            }
        });

        Services.Database.get_default ().item_deleted.connect ((item) => {
            if (item.project_id == id) {
                _project_count = update_project_count ();
                _percentage = update_percentage ();
                project_count_updated ();
            }
        });

        Services.Database.get_default ().item_added.connect ((item) => {
            if (item.project_id == id) {
                _project_count = update_project_count ();
                _percentage = update_percentage ();
                project_count_updated ();
            }
        });

        Services.EventBus.get_default ().item_moved.connect ((item, old_project_id, section_id, insert) => {
            if (item.project_id == id || old_project_id == id) {
                _project_count = update_project_count ();
                _percentage = update_percentage ();
                project_count_updated ();
            }
        });

        Services.Database.get_default ().section_moved.connect ((section, old_project_id) => {
            if (section.project_id == id || old_project_id == id) {
                _project_count = update_project_count ();
                _percentage = update_percentage ();
                project_count_updated ();
            }
        });
    }

    public Project.from_json (Json.Node node) {
        id = node.get_object ().get_string_member ("id");
        update_from_json (node);
        backend_type = BackendType.TODOIST;
    }

    public Project.from_google_tasklist_json (Json.Node node) {
        id = node.get_object ().get_string_member ("id");
        update_from_google_tasklist_json (node);
        backend_type = BackendType.GOOGLE_TASKS;
    }

    public void update_from_json (Json.Node node) {
        name = node.get_object ().get_string_member ("name");

        if (!node.get_object ().get_null_member ("color")) {
            color = node.get_object ().get_string_member ("color");
        }
        
        if (!node.get_object ().get_null_member ("is_deleted")) {
            is_deleted = node.get_object ().get_boolean_member ("is_deleted");
        }
        
        if (!node.get_object ().get_null_member ("is_archived")) {
            is_archived = node.get_object ().get_boolean_member ("is_archived");
        }
        
        if (!node.get_object ().get_null_member ("is_favorite")) {
            is_favorite = node.get_object ().get_boolean_member ("is_favorite");
        }
        
        if (!node.get_object ().get_null_member ("child_order")) {
            child_order = (int32) node.get_object ().get_int_member ("child_order");
        }
        
        if (!node.get_object ().get_null_member ("parent_id")) {
            parent_id = node.get_object ().get_string_member ("parent_id");
        } else {
            parent_id = "";
        }

        if (node.get_object ().has_member ("team_inbox") && !node.get_object ().get_null_member ("team_inbox")) {
            team_inbox = node.get_object ().get_boolean_member ("team_inbox");
        }

        if (node.get_object ().has_member ("inbox_project") && !node.get_object ().get_null_member ("inbox_project")) {
            inbox_project = node.get_object ().get_boolean_member ("inbox_project");
        }

        shared = node.get_object ().get_boolean_member ("shared");

        view_style = node.get_object ().get_string_member ("view_style") == "board" ?
            ProjectViewStyle.BOARD : ProjectViewStyle.LIST;
    }

    public void update_from_google_tasklist_json (Json.Node node) {
        name = node.get_object ().get_string_member ("title");
    }

    public void update_no_timeout () {
        if (backend_type == BackendType.TODOIST) {
            Services.Todoist.get_default ().update.begin (this, (obj, res) => {
                Services.Todoist.get_default ().update.end (res);
                Services.Database.get_default ().update_project (this);
            });
        } else if (backend_type == BackendType.LOCAL) {
            Services.Database.get_default ().update_project (this);
        }
    }

    public void update (bool cloud = true) {
        if (update_timeout_id != 0) {
            Source.remove (update_timeout_id);
        }

        update_timeout_id = Timeout.add (Constants.UPDATE_TIMEOUT, () => {
            update_timeout_id = 0;

            if (backend_type == BackendType.TODOIST && cloud) {
                Services.Todoist.get_default ().update.begin (this, (obj, res) => {
                    Services.Todoist.get_default ().update.end (res);
                    Services.Database.get_default ().update_project (this);
                });
            } else {
                Services.Database.get_default ().update_project (this);
            }

            return GLib.Source.REMOVE;
        });
    }

    public void update_async (Widgets.LoadingButton? loading_button = null) {
        if (loading_button != null) {
            loading_button.is_loading = true;
        }
        
        if (backend_type == BackendType.TODOIST) {
            Services.Todoist.get_default ().update.begin (this, (obj, res) => {
                Services.Todoist.get_default ().update.end (res);
                Services.Database.get_default ().update_project (this);

                if (loading_button != null) {
                    loading_button.is_loading = false;
                }
            });
        } else {
            Services.Database.get_default ().update_project (this);
        }
    }

    public Objects.Project? add_subproject_if_not_exists (Objects.Project new_project) {
        Objects.Project? return_value = null;
        lock (subprojects) {
            return_value = get_subproject (new_project.id);
            if (return_value == null) {
                new_project.set_parent (this);
                Services.Database.get_default ().insert_project (new_project);
                return_value = new_project;
            }
            return return_value;
        }
    }

    public Objects.Project? get_subproject (string id) {
        Objects.Project? return_value = null;
        lock (_subprojects) {
            foreach (var project in subprojects) {
                if (project.id == id) {
                    return_value = project;
                    break;
                }
            }
        }
        return return_value;
    }

    public void set_parent (Objects.Project project) {
        this._parent = project;
    }

    public Objects.Section add_section_if_not_exists (Objects.Section new_section) {
        Objects.Section? return_value = null;
        lock (_sections) {
            return_value = get_section (new_section.id);
            if (return_value == null) {
                new_section.set_project (this);
                add_section (new_section);
                Services.Database.get_default ().insert_section (new_section);
                return_value = new_section;
            }
            return return_value;
        }
    }

    public Objects.Section? get_section (string id) {
        Objects.Section? return_value = null;
        lock (_sections) {
            foreach (var section in sections) {
                if (section.id == id) {
                    return_value = section;
                    break;
                }
            }
        }
        return return_value;
    }

    public void add_section (Objects.Section section) {
        this._sections.add (section);
        section.deleted.connect (() => {
            _sections.remove (section);
        });
    }

    public Objects.Item add_item_if_not_exists (Objects.Item new_item, bool insert=true) {
        Objects.Item? return_value = null;
        lock (_items) {
            return_value = get_item (new_item.id);
            if (return_value == null) {
                new_item.set_project (this);
                add_item (new_item);
                Services.Database.get_default ().insert_item (new_item, insert);
                return_value = new_item;
            }
            return return_value;
        }
    }

    public Objects.Item? get_item (string id) {
        Objects.Item? return_value = null;
        lock (_items) {
            foreach (var item in items) {
                if (item.id == id) {
                    return_value = item;
                    break;
                }
            }
        }
        return return_value;
    }

    public void add_item (Objects.Item item) {
        this._items.add (item);
    }

    public override string get_add_json (string temp_id, string uuid) {
        return get_update_json (uuid, temp_id);
    }

    public override string get_update_json (string uuid, string? temp_id = null) {
        var builder = new Json.Builder ();
        builder.begin_array ();
        builder.begin_object ();

        // Set type
        builder.set_member_name ("type");
        builder.add_string_value (temp_id == null ? "project_update" : "project_add");

        builder.set_member_name ("uuid");
        builder.add_string_value (uuid);

        if (temp_id != null) {
            builder.set_member_name ("temp_id");
            builder.add_string_value (temp_id);
        }

        builder.set_member_name ("args");
            builder.begin_object ();

            if (temp_id == null) {
                builder.set_member_name ("id");
                builder.add_string_value (id);
            }

            builder.set_member_name ("name");
            builder.add_string_value (Util.get_default ().get_encode_text (name));

            builder.set_member_name ("color");
            builder.add_string_value (color);

            builder.set_member_name ("collapsed");
            builder.add_boolean_value (collapsed);

            builder.set_member_name ("is_favorite");
            builder.add_boolean_value (is_favorite);

            if (parent_id != "") {
                builder.set_member_name ("parent_id");
                builder.add_string_value (parent_id);
            } else {
                builder.set_member_name ("parent_id");
                builder.add_null_value ();
            }

            builder.end_object ();
        builder.end_object ();
        builder.end_array ();

        Json.Generator generator = new Json.Generator ();
        Json.Node root = builder.get_root ();
        generator.set_root (root);

        print ("%s\n".printf (generator.to_data (null)));
        return generator.to_data (null);
    }

    public override string to_json () {
        var builder = new Json.Builder ();
        builder.begin_object ();
        
        builder.set_member_name ("id");
        builder.add_string_value (id);

        builder.set_member_name ("name");
        builder.add_string_value (Util.get_default ().get_encode_text (name));

        builder.set_member_name ("color");
        builder.add_string_value (color);

        builder.set_member_name ("collapsed");
        builder.add_boolean_value (collapsed);

        builder.set_member_name ("is_favorite");
        builder.add_boolean_value (is_favorite);

        builder.end_object ();

        Json.Generator generator = new Json.Generator ();
        Json.Node root = builder.get_root ();
        generator.set_root (root);

        return generator.to_data (null);
    }

    public override string get_move_json (string uuid, string new_parent_id) {
        var builder = new Json.Builder ();
        builder.begin_array ();
        builder.begin_object ();

        // Set type
        builder.set_member_name ("type");
        builder.add_string_value ("project_move");

        builder.set_member_name ("uuid");
        builder.add_string_value (uuid);

        builder.set_member_name ("args");
            builder.begin_object ();
            
            builder.set_member_name ("id");
            builder.add_string_value (id);

            if (new_parent_id != "") {
                builder.set_member_name ("parent_id");
                builder.add_string_value (new_parent_id);    
            } else {
                builder.set_member_name ("parent_id");
                builder.add_null_value ();
            }

            builder.end_object ();
        builder.end_object ();
        builder.end_array ();

        Json.Generator generator = new Json.Generator ();
        Json.Node root = builder.get_root ();
        generator.set_root (root);
        
        return generator.to_data (null); 
    }

    public string to_string () {       
        return """
        _________________________________
            ID: %s
            NAME: %s
            DESCRIPTION: %s
            COLOR: %s
            BACKEND TYPE: %s
            INBOX: %s
            TEAM INBOX: %s
            CHILD ORDER: %i
            DELETED: %s
            ARCHIVED: %s
            FAVORITE: %s
            SHARED: %s
            VIEW: %s
            SHOW COMPLETED: %s
            SORT ORDER: %i
            COLLAPSED: %s
            PARENT ID: %s
        ---------------------------------
        """.printf (
            id.to_string (),
            name,
            description,
            color,
            backend_type.to_string (),
            inbox_project.to_string (),
            team_inbox.to_string (),
            child_order,
            is_deleted.to_string (),
            is_archived.to_string (),
            is_favorite.to_string (),
            shared.to_string (),
            view_style.to_string (),
            show_completed.to_string (),
            sort_order,
            collapsed.to_string (),
            parent_id.to_string ()
        );
    }

    private int update_project_count () {
        int returned = 0;
        foreach (Objects.Item item in Services.Database.get_default ().get_items_by_project (this)) {
            if (!item.checked) {
                returned++;
            }
        }
        return returned;
    }
    
    public double update_percentage () {
        int items_total = 0;
        int items_checked = 0;
        foreach (Objects.Item item in Services.Database.get_default ().get_items_by_project (this)) {
            items_total++;
            if (item.checked) {
                items_checked++;
            }
        }

        return ((double) items_checked / (double) items_total);
    }

    public Objects.Section prepare_new_section () {
        Objects.Section new_section = new Objects.Section ();
        new_section.project_id = id;
        new_section.name = _("New section");
        new_section.activate_name_editable = true;

        return new_section;
    }

    public void share_markdown () {
        Gdk.Clipboard clipboard = Gdk.Display.get_default ().get_clipboard ();
        clipboard.set_text (to_markdown ());
        Services.EventBus.get_default ().send_notification (
            Util.get_default ().create_toast (_("The project was copied to the Clipboard."))
        );
    }

    public void share_mail () {
        string uri = "";
        uri += "mailto:?subject=%s&body=%s".printf (name, to_markdown ());
        try {
            AppInfo.launch_default_for_uri (uri, null);
        } catch (Error e) {
            warning ("%s\n", e.message);
        }
    }

    private string to_markdown () {
        string text = "";
        text += "# %s\n".printf (name);


        foreach (Objects.Item item in items) {
            text += "- [%s] %s\n".printf (item.checked ? "x" : " ", item.content);
        }

        foreach (Objects.Section section in sections) {
            text += "\n";
            text += "## %s\n".printf (section.name);

            foreach (Objects.Item item in section.items) {
                text += "- [%s]%s%s\n".printf (item.checked ? "x" : " ", get_format_date (item), item.content);
                foreach (Objects.Item check in item.items) {
                    text += "  - [%s]%s%s\n".printf (check.checked ? "x" : " ", get_format_date (check), check.content);
                }
            }
        }

        return text;
    }

    private string get_format_date (Objects.Item item) {
        if (!item.has_due) {
            return " ";
        }

        return " (" + Util.get_default ().get_relative_date_from_date (item.due.datetime) + ") ";
    }
}

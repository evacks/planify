public class MainWindow : Adw.ApplicationWindow {
	public weak Planify app { get; construct; }

	private Layouts.Sidebar sidebar;
	private Gtk.Stack views_stack;
	private Adw.OverlaySplitView overlay_split_view;
	private Gtk.MenuButton settings_button;

	public Services.ActionManager action_manager;

	public MainWindow (Planify application) {
		Object (
			application: application,
			app: application,
			icon_name: Constants.APPLICATION_ID,
			title: _("Planify")
		);
	}

	static construct {
		weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
		default_theme.add_resource_path ("/io/github/alainm23/planify");
	}

	construct {
		if (Constants.PROFILE == "development") {
			add_css_class ("devel");
		}

		action_manager = new Services.ActionManager (app, this);

		Services.DBusServer.get_default ().item_added.connect ((id) => {
			var item = Services.Database.get_default ().get_item_by_id (id);
			Services.Database.get_default ().add_item (item);
		});

		var settings_popover = build_menu_app ();

		settings_button = new Gtk.MenuButton ();
		settings_button.add_css_class (Granite.STYLE_CLASS_FLAT);
		settings_button.popover = settings_popover;
		settings_button.child = new Widgets.DynamicIcon.from_icon_name ("dots-vertical");

		var search_button = new Gtk.Button () {
			child = new Widgets.DynamicIcon.from_icon_name ("planner-search")
		};
		search_button.add_css_class (Granite.STYLE_CLASS_FLAT);

		var sidebar_header = new Adw.HeaderBar () {
			title_widget = new Gtk.Label (null),
			hexpand = true
		};

		sidebar_header.add_css_class ("flat");
		sidebar_header.pack_end (settings_button);
		sidebar_header.pack_end (search_button);

		sidebar = new Layouts.Sidebar ();

		var sidebar_view = new Adw.ToolbarView ();
		sidebar_view.add_top_bar (sidebar_header);
		sidebar_view.content = sidebar;

		views_stack = new Gtk.Stack () {
			hexpand = true,
			vexpand = true,
			transition_type = Gtk.StackTransitionType.SLIDE_RIGHT,
			transition_duration = 125
		};

		var views_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		views_content.append (views_stack);

        var multiselect_toolbar = new Widgets.MultiSelectToolbar ();

		var views_overlay = new Gtk.Overlay ();
		views_overlay.child = views_content;
		views_overlay.add_overlay (multiselect_toolbar);

		var toast_overlay = new Adw.ToastOverlay ();
		toast_overlay.child = views_overlay;

		overlay_split_view = new Adw.OverlaySplitView ();
		overlay_split_view.content = toast_overlay;
		overlay_split_view.sidebar = sidebar_view;

		set_content (overlay_split_view);
		set_hide_on_close (Services.Settings.get_default ().settings.get_boolean ("run-in-background"));

		Services.Settings.get_default ().settings.bind ("pane-position", overlay_split_view, "min_sidebar_width", GLib.SettingsBindFlags.DEFAULT);
		Services.Settings.get_default ().settings.bind ("slim-mode", overlay_split_view, "show_sidebar", GLib.SettingsBindFlags.DEFAULT);

		Timeout.add (250, () => {
			init_backend ();
			overlay_split_view.show_sidebar = true;
			return GLib.Source.REMOVE;
		});

		var granite_settings = Granite.Settings.get_default ();
		granite_settings.notify["prefers-color-scheme"].connect (() => {
			if (Services.Settings.get_default ().settings.get_boolean ("system-appearance")) {
				Services.Settings.get_default ().settings.set_boolean (
					"dark-mode",
					granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK
					);
				Util.get_default ().update_theme ();
			}
		});

		Services.Settings.get_default ().settings.changed.connect ((key) => {
			if (key == "system-appearance") {
				Services.Settings.get_default ().settings.set_boolean (
					"dark-mode",
					granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK
					);
				Util.get_default ().update_theme ();
			} else if (key == "appearance" || key == "dark-mode") {
				Util.get_default ().update_theme ();
			} else if (key == "run-in-background") {
				set_hide_on_close (Services.Settings.get_default ().settings.get_boolean ("run-in-background"));
			} else if (key == "run-on-startup") {
				bool active = Services.Settings.get_default ().settings.get_boolean ("run-on-startup");
				if (active) {
					Planify.instance.ask_for_background.begin (Xdp.BackgroundFlags.AUTOSTART, (obj, res) => {
						if (Planify.instance.ask_for_background.end (res)) {
							Services.Settings.get_default ().settings.set_boolean ("run-on-startup", true);
						} else {
							Services.Settings.get_default ().settings.set_boolean ("run-on-startup", false);
						}
					});
				} else {
					Planify.instance.ask_for_background.begin (Xdp.BackgroundFlags.NONE, (obj, res) => {
						if (Planify.instance.ask_for_background.end (res)) {
							Services.Settings.get_default ().settings.set_boolean ("run-on-startup", false);
						} else {
							Services.Settings.get_default ().settings.set_boolean ("run-on-startup", false);
						}
					});
				}
			}
		});

		Services.EventBus.get_default ().pane_selected.connect ((pane_type, id) => {
			Services.EventBus.get_default ().unselect_all ();

			if (pane_type == PaneType.PROJECT) {
				add_project_view (Services.Database.get_default ().get_project (id));
			} else if (pane_type == PaneType.FILTER) {
				if (id == FilterType.INBOX.to_string ()) {
					add_inbox_view ();
				} else if (id == FilterType.TODAY.to_string ()) {
					add_today_view ();
				} else if (id == FilterType.SCHEDULED.to_string ()) {
					add_scheduled_view ();
				} else if (id == FilterType.PINBOARD.to_string ()) {
					add_pinboard_view ();
				} else if (id == FilterType.FILTER.to_string ()) {
					add_filters_view ();
				} else if (id.has_prefix ("priority")) {
					add_priority_view (id);
				} else if (id == "completed-view") {
					add_completed_view ();
				}
			} else if (pane_type == PaneType.LABEL) {
				add_label_view (id);
			}

			if (!overlay_split_view.show_sidebar) {
				show_hide_sidebar ();
			}
		});

		Services.EventBus.get_default ().send_notification.connect ((toast) => {
			toast_overlay.add_toast (toast);
		});

		Services.EventBus.get_default ().inbox_project_changed.connect (() => {
			add_inbox_view ();
		});

		settings_popover.show.connect (() => {
			Services.EventBus.get_default ().unselect_all ();
		});

		search_button.clicked.connect (() => {
			var dialog = new Dialogs.QuickFind.QuickFind ();
			dialog.show ();
		});
	}

	public void show_hide_sidebar () {
		overlay_split_view.show_sidebar = !overlay_split_view.show_sidebar;
	}

	private void init_backend () {
		Services.Database.get_default ().init_database ();

		if (Services.Database.get_default ().is_database_empty ()) {
			Util.get_default ().create_inbox_project ();
			Util.get_default ().create_tutorial_project ();
			Util.get_default ().create_default_labels ();
		}

		sidebar.init();

		Services.Notification.get_default ();
		Services.TimeMonitor.get_default ().init_timeout ();

		go_homepage ();

		Services.Database.get_default ().project_deleted.connect (valid_view_removed);

		Services.Todoist.get_default ().first_sync_finished.connect ((inbox_project_id) => {
			var dialog = new Adw.MessageDialog ((Gtk.Window) Planify.instance.main_window,
			                                    _("Tasks synced successfully"), _("Do you want to use Todoist as your default Inbox Project?"));

			dialog.body_use_markup = true;
			dialog.add_response ("cancel", _("Cancel"));
			dialog.add_response ("ok", _("Ok"));
			dialog.set_response_appearance ("ok", Adw.ResponseAppearance.SUGGESTED);
			dialog.show ();

			dialog.response.connect ((response) => {
				change_todoist_default (response == "ok", inbox_project_id);
			});
		});

		if (!Services.Todoist.get_default ().invalid_token ()) {
			Timeout.add (Constants.TODOIST_SYNC_TIMEOUT, () => {
				Services.Todoist.get_default ().run_server ();
				return GLib.Source.REMOVE;
			});
		}
	}

	public Views.Project add_project_view (Objects.Project project) {
		Views.Project? project_view;
		project_view = (Views.Project) views_stack.get_child_by_name (project.view_id);
		if (project_view == null) {
			project_view = new Views.Project (project);
			views_stack.add_named (project_view, project.view_id);
		}

		views_stack.set_visible_child_name (project.view_id);
		return project_view;
	}


	private void add_inbox_view () {
		add_project_view (
			Services.Database.get_default ().get_project (Services.Settings.get_default ().settings.get_string ("inbox-project-id"))
			);
	}

	public void add_today_view () {
		Views.Today? today_view;
		today_view = (Views.Today) views_stack.get_child_by_name ("today-view");
		if (today_view == null) {
			today_view = new Views.Today ();
			views_stack.add_named (today_view, "today-view");
		}

		views_stack.set_visible_child_name ("today-view");
	}

	public void add_scheduled_view () {
		Views.Scheduled.Scheduled? scheduled_view;
		scheduled_view = (Views.Scheduled.Scheduled) views_stack.get_child_by_name ("scheduled-view");
		if (scheduled_view == null) {
			scheduled_view = new Views.Scheduled.Scheduled ();
			views_stack.add_named (scheduled_view, "scheduled-view");
		}

		views_stack.set_visible_child_name ("scheduled-view");
	}

	public void add_pinboard_view () {
		Views.Pinboard? pinboard_view;
		pinboard_view = (Views.Pinboard) views_stack.get_child_by_name ("pinboard-view");
		if (pinboard_view == null) {
			pinboard_view = new Views.Pinboard ();
			views_stack.add_named (pinboard_view, "pinboard-view");
		}

		views_stack.set_visible_child_name ("pinboard-view");
	}

	public void add_filters_view () {
		Views.Labels? labels_view;
		labels_view = (Views.Labels) views_stack.get_child_by_name ("labels-view");
		if (labels_view == null) {
			labels_view = new Views.Labels ();
			views_stack.add_named (labels_view, "labels-view");
		}

		views_stack.set_visible_child_name ("labels-view");
	}

	public void add_priority_view (string view_id) {
		Views.Filter? filter_view;
		filter_view = (Views.Filter) views_stack.get_child_by_name ("priority-view");
		if (filter_view == null) {
			filter_view = new Views.Filter ();
			views_stack.add_named (filter_view, "priority-view");
		}

		filter_view.filter = Util.get_default ().get_priority_filter (view_id);
		views_stack.set_visible_child_name ("priority-view");
	}

	private void add_completed_view () {
		Views.Filter? filter_view;
		filter_view = (Views.Filter) views_stack.get_child_by_name ("completed-view");
		if (filter_view == null) {
			filter_view = new Views.Filter ();
			views_stack.add_named (filter_view, "completed-view");
		}

		filter_view.filter = Objects.Completed.get_default ();
		views_stack.set_visible_child_name ("completed-view");
	}

	private void add_label_view (string id) {
		Views.Label? label_view;
		label_view = (Views.Label) views_stack.get_child_by_name ("label-view");
		if (label_view == null) {
			label_view = new Views.Label ();
			views_stack.add_named (label_view, "label-view");
		}

		label_view.label = Services.Database.get_default ().get_label (id);
		views_stack.set_visible_child_name ("label-view");
	}

	public void go_homepage () {
		Services.EventBus.get_default ().pane_selected (
			PaneType.FILTER,
			Util.get_default ().get_filter ().to_string ()
			);
	}

	public void valid_view_removed (Objects.Project project) {
		Views.Project? project_view;
		project_view = (Views.Project) views_stack.get_child_by_name (project.view_id);
		if (project_view != null) {
			views_stack.remove (project_view);
			go_homepage ();
		}
	}

	public void add_task_action (string content = "") {
		if (views_stack.visible_child_name.has_prefix ("project")) {
			Views.Project? project_view = (Views.Project) views_stack.visible_child;
			if (project_view != null) {
				project_view.prepare_new_item (content);
			}
		} else if (views_stack.visible_child_name.has_prefix ("today-view")) {
			Views.Today? today_view = (Views.Today) views_stack.visible_child;
			if (today_view != null) {
				today_view.prepare_new_item (content);
			}
		} else if (views_stack.visible_child_name.has_prefix ("scheduled-view")) {
			//  Views.Scheduled.Scheduled? scheduled_view = (Views.Scheduled.Scheduled) views_stack.visible_child;
			//  if (scheduled_view != null) {
			//      scheduled_view.prepare_new_item (content);
			//  }
		} else if (views_stack.visible_child_name.has_prefix ("pinboard-view")) {
			//  Views.Pinboard? pinboard_view = (Views.Pinboard) views_stack.visible_child;
			//  if (pinboard_view != null) {
			//      pinboard_view.prepare_new_item (content);
			//  }
		} else if (views_stack.visible_child_name.has_prefix ("tasklist")) {
			//  Views.Tasklist? tasklist_view = (Views.Tasklist) views_stack.visible_child;
			//  if (tasklist_view != null) {
			//      tasklist_view.prepare_new_item (content);
			//  }
		}
	}

	public void new_section_action () {
		if (!views_stack.visible_child_name.has_prefix ("project")) {
			return;
		}

		Views.Project? project_view = (Views.Project) views_stack.visible_child;
		if (project_view != null) {
			Objects.Section new_section = project_view.project.prepare_new_section ();

			if (project_view.project.backend_type == BackendType.TODOIST) {
				Services.Todoist.get_default ().add.begin (new_section, (obj, res) => {
					new_section.id = Services.Todoist.get_default ().add.end (res);
					project_view.project.add_section_if_not_exists (new_section);
				});
			} else {
				new_section.id = Util.get_default ().generate_id ();
				project_view.project.add_section_if_not_exists (new_section);
			}
		}
	}

	private void change_todoist_default (bool use_todoist, string inbox_project_id) {
		if (use_todoist) {
			var old_inbox_project = Services.Database.get_default ().get_project (Services.Settings.get_default ().settings.get_string ("inbox-project-id"));
			old_inbox_project.inbox_project = false;
			old_inbox_project.update ();

			var new_inbox_project = Services.Database.get_default ().get_project (inbox_project_id);
			new_inbox_project.inbox_project = true;
			old_inbox_project.update ();

			Services.Settings.get_default ().settings.set_string ("inbox-project-id", inbox_project_id);
			Services.Settings.get_default ().settings.set_enum ("default-inbox", DefaultInboxProject.TODOIST);
			Services.EventBus.get_default ().inbox_project_changed ();

			if (views_stack.visible_child_name == old_inbox_project.view_id) {
				add_project_view (new_inbox_project);
			}
		}
	}

	private Gtk.Popover build_menu_app () {
		var preferences_item = new Widgets.ContextMenu.MenuItem (_("Preferences"));
		// preferences_item.tooltip_markup = Granite.markup_accel_tooltip ({"<Control>comma"}, _("Preferences"));
		preferences_item.add_css_class ("no-font-bold");

		var keyboard_shortcuts_item = new Widgets.ContextMenu.MenuItem (_("Keyboard shortcuts"));
		// keyboard_shortcuts_item.tooltip_markup = Granite.markup_accel_tooltip ({"F1"}, _("Keyboard shortcuts"));
		keyboard_shortcuts_item.add_css_class ("no-font-bold");

		var about_item = new Widgets.ContextMenu.MenuItem (_("About Planify"));
		about_item.add_css_class ("no-font-bold");

		var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		menu_box.margin_top = menu_box.margin_bottom = 3;
		menu_box.append (preferences_item);
		menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
		menu_box.append (keyboard_shortcuts_item);
		menu_box.append (about_item);

		var popover = new Gtk.Popover () {
			has_arrow = true,
			child = menu_box,
			position = Gtk.PositionType.BOTTOM
		};

		preferences_item.clicked.connect (() => {
			popover.popdown ();

			var dialog = new Dialogs.Preferences.PreferencesWindow ();
			dialog.show ();
		});

		about_item.clicked.connect (() => {
			popover.popdown ();
			about_dialog ();
		});

		keyboard_shortcuts_item.clicked.connect (() => {
			popover.popdown ();
			open_shortcuts_window ();
		});

		return popover;
	}

	public void open_shortcuts_window () {
		try {
			var build = new Gtk.Builder ();
			build.add_from_resource ("/io/github/alainm23/planify/shortcuts.ui");
			var window = (Gtk.ShortcutsWindow) build.get_object ("shortcuts-planify");
			window.set_transient_for (this);
			window.show ();
		} catch (Error e) {
			warning ("Failed to open shortcuts window: %s\n", e.message);
		}
	}

	private void about_dialog () {
		var dialog = new Adw.AboutWindow () {
			transient_for = (Gtk.Window) Planify.instance.main_window,
			modal = true
		};

		dialog.show ();

		dialog.application_icon = "io.github.alainm23.planify";
		dialog.application_name = "Planify";
		dialog.version = Constants.VERSION;
		dialog.developer_name = "Alain Meza H.";
		dialog.website = "https://github.com/alainm23/planner";
		dialog.developers = { "Alain" };
		dialog.issue_url = "https://github.com/alainm23/planner/issues";
	}
}

public class QuickAdd : Adw.Application {
    public MainWindow main_window;

    public static QuickAdd _instance = null;
    public static QuickAdd instance {
        get {
            if (_instance == null) {
                _instance = new QuickAdd ();
            }
            return _instance;
        }
    }
    
    construct {
        application_id = "io.github.alainm23.planify.quick-add";
        flags |= ApplicationFlags.FLAGS_NONE;
    }

    protected override void activate () {
        main_window = new MainWindow (this);
        main_window.show ();
        
        var quit_action = new SimpleAction ("quit", null);

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"Escape"});

        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.hide ();

                Timeout.add (500, () => {
                    main_window.destroy ();
                    return GLib.Source.REMOVE;
                });
            }
        });
        
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/github/alainm23/planify/index.css");
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        Util.get_default ().update_theme ();
    }

    public static int main (string[] args) {
        QuickAdd app = QuickAdd.instance;
        return app.run (args);
    }
}

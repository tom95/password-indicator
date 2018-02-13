
public errordomain DecryptError {
    WRONG_PASSPHRASE,
    UNKNOWN
}

public class Password.Services.Watcher : Object {

    public string root_path { get; construct set; }

    public signal void added (string file);
    public signal void removed (string file);

    public Watcher (string root_path) {
        Object (root_path: root_path);
    }

    construct {
        var file = File.new_for_path (root_path);

        try {
            file.monitor_directory (FileMonitorFlags.NONE, null).changed.connect (handler);
        } catch (Error e) {
            critical (e.message);
        }
    }

    void handler (File src, File? dest, FileMonitorEvent event) {
        switch (event) {
            case FileMonitorEvent.DELETED:
                removed (truncate_absolute_path (src.get_path ()));
                break;
            case FileMonitorEvent.CREATED:
                added (truncate_absolute_path (src.get_path ()));
                break;
        }
    }

    public async List<string> fetch_file_list () {
        var all_file_names = new List<string> ();

        var folders = new Queue<File> ();
        folders.push_tail (File.new_for_path (root_path));

        try {
            File folder;
            while ((folder = folders.pop_head()) != null) {
                var base_path = folder.get_path ();
                var enumerator = yield folder.enumerate_children_async (
                    FileAttribute.STANDARD_NAME, 0, Priority.DEFAULT);

                while (true) {
                    var files = yield enumerator.next_files_async (10, Priority.DEFAULT);
                    if (files == null) {
                        break;
                    }
                    foreach (var file in files) {
                        if (file.get_file_type () == FileType.DIRECTORY) {
                            folders.push_tail (folder.get_child (file.get_name ()));
                        } else {
                            all_file_names.prepend (
                                truncate_absolute_path (base_path + "/" + file.get_name ()));
                        }
                    }
                }
            }
        } catch (Error err) {
            // TODO
            critical ("Fatal error: %s\n", err.message);
        }

        return all_file_names;
    }

    /**
     * Remove prefix to home directory and password directory and .gpg ending
     */
    string truncate_absolute_path (string path) {
        return path.slice(root_path.length + 1, path.length - 4);
    }

    public async string decrypt_file (string relative_path, string passphrase) throws DecryptError {
        SourceFunc async_callback = decrypt_file.callback;
        var path = root_path + "/" + relative_path + ".gpg";

        string output = "";
        int stdout, stdin, stderr, exit_status = 0;
        Pid pid;

        /* FIXME
         * this is likely the most sensitive part of this program. we can't use
         * gpg2 here if we want to use our own password entry, because it keeps
         * spawning the gpg-agent window. using gpg, however, works just as well.
         */
        try {
            Process.spawn_async_with_pipes (null, {
                "gpg",
                "--quiet",
                "--yes",
                "--compress-algo=none",
                "--no-encrypt-to",
                "--batch",
                "--passphrase-fd=0",
                "-d",
                path
            }, Environ.get (), SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid, out stdin, out stdout, out stderr);
        } catch (Error e) {
            critical (e.message);
            throw new DecryptError.UNKNOWN (_("Unknown error occured."));
        }

        new IOChannel.unix_new (stderr).add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
            if (condition == IOCondition.HUP) {
                return false;
            }
            try {
                string line;
                channel.read_line (out line, null, null);
                warning ("Decrypt stderr: %s", line);
            } catch (Error e) {
                critical (e.message);
            }
            return true;
        });
        new IOChannel.unix_new (stdout).add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
            if (condition == IOCondition.HUP) {
                return false;
            }
            try {
                string line;
                channel.read_line (out line, null, null);
                output += line;
            } catch (Error e) {
                critical (e.message);
            }
            return true;
        });
        ChildWatch.add (pid, (p, status) => {
            exit_status = status;
            Process.close_pid (p);
            Idle.add ((owned) async_callback);
        });

        var input = new IOChannel.unix_new (stdin);
        try {
            input.write_chars (passphrase.to_utf8(), null);
            input.shutdown (true);
        } catch (Error e) {
            critical (e.message);
            throw new DecryptError.UNKNOWN (_("Unknown error occured."));
        }

        yield;

        if (exit_status == 512) {
            throw new DecryptError.WRONG_PASSPHRASE (_("Wrong passphrase entered."));
        } else if (exit_status != 0) {
            throw new DecryptError.UNKNOWN (_("Unknown error occured."));
        }

        return output;
    }
}

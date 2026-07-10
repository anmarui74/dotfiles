import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup';
import { ExtensionPreferences } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

export default class ZipeWeatherPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();

        const page = new Adw.PreferencesPage({
            title: 'Ubicación',
        });

        const group = new Adw.PreferencesGroup({
            title: 'Ciudad',
            description: 'Busca y selecciona tu ubicación',
        });

        const cityLabel = new Gtk.Label({
            label: `<b>Ciudad actual:</b> ${settings.get_string('city-name')}`,
            use_markup: true,
            halign: Gtk.Align.START,
            margin_bottom: 8,
        });
        group.add(cityLabel);

        const entry = new Gtk.SearchEntry({
            placeholder_text: 'Buscar ciudad...',
        });
        group.add(entry);

        const scrolled = new Gtk.ScrolledWindow({
            vexpand: true,
            min_content_height: 200,
        });
        const listbox = new Gtk.ListBox();
        scrolled.set_child(listbox);
        group.add(scrolled);

        const statusLabel = new Gtk.Label({
            halign: Gtk.Align.START,
            margin_top: 8,
        });
        group.add(statusLabel);

        listbox.connect('row-activated', (_box, row) => {
            settings.set_double('latitude', row._lat);
            settings.set_double('longitude', row._lon);
            settings.set_string('city-name', row._name);
            cityLabel.label = `<b>Ciudad actual:</b> ${row._name}`;
            statusLabel.label = '✓ Ubicación guardada.';
        });

        let searchTimeout = 0;

        entry.connect('search-changed', () => {
            const text = entry.text;
            if (!text || text.length < 2) return;

            if (searchTimeout) GLib.source_remove(searchTimeout);
            searchTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
                searchTimeout = 0;
                doSearch(text, listbox, statusLabel);
                return GLib.SOURCE_REMOVE;
            });
        });

        page.add(group);
        window.add(page);
    }
}

function doSearch(query, listbox, statusLabel) {
    statusLabel.label = 'Buscando...';

    while (listbox.get_first_child()) {
        listbox.remove(listbox.get_first_child());
    }

    const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=8&language=es&format=json`;
    const session = new Soup.Session();
    const msg = Soup.Message.new('GET', url);

    session.send_and_read_async(msg, GLib.PRIORITY_DEFAULT, null, (_session, result) => {
        try {
            const bytes = _session.send_and_read_finish(result);
            const text = new TextDecoder().decode(bytes.toArray());
            const data = JSON.parse(text);

            while (listbox.get_first_child()) {
                listbox.remove(listbox.get_first_child());
            }

            if (!data.results || data.results.length === 0) {
                statusLabel.label = 'No se encontraron resultados.';
                return;
            }

            statusLabel.label = `Se encontraron ${data.results.length} resultados:`;

            for (const r of data.results) {
                const name = [r.name, r.admin1, r.country].filter(Boolean).join(', ');
                const row = new Gtk.ListBoxRow();
                const label = new Gtk.Label({
                    label: name,
                    halign: Gtk.Align.START,
                    margin_start: 8,
                    margin_end: 8,
                    margin_top: 4,
                    margin_bottom: 4,
                });
                row.set_child(label);
                row._lat = r.latitude;
                row._lon = r.longitude;
                row._name = `${r.name}${r.admin1 ? ` (${r.admin1})` : ''}, ${r.country}`;
                listbox.append(row);
            }
        } catch (e) {
            statusLabel.label = `Error: ${e.message || e}`;
        }
    });
}

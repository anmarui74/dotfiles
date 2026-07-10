import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const WMO_DESC = {
  0: 'Despejado',
  1: 'Mayormente despejado',
  2: 'Parcialmente nublado',
  3: 'Nublado',
  45: 'Niebla',
  48: 'Niebla escarchada',
  51: 'Llovizna ligera',
  53: 'Llovizna moderada',
  61: 'Lluvia ligera',
  63: 'Lluvia moderada',
  65: 'Lluvia fuerte',
  71: 'Nieve ligera',
  73: 'Nieve moderada',
  75: 'Nieve fuerte',
  80: 'Chubascos ligeros',
  81: 'Chubascos moderados',
  82: 'Chubascos violentos',
  85: 'Chubascos de nieve',
  86: 'Chubascos de nieve',
  95: 'Tormenta',
  96: 'Tormenta con granizo',
  99: 'Tormenta con granizo',
};

const WMO_ICON = {
  0: 'weather-clear',
  1: 'weather-few-clouds',
  2: 'weather-few-clouds',
  3: 'weather-overcast',
  45: 'weather-fog',
  48: 'weather-fog',
  51: 'weather-showers-scattered',
  53: 'weather-showers-scattered',
  55: 'weather-showers-scattered',
  61: 'weather-showers',
  63: 'weather-showers',
  65: 'weather-showers',
  71: 'weather-snow',
  73: 'weather-snow',
  75: 'weather-snow',
  80: 'weather-showers-scattered',
  81: 'weather-showers',
  82: 'weather-showers',
  85: 'weather-snow-scattered',
  86: 'weather-snow-scattered',
  95: 'weather-storm',
  96: 'weather-storm',
  99: 'weather-storm',
};

function getIconName(code) {
  return WMO_ICON[code] || 'weather-clear';
}

function getDesc(code) {
  return WMO_DESC[code] || 'Desconocido';
}

function formatDate(dateStr) {
  const d = new Date(dateStr + 'T12:00:00');
  const hoy = new Date();
  hoy.setHours(12, 0, 0, 0);
  if (d.getTime() === hoy.getTime()) return 'Hoy';
  const dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  return `${dias[d.getDay()]} ${d.getDate()}/${d.getMonth() + 1}`;
}

function buildUrl(lat, lon) {
  return `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weathercode&daily=temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum,precipitation_probability_max,wind_speed_10m_max&timezone=auto&forecast_days=10`;
}

const ZipeWeatherIndicator = GObject.registerClass(
  class ZipeWeatherIndicator extends PanelMenu.Button {
    _init(settings) {
      super._init(0.0, 'Tiempo — 30°', false);
      log('Zipe Weather: init start');

      this._settings = settings;

      try {
        this.set_size(100, -1);
      } catch (e) {
        log('Zipe Weather: set_size error - ' + e);
      }

      this.set_style('min-width: 130px; padding: 0 6px;');

      const box = new St.BoxLayout({ style_class: 'zipe-panel-box' });

      this._icon = new St.Icon({
        icon_name: 'weather-clear',
        icon_size: 15,
        y_align: Clutter.ActorAlign.CENTER,
        style_class: 'zipe-panel-icon',
      });
      box.add_child(this._icon);

      this._label = new St.Label({
        text: '30°',
        y_align: Clutter.ActorAlign.CENTER,
        style_class: 'zipe-panel-label',
      });
      box.add_child(this._label);

      this.add_child(box);

      this._settings.connect('changed', () => {
        log('Zipe Weather: settings changed, refetching');
        this._fetchWeather();
      });

      this.menu.setSourceAlignment(0.5);
      this.menu._arrowAlignment = 0.5;
      if (this.menu.box) {
          this.menu.box.add_style_class_name('zipe-menu-content');
      }
      log('Zipe Weather: init calling fetch');
      this._fetchWeather();
      this._timeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 3600, () => {
        this._fetchWeather();
        return GLib.SOURCE_CONTINUE;
      });
      log('Zipe Weather: init done');
    }

    _fetchWeather() {
      const lat = this._settings.get_double('latitude');
      const lon = this._settings.get_double('longitude');
      const url = buildUrl(lat, lon);

      const session = new Soup.Session();
      const message = Soup.Message.new('GET', url);
      session.send_and_read_async(message, GLib.PRIORITY_DEFAULT, null, (_session, result) => {
        try {
          const bytes = _session.send_and_read_finish(result);
          const text = new TextDecoder().decode(bytes.toArray());
          const data = JSON.parse(text);
          this._updateUI(data);
        } catch (e) {
          log('Zipe Weather: error - ' + (e.message || e));
          this._label.text = '⚠️';
        }
      });
    }

    _updateUI(data) {
      if (!data || !data.daily) return;

      this.menu.removeAll();

      const daily = data.daily;
      const tempsMax = daily.temperature_2m_max;
      const tempsMin = daily.temperature_2m_min;
      const codes = daily.weathercode;
      const precips = daily.precipitation_sum;
      const winds = daily.wind_speed_10m_max;
      const precipProbs = daily.precipitation_probability_max;
      const times = daily.time;
      const city = this._settings.get_string('city-name');

      const tempActual = data.current ? Math.round(data.current.temperature_2m) : Math.round(tempsMax[0]);
      const iconName = getIconName(data.current ? data.current.weathercode : codes[0]);
      this._icon.icon_name = iconName;
      this._label.text = `${tempActual}°`;
      this.accessible_name = `${city} — ${tempActual}°C`;

      for (let i = 0; i < times.length; i++) {
        const item = new PopupMenu.PopupBaseMenuItem();

        const hbox = new St.BoxLayout({ style_class: 'zipe-item-box' });

        const fecha = formatDate(times[i]);
        const maxT = Math.round(tempsMax[i]);
        const minT = Math.round(tempsMin[i]);
        const probLluvia = `${precipProbs[i]}%`;
        const lluvia = `${precips[i].toFixed(1)} mm`;
        const viento = `${Math.round(winds[i])} km/h`;

        const fechaLabel = new St.Label({ text: fecha, style_class: 'zipe-col-fecha' });
        hbox.add_child(fechaLabel);

        const ico = new St.Icon({
          icon_name: getIconName(codes[i]),
          icon_size: 16,
        });
        hbox.add_child(ico);

        const tempLabel = new St.Label({ text: `${minT}° / ${maxT}°`, style_class: 'zipe-col-temp' });
        hbox.add_child(tempLabel);

        const lluviaLabel = new St.Label({ text: `💧${probLluvia}`, style_class: 'zipe-col-precip' });
        hbox.add_child(lluviaLabel);

        const vientoLabel = new St.Label({ text: `🌬${viento}`, style_class: 'zipe-col-wind' });
        hbox.add_child(vientoLabel);

        item.add_child(hbox);
        this.menu.addMenuItem(item);
      }

      this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
      const sourceItem = new PopupMenu.PopupMenuItem(`${city} — Datos: Open-Meteo.com`);
      sourceItem.reactive = false;
      sourceItem.label.add_style_class_name('zipe-weather-source');
      this.menu.addMenuItem(sourceItem);
    }

    destroy() {
      if (this._timeout) {
        GLib.source_remove(this._timeout);
        this._timeout = null;
      }
      super.destroy();
    }
  }
);

export default class ZipeWeatherExtension extends Extension {
  enable() {
    log('Zipe Weather: enabling');
    this._settings = this.getSettings();
    this._indicator = new ZipeWeatherIndicator(this._settings);
    Main.panel.addToStatusArea('zipe-weather', this._indicator, 0, 'right');
  }

  disable() {
    if (this._indicator) {
      this._indicator.destroy();
      this._indicator = null;
    }
    this._settings = null;
  }
}

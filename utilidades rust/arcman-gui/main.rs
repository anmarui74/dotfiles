use iced::{
    widget::{
        button, column, container, horizontal_rule, horizontal_space, row,
        scrollable, space::Space, text, text_input, vertical_space,
    },
    Alignment, Application, Background, Border, Color, Command, Element, Font,
    Length, Settings, Theme, executor, theme,
};
use std::borrow::Cow;
use std::process::Command as StdCmd;

const APP_NAME: &str = "arcman — Gestor de paquetes";

// ─── Icono ──────────────────────────────────────────────────────────

fn generate_icon() -> Vec<u8> {
    let size = 32u32;
    let mut pixels = Vec::with_capacity((size * size * 4) as usize);
    let cx = size as f64 / 2.0;
    let cy = size as f64 / 2.0;
    let outer_r = 14.0;
    let inner_r = 10.0;

    for y in 0..size {
        for x in 0..size {
            let dx = x as f64 - cx;
            let dy = y as f64 - cy;
            let dist = (dx * dx + dy * dy).sqrt();

            let (r, g, b, a) = if dist <= inner_r {
                // Centro — color de acento
                (0.22, 0.52, 0.86, 1.0)
            } else if dist <= outer_r {
                // Borde degradado
                let t = (dist - inner_r) / (outer_r - inner_r);
                let r = 0.22 + t * (0.60 - 0.22);
                let g = 0.52 + t * (0.30 - 0.52);
                let b = 0.86 + t * (0.10 - 0.86);
                (r, g, b, 1.0)
            } else {
                (0.0, 0.0, 0.0, 0.0)
            };
            pixels.push((r * 255.0) as u8);
            pixels.push((g * 255.0) as u8);
            pixels.push((b * 255.0) as u8);
            pixels.push((a * 255.0) as u8);
        }
    }
    pixels
}

// ─── Helpers ───────────────────────────────────────────────────────

fn strip_ansi(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut i = 0;
    let bytes = s.as_bytes();
    while i < bytes.len() {
        let b = bytes[i];
        if b == 0x1b {
            i += 1;
            if i < bytes.len() {
                match bytes[i] {
                    0x5b => {
                        // CSI: ESC [ params... letter
                        i += 1;
                        while i < bytes.len() {
                            let c = bytes[i];
                            if c.is_ascii_alphabetic() || c == 0x7e {
                                i += 1;
                                break;
                            }
                            i += 1;
                        }
                    }
                    0x5d => {
                        // OSC: ESC ] ... (terminated by BEL or ST)
                        i += 1;
                        while i < bytes.len() {
                            if bytes[i] == 0x07 {
                                i += 1;
                                break;
                            }
                            if bytes[i] == 0x1b && i + 1 < bytes.len() && bytes[i + 1] == 0x5c {
                                i += 2;
                                break;
                            }
                            i += 1;
                        }
                    }
                    _ => {
                        // Otros ESC (una sola letra)
                        i += 1;
                    }
                }
            }
        } else if b == 0x9b {
            // CSI 8-bit
            i += 1;
            while i < bytes.len() {
                let c = bytes[i];
                if c.is_ascii_alphabetic() || c == 0x7e {
                    i += 1;
                    break;
                }
                i += 1;
            }
        } else {
            out.push(b as char);
            i += 1;
        }
    }
    out
}

fn which(name: &str) -> bool {
    std::env::split_paths(&std::env::var_os("PATH").unwrap_or_default())
        .any(|d| d.join(name).exists())
}

fn detect_pm() -> &'static str {
    if which("yay") {
        "yay"
    } else if which("paru") {
        "paru"
    } else if which("pacman") {
        "pacman"
    } else {
        "none"
    }
}

fn system_is_dark() -> bool {
    if let Ok(out) = StdCmd::new("gsettings")
        .args(["get", "org.gnome.desktop.interface", "color-scheme"])
        .output()
    {
        let s = String::from_utf8_lossy(&out.stdout);
        if s.contains("dark") || s.contains("prefer-dark") {
            return true;
        }
    }
    true
}

async fn run_cmd(cmd: String, args: Vec<String>) -> Result<String, String> {
    let cmd_name = cmd.clone();
    let output = tokio::task::spawn_blocking(move || {
        StdCmd::new(&cmd).args(&args).output()
    })
    .await
    .map_err(|e| format!("Error interno: {e}"))?
    .map_err(|e| format!("Error al ejecutar '{cmd_name}': {e}"))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    let combined = strip_ansi(&format!("{stdout}{stderr}"));

    if output.status.success() || output.status.code() == Some(1) {
        Ok(combined)
    } else {
        Err(combined)
    }
}

async fn run_priv(cmd: String, args: Vec<String>) -> Result<String, String> {
    if which("pkexec") {
        let mut pkexec_args = vec![cmd];
        pkexec_args.extend(args);
        run_cmd("pkexec".to_string(), pkexec_args).await
    } else {
        Err("Se necesita pkexec (PolicyKit) para operaciones privilegiadas.\nInstala polkit o ejecuta el comando manualmente en una terminal.".to_string())
    }
}

// ─── App ───────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq)]
enum Screen {
    Status,
    Update,
    Search,
    Install,
    Remove,
    Orphans,
    Clean,
    Full,
    About,
}

#[derive(Debug, Clone)]
enum PendingAction {
    Install(Vec<String>),
    Remove(Vec<String>),
    Update,
    OrphansClean(Vec<String>),
    Clean,
    Full,
}

struct Confirmation {
    action: PendingAction,
    description: String,
}

struct App {
    screen: Screen,
    theme: Theme,
    loading: bool,
    output: String,
    error: Option<String>,
    search_query: String,
    pkg_input: String,
    confirmation: Option<Confirmation>,
    orphans_found: Vec<String>,
}

#[derive(Debug, Clone)]
enum Message {
    Navigate(Screen),
    ToggleTheme,
    SearchInputChanged(String),
    PkgInputChanged(String),
    RunStatus,
    RunUpdate,
    RunSearch,
    RunInstall,
    RunRemove,
    RunOrphans,
    RunOrphansClean,
    RunClean,
    RunFull,
    ConfirmAction,
    CancelAction,
    TaskResult(Result<String, String>),
}

impl Application for App {
    type Message = Message;
    type Flags = ();
    type Executor = executor::Default;
    type Theme = Theme;

    fn new(_flags: ()) -> (Self, Command<Message>) {
        let theme = if system_is_dark() {
            Theme::Dark
        } else {
            Theme::Light
        };
        (
            App {
                screen: Screen::Status,
                theme,
                loading: false,
                output: String::new(),
                error: None,
                search_query: String::new(),
                pkg_input: String::new(),
                confirmation: None,
                orphans_found: Vec::new(),
            },
            Command::none(),
        )
    }

    fn title(&self) -> String {
        APP_NAME.to_string()
    }

    fn update(&mut self, msg: Message) -> Command<Message> {
        match msg {
            Message::Navigate(s) => {
                self.screen = s;
                self.output.clear();
                self.error = None;
                self.confirmation = None;
                self.orphans_found.clear();
                Command::none()
            }
            Message::ToggleTheme => {
                self.theme = match self.theme {
                    Theme::Dark => Theme::Light,
                    _ => Theme::Dark,
                };
                Command::none()
            }
            Message::SearchInputChanged(v) => {
                self.search_query = v;
                Command::none()
            }
            Message::PkgInputChanged(v) => {
                self.pkg_input = v;
                Command::none()
            }
            Message::RunStatus => {
                self.loading = true;
                self.output.clear();
                self.error = None;
                Command::perform(
                    async {
                        let pm = detect_pm();
                        let mut out =
                            format!("Gestor de paquetes: {pm}\n");
                        out.push_str(&format!(
                            "yay:        {}\n",
                            if which("yay") { "✓" } else { "✗" }
                        ));
                        out.push_str(&format!(
                            "paru:       {}\n",
                            if which("paru") { "✓" } else { "✗" }
                        ));
                        out.push_str(&format!(
                            "paccache:   {}\n\n",
                            if which("paccache") { "✓" } else { "✗" }
                        ));
                        out.push_str("Comprobando actualizaciones...\n");
                        let result = tokio::task::spawn_blocking(|| {
                            StdCmd::new("pacman").args(["-Qu", "--color", "never"]).output()
                        })
                        .await;
                        match result {
                            Ok(Ok(output)) => {
                                let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                                let lines: Vec<&str> =
                                    stdout.lines().filter(|l| !l.is_empty()).collect();
                                if lines.is_empty() {
                                    out.push_str("Sistema actualizado.\n");
                                } else {
                                    out.push_str(&format!(
                                        "{} actualizaciones disponibles:\n",
                                        lines.len()
                                    ));
                                    for l in lines.iter().take(25) {
                                        out.push_str(l);
                                        out.push('\n');
                                    }
                                }
                            }
                            _ => out.push_str("No se pudo comprobar actualizaciones.\n"),
                        }
                        Ok(out)
                    },
                    Message::TaskResult,
                )
            }
            Message::RunUpdate => {
                self.confirmation = Some(Confirmation {
                    action: PendingAction::Update,
                    description: "Actualizar todos los paquetes del sistema".to_string(),
                });
                Command::none()
            }
            Message::RunSearch => {
                let q = self.search_query.trim().to_string();
                if q.is_empty() {
                    self.error = Some("Ingresa un termino de busqueda.".to_string());
                    return Command::none();
                }
                self.loading = true;
                self.output.clear();
                self.error = None;
                Command::perform(
                    async move {
                        let pm = detect_pm().to_string();
                        run_cmd(pm, vec!["-Ss".to_string(), "--color=never".to_string(), q]).await
                    },
                    Message::TaskResult,
                )
            }
            Message::RunInstall => {
                let pkgs: Vec<String> =
                    self.pkg_input.split_whitespace().map(String::from).collect();
                if pkgs.is_empty() {
                    self.error = Some("Ingresa uno o mas paquetes.".to_string());
                    return Command::none();
                }
                self.confirmation = Some(Confirmation {
                    action: PendingAction::Install(pkgs),
                    description: format!("Instalar: {}", self.pkg_input),
                });
                Command::none()
            }
            Message::RunRemove => {
                let pkgs: Vec<String> =
                    self.pkg_input.split_whitespace().map(String::from).collect();
                if pkgs.is_empty() {
                    self.error = Some("Ingresa uno o mas paquetes.".to_string());
                    return Command::none();
                }
                self.confirmation = Some(Confirmation {
                    action: PendingAction::Remove(pkgs),
                    description: format!("Eliminar: {}", self.pkg_input),
                });
                Command::none()
            }
            Message::RunOrphans => {
                self.loading = true;
                self.output.clear();
                self.error = None;
                self.orphans_found.clear();
                Command::perform(
                    async {
                        let result = tokio::task::spawn_blocking(|| {
                            StdCmd::new("pacman").args(["-Qtdq", "--color", "never"]).output()
                        })
                        .await;
                        match result {
                            Ok(Ok(output)) => {
                                let s = String::from_utf8_lossy(&output.stdout).to_string();
                                if s.trim().is_empty() {
                                    Ok("No hay paquetes huerfanos.".to_string())
                                } else {
                                    Ok(s.trim().to_string())
                                }
                            }
                            _ => Ok("No hay paquetes huerfanos.".to_string()),
                        }
                    },
                    Message::TaskResult,
                )
            }
            Message::RunOrphansClean => {
                let orphans = self.orphans_found.clone();
                if orphans.is_empty() {
                    self.error = Some("No hay huerfanos para eliminar.".to_string());
                    return Command::none();
                }
                self.confirmation = Some(Confirmation {
                    action: PendingAction::OrphansClean(orphans),
                    description: format!("Eliminar paquetes huerfanos"),
                });
                Command::none()
            }
            Message::RunClean => {
                self.confirmation = Some(Confirmation {
                    action: PendingAction::Clean,
                    description: "Limpiar cache de pacman".to_string(),
                });
                Command::none()
            }
            Message::RunFull => {
                self.confirmation = Some(Confirmation {
                    action: PendingAction::Full,
                    description: "Mantenimiento completo: actualizar + limpiar cache + eliminar huerfanos".to_string(),
                });
                Command::none()
            }
            Message::ConfirmAction => {
                if let Some(conf) = self.confirmation.take() {
                    self.loading = true;
                    self.output.clear();
                    self.error = None;
                    if self.screen == Screen::Orphans {
                        self.orphans_found.clear();
                    }
                    return Self::run_pending_action(conf.action);
                }
                Command::none()
            }
            Message::CancelAction => {
                self.confirmation = None;
                Command::none()
            }
            Message::TaskResult(result) => {
                self.loading = false;
                match result {
                    Ok(out) => self.output = out,
                    Err(e) => self.output = e,
                }
                if self.screen == Screen::Orphans {
                    self.orphans_found = self
                        .output
                        .lines()
                        .filter(|l| {
                            !l.is_empty() && l != &"No hay paquetes huerfanos."
                        })
                        .map(String::from)
                        .collect();
                }
                Command::none()
            }
        }
    }

    fn view(&self) -> Element<'_, Message> {
        if self.confirmation.is_some() {
            return self.render_confirm_dialog();
        }

        let sidebar = self.render_sidebar();
        let content = match self.screen {
            Screen::Status => self.render_status(),
            Screen::Update => self.render_update(),
            Screen::Search => self.render_search(),
            Screen::Install => self.render_install(),
            Screen::Remove => self.render_remove(),
            Screen::Orphans => self.render_orphans(),
            Screen::Clean => self.render_clean(),
            Screen::Full => self.render_full(),
            Screen::About => self.render_about(),
        };

        let content = container(content)
            .width(Length::Fill)
            .height(Length::Fill)
            .padding(25);

        container(row![sidebar, content].height(Length::Fill))
            .height(Length::Fill)
            .into()
    }

    fn theme(&self) -> Theme {
        self.theme.clone()
    }
}

// ─── View helpers ──────────────────────────────────────────────────

impl App {
    fn render_sidebar(&self) -> Element<'_, Message> {
        let palette = self.theme.palette();
        let bg = Color {
            r: palette.background.r * 0.95,
            g: palette.background.g * 0.95,
            b: palette.background.b * 0.95,
            a: 1.0,
        };

        let nav_items: [(Screen, &str); 9] = [
            (Screen::Status,    "\u{F0AD}  Estado"),
            (Screen::Update,    "\u{F021}  Actualizar"),
            (Screen::Search,    "\u{F002}  Buscar"),
            (Screen::Install,   "\u{F067}  Instalar"),
            (Screen::Remove,    "\u{F1F8}  Eliminar"),
            (Screen::Orphans,   "\u{F0F0}  Huerfanos"),
            (Screen::Clean,     "\u{F12D}  Limpiar"),
            (Screen::Full,      "\u{F005}  Completo"),
            (Screen::About,     "\u{F05A}  Acerca de"),
        ];

        let mut col = column![
            text("arcman").size(22),
            text("Gestor de paquetes").size(11).style(Color::from_rgb(0.5, 0.5, 0.5)),
            horizontal_rule(1),
            Space::with_height(6.0),
        ]
        .spacing(2)
        .padding(15)
        .width(180);

        for (screen, label) in &nav_items {
            let is_active = self.screen == *screen;
            let btn = button(text(*label).size(14))
                .width(Length::Fill)
                .padding(10)
                .on_press(Message::Navigate(screen.clone()));
            let btn: iced::widget::Button<'_, Message> = if is_active {
                btn.style(theme::Button::Primary)
            } else {
                btn.style(theme::Button::Text)
            };
            col = col.push(btn);
        }

        let theme_label = match self.theme {
            Theme::Dark => "Claro",
            _ => "Oscuro",
        };

        col = col
            .push(vertical_space())
            .push(horizontal_rule(1))
            .push(Space::with_height(5.0))
            .push(
                row![
                    text("Tema:").size(13),
                    horizontal_space(),
                    button(text(theme_label).size(13))
                        .style(theme::Button::Secondary)
                        .on_press(Message::ToggleTheme),
                ]
                .align_items(Alignment::Center),
            );

        container(col)
            .height(Length::Fill)
            .style(move |_: &Theme| container::Appearance {
                background: Some(Background::Color(bg)),
                ..Default::default()
            })
            .into()
    }

    fn page_content<'a>(&'a self, title: &str, desc: &str, body: Element<'a, Message>) -> Element<'a, Message> {
        let mut c = column![
            text(title).size(24),
            Space::with_height(4.0),
            text(desc).size(14),
            Space::with_height(15.0),
            body,
        ]
        .spacing(5);

        if let Some(ref err) = self.error {
            c = c.push(Space::with_height(5.0));
            c = c.push(
                container(text(err).style(Color::from_rgb(0.9, 0.3, 0.3)))
                    .padding(10)
                    .width(Length::Fill),
            );
        }

        if self.loading {
            c = c.push(Space::with_height(10.0));
            c = c.push(
                container(text("Procesando..."))
                    .padding(8)
                    .center_x(),
            );
        }

        if !self.output.is_empty() {
            c = c.push(Space::with_height(10.0));
            c = c.push(self.render_output(&self.output));
        }

        scrollable(container(c).width(Length::Fill)).into()
    }

    fn render_output(&self, content: &str) -> Element<'_, Message> {
        let palette = self.theme.palette();
        let bg = Color {
            r: palette.background.r * 0.9,
            g: palette.background.g * 0.9,
            b: palette.background.b * 0.9,
            a: 1.0,
        };

        container(
            scrollable(
                container(text(content).size(13))
                    .padding(15)
                    .width(Length::Fill),
            )
            .height(400),
        )
        .style(move |_: &Theme| container::Appearance {
            background: Some(Background::Color(bg)),
            border: Border {
                color: palette.primary,
                width: 1.0,
                radius: 6.0.into(),
            },
            ..Default::default()
        })
        .padding(2)
        .width(Length::Fill)
        .into()
    }

    fn action_button(&self, label: &str, msg: Message) -> Element<'_, Message> {
        button(text(label).size(14))
            .on_press(msg)
            .padding(12)
            .width(200)
            .into()
    }

    // ─── Screens ──────────────────────────────────────────────────

    fn render_status(&self) -> Element<'_, Message> {
        let mut body = column![].spacing(10);

        let info = text(
            "Muestra informacion del sistema: gestores de paquetes, \
             paquetes instalados y actualizaciones disponibles.",
        )
        .size(14);
            let btn = self.action_button("\u{F0AD}  Comprobar estado", Message::RunStatus);
        body = body.push(info).push(Space::with_height(5.0)).push(btn);

        self.page_content("Estado del sistema", "Informacion general del sistema.", body.into())
    }

    fn render_update(&self) -> Element<'_, Message> {
        let pm = detect_pm();
        let mut body = column![].spacing(10);

        if pm == "none" {
            body = body.push(
                container(
                    text("No se encontro ningun gestor de paquetes (pacman).")
                        .style(Color::from_rgb(0.9, 0.3, 0.3)),
                )
                .padding(10),
            );
        } else {
            let info = text(format!("Actualiza todos los paquetes del sistema usando {pm}."))
                .size(14);
            let btn = self.action_button("\u{F021}  Actualizar sistema", Message::RunUpdate);
            body = body.push(info).push(Space::with_height(5.0)).push(btn);
        }

        self.page_content("Actualizar sistema", "Mantiene tu sistema al dia.", body.into())
    }

    fn render_search(&self) -> Element<'_, Message> {
        let input = text_input("Ej: neovim, firefox...", &self.search_query)
            .on_input(Message::SearchInputChanged)
            .padding(10)
            .width(400);
        let btn = button(text("\u{F002}  Buscar").size(14))
            .on_press(Message::RunSearch)
            .padding(12)
            .width(200);

        let body = column![
            text("Busca paquetes en los repositorios.").size(14),
            Space::with_height(10.0),
            input,
            Space::with_height(10.0),
            btn,
        ]
        .spacing(5);

        self.page_content("Buscar paquete", "Encuentra paquetes disponibles.", body.into())
    }

    fn render_install(&self) -> Element<'_, Message> {
        let input = text_input("Ej: firefox neovim git...", &self.pkg_input)
            .on_input(Message::PkgInputChanged)
            .padding(10)
            .width(400);
        let btn = button(text("\u{F067}  Instalar").size(14))
            .on_press(Message::RunInstall)
            .padding(12)
            .width(200);

        let body = column![
            text("Instala uno o mas paquetes (separados por espacio).").size(14),
            Space::with_height(10.0),
            input,
            Space::with_height(10.0),
            btn,
        ]
        .spacing(5);

        self.page_content(
            "Instalar paquete(s)",
            "Agrega nuevos paquetes al sistema.",
            body.into(),
        )
    }

    fn render_remove(&self) -> Element<'_, Message> {
        let input = text_input("Ej: firefox neovim...", &self.pkg_input)
            .on_input(Message::PkgInputChanged)
            .padding(10)
            .width(400);
        let btn = button(text("\u{F1F8}  Eliminar").size(14))
            .on_press(Message::RunRemove)
            .padding(12)
            .width(200);

        let body = column![
            text(
                "Elimina uno o mas paquetes (separados por espacio). \
                 Se eliminaran tambien dependencias innecesarias.",
            )
            .size(14),
            Space::with_height(10.0),
            input,
            Space::with_height(10.0),
            btn,
        ]
        .spacing(5);

        self.page_content(
            "Eliminar paquete(s)",
            "Desinstala paquetes del sistema.",
            body.into(),
        )
    }

    fn render_orphans(&self) -> Element<'_, Message> {
        let mut body = column![].spacing(10);

        if self.orphans_found.is_empty() {
            let info = text(
                "Busca y elimina paquetes huerfanos (dependencias no utilizadas \
                 por ningun programa).",
            )
            .size(14);
            let btn = self.action_button("\u{F0F0}  Buscar huerfanos", Message::RunOrphans);
            body = body.push(info).push(Space::with_height(5.0)).push(btn);
        } else {
            body = body.push(
                text(format!(
                    "{} paquete(s) huerfano(s) encontrados:",
                    self.orphans_found.len()
                ))
                .size(14),
            );
            body = body.push(Space::with_height(5.0));
            let btn = self.action_button("\u{F0F0}  Eliminar huerfanos", Message::RunOrphansClean);
            body = body.push(btn);
        }

        self.page_content(
            "Paquetes huerfanos",
            "Limpia dependencias innecesarias.",
            body.into(),
        )
    }

    fn render_clean(&self) -> Element<'_, Message> {
        let mut body = column![].spacing(10);

        let info = text(
            "Limpia la cache de paquetes de pacman, \
             manteniendo solo las ultimas 3 versiones.",
        )
        .size(14);
        body = body.push(info).push(Space::with_height(5.0));

        if which("paccache") {
            let btn = self.action_button("\u{F12D}  Limpiar cache", Message::RunClean);
            body = body.push(btn);
        } else {
            body = body.push(
                container(
                    text(
                        "paccache no esta instalado. \
                         Instala pacman-contrib para esta funcion.",
                    )
                    .style(Color::from_rgb(0.8, 0.5, 0.1)),
                )
                .padding(10),
            );
        }

        self.page_content("Limpiar cache", "Libera espacio en el disco.", body.into())
    }

    fn render_full(&self) -> Element<'_, Message> {
        let mut body = column![].spacing(10);

        let info = text(
            "Realiza un mantenimiento completo del sistema: \
             actualizacion, limpieza de cache y eliminacion de paquetes huerfanos.",
        )
        .size(14);
            let btn = self.action_button("\u{F005}  Mantenimiento completo", Message::RunFull);
        body = body.push(info).push(Space::with_height(5.0)).push(btn);

        self.page_content(
            "Mantenimiento completo",
            "Todo en uno.",
            body.into(),
        )
    }

    fn render_about(&self) -> Element<'_, Message> {
        let pm = detect_pm();
        let body = column![
            text("arcman — Gestor de paquetes para Arch Linux").size(16),
            Space::with_height(10.0),
            text("Version: 0.2.0 (GUI)").size(14),
            text("Interfaz grafica construida con Iced (Rust).").size(14),
            Space::with_height(10.0),
            text("Gestor de paquetes detectado:").size(14),
            text(pm).size(18),
        ]
        .spacing(3);

        self.page_content("Acerca de", "Informacion sobre la aplicacion.", body.into())
    }

    fn run_pending_action(action: PendingAction) -> Command<Message> {
        match action {
            PendingAction::Install(pkgs) => {
                let pm = detect_pm().to_string();
                Command::perform(
                    async move {
                        let mut args = vec!["-S".to_string(), "--noconfirm".to_string(), "--color=never".to_string()];
                        args.extend(pkgs);
                        run_priv(pm, args).await
                    },
                    Message::TaskResult,
                )
            }
            PendingAction::Remove(pkgs) => {
                Command::perform(
                    async move {
                        let mut args = vec!["-Rsnc".to_string(), "--noconfirm".to_string(), "--color=never".to_string()];
                        args.extend(pkgs);
                        run_priv("pacman".to_string(), args).await
                    },
                    Message::TaskResult,
                )
            }
            PendingAction::Update => {
                let pm = detect_pm().to_string();
                Command::perform(
                    async move {
                        run_priv(pm, vec!["-Syu".to_string(), "--noconfirm".to_string(), "--color=never".to_string()]).await
                    },
                    Message::TaskResult,
                )
            }
            PendingAction::OrphansClean(orphans) => {
                Command::perform(
                    async move {
                                let mut args = vec!["-Rns".to_string(), "--noconfirm".to_string(), "--color=never".to_string()];
                        args.extend(orphans);
                        run_priv("pacman".to_string(), args).await
                    },
                    Message::TaskResult,
                )
            }
            PendingAction::Clean => {
                Command::perform(
                    async {
                        if which("paccache") {
                            run_priv("paccache".to_string(), vec!["-r".to_string()]).await
                        } else {
                            Err("paccache no esta instalado.\nInstala pacman-contrib.".to_string())
                        }
                    },
                    Message::TaskResult,
                )
            }
            PendingAction::Full => Command::perform(
                async {
                    let pm = detect_pm().to_string();
                    let mut out = String::new();
                    out.push_str(&"=".repeat(50));
                    out.push_str("\n  MANTENIMIENTO COMPLETO\n");
                    out.push_str(&"=".repeat(50));
                    out.push('\n');

                    out.push_str("\n[1/3] Actualizando el sistema...\n");
                    match run_priv(pm.clone(), vec!["-Syu".to_string(), "--noconfirm".to_string(), "--color=never".to_string()]).await {
                        Ok(s) => out.push_str(&s),
                        Err(e) => out.push_str(&e),
                    }

                    out.push_str("\n[2/3] Limpiando cache...\n");
                    if which("paccache") {
                        match run_priv("paccache".to_string(), vec!["-r".to_string()]).await {
                            Ok(s) => out.push_str(&s),
                            Err(e) => out.push_str(&e),
                        }
                    } else {
                        out.push_str("paccache no instalado.\n");
                    }

                    out.push_str("\n[3/3] Eliminando huerfanos...\n");
                    let pacman_out = tokio::task::spawn_blocking(|| {
                        StdCmd::new("pacman").args(["-Qtdq"]).output()
                    })
                    .await;
                    match pacman_out {
                        Ok(Ok(output)) => {
                            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                            let list: Vec<&str> =
                                stdout.lines().filter(|l| !l.is_empty()).collect();
                            if list.is_empty() {
                                out.push_str("No hay paquetes huerfanos.\n");
                            } else {
                                out.push_str(&format!("{} huerfanos encontrados.\n", list.len()));
                        let mut args = vec!["-Rns".to_string(), "--noconfirm".to_string(), "--color=never".to_string()];
                                args.extend(list.iter().map(|s| s.to_string()));
                                match run_priv("pacman".to_string(), args).await {
                                    Ok(r) => out.push_str(&r),
                                    Err(e) => out.push_str(&e),
                                }
                            }
                        }
                        _ => out.push_str("No se pudo buscar huerfanos.\n"),
                    }

                    out.push('\n');
                    out.push_str(&"=".repeat(50));
                    out.push_str("\n  Mantenimiento completo finalizado.\n");
                    out.push_str(&"=".repeat(50));
                    out.push('\n');
                    Ok(out)
                },
                Message::TaskResult,
            ),
        }
    }

    fn render_confirm_dialog(&self) -> Element<'_, Message> {
        let palette = self.theme.palette();
        let desc = self
            .confirmation
            .as_ref()
            .map(|c| c.description.as_str())
            .unwrap_or("");

        let bg = Color {
            r: palette.background.r * 1.1,
            g: palette.background.g * 1.1,
            b: palette.background.b * 1.1,
            a: 1.0,
        };

        let dialog = container(
            column![
                row![
                    text("\u{F071}").size(22).style(palette.danger),
                    horizontal_space(),
                    text("Confirmar operacion").size(18),
                    horizontal_space(),
                    text("").size(22),
                ]
                .align_items(Alignment::Center),
                horizontal_rule(1),
                Space::with_height(10.0),
                text(desc).size(14),
                Space::with_height(20.0),
                row![
                    button(
                        row![
                            text("\u{F00D}  Cancelar").size(14),
                        ]
                        .align_items(Alignment::Center),
                    )
                    .on_press(Message::CancelAction)
                    .padding(12)
                    .width(140)
                    .style(theme::Button::Secondary),
                    button(
                        row![
                            text("\u{F00C}  Confirmar").size(14),
                        ]
                        .align_items(Alignment::Center),
                    )
                    .style(theme::Button::Destructive)
                    .on_press(Message::ConfirmAction)
                    .padding(12)
                    .width(140),
                ]
                .spacing(15),
            ]
            .padding(30)
            .spacing(5)
            .align_items(Alignment::Center),
        )
        .style(move |_: &Theme| container::Appearance {
            background: Some(Background::Color(bg)),
            border: Border {
                color: palette.primary,
                width: 1.0,
                radius: 8.0.into(),
            },
            ..Default::default()
        })
        .max_width(440);

        container(dialog)
            .width(Length::Fill)
            .height(Length::Fill)
            .center_x()
            .center_y()
            .style(move |_: &Theme| container::Appearance {
                background: Some(Background::Color(Color {
                    a: 0.6,
                    ..palette.background
                })),
                ..Default::default()
            })
            .into()
    }
}

// ─── Main ──────────────────────────────────────────────────────────

pub fn main() -> iced::Result {
    let icon = iced::window::icon::from_rgba(generate_icon(), 32, 32).ok();
    let font_data: &'static [u8] = include_bytes!("../arcman-font.otf");
    App::run(Settings {
        default_font: Font::with_name("DroidSansMono Nerd Font"),
        fonts: vec![Cow::Borrowed(font_data)],
        window: iced::window::Settings {
            icon,
            platform_specific: iced::window::settings::PlatformSpecific {
                application_id: String::from("arcman-gui"),
            },
            size: [900u16, 720].into(),
            min_size: Some([720u16, 480].into()),
            ..Default::default()
        },
        ..Default::default()
    })
}

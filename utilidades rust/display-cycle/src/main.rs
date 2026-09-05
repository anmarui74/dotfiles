use eframe::egui;
use image::GenericImageView;

struct DisplayCycleApp {
    mode: usize,
    textures: Vec<egui::TextureHandle>,
    icon_paths: Vec<String>,
    last_mtimes: Vec<std::time::SystemTime>,
}

impl DisplayCycleApp {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        let icon_paths = vec![
            "/home/antonio/Documentos/dotfiles/utilidades rust/display-cycle/icons/extended.png".to_string(),
            "/home/antonio/Documentos/dotfiles/utilidades rust/display-cycle/icons/mirror.png".to_string(),
            "/home/antonio/Documentos/dotfiles/utilidades rust/display-cycle/icons/solo1.png".to_string(),
            "/home/antonio/Documentos/dotfiles/utilidades rust/display-cycle/icons/solo2.png".to_string(),
        ];
        let mut textures = Vec::new();
        let mut last_mtimes = Vec::new();
        for path in &icon_paths {
            if let Ok(meta) = std::fs::metadata(path) {
                if let Ok(mtime) = meta.modified() {
                    last_mtimes.push(mtime);
                } else {
                    last_mtimes.push(std::time::SystemTime::UNIX_EPOCH);
                }
            } else {
                last_mtimes.push(std::time::SystemTime::UNIX_EPOCH);
            }
            if let Ok(bytes) = std::fs::read(path) {
                if let Ok(img) = image::load_from_memory(&bytes) {
                    let size = [img.width() as usize, img.height() as usize];
                    let rgba = img.to_rgba8();
                    let pixels = rgba.as_raw().clone();
                    let color_image = egui::ColorImage::from_rgba_unmultiplied(size, &pixels);
                    let tex = cc.egui_ctx.load_texture(format!("icon_{}", textures.len()), color_image, egui::TextureOptions::default());
                    textures.push(tex);
                }
            }
        }
        while textures.len() < 4 {
            textures.push(cc.egui_ctx.load_texture("empty", egui::ColorImage::new([1,1], egui::Color32::TRANSPARENT), egui::TextureOptions::default()));
            last_mtimes.push(std::time::SystemTime::UNIX_EPOCH);
        }
        Self { mode: 0, textures, icon_paths, last_mtimes }
    }

    fn reload_if_needed(&mut self, ctx: &egui::Context) {
        for (i, path) in self.icon_paths.iter().enumerate() {
            if let Ok(meta) = std::fs::metadata(path) {
                if let Ok(mtime) = meta.modified() {
                    if mtime != self.last_mtimes[i] {
                        self.last_mtimes[i] = mtime;
                        if let Ok(bytes) = std::fs::read(path) {
                            if let Ok(img) = image::load_from_memory(&bytes) {
                                let size = [img.width() as usize, img.height() as usize];
                                let rgba = img.to_rgba8();
                                let pixels = rgba.as_raw().clone();
                                let color_image = egui::ColorImage::from_rgba_unmultiplied(size, &pixels);
                                let tex = ctx.load_texture(format!("icon_{}", i), color_image, egui::TextureOptions::default());
                                self.textures[i] = tex;
                            }
                        }
                    }
                }
            }
        }
    }
}

impl eframe::App for DisplayCycleApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        if ctx.input(|i| i.key_pressed(egui::Key::Escape)) {
            ctx.send_viewport_cmd(egui::ViewportCommand::Close);
        }
        let num_pressed = ctx.input(|i| {
            if i.key_pressed(egui::Key::Num1) { Some(0) }
            else if i.key_pressed(egui::Key::Num2) { Some(1) }
            else if i.key_pressed(egui::Key::Num3) { Some(2) }
            else if i.key_pressed(egui::Key::Num4) { Some(3) }
            else { None }
        });
        if let Some(idx) = num_pressed {
            self.mode = idx;
            apply_mode(idx);
            ctx.send_viewport_cmd(egui::ViewportCommand::Close);
        }
        self.reload_if_needed(ctx);
        egui::CentralPanel::default().show(ctx, |ui| {
            let icon_size = egui::Vec2::new(180.0, 180.0);
            let spacing = 20.0;
            let cols = 2;
            let rows = 2;
            let total_w = cols as f32 * icon_size.x + (cols as f32 - 1.0) * spacing;
            let total_h = rows as f32 * icon_size.y + (rows as f32 - 1.0) * spacing;
            let avail = ui.available_size();
            let start = egui::pos2((avail.x - total_w) / 2.0, (avail.y - total_h) / 2.0);
            for i in 0..4 {
                let col = i % cols;
                let row = i / cols;
                let x = start.x + col as f32 * (icon_size.x + spacing);
                let y = start.y + row as f32 * (icon_size.y + spacing);
                let rect = egui::Rect::from_min_size(egui::pos2(x, y), icon_size);
                let resp = ui.allocate_rect(rect, egui::Sense::click());
                if resp.clicked() {
                    self.mode = i;
                    apply_mode(i);
                    ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                }
                let tex = &self.textures[i];
                let painter = ui.painter();
                painter.image(
                    tex.id(),
                    rect,
                    egui::Rect::from_min_max(egui::pos2(0.0,0.0), egui::pos2(1.0,1.0)),
                    egui::Color32::WHITE,
                );
            }
        });
    }
}

fn apply_mode(mode: usize) {
    let dp1 = "DP-1";
    let dp2 = "DP-2";
    let mode1 = "3840x2160@59.997";
    let mode2 = "3840x2160@60.000";
    let scale = "1.33";
    let args = match mode {
        0 => vec!["set","-l","logical","-L","-M",dp2,"--mode",mode2,"--x","2880","--y","0","--primary","-s",scale,"-L","-M",dp1,"--mode",mode1,"--x","0","--y","0","-s",scale],
        1 => vec!["set","-l","logical","-L","-M",dp2,"--mode",mode2,"-M",dp1,"--mode",mode1,"--primary","-s",scale],
        2 => vec!["set","-l","logical","-L","-M",dp1,"--mode",mode1,"--x","0","--y","0","--primary","-s",scale],
        3 => vec!["set","-l","logical","-L","-M",dp2,"--mode",mode2,"--x","0","--y","0","--primary","-s",scale],
        _ => return,
    };
    let _ = std::process::Command::new("gdctl").args(&args).spawn();
}

struct LockGuard;
impl Drop for LockGuard {
    fn drop(&mut self) {
        let _ = std::fs::remove_file("/tmp/display-cycle.lock");
    }
}
fn main() {
    // single instance lock
    let lock_path = "/tmp/display-cycle.lock";
    let _lock_file = std::fs::OpenOptions::new().write(true).create_new(true).open(lock_path).unwrap_or_else(|_| {
        std::process::exit(0);
    });
    let _guard = LockGuard;
    let mut options = eframe::NativeOptions::default();
    options.viewport = egui::ViewportBuilder::default()
        .with_decorations(false)
        .with_minimize_button(false)
        .with_maximize_button(false)
        .with_close_button(false)
        .with_inner_size([560.0, 440.0])
        .with_transparent(true)
        .with_app_id("display-cycle");
    eframe::run_native(
        "Display Cycle",
        options,
        Box::new(|cc| {
            let mut fonts = egui::FontDefinitions::default();
            if let Ok(data) = std::fs::read("/usr/share/fonts/noto/NotoColorEmoji.ttf") {
                fonts.font_data.insert("emoji".to_owned(), egui::FontData::from_owned(data));
                fonts.families.get_mut(&egui::FontFamily::Proportional).unwrap().insert(0, "emoji".to_owned());
            }
            let kitty_path = "/home/antonio/.local/share/fonts/Droid Sans Mono Nerd Font Complete.otf";
            if let Ok(data) = std::fs::read(kitty_path) {
                fonts.font_data.insert("kitty".to_owned(), egui::FontData::from_owned(data));
                for family in &[egui::FontFamily::Proportional, egui::FontFamily::Monospace] {
                    fonts.families.get_mut(family).unwrap().push("kitty".to_owned());
                }
            }
            cc.egui_ctx.set_fonts(fonts);
            Box::new(DisplayCycleApp::new(cc))
        }),
    ).unwrap();
}

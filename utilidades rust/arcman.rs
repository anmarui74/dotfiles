use std::env;
use std::io::{self, Write};
use std::path::Path;
use std::process::{exit, Command, Stdio};

const BOLD: &str = "\x1b[1m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const RED: &str = "\x1b[31m";
const CYAN: &str = "\x1b[36m";
const RESET: &str = "\x1b[0m";

fn print_bold(s: &str)  { print!("{BOLD}{s}{RESET}"); }
fn print_green(s: &str) { print!("{GREEN}{s}{RESET}"); }
fn print_yellow(s: &str){ print!("{YELLOW}{s}{RESET}"); }
fn print_red(s: &str)   { print!("{RED}{s}{RESET}"); }
fn print_cyan(s: &str)  { print!("{CYAN}{s}{RESET}"); }
fn println_bold(s: &str)  { println!("{BOLD}{s}{RESET}"); }
fn println_green(s: &str) { println!("{GREEN}{s}{RESET}"); }
fn println_yellow(s: &str){ println!("{YELLOW}{s}{RESET}"); }
fn println_red(s: &str)   { println!("{RED}{s}{RESET}"); }
fn println_cyan(s: &str)  { println!("{CYAN}{s}{RESET}"); }

fn clear() {
    print!("\x1b[2J\x1b[H");
    _ = io::stdout().flush();
}

fn pause() {
    print!("\n  {YELLOW}Presiona Enter para continuar...{RESET}");
    _ = io::stdout().flush();
    _ = io::stdin().read_line(&mut String::new());
}

fn confirm(msg: &str) -> bool {
    print!("  {YELLOW}¿{msg}?{RESET} (s/N): ");
    _ = io::stdout().flush();
    let mut r = String::new();
    _ = io::stdin().read_line(&mut r);
    r.trim().eq_ignore_ascii_case("s")
}

fn check_root() {
    if let Ok(out) = Command::new("id").arg("-u").output() {
        if let Ok(uid) = String::from_utf8_lossy(&out.stdout).trim().parse::<u32>() {
            if uid == 0 {
                println_red("[ERROR] No ejecutes este programa como root/sudo.");
                println_red("        El programa pedirá permisos cuando sea necesario.");
                exit(1);
            }
        }
    }
}

#[derive(Debug, PartialEq, Clone)]
enum PkgManager {
    Yay,
    Paru,
    Pacman,
    None,
}

fn detect_pkg_manager() -> PkgManager {
    if which("yay") {
        PkgManager::Yay
    } else if which("paru") {
        PkgManager::Paru
    } else if which("pacman") {
        PkgManager::Pacman
    } else {
        PkgManager::None
    }
}

fn which(name: &str) -> bool {
    env::split_paths(&env::var_os("PATH").unwrap_or_default())
        .any(|d| Path::new(&d).join(name).is_file())
}

fn pm_name(pm: &PkgManager) -> &'static str {
    match pm {
        PkgManager::Yay => "yay",
        PkgManager::Paru => "paru",
        PkgManager::Pacman => "pacman",
        PkgManager::None => "ninguno",
    }
}

fn run_sudo(args: &[&str]) {
    let status = Command::new("sudo")
        .args(args)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status();
    match status {
        Ok(s) if s.success() => {}
        _ => println_red("[ERROR] El comando falló."),
    }
}

fn run_cmd(args: &[&str]) -> Option<String> {
    let out = Command::new(args[0])
        .args(&args[1..])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).to_string())
    } else {
        None
    }
}

fn show_help() {
    println!();
    println_bold("Uso: arcman [opción]");
    println!();
    println_bold("Opciones:");
    println_cyan("  update, -u           ");
    println!("    Actualiza el sistema con pacman + AUR (yay/paru)");
    println_cyan("  search <paquete>      ");
    println!("    Busca un paquete en los repositorios");
    println_cyan("  install <paquete...>  ");
    println!("    Instala uno o más paquetes");
    println_cyan("  remove <paquete...>   ");
    println!("    Elimina uno o más paquetes");
    println_cyan("  orphans               ");
    println!("    Muestra y elimina paquetes huérfanos");
    println_cyan("  clean                 ");
    println!("    Limpia la caché de pacman (paccache)");
    println_cyan("  full                  ");
    println!("    Actualiza + limpia caché + elimina huérfanos");
    println_cyan("  status, -s            ");
    println!("    Muestra el estado: gestores instalados, paquetes actualizables");
    println_cyan("  help, -h, --help      ");
    println!("    Muestra esta ayuda");
    println!();
    println_bold("Ejemplos:");
    println!("  arcman update");
    println!("  arcman search neovim");
    println!("  arcman install firefox vim");
    println!("  arcman full");
    println!("  arcman status");
    println!();
    println_bold("Sin argumentos: menú interactivo");
    println!();
    pause();
}

fn show_status() {
    clear();
    println!("\n  {}Estado del sistema{}\n", BOLD, RESET);

    let pm = detect_pkg_manager();
    print!("  Gestor de paquetes principal: ");
    match pm {
        PkgManager::None => println_red("ninguno"),
        ref p => {
            print_cyan(pm_name(p));
            println!();
        }
    }

    print!("  yay instalado:        ");
    if which("yay") { println_green("SÍ"); } else { println_red("NO"); }
    print!("  paru instalado:       ");
    if which("paru") { println_green("SÍ"); } else { println_red("NO"); }
    print!("  pacman-contrib (paccache): ");
    if which("paccache") { println_green("SÍ"); } else { println_red("NO"); }
    println!();

    println_yellow("  Comprobando actualizaciones...");
    if let Some(out) = run_cmd(&["pacman", "-Qu"]) {
        let lines: Vec<&str> = out.lines().filter(|l| !l.is_empty()).collect();
        if lines.is_empty() {
            println_green("  Sistema actualizado — no hay paquetes pendientes.");
        } else {
            println_yellow(&format!("  {} actualizaciones disponibles:", lines.len()));
            for line in &lines {
                let parts: Vec<&str> = line.splitn(4, ' ').collect();
                if parts.len() >= 4 && parts[1] == "->" {
                    println!("    {}: {} → {}", parts[0], parts[2], parts[3]);
                } else {
                    println!("    {line}");
                }
            }
        }
    }
    println!();
    pause();
}

fn do_update() {
    clear();
    println!("\n  {}Actualización del sistema{}\n", BOLD, RESET);
    let pm = detect_pkg_manager();
    if pm == PkgManager::None {
        println_red("[ERROR] No se encontró pacman.");
        pause();
        return;
    }
    println_cyan(&format!("  Usando gestor: {}", pm_name(&pm)));
    if !confirm("¿Deseas actualizar todos los paquetes") {
        println_yellow("  Cancelado.");
        pause();
        return;
    }
    println!();
    match pm {
        PkgManager::Yay => run_sudo(&["yay", "-Syu"]),
        PkgManager::Paru => run_sudo(&["paru", "-Syu"]),
        PkgManager::Pacman => run_sudo(&["pacman", "-Syu"]),
        PkgManager::None => unreachable!(),
    }
    println_green("\n  [OK] Actualización completada.\n");
    pause();
}

fn do_search() {
    clear();
    println!("\n  {}Buscar paquete{}\n", BOLD, RESET);
    print!("  Nombre del paquete a buscar: ");
    _ = io::stdout().flush();
    let mut term = String::new();
    _ = io::stdin().read_line(&mut term);
    let term = term.trim();
    if term.is_empty() {
        println_yellow("  Cancelado.");
        pause();
        return;
    }
    println!();
    let pm = detect_pkg_manager();
    let args: &[&str] = match pm {
        PkgManager::Yay => &["yay", "-Ss", term],
        PkgManager::Paru => &["paru", "-Ss", term],
        PkgManager::Pacman => &["pacman", "-Ss", term],
        PkgManager::None => {
            println_red("[ERROR] No se encontró pacman.");
            pause();
            return;
        }
    };
    let out = Command::new(args[0])
        .args(&args[1..])
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status();
    match out {
        Ok(s) if s.success() => {}
        _ => println_red("  No se encontraron resultados."),
    }
    println!();
    pause();
}

fn do_install(args: &[String]) {
    clear();
    println!("\n  {}Instalar paquete(s){}\n", BOLD, RESET);
    let pkgs: Vec<String> = if args.is_empty() {
        print!("  Nombres de los paquetes (separados por espacio): ");
        _ = io::stdout().flush();
        let mut line = String::new();
        _ = io::stdin().read_line(&mut line);
        let pkgs: Vec<String> = line.split_whitespace().map(|s| s.to_string()).collect();
        if pkgs.is_empty() {
            println_yellow("  Cancelado.");
            pause();
            return;
        }
        pkgs
    } else {
        args.to_vec()
    };

    if !confirm(&format!("¿Instalar '{}'", pkgs.join(" "))) {
        println_yellow("  Cancelado.");
        pause();
        return;
    }
    println!();
    let pm = detect_pkg_manager();
    let pkg_refs: Vec<&str> = pkgs.iter().map(|s| s.as_str()).collect();
    match pm {
        PkgManager::Yay | PkgManager::Paru => {
            let mut cmd = vec![pm_name(&pm), "-S"];
            cmd.extend(pkg_refs.iter().copied());
            run_sudo(&cmd);
        }
        PkgManager::Pacman => {
            let mut cmd = vec!["pacman", "-S"];
            cmd.extend(pkg_refs.iter().copied());
            run_sudo(&cmd);
        }
        PkgManager::None => println_red("[ERROR] No se encontró pacman."),
    }
    println!();
    pause();
}

fn do_remove(args: &[String]) {
    clear();
    println!("\n  {}Eliminar paquete(s){}\n", BOLD, RESET);
    let pkgs: Vec<String> = if args.is_empty() {
        print!("  Nombre del paquete a eliminar: ");
        _ = io::stdout().flush();
        let mut line = String::new();
        _ = io::stdin().read_line(&mut line);
        let pkgs: Vec<String> = line.split_whitespace().map(|s| s.to_string()).collect();
        if pkgs.is_empty() {
            println_yellow("  Cancelado.");
            pause();
            return;
        }
        pkgs
    } else {
        args.to_vec()
    };

    if !confirm(&format!("¿Eliminar '{}'", pkgs.join(" "))) {
        println_yellow("  Cancelado.");
        pause();
        return;
    }
    println!();
    let pm = detect_pkg_manager();
    let pkg_refs: Vec<&str> = pkgs.iter().map(|s| s.as_str()).collect();
    match pm {
        PkgManager::Yay | PkgManager::Paru => {
            let mut cmd = vec![pm_name(&pm), "-Rsnc"];
            cmd.extend(pkg_refs.iter().copied());
            run_sudo(&cmd);
        }
        PkgManager::Pacman => {
            let mut cmd = vec!["pacman", "-Rsnc"];
            cmd.extend(pkg_refs.iter().copied());
            run_sudo(&cmd);
        }
        PkgManager::None => println_red("[ERROR] No se encontró pacman."),
    }
    println!();
    pause();
}

fn do_orphans() {
    clear();
    println!("\n  {}Paquetes huérfanos{}\n", BOLD, RESET);
    println_yellow("  Buscando paquetes huérfanos...\n");
    let Some(out) = run_cmd(&["pacman", "-Qtdq"]) else {
        println_red("  Error al buscar huérfanos.");
        pause();
        return;
    };
    let orphans: Vec<&str> = out.lines().filter(|l| !l.is_empty()).collect();
    if orphans.is_empty() {
        println_green("  No hay paquetes huérfanos.\n");
        pause();
        return;
    }
    println_yellow(&format!("  {} paquetes huérfanos encontrados:\n", orphans.len()));
    for p in &orphans {
        println_red(&format!("    {p}"));
    }
    println!();
    if confirm("¿Eliminar paquetes huérfanos") {
        println!();
        run_sudo(&{
            let mut v = vec!["pacman", "-Rns"];
            v.extend(orphans.iter().copied());
            v
        });
        println_green("\n  Hecho.");
    } else {
        println_yellow("  Omitido.");
    }
    println!();
    pause();
}

fn do_clean() {
    clear();
    println!("\n  {}Limpiar caché de pacman{}\n", BOLD, RESET);
    if which("paccache") {
        if confirm("¿Limpiar caché (manteniendo 3 versiones)") {
            println!();
            run_sudo(&["paccache", "-r"]);
            println_green("\n  Caché limpiada.");
        } else {
            println_yellow("  Omitido.");
        }
    } else {
        println_yellow("  paccache no está instalado. Instala 'pacman-contrib'.");
        if confirm("¿Limpiar con pacman -Sc en su lugar") {
            println!();
            run_sudo(&["pacman", "-Sc"]);
            println_green("\n  Caché limpiada.");
        }
    }
    println!();
    pause();
}

fn do_full() {
    clear();
    println!("\n  {}Mantenimiento completo{}\n", BOLD, RESET);
    let pm = detect_pkg_manager();
    if pm == PkgManager::None {
        println_red("[ERROR] No se encontró pacman.");
        pause();
        return;
    }
    println_cyan(&format!("  Usando gestor: {}", pm_name(&pm)));
    if !confirm("¿Realizar mantenimiento completo (update + clean + orphans)") {
        println_yellow("  Cancelado.");
        pause();
        return;
    }
    println!();
    match pm {
        PkgManager::Yay => run_sudo(&["yay", "-Syu"]),
        PkgManager::Paru => run_sudo(&["paru", "-Syu"]),
        PkgManager::Pacman => run_sudo(&["pacman", "-Syu"]),
        PkgManager::None => unreachable!(),
    }
    println!();
    if which("paccache") {
        run_sudo(&["paccache", "-r"]);
    } else {
        println_yellow("  paccache no instalado, omitiendo limpieza de caché.");
    }
    println!();
    do_orphans_inner();
    println!();
    println_green(&format!("{BOLD}========================================{RESET}"));
    println_green(&format!("{BOLD}   Mantenimiento completo finalizado!{RESET}"));
    println_green(&format!("{BOLD}========================================{RESET}"));
    println!();
    pause();
}

fn do_orphans_inner() {
    let Some(out) = run_cmd(&["pacman", "-Qtdq"]) else { return };
    let orphans: Vec<&str> = out.lines().filter(|l| !l.is_empty()).collect();
    if orphans.is_empty() {
        println_green("  No hay paquetes huérfanos.");
        return;
    }
    println_yellow(&format!("  Eliminando {} paquetes huérfanos...", orphans.len()));
    run_sudo(&{
        let mut v = vec!["pacman", "-Rns"];
        v.extend(orphans.iter().copied());
        v
    });
}

fn menu() {
    loop {
        clear();
        println!();
        println!("  {}", "=".repeat(44));
        println_bold("  Arch Linux — Gestor de paquetes (Rust)");
        println!("  {}", "=".repeat(44));
        println!();
        let options: [(&str, fn()); 8] = [
            ("Comprobar actualizaciones", show_status),
            ("Actualizar el sistema", do_update),
            ("Buscar un paquete", do_search),
            ("Instalar un paquete", || do_install(&[])),
            ("Eliminar un paquete", || do_remove(&[])),
            ("Limpiar sistema (update + clean + orphans)", do_full),
            ("Ayuda", show_help),
            ("Salir", || exit(0)),
        ];
        for (i, (label, _)) in options.iter().enumerate() {
            println!("    {CYAN}{}.{RESET} {label}", i + 1);
        }
        println!();
        print!("  {BOLD}Elige una opción{RESET} [1-{}]: ", options.len());
        _ = io::stdout().flush();
        let mut choice = String::new();
        if io::stdin().read_line(&mut choice).is_err() {
            break;
        }
        let choice = choice.trim().parse::<usize>().unwrap_or(0);
        if choice == 0 || choice > options.len() {
            println_red("\n  Opción inválida.");
            pause();
            continue;
        }
        options[choice - 1].1();
    }
}

fn main() {
    check_root();
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        menu();
        return;
    }
    match args[0].as_str() {
        "help" | "-h" | "--help" => show_help(),
        "update" | "-u" => do_update(),
        "search" => {
            if args.len() > 1 {
                // just pass through to pacman search inline
                let pm = detect_pkg_manager();
                let cmd = match pm {
                    PkgManager::Yay => "yay",
                    PkgManager::Paru => "paru",
                    PkgManager::Pacman => "pacman",
                    PkgManager::None => {
                        println_red("[ERROR] No se encontró pacman.");
                        return;
                    }
                };
                let mut full = vec![cmd, "-Ss"];
                full.extend(args[1..].iter().map(|s| s.as_str()));
                _ = Command::new(full[0])
                    .args(&full[1..])
                    .stdin(Stdio::inherit())
                    .stdout(Stdio::inherit())
                    .stderr(Stdio::inherit())
                    .status();
            } else {
                do_search();
            }
        }
        "install" => {
            if args.len() > 1 {
                do_install(&args[1..].to_vec());
            } else {
                do_install(&[]);
            }
        }
        "remove" => {
            if args.len() > 1 {
                do_remove(&args[1..].to_vec());
            } else {
                do_remove(&[]);
            }
        }
        "orphans" => do_orphans(),
        "clean" => do_clean(),
        "full" => do_full(),
        "status" | "-s" => show_status(),
        _ => {
            println_red(&format!("[ERROR] Opción desconocida: {}", args[0]));
            show_help();
            exit(1);
        }
    }
}

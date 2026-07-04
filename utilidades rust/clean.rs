use std::io::{self, Write};
use std::process::{Command, Stdio};

/// Verifica si el script se está ejecutando como root (UID 0)
fn is_root() -> bool {
    if let Ok(status) = std::fs::read_to_string("/proc/self/status") {
        for line in status.lines() {
            if line.starts_with("Uid:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                // El formato es "Uid: \treal\tefectivo\t...". Verificamos si el UID real es 0.
                if parts.len() >= 2 && parts[1] == "0" {
                    return true;
                }
            }
        }
    }
    false
}

/// Pide confirmación al usuario (s/N)
fn prompt_confirmation(message: &str) -> io::Result<bool> {
    print!("{} (s/N): ", message);
    io::stdout().flush()?;
    
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    
    let response = input.trim().to_lowercase();
    Ok(response == "s" || response == "y" || response == "si" || response == "yes")
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=== Limpiador de Sistema para Arch Linux ===\n");

    // 1. Verificar privilegios de root
    if !is_root() {
        eprintln!("Error: Este script requiere privilegios de administrador.");
        eprintln!("Por favor, ejecútalo usando: sudo clean");
        return Ok(());
    }

    // 2. Buscar paquetes huérfanos
    println!("Buscando paquetes huérfanos...");
    let output = Command::new("pacman")
        .arg("-Qdtq")
        .stdout(Stdio::piped())
        .stderr(Stdio::null()) // Ignoramos stderr porque pacman devuelve error si no hay huérfanos
        .output()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let orphans: Vec<&str> = stdout.trim().split_whitespace().collect();

    if orphans.is_empty() {
        println!("¡Excelente! No se encontraron paquetes huérfanos en el sistema.\n");
    } else {
        println!("\nSe encontraron {} paquete(s) huérfano(s):", orphans.len());
        for pkg in &orphans {
            println!("  - {}", pkg);
        }
        println!();

        // 3. Confirmar y eliminar huérfanos
        if prompt_confirmation("¿Deseas eliminar estos paquetes y sus configuraciones?")? {
            println!("\nEliminando paquetes huérfanos...");
            
            let mut remove_cmd = Command::new("pacman");
            remove_cmd.arg("-Rns"); // -R (remove), -n (no config), -s (recursive)
            remove_cmd.args(&orphans);
            
            // Ejecutamos sin capturar stdout/stderr para que el usuario vea el progreso de pacman
            let status = remove_cmd.status()?;
            
            if status.success() {
                println!("\nPaquetes huérfanos eliminados correctamente.");
            } else {
                eprintln!("\nAdvertencia: pacman terminó con errores. Revisa la salida superior.");
            }
        } else {
            println!("Eliminación de paquetes huérfanos cancelada.");
        }
    }

    println!("\n----------------------------------------");

    // 4. Limpiar caché de paquetes (Opción segura: -Sc)
    // Nota: Usamos -Sc (elimina solo paquetes que ya no están instalados) en lugar de -Scc 
    // para evitar borrar la caché de paquetes que sí tienes instalados actualmente.
    if prompt_confirmation("¿Deseas limpiar la caché de paquetes no instalados? (pacman -Sc)")? {
        println!("\nLimpiando caché de paquetes...");
        Command::new("pacman").arg("-Sc").status()?;
        println!("Caché limpiada correctamente.");
    } else {
        println!("Limpieza de caché omitida.");
    }

    println!("\n=== Proceso de limpieza finalizado ===");
    Ok(())
}

#[cfg(windows)]
pub mod windows;
#[cfg(windows)]
pub use windows::*;

#[cfg(target_os = "linux")]
pub mod unix;
#[cfg(target_os = "linux")]
pub use unix::*;

#[cfg(not(any(target_os = "linux", windows)))]
compile_error!("platform not supported");

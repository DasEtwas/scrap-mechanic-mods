mod backend;
mod injector;
mod peer;

pub const PORT: u16 = 25752;

#[cfg(windows)]
pub const WINDOW_TITLE: &str = "Scrap Mechanic";
#[cfg(target_os = "linux")]
pub const PROCESS_NAME: &str = "ScrapMechanic.e";

pub const DEFAULT_PORT: u16 = 25752;

use crate::injector::Injector;
use clap::{value_t_or_exit, App, Arg};

#[cfg(not(target_pointer_width = "64"))]
use compile_error_this_must_run_with_64_bit_pointers;

fn main() {
    println!(
        "Copyright 2019 DasEtwas

This program modifies memory of the game directly.
It binds a given UDP port on localhost and receives instructions from other applications
through this connection. These applications may use this software in ways it was not
designed to be used and may decrease the game's performance or cause considerable
system slowdown.
Although it is not designed to do so, this program may..
- make the world unloadable/corrupted.
- crash the game.
- make the game unplayable.
- irreversibly corrupt any running program including the operating system or its files.

THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

By using this software you confirm to have read this disclaimer and understand the
possible consequences of its usage.
"
    );

    let clap = App::new("sminject")
        .arg(
            Arg::with_name("port")
                .short("p")
                .default_value("25752")
                .takes_value(true)
                .validator(|s| s.parse::<u16>().map_err(|e| format!("{:?}", e)).map(|_| ())),
        )
        .arg(Arg::with_name("netdebug").short("n").takes_value(false))
        .get_matches();

    let game = match backend::Game::new() {
        Ok(game) => game,
        Err(e) => err_exit(format!("Failed to link with game: {}", e), 1),
    };

    let mut injector = Injector::new(
        game,
        value_t_or_exit!(clap, "port", u16),
        clap.is_present("netdebug"),
    );

    if let Err(e) = injector.run() {
        println!("error: {:?}", e)
    }
}

pub fn err_exit(error: String, code: i32) -> ! {
    eprintln!("{}", error);
    std::process::exit(code)
}

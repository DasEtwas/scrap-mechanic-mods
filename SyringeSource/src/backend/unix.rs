// currently unused and does not compile

use crate::PROCESS_NAME;
use anyhow::*;
use std::mem::size_of;
use std::process::Command;

extern "C" {
    pub fn process_vm_readv(
        pid: libc::pid_t,
        local_iov: *const libc::iovec,
        liovcnt: libc::c_ulong,
        remote_iov: *const libc::iovec,
        riovcnt: libc::c_ulong,
        flags: libc::c_ulong,
    ) -> isize;

    pub fn process_vm_writev(
        pid: libc::pid_t,
        local_iov: *const libc::iovec,
        liovcnt: libc::c_ulong,
        remote_iov: *const libc::iovec,
        riovcnt: libc::c_ulong,
        flags: libc::c_ulong,
    ) -> isize;
}

pub struct Game {
    pid: libc::pid_t,
    pages: Vec<(usize, usize, (bool, bool, bool, bool))>,
}

impl Game {
    pub fn new() -> Result<Game, anyhow::Error> {
        let pid = String::from_utf8(
            Command::new("pidof")
                .arg("-s")
                .arg(PROCESS_NAME)
                .output()?
                .stdout,
        )?
        .trim()
        .parse::<libc::pid_t>()?;

        dbg!(pid);

        Ok(Game { pid, pages: vec![] })
    }

    /// Tries to write a value at address `ptr` in the game's memory
    pub unsafe fn write<T>(&self, ptr: *mut T, value: &T) -> Result<(), anyhow::Error> {
        let ptr_high = std::mem::size_of_val(value) + ptr as usize;

        let mut bytes_written = 0;

        for (local_iov, remote_iov) in self
            .pages
            .iter()
            .skip_while(|(_page_start, page_end, _rwxp)| *page_end <= ptr as usize)
            .take_while(|(page_start, _page_end, _rwxp)| *page_start < ptr_high as usize)
            .filter_map(|(page_start, page_end, rwxp)| {
                if let (_, true, _, _) = rwxp {
                    Some((page_start, page_end))
                } else {
                    None
                }
            })
            .map(|(&page_start, &page_end)| {
                let low = page_start.max(ptr as usize).min(page_end);
                let high = page_end.min(ptr_high).max(page_start);

                (
                    libc::iovec {
                        iov_base: (value as *const T as usize + low - ptr as usize) as _,
                        iov_len: high - low,
                    },
                    libc::iovec {
                        iov_base: low as _,
                        iov_len: high - low,
                    },
                )
            })
        {
            let ret_val = process_vm_writev(self.pid, &local_iov, 1, &remote_iov, 1, 0);

            match ret_val {
                x if x as usize == local_iov.iov_len => bytes_written += ret_val as usize,
                -1 => {
                    /*println!(
                        "failed to write memory at {:08X}: {:?}",
                        remote_iov.iov_base as usize,
                        std::io::Error::last_os_error()
                    );*/
                }
                _ => {
                    /*println!(
                        "failed to write mmeory completely at {:08X}",
                        remote_iov.iov_base as usize,
                    );*/
                }
            }
        }

        if bytes_written == std::mem::size_of_val(value) {
            Ok(())
        } else {
            Err(anyhow!("incomplete write"))
        }
    }

    pub unsafe fn update_pages(&mut self) -> Result<(), anyhow::Error> {
        self.pages = std::fs::read_to_string(format!("/proc/{}/maps", self.pid))?
            .lines()
            .filter_map(|row| {
                let mut columns = row.split_whitespace();

                let mut page_bounds = columns.next()?.split('-');
                let page_start = usize::from_str_radix(page_bounds.next()?, 16)
                    .expect("malformed /proc/{id}/maps output");
                let page_end = usize::from_str_radix(page_bounds.next()?, 16)
                    .expect("malformed /proc/{id}/maps output");
                let rwxp = columns.next()?;
                let rwxp = (
                    rwxp.contains('r'),
                    rwxp.contains('w'),
                    rwxp.contains('x'),
                    rwxp.contains('p'),
                );

                Some((page_start, page_end, rwxp))
            })
            .filter(|(_, _, (r, _, _, _))| *r)
            .collect::<Vec<(usize, usize, (bool, bool, bool, bool))>>();

        Ok(())
    }

    /// Returns a vector with length `len` which was filled with the game's process memory
    /// in the range `ptr..(ptr + len * size_of::<T>())`
    /// the memory pages are iterated and only pages with the AllocationProtect flags of PAGE_EXECUTE_READWRITE or PAGE_READWRITE or PAGE_EXECUTE_READ or PAGE_READONLY
    /// and PAGE_GUARD or PAGE_NOACCESS are read from.
    pub unsafe fn read_vec<T>(&self, ptr: *const T, len: usize) -> Result<Vec<T>, anyhow::Error> {
        let mut buffer = Vec::<T>::with_capacity(len);
        buffer.set_len(buffer.capacity());
        let ptr = ptr as usize;
        let ptr_high = ptr + size_of::<T>() * len as usize;

        for (local_iov, remote_iov) in self
            .pages
            .iter()
            .skip_while(|(_page_start, page_end, _rwxp)| *page_end <= ptr as usize)
            .take_while(|(page_start, _page_end, _rwxp)| *page_start < ptr_high as usize)
            .map(|&(page_start, page_end, _)| {
                let low = page_start.max(ptr).min(page_end);
                let high = page_end.min(ptr_high).max(page_start);

                (
                    libc::iovec {
                        iov_base: (buffer.as_mut_ptr() as usize + low - ptr) as _,
                        iov_len: high - low,
                    },
                    libc::iovec {
                        iov_base: low as _,
                        iov_len: high - low,
                    },
                )
            })
        {
            let ret_val = process_vm_readv(self.pid, &local_iov, 1, &remote_iov, 1, 0);

            match ret_val {
                x if x as usize == local_iov.iov_len => (),
                -1 => {
                    /*println!(
                        "failed to read memory at {:08X}: {:?}",
                        remote_iov.iov_base as usize,
                        std::io::Error::last_os_error()
                    );*/
                }
                _ => {
                    /*println!(
                        "failed to read mmeory completely at {:08X}",
                        remote_iov.iov_base as usize,
                    );*/
                }
            }
        }

        Ok(buffer)
    }
}

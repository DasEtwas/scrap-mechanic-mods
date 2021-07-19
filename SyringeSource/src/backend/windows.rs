use crate::WINDOW_TITLE;
use color_eyre::eyre::*;
use err_derive::*;
use winapi::{
    ctypes::c_void,
    shared::{minwindef::DWORD, ntdef::LUID, winerror::WAIT_TIMEOUT},
    um::{
        errhandlingapi, handleapi, memoryapi, processthreadsapi, securitybaseapi,
        synchapi::WaitForSingleObject,
        winbase,
        winnt::{
            HANDLE, LUID_AND_ATTRIBUTES, MEMORY_BASIC_INFORMATION, PAGE_EXECUTE_READ,
            PAGE_EXECUTE_READWRITE, PAGE_GUARD, PAGE_NOACCESS, PAGE_READONLY, PAGE_READWRITE,
            PROCESS_QUERY_INFORMATION, PROCESS_VM_OPERATION, PROCESS_VM_READ, PROCESS_VM_WRITE,
            SE_DEBUG_NAME, SE_PRIVILEGE_ENABLED, TOKEN_ADJUST_PRIVILEGES, TOKEN_PRIVILEGES,
            TOKEN_QUERY,
        },
        winnt::{MEM_FREE, SYNCHRONIZE},
        winuser,
    },
};

const PERMISSIONS: DWORD = PROCESS_QUERY_INFORMATION
    | PROCESS_VM_READ
    | PROCESS_VM_WRITE
    | PROCESS_VM_OPERATION
    | SYNCHRONIZE;
const STRING_BUF_LEN: usize = 512;

///https://docs.microsoft.com/en-us/windows/desktop/Debug/system-error-codes
pub fn get_last_error() -> DWORD {
    unsafe { errhandlingapi::GetLastError() }
}

#[derive(Debug, Error)]
pub enum WinError {
    /// if a specific WinAPI function call caused an error code
    /// https://docs.microsoft.com/en-us/windows/desktop/Debug/system-error-codes
    /// (WinAPI function <header>::<function>, <error code>)
    #[error(
        display = "Windows error code: {:#010X} / {} (custom info: {})",
        1,
        1,
        0
    )]
    Code(&'static str, DWORD),
    /// if a call to a WinAPI function call contains not enough data or did only partially work
    #[error(display = "error interacting with WinAPI: \"{}\"", 0)]
    Check(&'static str),
}

pub struct Game {
    process_handle: *mut c_void,
}

// the pointer is only a handle
unsafe impl Send for Game {}
unsafe impl Sync for Game {}

impl Game {
    pub fn new() -> Result<Game, Report> {
        unsafe {
            enable_debug_privileges()?;
        }

        let window_handle = unsafe {
            winuser::FindWindowW(
                wstring_nul("CONTRAPTION_WINDOWS_CLASS").as_ptr(),
                wstring_nul(WINDOW_TITLE).as_ptr(),
            )
        };
        if window_handle.is_null() {
            return Err(eyre!("failed to get window handle to \"{}\"", WINDOW_TITLE));
        }

        let process_id = unsafe {
            let mut pid = 0;
            winuser::GetWindowThreadProcessId(window_handle, &mut pid);
            pid
        };

        if process_id == 16777216 {
            return Err(eyre!(
                "failed to get process handle to \"{}\"",
                WINDOW_TITLE
            ));
        }

        let window_name = vec![0u16; STRING_BUF_LEN];
        let window_name = String::from_utf16_lossy(
            &window_name[..unsafe {
                winuser::GetWindowTextW(
                    window_handle,
                    window_name.as_ptr() as *mut _,
                    STRING_BUF_LEN as i32,
                ) as usize
            }],
        );

        let window_name = window_name.trim_end().to_owned();

        if &window_name != "Scrap Mechanic" {
            return Err(eyre!("hooked into wrong process: {}", window_name));
        }

        let process_handle =
            open_process(PERMISSIONS, process_id).expect("opened process with invalid handle");

        Ok(Game { process_handle })
    }

    // https://stackoverflow.com/a/6493793
    pub fn is_running(&self) -> bool {
        let ret = unsafe { WaitForSingleObject(self.process_handle, 0) };

        ret == WAIT_TIMEOUT
    }

    /// Tries to write a value at address `ptr` in the game's memory
    pub unsafe fn write<T>(&self, ptr: *mut T, value: &T) -> Result<(), Report> {
        let mut memory_basic_information = std::mem::zeroed::<MEMORY_BASIC_INFORMATION>();

        let ptr = ptr as usize;

        let val_bytes = value as *const T as *const u8;
        let ptr_high = std::mem::size_of_val(value) + ptr;
        let mut total_bytes_written = 0;

        let mut page_start = ptr;
        while page_start <= ptr_high as usize {
            if memoryapi::VirtualQueryEx(
                self.process_handle,
                page_start as *const c_void,
                &mut memory_basic_information,
                std::mem::size_of::<MEMORY_BASIC_INFORMATION>(),
            ) != 0
            {
                page_start = memory_basic_information.BaseAddress as usize
                    + memory_basic_information.RegionSize as usize;

                let allocation_protect = memory_basic_information.AllocationProtect;

                if ((allocation_protect & (PAGE_EXECUTE_READWRITE | PAGE_READWRITE)) != 0)
                    && ((allocation_protect & (PAGE_GUARD | PAGE_NOACCESS)) == 0)
                {
                    let hi = (memory_basic_information.BaseAddress as usize
                        + memory_basic_information.RegionSize as usize)
                        .min(ptr_high);
                    let lo = (memory_basic_information.BaseAddress as usize).max(ptr);

                    let mut bytes_written = 0;

                    if memoryapi::WriteProcessMemory(
                        self.process_handle,
                        lo as *mut c_void,
                        (val_bytes as usize + (lo - ptr)) as *mut c_void,
                        (hi - ptr) - (lo - ptr),
                        &mut bytes_written,
                    ) == 0
                    {
                        return Err(WinError::Code(
                            "memoryapi::WriteProcessMemory",
                            get_last_error(),
                        )
                        .into());
                    } else {
                        assert_eq!(
                            (hi - ptr) - (lo - ptr),
                            bytes_written,
                            "write must be complete"
                        );
                        total_bytes_written += bytes_written;
                    }
                }
            } else {
                return Err(WinError::Code("memoryapi::VirtualQueryEx", get_last_error()).into());
            }
        }
        if total_bytes_written == std::mem::size_of_val(value) {
            Ok(())
        } else {
            return Err(WinError::Check("wrote value partially").into());
        }
    }

    pub unsafe fn update_pages(&mut self) -> Result<(), Report> {
        Ok(())
    }

    /// Returns a vector with length `len` which was filled with the game's process memory
    /// in the range `ptr..(ptr + len * size_of::<T>())`
    /// the memory pages are iterated and only pages with the AllocationProtect flags of PAGE_EXECUTE_READWRITE or PAGE_READWRITE or PAGE_EXECUTE_READ or PAGE_READONLY
    /// and PAGE_GUARD or PAGE_NOACCESS are read from.
    pub unsafe fn read_vec<T>(&self, ptr: *const T, len: usize) -> Result<Vec<T>, Report> {
        let mut memory_basic_information = std::mem::zeroed::<MEMORY_BASIC_INFORMATION>();

        let ptr = ptr as usize;

        let mut ret = Vec::<T>::with_capacity(len);
        ret.set_len(ret.capacity());
        let ptr_high = (len * std::mem::size_of::<T>()) + ptr;

        let mut _number_of_bytes_read = 0;

        let mut page_start = ptr;
        while page_start <= ptr_high as usize {
            if memoryapi::VirtualQueryEx(
                self.process_handle,
                page_start as *const c_void,
                &mut memory_basic_information,
                std::mem::size_of::<MEMORY_BASIC_INFORMATION>(),
            ) != 0
            {
                page_start = memory_basic_information.BaseAddress as usize
                    + memory_basic_information.RegionSize as usize;

                let allocation_protect = memory_basic_information.AllocationProtect;

                if memory_basic_information.State & MEM_FREE == 0
                    && ((allocation_protect
                        & (PAGE_EXECUTE_READWRITE
                            | PAGE_READWRITE
                            | PAGE_EXECUTE_READ
                            | PAGE_READONLY))
                        != 0)
                    && ((allocation_protect & (PAGE_GUARD | PAGE_NOACCESS)) == 0)
                {
                    let mut bytes_read = 0;
                    let hi = (memory_basic_information.BaseAddress as usize
                        + memory_basic_information.RegionSize as usize)
                        .min(ptr_high)
                        .max(memory_basic_information.BaseAddress as usize);
                    let lo = (memory_basic_information.BaseAddress as usize)
                        .max(ptr)
                        .min(
                            memory_basic_information.BaseAddress as usize
                                + memory_basic_information.RegionSize as usize,
                        );

                    if memoryapi::ReadProcessMemory(
                        self.process_handle,
                        lo as *const c_void,
                        (ret.as_mut_ptr() as usize + (lo - ptr)) as *mut c_void,
                        (hi - ptr) - (lo - ptr),
                        &mut bytes_read,
                    ) == 0
                    {
                        if get_last_error() == 299 {
                            // page was probably changed between the virtualqueryex call and the read
                            // good enough
                            /*ERROR_PARTIAL_COPY
                                299 (0x12B)
                                Only part of a ReadProcessMemory or WriteProcessMemory request was completed.
                            */
                            _number_of_bytes_read += bytes_read;
                        } else {
                            // read failed, even tho it is in bounds -> ignore
                            return Err(WinError::Code(
                                "memoryapi::ReadProcessMemory",
                                get_last_error(),
                            )
                            .into());
                        }
                    } else {
                        _number_of_bytes_read += bytes_read;
                    }
                }
            } else {
                return Err(WinError::Code("memoryapi::VirtualQueryEx", get_last_error()).into());
            }
        }
        Ok(ret)
    }
}

/**
 * https://stackoverflow.com/questions/43079931/java-jna-base-address-finding
 * Enables debug privileges for this process, required for OpenProcess() to
 * get processes other than the current user
 */
unsafe fn enable_debug_privileges() -> Result<(), WinError> {
    let mut handle = std::mem::zeroed::<HANDLE>();

    if processthreadsapi::OpenProcessToken(
        processthreadsapi::GetCurrentProcess(),
        TOKEN_QUERY | TOKEN_ADJUST_PRIVILEGES,
        &mut handle,
    ) == 0
    {
        Err(WinError::Code(
            "processthreadsapi::OpenProcessToken",
            get_last_error(),
        ))
    } else {
        let mut luid = std::mem::zeroed::<LUID>();
        if winbase::LookupPrivilegeValueW(
            std::ptr::null(),
            wstring_nul(SE_DEBUG_NAME).as_ptr(),
            &mut luid,
        ) == 0
        {
            let _ = handleapi::CloseHandle(handle);

            Err(WinError::Code(
                "winbase::LookupPrivilegeValueW",
                get_last_error(),
            ))
        } else {
            let mut tkp = std::mem::zeroed::<TOKEN_PRIVILEGES>();
            tkp.PrivilegeCount = 1;
            tkp.Privileges[0] = LUID_AND_ATTRIBUTES {
                Luid: luid,
                Attributes: SE_PRIVILEGE_ENABLED,
            };
            if securitybaseapi::AdjustTokenPrivileges(
                handle,
                false as i32,
                &mut tkp,
                0,
                std::ptr::null_mut(),
                std::ptr::null_mut(),
            ) == 0
            {
                let _ = handleapi::CloseHandle(handle);

                Err(WinError::Code(
                    "winbase::LookupPrivilegeValueW",
                    get_last_error(),
                ))
            } else if handleapi::CloseHandle(handle) == 0 {
                Err(WinError::Code("handleapi::CloseHandle", get_last_error()))
            } else {
                Ok(())
            }
        }
    }
}

fn open_process(permissions: DWORD, pid: DWORD) -> Result<HANDLE, WinError> {
    unsafe {
        let res = processthreadsapi::OpenProcess(permissions, true as i32, pid);
        if res.is_null() {
            Err(WinError::Check("processthreadsapi::OpenProcess: null ptr"))
        } else {
            Ok(res)
        }
    }
}

/// converts a regular string to a UTF-16 nul-terminated vector
pub fn wstring_nul(s: &str) -> Vec<u16> {
    let mut ret = s.encode_utf16().collect::<Vec<u16>>();
    ret.push(0);
    ret
}

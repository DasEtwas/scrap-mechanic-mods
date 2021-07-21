use crate::backend::Game;
use crate::err_exit;
use crate::peer::{
    Delimiter, Peer, DATA_VALUES, DELIMITER, DELIMITER_LEN, DELIMITER_LOOKUP, DELIMITER_MIN_VALUE,
    PEER_INPUT_OFFS,
};
use byteorder::{BigEndian, ByteOrder};
use color_eyre::eyre::*;
use color_eyre::Report;
use crossbeam_channel::{Receiver, Sender};
use parking_lot::RwLock;
use std::num::NonZeroU64;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::JoinHandle;
use std::time::Duration;
use std::{
    mem::size_of,
    net::{Ipv4Addr, SocketAddr, SocketAddrV4, UdpSocket},
};
use winapi::um::sysinfoapi::GetSystemInfo;

pub enum ServerInstruction {
    SetValues(Vec<(u32, f64)>),
    Scan,
    GetValues(Vec<u32>, SocketAddr),
    PollAll,
    AbortScan,
}

pub enum AppInstruction {
    ReturnValues(Vec<(u32, f64)>, SocketAddr),
}

pub struct Server {
    pub incoming: Receiver<ServerInstruction>,
    pub outgoing: Sender<AppInstruction>,
}

impl Server {
    fn new(port: u16, net_debug: bool) -> Server {
        let (incoming_server, incoming) = crossbeam_channel::unbounded::<ServerInstruction>();
        let (outgoing, outgoing_server) = crossbeam_channel::unbounded::<AppInstruction>();

        std::thread::spawn(move || {
            let socket = match UdpSocket::bind(SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, port)) {
                Ok(s) => s,
                Err(e) => err_exit(format!("error creating server socket: {}", e), 2),
            };
            socket.set_nonblocking(true).unwrap();

            let mut buf = [0; 8192];

            if net_debug {
                println!(
                    "started listening on port {}, buffer size {} bytes",
                    port,
                    buf.len()
                );
            }

            loop {
                for outgoing in outgoing_server.try_iter() {
                    match outgoing {
                        AppInstruction::ReturnValues(values, addr) => {
                            let mut buf = vec![10u8];
                            buf.extend(
                                values
                                    .into_iter()
                                    .map(|(channel, value)| {
                                        let mut buf =
                                            vec![0u8; size_of::<u32>() + size_of::<f64>()];
                                        BigEndian::write_u32(&mut buf[0..4], channel);
                                        BigEndian::write_f64(&mut buf[4..12], value);
                                        buf
                                    })
                                    .flatten(),
                            );

                            socket.send_to(buf.as_slice(), &addr).unwrap();

                            if net_debug {
                                println!("sent {} bytes to {:?}", buf.len(), addr);
                            }
                        }
                    }
                }

                while let Ok((len, recv_address)) = socket.recv_from(&mut buf) {
                    let received = buf[..len].to_vec();

                    if received.is_empty() {
                        eprintln!("received malformed packet: data length is zero");
                    } else {
                        match received[0] {
                            1 => {
                                let channels_values = received[1..]
                                    .chunks_exact(size_of::<u32>() + size_of::<f64>())
                                    .map(|bytes| {
                                        (
                                            BigEndian::read_u32(&bytes[0..4]),
                                            BigEndian::read_f64(&bytes[4..12]),
                                        )
                                    })
                                    .collect::<Vec<(u32, f64)>>();

                                if net_debug {
                                    println!(
                                        "received request to set channel values: {:?}",
                                        channels_values
                                    );
                                }

                                incoming_server
                                    .send(ServerInstruction::SetValues(channels_values))
                                    .unwrap();
                            }
                            2 => {
                                let channels = received[1..]
                                    .chunks_exact(size_of::<u32>())
                                    .map(|bytes| (BigEndian::read_u32(&bytes[0..4])))
                                    .collect::<Vec<u32>>();

                                if net_debug {
                                    println!("received request to return channel values for channels: {:?}", channels);
                                }

                                incoming_server
                                    .send(ServerInstruction::GetValues(channels, recv_address))
                                    .unwrap()
                            }
                            3 => {
                                if net_debug {
                                    println!("received request to scan for new peers");
                                }
                                incoming_server.send(ServerInstruction::Scan).unwrap();
                            }
                            4 => {
                                incoming_server.send(ServerInstruction::PollAll).unwrap();
                            }
                            5 => {
                                incoming_server.send(ServerInstruction::AbortScan).unwrap();
                            }
                            _ => (),
                        }
                    }
                }

                std::thread::sleep(Duration::from_micros(150));
            }
        });

        Server { incoming, outgoing }
    }
}

pub struct Injector {
    pub game: Arc<RwLock<Game>>,
    pub peers: Vec<Peer>,
    pub server: Server,
    pub peer_pool: Vec<Option<NonZeroU64>>,
}

pub struct SearchResult {
    found_peers: Vec<Peer>,
    time_took: Duration,
    bytes_read: usize,
}

impl Injector {
    pub fn new(game: Game, port: u16, netdebug: bool) -> Injector {
        let server = Server::new(port, netdebug);

        Injector {
            game: Arc::new(RwLock::new(game)),
            peers: vec![],
            server,
            peer_pool: vec![],
        }
    }

    pub fn run(&mut self) -> Result<(), Report> {
        let mut scan_interrupt_signal_join_handle: Option<(
            Arc<AtomicBool>,
            Arc<AtomicBool>,
            JoinHandle<SearchResult>,
        )> = None;

        while let Ok(instruction) = self.server.incoming.recv() {
            let mut responses = Vec::new();

            if let Some((_interrupt_signal, done_signal, _join_handle)) =
                &scan_interrupt_signal_join_handle
            {
                if done_signal.load(Ordering::Relaxed) {
                    let (_, _, join_handle) = scan_interrupt_signal_join_handle.take().unwrap();

                    match join_handle.join() {
                        Ok(res) => {
                            for peer in res.found_peers.iter() {
                                println!(
                                    "Added new peer at base address {:#0X}",
                                    peer.address() as usize
                                )
                            }

                            self.peers.extend(res.found_peers.into_iter());

                            self.peers.sort_by_key(|p| p.address() as usize);
                            self.peers.dedup_by_key(|p| p.address() as usize);

                            println!("Current peer list ({}):", self.peers.len());

                            for peer in self.peers.iter() {
                                println!(
                                    "Address: {:#0X}, Channel: {}",
                                    peer.address() as usize,
                                    peer.channel
                                );
                            }
                        }
                        Err(e) => {
                            eprintln!("Failed to get scan result: {:?}", e);
                        }
                    }
                }
            }

            if !self.game.read().is_running() {
                println!("Game is not running anymore");
                return Ok(());
            }

            match instruction {
                ServerInstruction::SetValues(channels_values) => {
                    channels_values.into_iter().for_each(|(channel, value)| {
                        let mut remove = vec![];
                        for (i, peer) in self
                            .peers
                            .iter_mut()
                            .enumerate()
                            .filter(|(_, peer)| peer.channel == channel)
                        {
                            peer.input = value;

                            if !Self::write_peer(&self.game.read(), peer) {
                                remove.push(i);
                            }
                        }

                        // remove in reverse order to prevent index shifting
                        for i in remove.into_iter().rev() {
                            println!(
                                "Removed peer at {:#018X}, {} left",
                                self.peers.remove(i).address() as usize,
                                self.peers.len()
                            );
                        }
                    })
                }
                ServerInstruction::Scan => {
                    if scan_interrupt_signal_join_handle.is_some() {
                        eprintln!("Already scanning.");
                    } else {
                        let interrupt_signal = Arc::new(AtomicBool::new(false));
                        let done_signal = Arc::new(AtomicBool::new(false));

                        unsafe {
                            self.game.write().update_pages().unwrap();
                        }

                        let join_handle = std::thread::spawn({
                            let known_peers = self.peers.clone();
                            let peer_pool = self.peer_pool.clone();
                            let game = self.game.clone();
                            let interrupt_signal = interrupt_signal.clone();
                            let done_signal = done_signal.clone();

                            move || {
                                println!("Scanning for peers");

                                let res = Self::search_peers(
                                    known_peers,
                                    peer_pool,
                                    game,
                                    interrupt_signal,
                                );

                                println!(
                                    "Scanned {} bytes for peers in {}ms, found {} new peers. Waiting for next packet to add peers to list.",
                                    res.bytes_read,
                                    res.time_took.as_millis(),
                                    res.found_peers.len()
                                );

                                done_signal.store(true, Ordering::Relaxed);

                                res
                            }
                        });

                        scan_interrupt_signal_join_handle =
                            Some((interrupt_signal, done_signal, join_handle));
                    }
                }
                ServerInstruction::PollAll => {
                    println!("Polling all {} peers", self.peers.len());
                    let mut remove = vec![];

                    unsafe {
                        self.game.write().update_pages().unwrap();
                    }

                    for (i, peer) in self.peers.iter_mut().enumerate() {
                        if !matches!(
                            Self::read_peer(&self.game.read(), peer, &mut self.peer_pool),
                            Ok(true)
                        ) {
                            remove.push(i);
                        }
                    }

                    // remove in reverse order to prevent index shifting
                    for i in remove.into_iter().rev() {
                        println!(
                            "Removed invalid peer at {:#018X}",
                            self.peers.remove(i).address() as usize
                        );
                    }
                }
                ServerInstruction::GetValues(channels, addr) => {
                    responses.push(AppInstruction::ReturnValues(
                        {
                            let mut ret = vec![];
                            for channel in channels {
                                let mut remove = vec![];
                                if let Some((i, peer)) = self
                                    .peers
                                    .iter_mut()
                                    .enumerate()
                                    .find(|(_, peer)| peer.channel == channel)
                                {
                                    if let Ok(true) = Self::read_peer(
                                        &self.game.read(),
                                        peer,
                                        &mut self.peer_pool,
                                    ) {
                                        if let Some(output) = peer.output {
                                            ret.push((channel, output));
                                        }
                                    } else {
                                        remove.push(i);
                                    }
                                }

                                // remove in reverse order to prevent index shifting
                                for i in remove.into_iter().rev() {
                                    println!(
                                        "Removed invalid peer at {:#018X}",
                                        self.peers.remove(i).address() as usize
                                    );
                                }
                            }
                            ret
                        },
                        addr,
                    ));
                }
                ServerInstruction::AbortScan => {
                    if let Some((interrupt_signal, _, _)) = &scan_interrupt_signal_join_handle {
                        interrupt_signal.store(true, Ordering::Relaxed);
                        println!("Sent abort signal to scanning thread");
                    } else {
                        eprintln!("No scanning in progress to abort.");
                    }
                }
            }

            for response in responses {
                self.server.outgoing.try_send(response)?;
            }
        }

        Ok(())
    }

    /// reads peer's memory and updates it's internal state to reflect game memory
    fn read_peer(
        game: &Game,
        peer: &mut Peer,
        peer_pool: &mut Vec<Option<NonZeroU64>>,
    ) -> Result<bool, Report> {
        unsafe {
            let address = peer.address() as usize;
            // reads the lua-side `data` array table which we hope is contiguous and unique
            let data = game.read_vec(
                (address as usize) as *const f64,
                DELIMITER_LEN + DATA_VALUES + peer_pool.len().max(1),
            )?;

            let mut delim = [0.0; DELIMITER_LEN];
            delim.copy_from_slice(&data[..DELIMITER_LEN]);

            let mut values = [0.0; DATA_VALUES];
            values.copy_from_slice(&data[DELIMITER_LEN..DELIMITER_LEN + DATA_VALUES]);

            // validate delimiter before writing input
            if Peer::is_delimiter_valid(delim) {
                let pool_size = (values[10].max(0.0) as usize).max(peer_pool.len());

                if pool_size > peer_pool.len() {
                    peer_pool.resize(pool_size, None);

                    // we recurse as long as the peer pool size increases, so we can read the whole pool
                    Self::read_peer(game, peer, peer_pool)
                } else {
                    peer.update_data(values);

                    peer_pool
                        .iter_mut()
                        .zip(data[DELIMITER_LEN + 11..].iter())
                        .for_each(|(pool, lua)| {
                            if *lua == -1.0 || (!lua.is_finite() || lua.is_sign_negative()) {
                                // -1 indicates a destroyed part
                                *pool = None;
                            } else {
                                // this peer probably has more recent data, let's update it
                                *pool = pool.or(NonZeroU64::new((*lua) as u64))
                            }
                        });

                    //println!("Downloaded peer addresses: {:018X?}", &peer_pool);

                    //println!("values: {:?}", value_data);
                    Ok(true)
                }
            } else {
                Ok(false)
            }
        }
    }

    /// reads peer's memory and updates it's internal state to reflect game memory
    /// also write's this peer's inputs into the game
    fn write_peer(game: &Game, peer: &mut Peer) -> bool {
        unsafe {
            let address = peer.address() as usize;
            let input = peer.input;
            if let Ok(value_data) =
                game.read_vec(address as *const f64, DELIMITER_LEN + DATA_VALUES)
            {
                let mut delim = [0.0; DELIMITER_LEN];
                delim.copy_from_slice(&value_data[..DELIMITER_LEN]);

                let mut values = [0.0; DATA_VALUES];
                values.copy_from_slice(&value_data[DELIMITER_LEN..]);

                // validate delimiter before writing input
                if Peer::is_delimiter_valid(delim) {
                    if let Err(e) = game.write(
                        (address as usize
                            + size_of::<Delimiter>()
                            + size_of::<f64>() * PEER_INPUT_OFFS)
                            as *mut f64,
                        &input,
                    ) {
                        eprintln!(
                            "Failed to update peer data: {}\t (peer {:#018X})",
                            e, address
                        );
                        false
                    } else {
                        peer.update_data(values);
                        true
                    }
                } else {
                    false
                }
            } else {
                false
            }
        }
    }

    /// "Scan"
    pub fn search_peers(
        mut known_peers: Vec<Peer>,
        mut peer_pool: Vec<Option<NonZeroU64>>,
        game: Arc<RwLock<Game>>,
        interrupt_signal: Arc<AtomicBool>,
    ) -> SearchResult {
        let start = std::time::Instant::now();
        let mut found_peers = Vec::new();
        let mut bytes_read = 0;

        // start address before which probably none of the lua objects exist
        const START_ADDR: usize = 7734552;
        /// found to be best size/speed DELIMITER_LEN * 240
        /// generally, a greater value is faster
        const READ_SIZE: usize = DELIMITER_LEN * 240;

        // we read all peers in the hope that one is still valid, so it can give us the peer pool
        for peer in known_peers.iter_mut() {
            let _ = Self::read_peer(&game.read(), peer, &mut peer_pool);
        }

        if known_peers.is_empty() {
            peer_pool.clear();
        }

        let (min_address, max_address) = unsafe {
            let mut system_info = std::mem::zeroed::<winapi::um::sysinfoapi::SYSTEM_INFO>();
            GetSystemInfo(&mut system_info);
            (
                system_info.lpMinimumApplicationAddress as usize,
                system_info.lpMaximumApplicationAddress as usize,
            )
        };

        let mut search_addr = START_ADDR.max(min_address) / size_of::<f64>() * size_of::<f64>();

        let mut special_addresses_iter = vec![];

        let mut pool_found = false;
        let mut scan_time_warning_printed = false;

        while search_addr < max_address {
            assert_eq!(search_addr % size_of::<f64>(), 0, "unaligned f64 pointer");

            if interrupt_signal.load(Ordering::Relaxed) {
                println!("Interrupted scanning");
                break;
            }

            if special_addresses_iter.is_empty() {
                if pool_found {
                    // we found the pool and checked every address in it for peers
                    // -> probably every peer was found
                    println!("Finished scanning every peer in peerPool");
                    break;
                }

                let addresses = peer_pool
                    .iter()
                    .enumerate()
                    .filter_map(|(peer_pool_index, x)| x.map(|ptr| (peer_pool_index, ptr.get())))
                    .map(|(_i, ptr)| ptr)
                    .collect::<Vec<u64>>();

                // LuaJIT (x64) src/lj_obj.h->GCTab,MRef
                // in the Lua mod we print the Peer.data table, resulting in something like: "table: 0x02472939D"
                // we follow the pointer chain:
                // "table: 0x02472939D" (0x02472939D) -> GCTab + 16 -> array data at index zero + 8 -> first array element
                let table_addresses = addresses
                    .into_iter()
                    .filter_map(|gc_tab_pointer| unsafe {
                        game.read()
                            .read_vec((gc_tab_pointer as usize + 16) as *const usize, 1)
                            .ok()
                            .map(|vec| vec[0])
                            .filter(|table_array_ptr| *table_array_ptr != usize::MAX)
                            .map(|table_array_ptr| table_array_ptr + 8)
                    })
                    .collect::<Vec<_>>();

                if table_addresses.is_empty() {
                    if !scan_time_warning_printed {
                        println!("No existing valid peers could be used to find other peer's pointers directly. Searching may take significant time. Use the abort scan packet to interrupt scanning.")
                    }

                    scan_time_warning_printed = true;
                } else {
                    special_addresses_iter = table_addresses;
                    pool_found = true;
                }
            } else {
                search_addr = special_addresses_iter.remove(0);
                // align to 8 bytes
                search_addr -= search_addr % size_of::<f64>();
            }

            let new_peers = match unsafe {
                game.read()
                    .read_vec(search_addr as usize as *const f64, READ_SIZE)
            } {
                Ok(data) => {
                    // READ_SIZE == data.len()
                    bytes_read += data.len() * size_of::<f64>();

                    let mut new_peers = Vec::new();

                    // 'search_region_idx' is the index inside of 'data'
                    let mut search_region_idx = 0;
                    while search_region_idx < data.len() {
                        let search_region_first_value = data[search_region_idx];

                        if search_region_first_value >= DELIMITER_MIN_VALUE
                            && DELIMITER.contains(&search_region_first_value)
                        {
                            let i = DELIMITER_LOOKUP[search_region_first_value as usize] as usize;

                            let value_delim_idx = i * size_of::<f64>();

                            // lower bounds check
                            if search_addr as usize > value_delim_idx && i <= search_region_idx {
                                // process memory pointer to delimiter start
                                let delimiter_ptr = (search_addr as usize
                                    + search_region_idx * size_of::<f64>()
                                    - value_delim_idx)
                                    as *const f64;

                                if !known_peers
                                    .iter()
                                    .chain(found_peers.iter())
                                    .any(|peer| peer.address() as *const f64 == delimiter_ptr)
                                {
                                    let mut peer = Peer::new(delimiter_ptr as *const Delimiter);

                                    match Self::read_peer(&game.read(), &mut peer, &mut peer_pool) {
                                        Ok(true) => {
                                            new_peers.push(peer);
                                        }
                                        // memory read failed somehow
                                        Err(e) => {
                                            println!("Failed to read peer while scanning: {}", e);
                                        }
                                        // we found garbage
                                        Ok(false) => (),
                                    }
                                }
                            }
                        }

                        // we try to probe at least 3 values of a potential delimiter because one value is always random
                        search_region_idx += DELIMITER_LEN / 3;
                    }

                    new_peers
                }
                Err(_) => Vec::new(),
            };

            found_peers.extend_from_slice(&new_peers);
            search_addr += (READ_SIZE - DELIMITER_LEN * 2) * size_of::<f64>();
        }

        let time = start.elapsed();

        found_peers.sort_by_key(|p| p.address() as usize);
        found_peers.dedup_by_key(|p| p.address() as usize);

        SearchResult {
            found_peers,
            time_took: time,
            bytes_read,
        }
    }
}

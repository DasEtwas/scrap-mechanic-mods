use lazy_static::*;
use std::fmt::{Display, Error, Formatter};
use std::time::SystemTime;

// has nothing to do with data values
pub const DELIMITER_MIN_VALUE: f64 = 9.0;

lazy_static! {
    pub static ref DELIMITER: Vec<f64> = {
        let ret = vec![
            14.0, 237.0, 139.0, 191.0, 192.0, 176.0, 201.0, 118.0, 152.0, 171.0, 27.0, 199.0, 55.0, 77.0, 217.0, 101.0, 122.0, 155.0, 15.0, 180.0, 60.0, 239.0, 58.0, 248.0, 17.0, 204.0, 198.0, 38.0, 98.0, 125.0, 206.0, 61.0, 174.0, 137.0, 80.0, 43.0, 213.0, 59.0, 172.0, 236.0, 51.0, 18.0, 28.0, 11.0, 227.0, 104.0, 170.0, 105.0, 42.0, 86.0, 156.0, 66.0, 138.0, 207.0, 83.0, 159.0, 222.0, 121.0, 185.0, 94.0, 158.0, 32.0, 254.0, 13.0, 67.0, 203.0, 221.0, 79.0, 106.0, 120.0, 54.0, 150.0, 108.0, 16.0, 226.0, 48.0, 146.0, 173.0, 202.0, 57.0, 157.0, 242.0, 210.0, 110.0, 129.0, 21.0, 253.0, 114.0, 228.0, 241.0, 12.0, 39.0, 102.0, 142.0, 182.0, 149.0, 211.0, 97.0, 153.0, 116.0, 23.0, 112.0, 93.0, 103.0, 195.0, 82.0, 131.0, 140.0, 46.0, 243.0, 194.0, 205.0, 154.0, 147.0, 25.0, 196.0, 119.0, 63.0, 188.0, 244.0, 99.0, 71.0, 45.0, 164.0, 166.0, 111.0, 113.0, 89.0, 165.0, 41.0, 49.0, 31.0, 85.0, 132.0, 220.0, 200.0, 143.0, 249.0, 40.0, 130.0, 19.0, 219.0, 162.0, 30.0, 92.0, 247.0, 160.0, 90.0, 20.0, 214.0, 34.0, 134.0, 161.0, 26.0, 229.0, 81.0, 141.0, 9.0, 72.0, 212.0, 126.0, 115.0, 69.0, 56.0, 117.0, 123.0, 168.0, 208.0, 231.0, 33.0, 215.0, 78.0, 251.0, 230.0, 189.0, 235.0, 127.0, 223.0, 181.0, 136.0, 52.0, 35.0, 87.0, 187.0, 64.0, 88.0, 76.0, 234.0, 74.0, 178.0, 145.0, 70.0, 29.0, 75.0, 240.0, 37.0, 135.0, 68.0, 44.0, 224.0, 124.0, 24.0, 50.0, 175.0, 184.0, 133.0, 167.0, 73.0, 91.0, 197.0, 186.0, 218.0, 233.0, 209.0, 238.0, 245.0, 193.0, 151.0, 62.0, 36.0, 179.0, 252.0, 216.0, 232.0, 10.0, 250.0, 246.0, 95.0, 190.0, 128.0, 84.0, 255.0, 107.0, 100.0, 109.0, 169.0, 183.0, 177.0, 163.0, 148.0, 96.0, 225.0, 53.0, 144.0, 22.0, 65.0, 47.0,
        ];

        assert_eq!(DELIMITER_LEN, ret.len());
        ret
    };

    /// creates a reverse lookup table for all float values
    /// to get the location of a certain f64 in the delimiter, cast it as usize and index DELIMITER_LOOKUP, then cast the u16 to usize
   pub static ref DELIMITER_LOOKUP: Vec<u16> = {
        let max = DELIMITER.iter().map(|f| *f as usize).max().unwrap();
        let mut vec = vec![0; max + 1];

        DELIMITER.iter().enumerate().for_each(|(i, v)| vec[*v as usize] = i as u16);
        vec
    };
}

pub const DELIMITER_LEN: usize = 247;
pub type Delimiter = [f64; DELIMITER_LEN];
pub type PeerData = [f64; DATA_VALUES];

pub const DATA_VALUES: usize = 10 + 1; // number of fields in the array that are not the search identifier + global peerPool size

/// if a script has this value in the output slot, it means that it does not write output
/// the script writes output if the part has at least 1 seat connected and that seat is active (player sitting inside), and it has at least one other input
/// scripts with this value may not overwrite the local channel output values
pub const NO_OUTPUT_VALUE: f64 = -5.75469999999999994422213214208E29;

/// offset in double floats of the peer's input value to write into game memory
pub const PEER_INPUT_OFFS: usize = 1;

/// represents a reference (pointer) to the array of a peer part
#[derive(Copy, Clone, Debug)]
pub struct Peer {
    /// the peer's address in the game's memory (denotes the address of the first element of the `data` table/array)
    address: *const Delimiter,
    /// input provided by this application, set by writing to the process if the peer is active
    pub input: f64,
    /// output value of the part, None if the part does not have at least one active seat connected and another interactable to input its value or the seat is not occupied
    pub output: Option<f64>,
    pub channel: u32,
    /// part color
    pub red: f64,
    /// part color
    pub green: f64,
    /// part color
    pub blue: f64,
    /// number of connected children #self.interactable:getChildren()
    pub num_outputs: u32,
    /// number of connected parents #self.interactable:getParents()
    pub num_inputs: u32,
    /// self.shape:getId()
    pub shape_id: u64,
    pub peer_pool_index: usize,
    /// the instant when this peer's values were last updated
    last_updated: SystemTime,
}

// pointer is one of another process
unsafe impl Send for Peer {}

impl Peer {
    pub fn new(address: *const Delimiter) -> Peer {
        Peer {
            address,
            input: 0.0,
            output: None,
            channel: 0,
            red: 0.0,
            green: 0.0,
            blue: 0.0,
            num_outputs: 0,
            num_inputs: 0,
            shape_id: 0,
            peer_pool_index: 0,
            last_updated: SystemTime::now(),
        }
    }

    pub fn address(&self) -> *const Delimiter {
        self.address
    }

    #[allow(clippy::float_cmp)]
    /// checks if the delimiter's doubles match with the given DELIMITER
    pub fn is_delimiter_valid(data: Delimiter) -> bool {
        const ALLOWED_WRONG: usize = 2;
        const DELETED_VALUE: f64 = 500.0;

        let mut wrongs = 0;

        for (memory, delimiter) in data.iter().zip(DELIMITER.iter()) {
            if memory != delimiter {
                wrongs += 1;

                if *memory == DELETED_VALUE {
                    return false;
                }
            }
        }

        wrongs <= ALLOWED_WRONG
    }

    pub fn update_data(&mut self, data: PeerData) {
        let [channel, _input, output, red, green, blue, num_outputs, num_inputs, shape_id, peer_pool_index, _] =
            data;

        self.channel = (channel - 5000.0).floor().min(u32::MAX as f64).max(0.0) as u32;

        if output != NO_OUTPUT_VALUE {
            // write channel output
            // Channels.setOut(script.channel, script.out);
            self.output = Some(output);
        } else {
            self.output = None;
        }

        self.red = red.min(1.0).max(0.0);
        self.green = green.min(1.0).max(0.0);
        self.blue = blue.min(1.0).max(0.0);
        self.num_outputs = num_outputs.floor() as u32;
        self.num_inputs = num_inputs.floor() as u32;
        self.shape_id = shape_id.floor() as u64;
        self.peer_pool_index = peer_pool_index.floor() as usize;

        self.last_updated = SystemTime::now();
    }
}

impl Display for Peer {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        writeln!(
            f,
            "Script[\naddress: {:#018X}\nchannel: {}\ninput: {}\noutput: {}\nred: {}\ngreen: {}\nblue: {}\noutputs: {}\ninputs: {}\nshape ID: {}\n]",
            self.address as usize,
            self.channel,
            self.input,
            match self.output {
                None => "Nothing connected as input".to_owned(),
                Some(v) => format!("{}", v),
            },
            self.red,
            self.green,
            self.blue,
            self.num_outputs,
            self.num_inputs,
            self.shape_id
        )
    }
}

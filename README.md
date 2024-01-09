# TotalViewITCH.jl
A toolkit to process NASDAQ TotalView-ITCH data for academic research.

## Description
Nasdaq TotalView-ITCH (“TotalView”) is a data feed used by professional traders to maintain a real-time view of market conditions. TotalView disseminates all quote and order activity for securities traded on the Nasdaq exchange—several billion messages per day—allowing users to reconstruct the limit order book for any security up to arbitrary depth with nanosecond precision. It is a unique data source for financial economists and engineers examining topics such as information flows through lit exchanges, optimal trading strategies, and the development of macro-level indicators from micro-level signals (e.g., a market turbulence warning).

While TotalView data is provided at no charge to academic researchers via the Historical TotalView-ITCH offering, historical data uses a binary file specification that poses challenges for researchers. TotalViewITCH.jl is a pure Julia package developed to efficiently process historical data files for academic research purposes. The package consists of: (1) a core module to parse Historical TotalView binary file format messages (i.e., deserialization), (2) a module to reconstruct limit order books from parsed messages, and (3) a module to store processed data into a research-friendly format.

## Usage
Usage is straightforward:
```julia
using TotalViewITCH
using TotalViewITCH: Parser, Backend, FileSystem, MongoDB, find
using Dates

parser = Parser{FileSystem}("./data/test")
parser("./data/bin/S031413-v41.txt", Date("2013-03-14"), ["A"], 4.1)
```
This example parses a raw ITCH file, `S031213-v41.txt`, which happens to have
`v4.1` formatting, and stores the extracted data (message, orderbooks, etc.) to
CSV files in `./data/test`. To process multiple tickers, simply add additional
tickers to the list:
```julia
parser("./data/bin/S031413-v41.txt", Date("2013-03-14"), ["A", "APPL"], 4.1)
```
Processing of multiple files (i.e., dates) should be performed with multiple
processes or, better yet, using multiple jobs on a high-performance computing
cluster.

The output has the following directory structure:
```
test
|- messages
   |- ticker=A
      |- date=2013-03-14
         |- partition.csv
|- orderbooks
|- noii
|- trades
```
This structure is convenient for parallelizing analyses performed at the
ticker-date level. For convenience, there is also a `find` method to pull all
day associated with a ticker-date pair:
```julia
df = find(parser.backend, "messages", "A", Date("2013-03-14"))
```
This method isn't recommended for large-scale analysis, but works fine for
exploring single ticker-dates.

> For large-scale analyses, its recommended to convert the processed data to
> the Apache Parquet format and use tools such as Apache Spark.

#### MongoDB
For small to medium sized databases, `TotalViewITCH` also provides a MongoDB
backend. To set up a MongoDB database with Docker, run:
```bash
docker run -p 27017:27017 --volume path/to/data/db:/data/db mongo:latest
```
This command exposes the database to your local machine on port `27017`. Now you
can populate the database in Julia:
```julia
backend = MongoDB("mongodb://localhost:27017", "test")
parser = Parser{MongoDB}(backend)
parser("./data/bin/S031413-v41.txt", Date("2013-03-14"), ["A"], 4.1)
```

## Data Version Support
`TotalViewITCH.jl` supports versions `4.1` and `5.0` of the TotalView-ITCH file
specificiation. The parser processes all message type required to reconstruct
limit order books as well as several additional types that do not impact the
order book.

| Message Type       | Symbol | Supported? | Notes                                 |
| ------------------ | :----: | :--------: | ------------------------------------- |
| Timestamp          | T      | 4.1        | Message type only exists for `v4.1`.  |
| System             | S      | ✓          |                                       |
| Market Participant | L      |            |                                       |
| Trade Action       | H      | ✓          |                                       |
| Reg SHO            | Y      |            |                                       |
| Stock Directory    | R      |            |                                       |
| Add                | A      | ✓          |                                       |
| Add w/ MPID        | F      | ✓          |                                       |
| Execute            | E      | ✓          |                                       |
| Execute w/ Price   | C      | ✓          |                                       |
| Cancel             | X      | ✓          |                                       |
| Delete             | D      | ✓          |                                       |
| Replace            | U      | ✓          |                                       |
| Cross Trade        | Q      | ✓          | Ignored by order book updates.        |
| Trade              | P      | ✓          | Ignored by order book updates.        |
| Broken Trade       | B      |            | Ignored by order book updates.        |
| NOII               | I      | ✓          |                                       |
| RPII               | N      |            |                                       |

**Table 1** The message types processed by `TotalViewITCH`.

#### Planned Work
At present, `TotalViewITCH` does **not** process:
- stock trading action codes (e.g., trading halts for individual stocks),
- Reg SHO codes,
- market participant position codes,
- execution codes

#### System Event Codes
There is no additional processing required for daily system event codes except for variant "C", which indicates the end of messages and therefore signals the program to stop reading messages. Likewise, there is no special processing required for system event codes that indicate emergency market conditions. We simply record these messages in the messages database.

<!-- #### Stock Trading Action Codes
- I don't know what should be done about these codes. E.g. if a stock is halted or paused, then does Nasdaq disseminate messages for that stock (that need to be ignored until resumption)? In that case, I can simply record the message. Otherwise, I have to hold onto incoming messages for that stock until resumption and then run order book updates on the backlog before processing new messages.

#### Reg SHO Codes
- No idea...

#### Market Participant Position Codes
- These can simply be recorded. They have no impact on the order book.

#### Execution Codes
- The printable code ('Y' or 'N') has no effect on order book updates, but should be recorded in the database for volume calculations. -->

## Contributing
This package is intended to be a community resource for researchers working with
TotalViewITCH. If you find a bug, have a suggestion or otherwise wish to
contribute to the package, please feel free to create an issue.

# TotalViewITCH.jl

## Description
A toolkit to process NASDAQ TotalView-ITCH data.

This package is intended for an academic audience.


## Data Version Support

### v4.1

#### Message Types

| Message Type       | Symbol | Supported? | Notes                                 |
| ------------------ | :----: | :--------: | ------------------------------------- |
| Timestamp          | T      | ✓          |                                       |
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
| Cross Trade        | Q      | ✓          | Ignored by order book updates         |
| Trade              | P      | ✓          | Ignored by order book updates         |
| Brodken Trade      | B      |            | Ignored by order book updates         |
| NOII               | I      | ✓          |                                       |
| RPII               | N      |            |                                       |

#### System Event Codes
- There is no special processing required for "daily" system event codes except from `C`, which indicates the end of messages and therefore signals the program to stop reading messages.
- There is no special processing required for "as needed" system event codes, which indicate emergency market conditions. We simply record these messages in the messages database.

#### Stock Trading Action Codes
- I don't know what should be done about these codes. E.g. if a stock is halted or paused, then does Nasdaq disseminate messages for that stock (that need to be ignored until resumption)? In that case, I can simply record the message. Otherwise, I have to hold onto incoming messages for that stock until resumption and then run order book updates on the backlog before processing new messages.

#### Reg SHO Codes
- No idea...

#### Market Participant Position Codes
- These can simply be recorded. They have no impact on the order book.

#### Execution Codes
- The printable code ('Y' or 'N') has no effect on order book updates, but should be recorded in the database for volume calculations.


### v5.0
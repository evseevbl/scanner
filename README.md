# scanner

Simple script for scanning your Redis.

## TL;DR
1. Write your own lua script with `init`, `map` and `reduce` functions. See `examples/` for more details.
2. Call `lua scan.lua -h <host>:<port> -s <your-script.lua>` to execute it.
3. The main idea is to do as much work on the server as possible, and avoid sending all keys and values to the client, as it is usually done with SCAN.

## Usage
`lua scan.lua` accepts the following arguments:
- `-h` host and port separated by semicolon. Multiple comma-separated hosts can be specified, for example `localhost:6301,localhost:6302`
- `-s` name of user script
- `-k` optional: keys per scan
- `-m` optional: max scans per EVAL call 

It is also possible to import `scanner.lua` like it is done in `scan.lua` and add your logic on top of it.

Lua 5.1 with redis-lua package is required. You can install it locally or use Dockerfile and run scanner in the container:
```shell
docker build . -t scanner:latest
docker run --network host -v `pwd`:/scanner -w /scanner -it --rm scanner:latest sh
```


## How it works
The code consists of three lua scripts:
* user script with implementation of `init`, `map` and `reduce`
* server part (template)
* client part

### User-provided script
It must contain implementations of three functions: 
* `init()` will be called to initialize empty state. Return empty accumulator, usually a table.
* `map(keys)` will be called with a range of keys and should return accumulator
* `reduce(acc, result)` will be used to combine accumulator with new result and should return new accumulator.  

**Note:** `reduce` is happening both at the server (between scans) and client (between server script invocations). It allows a tradeoff between scanning the whole server during one server script execution (which may take too long) and executing it too many times (making many requests and sending lots of data over the network). Use `max_scans` to adjust how many scans are performed during one server script execution.

A special subset of Lua must be used:
* no global variables
* only a few builtin [libraries](https://redis.io/docs/interact/programmability/lua-api/#runtime-libraries) are available

For more specific cases you can add the following declarations to the user script:
* function `should_stop` implemented to abort scan and return intermediate results based on some condition.
* string `scan_type` to filter only specific key types (ie, only hash sets)
* string `scan_match` to filter keys by pattern
* function `finish(result)` can be implemented to process resulting accumulator after the scan finishes. It is only executed locally, so it is possible to import any installed libraries (for example, save output in json or csv).

### Server script
It is constructed by combining user-provided script with server template. During one execution of server script up to `max_scans` are performed with `keys_per_scan` keys each. Next offset and reduced result are returned to the client.

### Client script
It constructs the server script and uploads it to all hosts. Then it executes server script multiple times, until offset reaches zero and scan is finished. If `finish` is defined, the client script will execute it after the scan is finished.


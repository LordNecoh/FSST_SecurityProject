# HTTP Data Leak — Proxy and Malicious Server

This project implements the network-security assignment scenario. It contains a malicious HTTP server that receives data through custom data-leak techniques, and a proxy/bridge that forwards client requests to the server while blocking the leak when the traffic passes through the proxy.

The scenario is run with Docker Compose and starts two HTTP services:

- the proxy listens on `localhost:8000`;
- the malicious server listens on `localhost:8001`.

The direct server port is used to show that the leak techniques work. The proxy port is used to show that the same techniques are neutralized when the defensive bridge is used.

---

## 1. Architecture

```text
                    Protected path

[ Client / data leaker ]
          |
          | HTTP on localhost:8000
          v
[ Proxy / bridge container ]
          |
          | HTTP to server:8001
          v
[ Malicious server container ]


                    Direct test path

[ Client / data leaker ] ---> HTTP on localhost:8001 ---> [ Malicious server ]
```

### Components

The project has two main components.

The `proxy` service listens on port `8000` that behaves like a transparent bridge: it receives client requests, forwards them to the malicious server, receives the server response, and sends it back to the client. For configured leak entrypoints, it sanitizes only the malicious `PUT /<entrypoint>` requests.

The `server` service listens on port `8001`. It is the malicious HTTP service that registers dynamic entrypoints, receives data through the implemented covert channels, reconstructs the leaked value, stores it in memory, and returns it through `GET /<entrypoint>`.

The proxy is intentionally separated from the malicious server. This models the case in which a network administrator cannot directly modify the service but can place a defensive bridge in front of it.

---

## 2. Implemented leak techniques

The implementation supports multiple independent leak activities at the same time and each activity is identified by its own dynamic entrypoint.

### 2.1 Dedicated header — `dedicated_header`

The client transfers data through the custom HTTP header `X-dataleak`.

Example direct leak request:

```http
PUT /sampleleak HTTP/1.1
Host: localhost:8001
X-dataleak: Y2lhbw==
```

`Y2lhbw==` is the Base64 representation of `ciao`.

Server behavior:

- the server reads the value of `X-dataleak`;
- the value is stored as the leaked value for that entrypoint;
- if the same entrypoint receives another dedicated-header leak, the newest value replaces the previous one.

Proxy defense:

- the proxy removes the leak-carrying header before forwarding the request;
- as a result, the malicious server receives no useful data for that leak.

### 2.2 Headers order — `headers_order`

The client transfers one bit per HTTP request by changing the relative order of two headers.

The implemented test convention is:

```text
Header-A before Header-B  -> bit 0
Header-B before Header-A  -> bit 1
```

Eight consecutive bits form one ASCII character and a sequence of eight zero bits, `00000000`, terminates the current string.

For usage of the assignment, the logical payload should be Base64-encoded text. For example like we report before, the string `ciao` should be sent as the ASCII characters of `Y2lhbw==`, followed by the `00000000` terminator.

Server behavior:

- each valid request contributes one bit to the entrypoint bit buffer;
- every group of 8 bits is decoded as one ASCII character;
- `00000000` terminates the current string;
- data sent after a terminator starts a new value and replaces the previous reconstructed value.

Proxy defense:

- the proxy changes the header sequence before forwarding the request;
- this destroys the ordering-based bit encoding;
- the server therefore reconstructs either no data or incorrect data, so the leak is neutralized.

---

## 3. API reference

The same API is available through the proxy on port `8000` and directly on the malicious server on port `8001`.

Use port `8000` to test the protected scenario. Use port `8001` only to show that the malicious server would work if the proxy were bypassed.

Important: in the protected scenario, send `POST /setup` through the proxy on port `8000`. The proxy records the entrypoint during setup; if setup is sent only to port `8001`, the malicious server knows the entrypoint but the proxy does not know that the corresponding `PUT` requests must be sanitized.

### 3.1 `POST /setup`

Registers a dynamic leak entrypoint.

This request is forwarded by the proxy without sanitization.

```bash
curl -X POST http://localhost:8000/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "sampleleak", "type": "dedicatedheader"}'
```

Request body:

| Field | Type | Description |
| --- | --- | --- |
| `entrypoint` | string | URI path to use for the leak. Both `sampleleak` and `/sampleleak` are accepted. |
| `type` | string | Leak technique. Allowed values: `dedicatedheader`, `headersorder`. |

Expected result:

- `200 OK` if the setup succeeds;
- `400 Bad Request` if the leak type is not supported by the malicious server.

### 3.2 `PUT /<entrypoint>`

Sends data to the configured leak entrypoint.

This is the only request type sanitized by the proxy.

Dedicated-header example through the proxy:

```bash
curl -X PUT http://localhost:8000/sampleleak \
  -H "X-dataleak: Y2lhbw=="
```

Dedicated-header example bypassing the proxy:

```bash
curl -X PUT http://localhost:8001/sampleleak \
  -H "X-dataleak: Y2lhbw=="
```

Expected result:

- through `8000`, the proxy sanitizes the request and the leak should fail;
- through `8001`, the malicious server receives the leak directly and stores it.

### 3.3 `GET /<entrypoint>`

Retrieves the value reconstructed by the malicious server.

```bash
curl -X GET http://localhost:8000/sampleleak
```

Expected result:

- `200 OK` with the reconstructed value if the entrypoint exists;
- `404 Not Found` if the entrypoint has not been configured.

### 3.4 `DELETE /clear`

Clears all in-memory server state: configured entrypoints, leaked values, and partial bit buffers.

This endpoint is intended for repeatable tests and demonstrations.

```bash
curl -X DELETE http://localhost:8001/clear
```

---

## 4. Requirements

All the following tools need to be installed before running the project:

- Docker
- Docker Compose plugin (`docker compose`)
- `curl`
- a Bash-compatible shell

No HTTPS configuration is required in fact the assignment tests just the HTTP endpoints.

The services use in-memory state, by restarting the containers or calling `DELETE /clear` removes configured entrypoints, leaked values, and partial bit buffers.

---

## 5. Run from scratch

### 5.1 Extract the submission archive

```bash
unzip progetto_dataleak.zip
cd progetto_dataleak
```

If the archive has a different name, replace `progetto_dataleak.zip` with the actual file name.

### 5.2 Build and start the containers

```bash
docker compose up --build -d
```

This command builds both services and starts them in the background.

### 5.3 Check that both services are running

```bash
docker compose ps
```

The expected exposed ports are:

```text
0.0.0.0:8000->8000/tcp    proxy
0.0.0.0:8001->8001/tcp    server
```

### 5.4 View logs during the demonstration

```bash
docker compose logs -f
```

If you encounter issues with Docker Compose, we recommend using the `logs` flag to view the system logs during the Compose phase

### 5.5 Stop the environment

```bash
docker compose down
```

---

## 6. Automated tests

Make the test scripts executable:

```bash
chmod +x test_complete.sh
```
```bash
chmod +x test_faq.sh
```
As for `./test_complete.sh`, it can be run in three different modes (protected/unprotected/direct)
```bash
Usage: ./test_complete.sh <mode>
  protected    - Through proxy, protection enabled  (port 8000)
  unprotected  - Through proxy, protection disabled (port 8000)
  direct       - Direct to server, no proxy         (port 8001)
```
### 6.1 Complete protected test through the proxy

```bash
./test_complete.sh protected
```

Expected behavior:

- `dedicatedheader` does not leak the original value;
- `headersorder` does not reconstruct the original string;
- the script reports that the protected behavior is correct.

### 6.2 Direct malicious-server test

```bash
./test_complete.sh direct
```

Expected behavior:

- `dedicatedheader` successfully stores and returns `dGVjMQ==`;
- `headersorder` successfully reconstructs `tec2`;
- this proves that the malicious server works when the proxy is bypassed.

### 6.3 Unprotected test through the proxy (disabled)

```bash
./test_complete.sh unprotected
```

Expected behavior:
- The script communicates with the proxy on port 8000, but disables the sanitization features by sending `{"enabled": false}` during the `/setup` phase;
- `dedicatedheader` successfully forwards the `X-dataleak` header to the server, allowing it to store and return `dGVjMQ==`;
- `headersorder` successfully forwards the requests keeping their native order intact, allowing the malicious server to reconstruct the original string `tec2`;
- This proves that the proxy supports a dynamic bypass mode and remains fully transparent when protection is explicitly disabled for an entrypoint.
  
Before each test, the scripts clear the server state with `DELETE /clear`.

### Core Requirements & Edge Cases test (./test_faq.sh)

The `./test_faq.sh` script focuses on validating edge cases, memory overwriting mechanisms, and specific operational constraints (defined in the FAQ on Aulaweb). It tests how both components handle sequential data streams, buffer overwrites, and the delimiter logic

It requires specifying the target port and whether the proxy mode is active (on) or bypassed (off):

```bash
Usage: ./test_faq.sh <PORT> <on|off>
  Test via Proxy:  ./test_faq.sh 8000 on
  Test via Server: ./test_faq.sh 8001 off
```

### 6.4 Direct malicious-server edge case validation

```bash
./test_faq.sh 8001 off
```

Expected behavior:
- `dedicatedheader` (Data Overwrite): The attacker sends a payload containing `'OLD'`, followed by a payload containing `'NEW'`. The malicious server must properly clear its buffer upon receiving the second payload and return exclusively `TkVX `(`'NEW'`);
- `headersorder` (Sequential Delimiters): The attacker sends character `'A'`, followed by 8 consecutive zero bits (the string terminator), followed by character `'B'`, and another string terminator. The server must correctly process the delimiter, reset its state machine for the new character block, overwrite the internal storage, and return exclusively `B`;
- This proves that the malicious server handles memory updates, sequential transmissions, and state resets properly when the proxy is bypassed.

### 6.5 Protected edge case validation through the proxy

```bash
./test_faq.sh 8000 on
```

Expected behavior:
- `dedicatedheader` Mitigation: The proxy intercepts both sequential `PUT` requests, strips the `X-dataleak` header on both occurrences, and passes clean packets to the backend. The server returns an empty string `''`;
- `headersorder` Mitigation: The proxy processes the consecutive stream of 32 HTTP requests, altering the physical line order of `Header-A` and `Header-B` across the entire transmission. The sequence of bits is corrupted before hitting the server backend, failing to reconstruct the consecutive sequences;
- The script reports that both edge case attacks have been successfully neutralized by the active proxy layout.

Before each test, the scripts clear the server state with `DELETE /clear`.

---

## 7. Manual demonstration commands

### 7.1 Dedicated header: direct server leak succeeds

By interacting directly with the malicious server on port 8001, the X-dataleak header is processed without any validation or filtering.

```bash
curl -X DELETE http://localhost:8001/clear

curl -X POST http://localhost:8001/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_direct", "type": "dedicatedheader"}'

curl -X PUT http://localhost:8001/demo_direct \
  -H "X-dataleak: Y2lhbw=="

curl -X GET http://localhost:8001/demo_direct
```

Expected output:

```text
Y2lhbw==
```

### 7.2 Dedicated header: proxy blocks the leak

By sending the request through the proxy on port 8000 with implicit protection, the proxy intercepts the non-standard header and drops it.

```bash
curl -X DELETE http://localhost:8001/clear

curl -X POST http://localhost:8000/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_proxy", "type": "dedicatedheader"}'

curl -X PUT http://localhost:8000/demo_proxy \
  -H "X-dataleak: Y2lhbw=="

curl -X GET http://localhost:8000/demo_proxy
```

Expected output:

```text

```

The empty output means that the proxy forwarded the request but removed the data used by the covert channel.

### 7.3 Proxy transparent bypass (Unprotected mode) 

By passing an explicit "enabled": false flag during setup, the proxy registers the route but intentionally skips the sanitization layer.

```bash
# Clear previous configurations
curl -X DELETE http://localhost:8001/clear

# Register the entrypoint on the proxy explicitly disabling protection
curl -X POST http://localhost:8000/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_dh_unprotected", "type": "dedicatedheader", "enabled": false}'

# Send the payload through the proxy
curl -X PUT http://localhost:8000/demo_dh_unprotected \
  -H "X-dataleak: Y2lhbw=="

# Verify that the leak successfully reached the backend
curl -X GET http://localhost:8000/demo_dh_unprotected
```

Expected output:

```text
Y2lhbw==
```

### 7.4 Direct server leak succeeds (Bypassing the proxy)

This technique exfiltrates data bit-by-bit by swapping the physical transmission order of two consecutive headers (Header-A and Header-B). If Header-A < Header-B, a 0 bit is registered; otherwise, a 1 bit is registered.
The following commands simulate transmitting the letter 't' (01110100), followed by 8 consecutive 0 bits as the string delimiter (STOP sequence).

```bash
# Clear previous configurations
curl -X DELETE http://localhost:8001/clear

# Register the entrypoint directly on the server
curl -X POST http://localhost:8001/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_ho_direct", "type": "headersorder"}'

# Send 8 bits representing 't' (01110100)
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-A: 1" -H "Header-B: 1" # bit 0
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-B: 1" -H "Header-A: 1" # bit 1
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-B: 1" -H "Header-A: 1" # bit 1
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-B: 1" -H "Header-A: 1" # bit 1
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-A: 1" -H "Header-B: 1" # bit 0
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-B: 1" -H "Header-A: 1" # bit 1
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-A: 1" -H "Header-B: 1" # bit 0
curl -X PUT http://localhost:8001/demo_ho_direct -H "Header-A: 1" -H "Header-B: 1" # bit 0

# Send 8 consecutive 0 bits as the string delimiter (STOP sequence)
for i in {1..8}; do curl -s -X PUT http://localhost:8001/demo_ho_direct -H "Header-A: 1" -H "Header-B: 1"; done

# Collect the reconstructed text from the server
curl -X GET http://localhost:8001/demo_ho_direct
```

Expected output:

```text
t
```

### 7.5 Proxy neutralizes the covert channel (Protected mode)

When sending the same exact sequence to port 8000, the proxy enforces a predefined native order on incoming headers, altering the malicious sequence before it reaches the backend.

```bash
# Clear previous configurations
curl -X DELETE http://localhost:8001/clear

# Register the entrypoint on the proxy with active protection
curl -X POST http://localhost:8000/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_ho_proxy", "type": "headersorder"}'

# Send the same bit stream representing 't' through the proxy
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-A: 1" -H "Header-B: 1"
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-A: 1" -H "Header-B: 1"
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-A: 1" -H "Header-B: 1"
curl -X PUT http://localhost:8000/demo_ho_proxy -H "Header-A: 1" -H "Header-B: 1"
for i in {1..8}; do curl -s -X PUT http://localhost:8000/demo_ho_proxy -H "Header-A: 1" -H "Header-B: 1"; done

# Check the final string reconstructed by the server backend
curl -X GET http://localhost:8000/demo_ho_proxy
```

Expected output:

```text
ý<Þ&
```
(Or any other corrupted character sequence. The output string will be broken or empty because the proxy standardized the transmission order of the keys, corrupting the hidden payload).

### 7.6 Proxy transparent bypass (Unprotected mode)

```bash
# Clear previous configurations
curl -X DELETE http://localhost:8001/clear

# Register the entrypoint on the proxy explicitly disabling protection
curl -X POST http://localhost:8000/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_ho_unprotected", "type": "headersorder", "enabled": false}'

# Send the bit stream representing 't' through the proxy
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-A: 1" -H "Header-B: 1"
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-A: 1" -H "Header-B: 1"
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-B: 1" -H "Header-A: 1"
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-A: 1" -H "Header-B: 1"
curl -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-A: 1" -H "Header-B: 1"
for i in {1..8}; do curl -s -X PUT http://localhost:8000/demo_ho_unprotected -H "Header-A: 1" -H "Header-B: 1"; done

# Verify that the character was decoded successfully
curl -X GET http://localhost:8000/demo_ho_unprotected
```

Expected output:

```text
t
```


---

## 8. Extensibility

The implementation is organized around technique-specific modules. The core server and proxy logic dispatch work through registries:

- server-side leak extractors are registered in `EXTRACTORS`;
- proxy-side leak sanitizers are registered in `SANITIZERS`.

This allows a new leak technique to be added without rewriting the HTTP routing logic.

### 8.1 Add a new malicious-server extractor

Create a new module under:

```text
server/modules/
```

The new extractor should implement the same interface used by the existing extractors:

```python
extract(headers, entrypoint, leaked_data, bit_buffers)
```

The extractor receives the HTTP headers, the current entrypoint, the dictionary containing reconstructed values, and the dictionary containing partial bit buffers.

Then register it in the server registry:

```python
EXTRACTORS = {
    "dedicatedheader": DedicatedHeaderExtractor(),
    "headersorder": HeadersOrderExtractor(),
    "newtechnique": NewTechniqueExtractor()
}
```

### 8.2 Add a new proxy sanitizer

Create a new module under:

```text
proxy/modules/
```

The new sanitizer should implement the same interface used by the existing sanitizers:

```python
sanitize(headers_list)
```

The sanitizer receives the request headers as an ordered list of `(key, value)` pairs and must return the sanitized list to forward to the malicious server.

Then register it in the proxy registry:

```python
SANITIZERS = {
    "dedicatedheader": DedicatedHeaderSanitizer(),
    "headersorder": HeadersOrderSanitizer(),
    "newtechnique": NewTechniqueSanitizer()
}
```

### 8.3 Add tests for the new technique

A new technique should include at least:

- one direct-server test proving that the malicious server can reconstruct the data;
- one proxy test proving that the same leak fails when routed through port `8000`.

---

## 9. Project structure

```text
progetto_dataleak/
├── README.md
├── docker-compose.yml
├── group_<groupname>.csv
├── test_complete.sh
├── test_server.sh
├── test_tec1.sh
├── test_tec2.sh
├── proxy/
│   ├── Dockerfile
│   ├── proxy.py
│   ├── requirements.txt
│   └── modules/
│       ├── base_module.py
│       ├── dedicated_header.py
│       └── headers_order.py
└── server/
    ├── Dockerfile
    ├── server.py
    ├── requirements.txt
    └── modules/
        ├── base_module.py
        ├── dedicated_header.py
        └── headers_order.py
```


# Authors
Leonardo Necordi, S5642683
Anna Beardo, S5633630
Luigi Trabucco, S5681875
